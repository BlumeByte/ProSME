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

const ok = (body: Record<string, unknown> = {}) => json(200, { ok: true, ...body });

const fail = (error: unknown) =>
  json(200, {
    ok: false,
    error: error instanceof Error ? error.message : String(error),
  });

const requiredEnv = (key: string) => {
  const value = Deno.env.get(key);
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};

const clean = (value: unknown) => String(value ?? '').trim();
const cleanNullable = (value: unknown) => {
  const normalized = clean(value);
  return normalized.length === 0 ? null : normalized;
};

const hasOwn = (source: Record<string, unknown>, key: string) =>
  Object.prototype.hasOwnProperty.call(source, key);

const numberOrZero = (value: unknown) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const validEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);

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

    if (!authorization.startsWith('Bearer ')) return fail('Missing developer session.');

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) return fail('Invalid developer session.');

    const { data: caller, error: callerError } = await userClient
      .from('profiles')
      .select('id,role,email')
      .eq('id', user.id)
      .maybeSingle();

    if (callerError) return fail(callerError.message);
    if (caller?.role !== 'developer') {
      return fail('Only developer accounts can use this action.');
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
      const phone = clean(body.phone);
      const country = clean(body.country);
      const location = clean(body.location);
      const password = clean(body.password) || randomPassword();
      const allowedRoles = new Set(['customer', 'artisan', 'developer']);

      if (!validEmail(email)) return fail('Valid email is required.');
      if (!allowedRoles.has(role)) return fail('Invalid role.');

      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName, role },
        app_metadata: { role },
      });

      if (error) return fail(error.message);
      const createdUser = data.user;

      const { error: profileError } = await adminClient.from('profiles').upsert({
        id: createdUser.id,
        email,
        full_name: fullName,
        phone,
        country: country || undefined,
        location,
        role,
        verification_status: role === 'artisan' ? 'pending' : 'verified',
      });

      if (profileError) return fail(profileError.message);
      const redirectTo = Deno.env.get('PASSWORD_RESET_REDIRECT_URL') || undefined;
      const { error: resetError } = await adminClient.auth.resetPasswordForEmail(email, { redirectTo });
      return ok({
        userId: createdUser.id,
        temporaryPassword: password,
        passwordResetSent: !resetError,
        warning: resetError?.message,
      });
    }

    if (action === 'bulkCreateUsers') {
      const accounts = Array.isArray(body.accounts) ? body.accounts : [];
      const created: Array<Record<string, unknown>> = [];
      const failed: Array<Record<string, unknown>> = [];
      const allowedRoles = new Set(['customer', 'artisan', 'developer']);

      for (const rawAccount of accounts.slice(0, 200)) {
        const account = rawAccount && typeof rawAccount === 'object' ? rawAccount as Record<string, unknown> : {};
        const email = clean(account.email).toLowerCase();
        const role = clean(account.role) || 'customer';
        const fullName = clean(account.full_name) || clean(account.name) || email.split('@')[0];
        const password = clean(account.password) || randomPassword();

        if (!validEmail(email)) {
          failed.push({ email, error: 'Valid email is required.' });
          continue;
        }
        if (!allowedRoles.has(role)) {
          failed.push({ email, error: 'Invalid role.' });
          continue;
        }

        const { data, error } = await adminClient.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { full_name: fullName, role },
          app_metadata: { role },
        });

        if (error || !data.user) {
          failed.push({ email, error: error?.message || 'Could not create user.' });
          continue;
        }

        const { error: profileError } = await adminClient.from('profiles').upsert({
          id: data.user.id,
          email,
          full_name: fullName,
          phone: clean(account.phone),
          country: cleanNullable(account.country),
          location: clean(account.location),
          role,
          verification_status: role === 'artisan' ? 'pending' : 'verified',
        });

        if (profileError) {
          failed.push({ email, error: profileError.message });
          continue;
        }

        const redirectTo = Deno.env.get('PASSWORD_RESET_REDIRECT_URL') || undefined;
        const { error: resetError } = await adminClient.auth.resetPasswordForEmail(email, { redirectTo });
        created.push({
          email,
          userId: data.user.id,
          temporaryPassword: password,
          passwordResetSent: !resetError,
          warning: resetError?.message,
        });
      }

      return ok({ created, failed });
    }

    if (action === 'updateProfile') {
      const id = clean(body.id);
      const patch = body.patch && typeof body.patch === 'object' ? body.patch as Record<string, unknown> : {};
      if (!id) return fail('Profile id is required.');

      const sanitized: Record<string, unknown> = {};
      for (const key of [
        'full_name',
        'phone',
        'country',
        'location',
        'role',
        'verification_status',
        'verification_notes',
        'verification_reviewed_at',
        'verification_retry_after',
      ]) {
        if (hasOwn(patch, key)) sanitized[key] = cleanNullable(patch[key]);
      }
      const { error } = await adminClient.from('profiles').update(sanitized).eq('id', id);
      if (error) return fail(error.message);
      return ok();
    }

    if (action === 'upsertListing') {
      const id = clean(body.id);
      const patch = body.patch && typeof body.patch === 'object' ? body.patch as Record<string, unknown> : {};
      const row = {
        title: clean(patch.title),
        description: clean(patch.description),
        category: clean(patch.category) || 'General',
        location: clean(patch.location),
        price_min: numberOrZero(patch.price_min),
        price_max: numberOrZero(patch.price_max),
        artisan_id: clean(patch.artisan_id),
        tenant_id: cleanNullable(patch.tenant_id),
      };
      const update = Object.fromEntries(
        Object.entries(row).filter(([, value]) => value !== '' && value !== null)
      );
      if (!id && !row.artisan_id) return fail('Artisan owner is required.');
      if (!id && !row.title) return fail('Listing title is required.');

      const query = id
        ? adminClient.from('listings').update(update).eq('id', id).select('id').maybeSingle()
        : adminClient.from('listings').insert(update).select('id').maybeSingle();
      const { data, error } = await query;
      if (error) return fail(error.message);
      return ok({ id: data?.id || id });
    }

    if (action === 'deleteListing') {
      const id = clean(body.id);
      if (!id) return fail('Listing id is required.');
      const { error } = await adminClient.from('listings').delete().eq('id', id);
      if (error) return fail(error.message);
      return ok();
    }

    if (action === 'upsertJob') {
      const id = clean(body.id);
      const patch = body.patch && typeof body.patch === 'object' ? body.patch as Record<string, unknown> : {};
      const row = {
        title: clean(patch.title),
        description: clean(patch.description),
        location: clean(patch.location),
        budget: numberOrZero(patch.budget),
        status: clean(patch.status) || 'active',
        created_by: clean(patch.created_by),
        tenant_id: cleanNullable(patch.tenant_id),
      };
      const update = Object.fromEntries(
        Object.entries(row).filter(([, value]) => value !== '' && value !== null)
      );
      if (!id && !row.created_by) return fail('Job owner is required.');
      if (!id && !row.title) return fail('Job title is required.');

      const query = id
        ? adminClient.from('jobs').update(update).eq('id', id).select('id').maybeSingle()
        : adminClient.from('jobs').insert(update).select('id').maybeSingle();
      const { data, error } = await query;
      if (error) return fail(error.message);
      return ok({ id: data?.id || id });
    }

    if (action === 'deleteJob') {
      const id = clean(body.id);
      if (!id) return fail('Job id is required.');
      const { error } = await adminClient.from('jobs').delete().eq('id', id);
      if (error) return fail(error.message);
      return ok();
    }

    if (action === 'sendPasswordReset') {
      const email = clean(body.email).toLowerCase();
      if (!validEmail(email)) return fail('Valid email is required.');

      const redirectTo = Deno.env.get('PASSWORD_RESET_REDIRECT_URL') || undefined;
      const { error } = await adminClient.auth.resetPasswordForEmail(email, { redirectTo });
      if (error) return fail(error.message);
      return ok();
    }

    if (action === 'setPassword') {
      const userId = clean(body.userId);
      const password = clean(body.password) || randomPassword();
      if (!userId) return fail('User id is required.');

      const { error } = await adminClient.auth.admin.updateUserById(userId, { password });
      if (error) return fail(error.message);
      return ok({ temporaryPassword: password });
    }

    return fail('Unknown developer action.');
  } catch (error) {
    return fail(error);
  }
});
