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

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};

const clean = (value: unknown) => String(value ?? '').trim();

const randomPassword = () => {
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  const token = btoa(String.fromCharCode(...bytes)).replace(/[^a-zA-Z0-9]/g, '').slice(0, 12);
  return `${token}Aa!7`;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' });

  try {
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const anonKey = requiredEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const authorization = req.headers.get('Authorization') || '';

    if (!authorization.startsWith('Bearer ')) {
      return json(401, { error: 'Missing developer session.' });
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) return json(401, { error: 'Invalid developer session.' });

    const { data: caller, error: callerError } = await userClient
      .from('profiles')
      .select('id,role,email')
      .eq('id', user.id)
      .maybeSingle();

    if (callerError) return json(500, { error: callerError.message });
    if (caller?.role !== 'developer') {
      return json(403, { error: 'Only developer accounts can use this action.' });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json().catch(() => ({}));
    const action = clean(body.action);

    if (action === 'createUser') {
      const email = clean(body.email).toLowerCase();
      const role = clean(body.role) || 'customer';
      const fullName = clean(body.full_name) || email.split('@')[0];
      const password = clean(body.password) || randomPassword();
      const allowedRoles = new Set(['customer', 'artisan', 'developer']);

      if (!email || !email.includes('@')) return json(400, { error: 'Valid email is required.' });
      if (!allowedRoles.has(role)) return json(400, { error: 'Invalid role.' });

      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
        app_metadata: { role },
      });

      if (error) return json(400, { error: error.message });
      const createdUser = data.user;

      const { error: profileError } = await adminClient.from('profiles').upsert({
        id: createdUser.id,
        email,
        full_name: fullName,
        role,
        verification_status: role === 'artisan' ? 'pending' : 'verified',
      });

      if (profileError) return json(400, { error: profileError.message });
      return json(200, { ok: true, userId: createdUser.id, temporaryPassword: password });
    }

    if (action === 'sendPasswordReset') {
      const email = clean(body.email).toLowerCase();
      if (!email || !email.includes('@')) return json(400, { error: 'Valid email is required.' });

      const redirectTo = Deno.env.get('PASSWORD_RESET_REDIRECT_URL') || undefined;
      const { error } = await adminClient.auth.resetPasswordForEmail(email, { redirectTo });
      if (error) return json(400, { error: error.message });
      return json(200, { ok: true });
    }

    if (action === 'setPassword') {
      const userId = clean(body.userId);
      const password = clean(body.password) || randomPassword();
      if (!userId) return json(400, { error: 'User id is required.' });

      const { error } = await adminClient.auth.admin.updateUserById(userId, { password });
      if (error) return json(400, { error: error.message });
      return json(200, { ok: true, temporaryPassword: password });
    }

    return json(400, { error: 'Unknown developer action.' });
  } catch (error) {
    return json(500, { error: error instanceof Error ? error.message : String(error) });
  }
});
