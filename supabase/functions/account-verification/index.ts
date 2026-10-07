import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';
import { sendMail } from '../_shared/mailer.ts';

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

const timingSafeEqual = (a: string, b: string) => {
  const encoder = new TextEncoder();
  const x = encoder.encode(a);
  const y = encoder.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
};

const clientIp = (req: Request) =>
  (
    req.headers.get('cf-connecting-ip') ||
    req.headers.get('x-forwarded-for') ||
    'unknown'
  )
    .split(',')[0]
    .trim() || 'unknown';

// Fixed-window counter (public.rate_limit_hit). Fails open on a database error
// so a transient outage does not lock everyone out of verification.
const allowRequest = async (
  adminClient: ReturnType<typeof createClient>,
  bucket: string,
  max: number,
  windowSeconds: number,
) => {
  const { data, error } = await adminClient.rpc('rate_limit_hit', {
    p_bucket: bucket,
    p_max: max,
    p_window_seconds: windowSeconds,
  });
  if (error) {
    console.error('rate limit check failed', error.message);
    return true;
  }
  return data === true;
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
  const body = `Your ProSME verification code is ${code}. It expires in 10 minutes.`;
  await sendMail({
    to,
    subject: 'Your ProSME verification code',
    text: body,
    html: `<p>${escapeHtml(body)}</p>`,
  });
};

const phoneForTwilio = (phone: string) => {
  const compact = clean(phone).replace(/[\s()-]/g, '');
  if (/^\+[1-9]\d{7,14}$/.test(compact)) return compact;
  if (/^0\d{8,13}$/.test(compact)) return `+233${compact.slice(1)}`;
  return compact;
};

const twilioVerifyConfig = () => {
  const serviceSid = env('TWILIO_VERIFY_SERVICE_SID') || (env('TWILIO_ACCOUNT_SID').startsWith('VA') ? env('TWILIO_ACCOUNT_SID') : '');
  const username = env('TWILIO_API_KEY_SID') || (env('TWILIO_ACCOUNT_SID').startsWith('AC') ? env('TWILIO_ACCOUNT_SID') : '');
  const password = env('TWILIO_API_KEY_SECRET') || env('TWILIO_AUTH_TOKEN');
  if (!serviceSid || !username || !password) {
    throw new Error('SMS verification is not configured. Add TWILIO_VERIFY_SERVICE_SID plus TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN or TWILIO_API_KEY_SID/TWILIO_API_KEY_SECRET secrets.');
  }
  return { serviceSid, username, password };
};

const twilioVerifyRequest = async (path: string, params: URLSearchParams) => {
  const { serviceSid, username, password } = twilioVerifyConfig();
  const response = await fetch(`https://verify.twilio.com/v2/Services/${serviceSid}/${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${btoa(`${username}:${password}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(clean(payload?.message) || clean(payload?.error_message) || 'SMS verification request failed.');
  }
  return payload;
};

const sendPhoneVerification = async (to: string) => {
  const body = new URLSearchParams({
    To: to,
    Channel: 'sms',
  });
  await twilioVerifyRequest('Verifications', body);
};

const checkPhoneVerification = async (to: string, code: string) => {
  const body = new URLSearchParams({
    To: to,
    Code: code,
  });
  const payload = await twilioVerifyRequest('VerificationCheck', body);
  return clean(payload?.status) === 'approved' || payload?.valid === true;
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
      const destination = channel === 'email' ? clean(profile.email || user.email).toLowerCase() : phoneForTwilio(clean(profile.phone || user.phone));
      if (!destination) return json(200, { ok: false, error: channel === 'email' ? 'No email address is saved.' : 'No phone number is saved.' });
      // The destination is whatever the user typed into their own profile, so
      // without limits this would send SMS/e-mail to arbitrary third parties
      // (harassment, SMS pumping). Cap per user, per destination and per IP.
      const ip = clientIp(req);
      if (
        !(await allowRequest(adminClient, `verify-req-user:${user.id}`, 6, 3600)) ||
        !(await allowRequest(adminClient, `verify-req-dest:${channel}:${destination}`, 3, 3600)) ||
        !(await allowRequest(adminClient, `verify-req-ip:${ip}`, 20, 3600)) ||
        (channel === 'phone' &&
          !(await allowRequest(adminClient, `verify-sms-dest:${destination}`, 5, 86400)))
      ) {
        return json(200, { ok: false, error: 'Too many requests. Please try again later.' });
      }
      if (channel === 'phone') {
        if (!/^\+[1-9]\d{7,14}$/.test(destination)) {
          return json(200, { ok: false, error: 'Enter the phone number with country code, for example +233256122555.' });
        }
        await sendPhoneVerification(destination);
        return json(200, { ok: true });
      }

      const code = randomCode();
      const codeHash = await hashCode(user.id, channel, code);

      // Keep any previous unused code valid until the replacement email is
      // actually sent. If delivery fails, remove the unsent replacement so
      // the user is not left with an active code they never received.
      const { data: inserted, error: insertError } = await adminClient
        .from('profile_verification_codes')
        .insert({
          user_id: user.id,
          channel,
          destination,
          code_hash: codeHash,
          expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
        })
        .select('id')
        .single();
      if (insertError) throw new Error(insertError.message);

      try {
        await sendEmail(destination, code);
      } catch (error) {
        await adminClient
          .from('profile_verification_codes')
          .delete()
          .eq('id', inserted.id);
        throw error;
      }

      await adminClient
        .from('profile_verification_codes')
        .update({ consumed_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('channel', channel)
        .neq('id', inserted.id)
        .is('consumed_at', null);

      return json(200, { ok: true });
    }

    if (action === 'verifyEmailCode' || action === 'verifyPhoneCode') {
      const code = clean(body.code).replace(/\s+/g, '');
      if (!/^\d{6}$/.test(code)) return json(200, { ok: false, error: 'Enter the 6-digit code.' });
      if (!(await allowRequest(adminClient, `verify-check-user:${user.id}`, 20, 3600))) {
        return json(200, { ok: false, error: 'Too many attempts. Please try again later.' });
      }
      if (channel === 'phone') {
        const destination = phoneForTwilio(clean(profile.phone || user.phone));
        if (!/^\+[1-9]\d{7,14}$/.test(destination)) {
          return json(200, { ok: false, error: 'Enter the phone number with country code, for example +233256122555.' });
        }
        const approved = await checkPhoneVerification(destination, code);
        if (!approved) return json(200, { ok: false, error: 'Invalid verification code.' });
        const { error: updateError } = await adminClient
          .from('profiles')
          .update({ phone_verified: true })
          .eq('id', user.id);
        if (updateError) throw new Error(updateError.message);
        return json(200, { ok: true });
      }

      const codeHash = await hashCode(user.id, channel, code);
      // Always load the newest unused code (not "the one matching this guess"):
      // a wrong guess must count against it, otherwise the 5-attempt cap never
      // triggers and the 6-digit code can be brute-forced inside its window.
      const { data: latest, error: findError } = await adminClient
        .from('profile_verification_codes')
        .select('id,code_hash,destination,attempt_count,expires_at')
        .eq('user_id', user.id)
        .eq('channel', channel)
        .is('consumed_at', null)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (findError) throw new Error(findError.message);
      if (!latest) return json(200, { ok: false, error: 'Invalid verification code.' });
      if (new Date(clean(latest.expires_at)).getTime() < Date.now()) {
        return json(200, { ok: false, error: 'Verification code expired.' });
      }
      const attempts = latest.attempt_count ?? 0;
      if (attempts >= 5) {
        return json(200, { ok: false, error: 'Too many attempts. Request a new code.' });
      }
      // The code proves ownership of the address it was SENT to, which must
      // still be the address on the profile (it can be edited in between).
      const currentEmail = clean(profile.email || user.email).toLowerCase();
      if (
        !timingSafeEqual(clean(latest.code_hash), codeHash) ||
        clean(latest.destination).toLowerCase() !== currentEmail
      ) {
        await adminClient
          .from('profile_verification_codes')
          .update({ attempt_count: attempts + 1 })
          .eq('id', latest.id);
        return json(200, { ok: false, error: 'Invalid verification code.' });
      }

      await adminClient
        .from('profile_verification_codes')
        .update({ consumed_at: new Date().toISOString(), attempt_count: attempts + 1 })
        .eq('id', latest.id);
      const { error: updateError } = await adminClient
        .from('profiles')
        .update(channel === 'email' ? { email_verified: true } : { phone_verified: true })
        .eq('id', user.id);
      if (updateError) throw new Error(updateError.message);
      return json(200, { ok: true });
    }

    return json(200, { ok: false, error: 'Unknown verification action.' });
  } catch (error) {
    console.error('account-verification failed', error);
    return json(200, {
      ok: false,
      error: 'Verification request failed. Please try again.',
    });
  }
});
