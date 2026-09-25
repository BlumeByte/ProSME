import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-email-dispatch-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type PushRow = {
  id: string;
  related_user_id: string;
  title: string;
  body: string | null;
  data: Record<string, unknown> | null;
  attempt_count: number | null;
};

type DeviceToken = { id: string; fcm_token: string };

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key)?.trim();
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};

const clean = (value: unknown) => String(value ?? '').trim();

const base64UrlFromBytes = (bytes: ArrayBuffer | Uint8Array) => {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let str = '';
  for (const byte of arr) str += String.fromCharCode(byte);
  return btoa(str).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
};

const base64UrlFromJson = (value: unknown) =>
  base64UrlFromBytes(new TextEncoder().encode(JSON.stringify(value)));

// Firebase service account private keys are PKCS8 PEM; strip the markers and
// whitespace (handles both literal and \n-escaped secrets) before decoding.
const importPrivateKey = async (pem: string) => {
  const contents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  const binary = Uint8Array.from(atob(contents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
};

const getFcmAccessToken = async (clientEmail: string, privateKeyPem: string) => {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64UrlFromJson(header)}.${base64UrlFromJson(claims)}`;
  const key = await importPrivateKey(privateKeyPem);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64UrlFromBytes(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    throw new Error(clean(payload?.error_description) || 'Could not obtain an FCM access token.');
  }
  return clean(payload.access_token) as string;
};

type FcmError = Error & { code?: string };

const sendFcm = async ({
  projectId,
  accessToken,
  fcmToken,
  title,
  body,
  data,
}: {
  projectId: string;
  accessToken: string;
  fcmToken: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
}) => {
  const stringData: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value !== null && value !== undefined) stringData[key] = String(value);
  }
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data: stringData,
          android: { priority: 'high' },
          apns: { headers: { 'apns-priority': '10' }, payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    const err = new Error(
      clean(payload?.error?.message) || `FCM returned HTTP ${response.status}`,
    ) as FcmError;
    err.code = clean(payload?.error?.status);
    throw err;
  }
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { ok: false, error: 'Method not allowed' });

  const dispatchSecret = Deno.env.get('EMAIL_DISPATCH_SECRET');
  if (!dispatchSecret || req.headers.get('x-email-dispatch-secret') !== dispatchSecret) {
    return json(401, { ok: false, error: 'Unauthorized' });
  }

  try {
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const firebaseProjectId = requiredEnv('FIREBASE_PROJECT_ID');
    const firebaseClientEmail = requiredEnv('FIREBASE_CLIENT_EMAIL');
    const firebasePrivateKey = requiredEnv('FIREBASE_PRIVATE_KEY');

    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Math.max(Number(body.limit || 25), 1), 50);
    const maxAttempts = Math.min(Math.max(Number(body.maxAttempts || 5), 1), 10);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await adminClient
      .from('push_outbox')
      .select('id,related_user_id,title,body,data,attempt_count')
      .is('sent_at', null)
      .lt('attempt_count', maxAttempts)
      .order('created_at', { ascending: true })
      .limit(limit);
    if (error) throw new Error(error.message);

    const rows = (data ?? []) as PushRow[];
    if (rows.length === 0) return json(200, { ok: true, sent: [], failed: [] });

    const accessToken = await getFcmAccessToken(firebaseClientEmail, firebasePrivateKey);

    const sent: string[] = [];
    const failed: Array<{ id: string; error: string }> = [];

    for (const row of rows) {
      try {
        const { data: tokens, error: tokensError } = await adminClient
          .from('device_tokens')
          .select('id,fcm_token')
          .eq('user_id', row.related_user_id);
        if (tokensError) throw new Error(tokensError.message);

        const deviceTokens = (tokens ?? []) as DeviceToken[];
        if (deviceTokens.length === 0) {
          await adminClient
            .from('push_outbox')
            .update({ sent_at: new Date().toISOString(), last_error: 'No device registered.' })
            .eq('id', row.id);
          continue;
        }

        let delivered = false;
        let lastError = '';
        for (const device of deviceTokens) {
          try {
            await sendFcm({
              projectId: firebaseProjectId,
              accessToken,
              fcmToken: device.fcm_token,
              title: row.title,
              body: row.body ?? '',
              data: row.data ?? {},
            });
            delivered = true;
          } catch (deviceError) {
            const fcmError = deviceError as FcmError;
            if (fcmError.code === 'UNREGISTERED' || fcmError.code === 'NOT_FOUND') {
              await adminClient.from('device_tokens').delete().eq('id', device.id);
            } else {
              lastError = fcmError.message;
            }
          }
        }

        if (delivered) {
          await adminClient
            .from('push_outbox')
            .update({ sent_at: new Date().toISOString(), last_error: null })
            .eq('id', row.id);
          sent.push(row.id);
        } else {
          throw new Error(lastError || 'No device accepted the push.');
        }
      } catch (rowError) {
        const message = rowError instanceof Error ? rowError.message : String(rowError);
        failed.push({ id: row.id, error: message });
        await adminClient
          .from('push_outbox')
          .update({
            attempt_count: (row.attempt_count ?? 0) + 1,
            last_attempt_at: new Date().toISOString(),
            last_error: message,
          })
          .eq('id', row.id);
      }
    }

    return json(200, { ok: true, sent, failed });
  } catch (error) {
    console.error('send-push-outbox failed', error);
    return json(200, { ok: false, error: 'Push dispatch failed. Check Edge Function logs.' });
  }
});
