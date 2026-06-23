import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const clean = (value: unknown) => String(value ?? '').trim();
const env = (key: string) => clean(Deno.env.get(key));
const requiredEnv = (key: string) => {
  const value = env(key);
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};
const validEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);

const sha256 = async (value: string) => {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
};

const allowedRedirect = (value: string) => {
  const configured = env('PASSWORD_RESET_ALLOWED_REDIRECTS')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const allowed = new Set([
    'com.prosme.app://login-callback',
    'https://prosme.vercel.app/reset-password',
    ...configured,
  ]);
  if (!allowed.has(value)) throw new Error('Password reset redirect is not allowed.');
  return value;
};

const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const sendEmail = async (email: string, actionLink: string) => {
  const apiKey = requiredEnv('RESEND_API_KEY');
  const from = env('RESEND_FROM_EMAIL') ||
    env('PROSME_FROM_EMAIL') ||
    'ProSME <noreply@blumebyte.com>';
  const safeLink = escapeHtml(actionLink);
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: 'Reset your ProSME password',
      text: `Use this secure link to choose a new ProSME password: ${actionLink}`,
      html: `<p>Use the button below to choose a new ProSME password.</p><p><a href="${safeLink}" style="display:inline-block;padding:12px 18px;background:#0f1b3d;color:#fff;text-decoration:none;border-radius:6px">Reset password</a></p><p>If you did not request this, you can ignore this email.</p>`,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      clean(payload?.message) || clean(payload?.error) || `Resend returned HTTP ${response.status}`,
    );
  }
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ ok: false, error: 'Method not allowed.' });

  try {
    const body = await req.json().catch(() => ({}));
    const email = clean(body.email).toLowerCase();
    if (!validEmail(email)) return json({ ok: false, error: 'Enter a valid email address.' });
    const redirectTo = allowedRedirect(clean(body.redirectTo));
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const emailHash = await sha256(email);
    await admin
      .from('password_recovery_attempts')
      .delete()
      .lt('requested_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());
    const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    const { data: recent, error: rateError } = await admin
      .from('password_recovery_attempts')
      .select('requested_at')
      .eq('email_hash', emailHash)
      .gte('requested_at', since)
      .order('requested_at', { ascending: false })
      .limit(3);
    if (rateError) throw new Error(rateError.message);
    if ((recent?.length ?? 0) >= 3) return json({ ok: true });
    const latest = clean(recent?.[0]?.requested_at);
    if (latest && Date.now() - new Date(latest).getTime() < 60 * 1000) {
      return json({ ok: true });
    }

    const { error: insertError } = await admin
      .from('password_recovery_attempts')
      .insert({ email_hash: emailHash });
    if (insertError) throw new Error(insertError.message);

    const { data, error: linkError } = await admin.auth.admin.generateLink({
      type: 'recovery',
      email,
      options: { redirectTo },
    });
    if (linkError) {
      if (linkError.message.toLowerCase().includes('user')) return json({ ok: true });
      throw new Error(linkError.message);
    }
    const actionLink = clean(data?.properties?.action_link);
    if (!actionLink) throw new Error('Supabase did not return a recovery link.');
    await sendEmail(email, actionLink);
    return json({ ok: true });
  } catch (error) {
    return json({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
