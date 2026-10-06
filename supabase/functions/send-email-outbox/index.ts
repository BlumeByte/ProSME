import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';
import { sendMail } from '../_shared/mailer.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-email-dispatch-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type EmailRow = {
  id: string;
  to_email: string | null;
  subject: string;
  body: string;
  html: string | null;
  related_user_id: string | null;
  attempt_count: number | null;
};

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

const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const toHtml = (body: string) =>
  `<div style="font-family:Arial,sans-serif;font-size:15px;line-height:1.55;color:#111827;">${escapeHtml(
    body,
  ).replaceAll('\n', '<br>')}</div>`;

const humanizeBody = (body: string) => {
  const value = clean(body);
  if (!value.startsWith('{') && !value.startsWith('[')) return value;
  try {
    const parsed = JSON.parse(value);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return value;
    }
    const record = parsed as Record<string, unknown>;
    const candidates = [
      clean(record.message),
      clean(record.body),
      clean(record.content),
      clean(record.title),
      clean(record.description),
    ].filter(Boolean);
    if (candidates.length) return candidates.join('\n\n');
    const lines = Object.entries(record)
      .filter(([, field]) => field !== null && field !== undefined)
      .slice(0, 8)
      .map(([key, field]) => `${key.replaceAll('_', ' ')}: ${clean(field)}`);
    return lines.length ? lines.join('\n') : value;
  } catch (_) {
    return value;
  }
};

const timingSafeEqual = (a: string, b: string) => {
  const encoder = new TextEncoder();
  const x = encoder.encode(a);
  const y = encoder.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
};

const authorize = async (
  req: Request,
  supabaseUrl: string,
  anonKey: string,
) => {
  const dispatchSecret = Deno.env.get('EMAIL_DISPATCH_SECRET');
  if (
    dispatchSecret &&
    timingSafeEqual(
      req.headers.get('x-email-dispatch-secret') || '',
      dispatchSecret,
    )
  ) {
    return { userId: null, canDispatchAll: true };
  }

  const authorization = req.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) {
    throw new Error('Missing session.');
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();
  if (userError || !user) throw new Error('Invalid session.');

  const { data: profile, error: profileError } = await userClient
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();
  if (profileError) throw new Error(profileError.message);
  return {
    userId: user.id,
    canDispatchAll: clean(profile?.role) === 'admin',
  };
};

const resolveRecipient = async (
  adminClient: ReturnType<typeof createClient>,
  row: EmailRow,
) => {
  const direct = clean(row.to_email).toLowerCase();
  if (direct) return direct;
  if (!row.related_user_id) return '';

  const { data, error } = await adminClient
    .from('profiles')
    .select('email')
    .eq('id', row.related_user_id)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return clean(data?.email).toLowerCase();
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { ok: false, error: 'Method not allowed' });

  try {
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const anonKey = requiredEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');

    const auth = await authorize(req, supabaseUrl, anonKey);

    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Math.max(Number(body.limit || 20), 1), 50);
    const maxAttempts = Math.min(Math.max(Number(body.maxAttempts || 5), 1), 10);
    const requestedRelatedUserId = clean(body.relatedUserId);

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let query = adminClient
      .from('email_outbox')
      .select('id,to_email,subject,body,html,related_user_id,attempt_count')
      .is('sent_at', null)
      .lt('attempt_count', maxAttempts)
      .order('created_at', { ascending: true });
    if (auth.canDispatchAll && requestedRelatedUserId) {
      query = query.eq('related_user_id', requestedRelatedUserId);
    } else if (!auth.canDispatchAll) {
      query = query.eq('related_user_id', auth.userId);
    }
    const { data, error } = await query.limit(limit);
    if (error) throw new Error(error.message);

    const sent: string[] = [];
    const failed: Array<{ id: string; error: string }> = [];

    for (const row of (data ?? []) as EmailRow[]) {
      try {
        const to = await resolveRecipient(adminClient, row);
        if (!to) throw new Error('Missing recipient email.');

        const text = humanizeBody(row.body);
        const transportId = await sendMail({
          to,
          subject: row.subject,
          text,
          html: row.html ?? toHtml(text),
        });

        const { error: updateError } = await adminClient
          .from('email_outbox')
          .update({
            sent_at: new Date().toISOString(),
            last_attempt_at: new Date().toISOString(),
            last_error: null,
            resend_message_id: transportId,
          })
          .eq('id', row.id);
        if (updateError) throw new Error(updateError.message);
        sent.push(row.id);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        failed.push({ id: row.id, error: message });
        await adminClient
          .from('email_outbox')
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
    console.error('send-email-outbox failed', error);
    return json(200, {
      ok: false,
      error: 'Email dispatch failed. Check Edge Function logs.',
    });
  }
});
