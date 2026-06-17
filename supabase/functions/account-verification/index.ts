import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const clean = (value: unknown) => String(value ?? '').trim();

const env = (key: string) => clean(Deno.env.get(key));

const requiredEnv = (key: string) => {
  const value = env(key);
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};

const randomCode = () => {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  const value =
    ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) >>> 0;
  return String(100000 + (value % 900000));
};

const hashCode = async (userId: string, channel: string, code: string) => {
  const secret = requiredEnv('VERIFICATION_CODE_SECRET');
  const data = new TextEncoder().encode(`${secret}:${userId}:${channel}:${code}`);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
};

const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const sendEmail = async (to: string, code: string) => {
  const apiKey = requiredEnv('RESEND_API_KEY');
  const from = env('RESEND_FROM_EMAIL') || 'ProSME <noreply@blumebyte.com>';
  const body = `Your ProSME verification code is ${code}. It expires in 10 minutes.`;
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: 'Your ProSME verification code',
      text: body,
      html: `<p>${escapeHtml(body)}</p>`,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(clean(payload?.message) || clean(payload?.error) || 'Email could not be sent.');
  }
};

const sendSms = async (to: string, code: string) => {
  const accountSid = env('TWILIO_ACCOUNT_SID');
  const authToken = env('TWILIO_AUTH_TOKEN');
  const from = env('TWILIO_FROM_PHONE');
  if (!accountSid || !authToken || !from) {
    throw new Error('SMS delivery is not configured. Add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM_PHONE secrets.');
  }
  const body = new URLSearchParams({
    From: from,
    To: to,
    Body: `Your ProSME verification code is ${code}. It expires in 10 minutes.`,
  });
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(clean(payload?.message) || 'SMS could not be sent.');
  }
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { ok: false, error: 'Method not allowed' });

  try {
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const anonKey = requiredEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const authorization = req.headers.get('Authorization') || '';
    if (!authorization.startsWith('Bearer ')) return json(200, { ok: false, error: 'Missing session.' });

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) return json(200, { ok: false, error: 'Invalid session.' });

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const body = await req.json().catch(() => ({}));
    const action = clean(body.action);
    const channel = action.toLowerCase().includes('phone') ? 'phone' : 'email';

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('id,email,phone')
      .eq('id', user.id)
      .maybeSingle();
    if (profileError) throw new Error(profileError.message);
    if (!profile) return json(200, { ok: false, error: 'Profile was not found.' });

    if (action === 'requestEmailCode' || action === 'requestPhoneCode') {
      const destination = channel === 'email' ? clean(profile.email || user.email).toLowerCase() : clean(profile.phone || user.phone);
      if (!destination) return json(200, { ok: false, error: channel === 'email' ? 'No email address is saved.' : 'No phone number is saved.' });
      if (channel === 'phone' && (!env('TWILIO_ACCOUNT_SID') || !env('TWILIO_AUTH_TOKEN') || !env('TWILIO_FROM_PHONE'))) {
        return json(200, {
          ok: false,
          error: 'SMS delivery is not configured. Add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_FROM_PHONE secrets.',
        });
      }

      const code = randomCode();
      const codeHash = await hashCode(user.id, channel, code);
      await adminClient
        .from('profile_verification_codes')
        .update({ consumed_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('channel', channel)
        .is('consumed_at', null);

      const { error: insertError } = await adminClient
        .from('profile_verification_codes')
        .insert({
          user_id: user.id,
          channel,
          destination,
          code_hash: codeHash,
          expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
        });
      if (insertError) throw new Error(insertError.message);

      if (channel === 'email') {
        await sendEmail(destination, code);
      } else {
        await adminClient.from('sms_outbox').insert({
          to_phone: destination,
          body: 'A ProSME phone verification code was requested.',
          related_user_id: user.id,
        });
        await sendSms(destination, code);
      }
      return json(200, { ok: true });
    }

    if (action === 'verifyEmailCode' || action === 'verifyPhoneCode') {
      const code = clean(body.code).replace(/\s+/g, '');
      if (!/^\d{6}$/.test(code)) return json(200, { ok: false, error: 'Enter the 6-digit code.' });
      const codeHash = await hashCode(user.id, channel, code);
      const { data: existing, error: findError } = await adminClient
        .from('profile_verification_codes')
        .select('id,attempt_count,expires_at')
        .eq('user_id', user.id)
        .eq('channel', channel)
        .eq('code_hash', codeHash)
        .is('consumed_at', null)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (findError) throw new Error(findError.message);
      if (!existing) return json(200, { ok: false, error: 'Invalid verification code.' });
      if (new Date(clean(existing.expires_at)).getTime() < Date.now()) {
        return json(200, { ok: false, error: 'Verification code expired.' });
      }
      if ((existing.attempt_count ?? 0) >= 5) {
        return json(200, { ok: false, error: 'Too many attempts. Request a new code.' });
      }

      await adminClient
        .from('profile_verification_codes')
        .update({ consumed_at: new Date().toISOString(), attempt_count: (existing.attempt_count ?? 0) + 1 })
        .eq('id', existing.id);
      const { error: updateError } = await adminClient
        .from('profiles')
        .update(channel === 'email' ? { email_verified: true } : { phone_verified: true })
        .eq('id', user.id);
      if (updateError) throw new Error(updateError.message);
      return json(200, { ok: true });
    }

    return json(200, { ok: false, error: 'Unknown verification action.' });
  } catch (error) {
    return json(200, {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
