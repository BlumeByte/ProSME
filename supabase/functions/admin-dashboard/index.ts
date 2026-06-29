import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const ok = (body: Record<string, unknown> = {}) =>
  json(200, { ok: true, ...body });

const fail = (error: unknown) =>
  json(200, {
    ok: false,
    error: typeof error === 'string' ? error : 'Admin request failed.',
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

const verificationAmountUsdFor = (role: string) => (role === 'artisan' ? 5 : 2);

const verificationPeriodEnd = (interval: string) => {
  const end = new Date();
  if (interval === 'yearly') {
    end.setUTCFullYear(end.getUTCFullYear() + 1);
  } else {
    end.setUTCMonth(end.getUTCMonth() + 1);
  }
  return end.toISOString();
};

const approvePaidVerification = async ({
  adminClient,
  userId,
  adminId,
  notes,
}: {
  adminClient: ReturnType<typeof createClient>;
  userId: string;
  adminId: string;
  notes: string;
}) => {
  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('id,email,role')
    .eq('id', userId)
    .maybeSingle();
  if (profileError) throw new Error(profileError.message);
  if (!profile) throw new Error('Profile not found.');
  const role = clean(profile.role) === 'artisan' ? 'artisan' : 'customer';
  const now = new Date().toISOString();

  const { data: subscription, error: subscriptionError } = await adminClient
    .from('verification_subscriptions')
    .select('id,status,current_period_end')
    .eq('user_id', userId)
    .maybeSingle();
  if (subscriptionError) throw new Error(subscriptionError.message);
  if (!subscription || clean(subscription.status) !== 'paid_pending_review') {
    throw new Error('Paystack payment must be confirmed before approval.');
  }

  await adminClient
    .from('verification_subscriptions')
    .update({
      status: 'active',
      admin_approved_by: adminId,
      admin_approved_at: now,
      updated_at: now,
    })
    .eq('id', subscription.id);

  await adminClient
    .from('profiles')
    .update({
      verification_status: 'verified',
      verification_notes: notes,
      verification_reviewed_at: now,
      verification_retry_after: null,
      verification_expires_at: subscription.current_period_end,
    })
    .eq('id', userId);

  await adminClient.from('admin_notifications').insert({
    type: 'verification_approved',
    title: 'Verification approved',
    body: `${role} documents and payment were approved. The badge is active.`,
    actor_id: adminId,
    related_user_id: userId,
    related_table: 'verification_subscriptions',
    related_id: subscription?.id,
  });

  await adminClient.from('email_outbox').insert({
    to_email: null,
    subject: 'Your ProSME verification was approved',
    body: 'Your payment and documents were approved. Your public verification badge is active.',
    related_user_id: userId,
  });
};

const overrideVerificationPaid = async ({
  adminClient,
  userId,
  adminId,
  notes,
  interval,
}: {
  adminClient: ReturnType<typeof createClient>;
  userId: string;
  adminId: string;
  notes: string;
  interval: string;
}) => {
  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('id,email,role')
    .eq('id', userId)
    .maybeSingle();
  if (profileError) throw new Error(profileError.message);
  if (!profile) throw new Error('Profile not found.');

  const role = clean(profile.role) === 'artisan' ? 'artisan' : 'customer';
  const planInterval = clean(interval) === 'yearly' ? 'yearly' : 'monthly';
  const now = new Date().toISOString();
  const end = verificationPeriodEnd(planInterval);
  const reference = `admin_override_${userId.replaceAll('-', '').slice(0, 12)}_${Date.now()}`;
  const amountUsd =
    verificationAmountUsdFor(role) * (planInterval === 'yearly' ? 12 : 1);

  const { data: subscription, error: subscriptionError } = await adminClient
    .from('verification_subscriptions')
    .upsert(
      {
        user_id: userId,
        role,
        plan_interval: planInterval,
        status: 'active',
        amount_usd: amountUsd,
        charge_currency: clean(Deno.env.get('PAYSTACK_CURRENCY')) || 'GHS',
        charge_amount: 0,
        paystack_reference: reference,
        current_period_start: now,
        current_period_end: end,
        last_payment_at: now,
        auto_renew: false,
        admin_approved_by: adminId,
        admin_approved_at: now,
        updated_at: now,
      },
      { onConflict: 'user_id' },
    )
    .select('id')
    .maybeSingle();
  if (subscriptionError) throw new Error(subscriptionError.message);

  await adminClient.from('verification_payments').upsert(
    {
      subscription_id: subscription?.id,
      user_id: userId,
      role,
      plan_interval: planInterval,
      status: 'success',
      amount_usd: amountUsd,
      charge_currency: clean(Deno.env.get('PAYSTACK_CURRENCY')) || 'GHS',
      charge_amount: 0,
      paystack_reference: reference,
      gateway_response: 'Admin marked paid and verified',
      paid_at: now,
      raw_payload: { source: 'admin_override', admin_id: adminId, notes },
    },
    { onConflict: 'paystack_reference' },
  );

  await adminClient
    .from('profiles')
    .update({
      verification_status: 'verified',
      verification_notes: notes,
      verification_expires_at: end,
      verification_reviewed_at: now,
      verification_retry_after: null,
    })
    .eq('id', userId);

  await adminClient.from('admin_notifications').insert({
    type: 'verification_admin_override',
    title: 'Verification manually activated',
    body: `${role} verification was marked paid and active by admin.`,
    actor_id: adminId,
    related_user_id: userId,
    related_table: 'verification_subscriptions',
    related_id: subscription?.id,
  });

  await adminClient.from('email_outbox').insert({
    to_email: null,
    subject: 'Your ProSME verification is active',
    body: `Your verification badge is active until ${new Date(end).toDateString()}.`,
    related_user_id: userId,
  });

  return { subscriptionId: subscription?.id, currentPeriodEnd: end, reference };
};

const requestExtraVerification = async ({
  adminClient,
  userId,
  adminId,
  message,
}: {
  adminClient: ReturnType<typeof createClient>;
  userId: string;
  adminId: string;
  message: string;
}) => {
  const body =
    clean(message) ||
    'Please upload clearer or additional verification documents before approval.';
  const now = new Date().toISOString();
  await adminClient
    .from('profiles')
    .update({
      verification_status: 'pending',
      verification_notes: body,
      verification_reviewed_at: now,
      verification_retry_after: null,
    })
    .eq('id', userId);

  await adminClient.from('admin_notifications').insert({
    type: 'verification_more_info_requested',
    title: 'More verification information requested',
    body,
    actor_id: adminId,
    related_user_id: userId,
    related_table: 'profiles',
    related_id: userId,
  });

  await adminClient.from('email_outbox').insert({
    to_email: null,
    subject: 'More information needed for ProSME verification',
    body,
    related_user_id: userId,
  });
};

const validEmail = (value: string) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);

const passwordResetRedirectUrl = (requestedValue: string) => {
  const value =
    clean(Deno.env.get('PASSWORD_RESET_REDIRECT_URL')) || clean(requestedValue);
  if (!value) {
    throw new Error(
      'PASSWORD_RESET_REDIRECT_URL is not configured and no recovery URL was supplied.',
    );
  }
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error('PASSWORD_RESET_REDIRECT_URL must be a valid URL.');
  }
  if (url.protocol !== 'https:' && url.hostname !== 'localhost') {
    throw new Error('PASSWORD_RESET_REDIRECT_URL must use HTTPS.');
  }
  return value;
};

const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const sendRecoveryWithResend = async (email: string, actionLink: string) => {
  const apiKey = clean(Deno.env.get('RESEND_API_KEY'));
  if (!apiKey) throw new Error('RESEND_API_KEY is not configured');
  const from =
    clean(Deno.env.get('RESEND_FROM_EMAIL')) ||
    clean(Deno.env.get('PROSME_FROM_EMAIL')) ||
    'ProSME <noreply@prosme.blumebyte.com>';
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
      clean(payload?.message) ||
        clean(payload?.error) ||
        `Resend returned HTTP ${response.status}`,
    );
  }
};

const sendPasswordRecovery = async ({
  email,
  adminClient,
  publicClient,
  redirectTo: requestedRedirectTo,
}: {
  email: string;
  adminClient: ReturnType<typeof createClient>;
  publicClient: ReturnType<typeof createClient>;
  redirectTo: string;
}) => {
  const redirectTo = passwordResetRedirectUrl(requestedRedirectTo);
  const { error: mailerError } = await publicClient.auth.resetPasswordForEmail(
    email,
    {
      redirectTo,
    },
  );
  if (!mailerError) return { provider: 'supabase' };

  try {
    const { data, error: linkError } =
      await adminClient.auth.admin.generateLink({
        type: 'recovery',
        email,
        options: { redirectTo },
      });
    if (linkError) throw linkError;
    const actionLink = clean(data?.properties?.action_link);
    if (!actionLink) throw new Error('Supabase did not return a recovery link');
    await sendRecoveryWithResend(email, actionLink);
    return { provider: 'resend', mailerWarning: mailerError.message };
  } catch (fallbackError) {
    const fallbackMessage =
      fallbackError instanceof Error
        ? fallbackError.message
        : String(fallbackError);
    throw new Error(
      `Recovery email failed. Supabase: ${mailerError.message}. Resend fallback: ${fallbackMessage}. Verify Auth email settings, PASSWORD_RESET_REDIRECT_URL, and Resend secrets.`,
    );
  }
};

const randomPassword = () => {
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  const token = btoa(String.fromCharCode(...bytes))
    .replace(/[^a-zA-Z0-9]/g, '')
    .slice(0, 12);
  return `${token}Aa!7`;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS')
    return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' });

  try {
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const anonKey = requiredEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const authorization = req.headers.get('Authorization') || '';

    if (!authorization.startsWith('Bearer '))
      return fail('Missing admin session.');

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) return fail('Invalid admin session.');

    const { data: caller, error: callerError } = await userClient
      .from('profiles')
      .select('id,role,email')
      .eq('id', user.id)
      .maybeSingle();

    if (callerError) return fail(callerError.message);
    if (caller?.role !== 'admin') {
      return fail('Only admin accounts can use this action.');
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const publicClient = createClient(supabaseUrl, anonKey, {
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
      const allowedRoles = new Set(['customer', 'artisan', 'admin']);

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

      const { error: profileError } = await adminClient
        .from('profiles')
        .upsert({
          id: createdUser.id,
          email,
          full_name: fullName,
          phone,
          country: country || undefined,
          location,
          role,
          verification_status: 'pending',
        });

      if (profileError) return fail(profileError.message);
      let resetResult: Record<string, unknown> = {};
      let resetWarning = '';
      try {
        resetResult = await sendPasswordRecovery({
          email,
          adminClient,
          publicClient,
          redirectTo: clean(body.redirectTo),
        });
      } catch (error) {
        resetWarning = error instanceof Error ? error.message : String(error);
      }
      return ok({
        userId: createdUser.id,
        temporaryPassword: password,
        passwordResetSent: !resetWarning,
        warning: resetWarning || undefined,
        ...resetResult,
      });
    }

    if (action === 'bulkCreateUsers') {
      const accounts = Array.isArray(body.accounts) ? body.accounts : [];
      const created: Array<Record<string, unknown>> = [];
      const failed: Array<Record<string, unknown>> = [];
      const allowedRoles = new Set(['customer', 'artisan', 'admin']);

      for (const rawAccount of accounts.slice(0, 200)) {
        const account =
          rawAccount && typeof rawAccount === 'object'
            ? (rawAccount as Record<string, unknown>)
            : {};
        const email = clean(account.email).toLowerCase();
        const role = clean(account.role) || 'customer';
        const fullName =
          clean(account.full_name) ||
          clean(account.name) ||
          email.split('@')[0];
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
          failed.push({
            email,
            error: error?.message || 'Could not create user.',
          });
          continue;
        }

        const { error: profileError } = await adminClient
          .from('profiles')
          .upsert({
            id: data.user.id,
            email,
            full_name: fullName,
            phone: clean(account.phone),
            country: cleanNullable(account.country),
            location: clean(account.location),
            role,
            verification_status: 'pending',
          });

        if (profileError) {
          failed.push({ email, error: profileError.message });
          continue;
        }

        let resetResult: Record<string, unknown> = {};
        let resetWarning = '';
        try {
          resetResult = await sendPasswordRecovery({
            email,
            adminClient,
            publicClient,
            redirectTo: clean(body.redirectTo),
          });
        } catch (resetError) {
          resetWarning =
            resetError instanceof Error
              ? resetError.message
              : String(resetError);
        }
        created.push({
          email,
          userId: data.user.id,
          temporaryPassword: password,
          passwordResetSent: !resetWarning,
          warning: resetWarning || undefined,
          ...resetResult,
        });
      }

      return ok({ created, failed });
    }

    if (action === 'updateProfile') {
      const id = clean(body.id);
      const patch =
        body.patch && typeof body.patch === 'object'
          ? (body.patch as Record<string, unknown>)
          : {};
      if (!id) return fail('Profile id is required.');

      const sanitized: Record<string, unknown> = {};
      const requestedVerificationStatus = clean(patch.verification_status);
      if (requestedVerificationStatus === 'verified') {
        await approvePaidVerification({
          adminClient,
          userId: id,
          adminId: user.id,
          notes: clean(patch.verification_notes),
        });
        return ok({ verified: true });
      }
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
      const { error } = await adminClient
        .from('profiles')
        .update(sanitized)
        .eq('id', id);
      if (error) return fail(error.message);
      if (requestedVerificationStatus === 'rejected') {
        await adminClient.from('admin_notifications').insert({
          type: 'verification_rejected',
          title: 'Verification rejected',
          body:
            clean(patch.verification_notes) ||
            'Your verification was rejected. Please restart with clearer documents.',
          actor_id: user.id,
          related_user_id: id,
          related_table: 'profiles',
          related_id: id,
        });
        await adminClient.from('email_outbox').insert({
          to_email: null,
          subject: 'Your ProSME verification needs attention',
          body:
            clean(patch.verification_notes) ||
            'Your verification was rejected. Please restart with clearer documents.',
          related_user_id: id,
        });
      }
      return ok();
    }

    if (action === 'overrideVerificationPaid') {
      const userId = clean(body.userId || body.id);
      if (!userId) return fail('Profile id is required.');
      const result = await overrideVerificationPaid({
        adminClient,
        userId,
        adminId: user.id,
        notes:
          clean(body.notes) ||
          'Admin reviewed documents and marked payment complete.',
        interval: clean(body.interval),
      });
      return ok(result);
    }

    if (action === 'requestExtraVerification') {
      const userId = clean(body.userId || body.id);
      if (!userId) return fail('Profile id is required.');
      await requestExtraVerification({
        adminClient,
        userId,
        adminId: user.id,
        message: clean(body.message),
      });
      return ok();
    }

    if (action === 'deleteUser') {
      const userId = clean(body.userId || body.id);
      if (!userId) return fail('User id is required.');
      if (userId === user.id) {
        return fail(
          'You cannot delete the Admin Account you are currently using.',
        );
      }

      const { error } = await adminClient.auth.admin.deleteUser(userId);
      if (error) return fail(error.message);

      await adminClient.from('profiles').delete().eq('id', userId);
      return ok({ userId });
    }

    if (action === 'upsertListing') {
      const id = clean(body.id);
      const patch =
        body.patch && typeof body.patch === 'object'
          ? (body.patch as Record<string, unknown>)
          : {};
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
        Object.entries(row).filter(
          ([, value]) => value !== '' && value !== null,
        ),
      );
      if (!id && !row.artisan_id) return fail('Artisan owner is required.');
      if (!id && !row.title) return fail('Listing title is required.');

      const query = id
        ? adminClient
            .from('listings')
            .update(update)
            .eq('id', id)
            .select('id')
            .maybeSingle()
        : adminClient
            .from('listings')
            .insert(update)
            .select('id')
            .maybeSingle();
      const { data, error } = await query;
      if (error) return fail(error.message);
      return ok({ id: data?.id || id });
    }

    if (action === 'deleteListing') {
      const id = clean(body.id);
      if (!id) return fail('Listing id is required.');
      const { error } = await adminClient
        .from('listings')
        .delete()
        .eq('id', id);
      if (error) return fail(error.message);
      return ok();
    }

    if (action === 'upsertJob') {
      const id = clean(body.id);
      const patch =
        body.patch && typeof body.patch === 'object'
          ? (body.patch as Record<string, unknown>)
          : {};
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
        Object.entries(row).filter(
          ([, value]) => value !== '' && value !== null,
        ),
      );
      if (!id && !row.created_by) return fail('Job owner is required.');
      if (!id && !row.title) return fail('Job title is required.');

      const query = id
        ? adminClient
            .from('jobs')
            .update(update)
            .eq('id', id)
            .select('id')
            .maybeSingle()
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

      const result = await sendPasswordRecovery({
        email,
        adminClient,
        publicClient,
        redirectTo: clean(body.redirectTo),
      });
      return ok(result);
    }

    if (action === 'setPassword') {
      const userId = clean(body.userId);
      const password = clean(body.password) || randomPassword();
      if (!userId) return fail('User id is required.');

      const { error } = await adminClient.auth.admin.updateUserById(userId, {
        password,
      });
      if (error) return fail(error.message);
      return ok({ temporaryPassword: password });
    }

    return fail('Unknown admin action.');
  } catch (error) {
    console.error('admin-dashboard failed', error);
    return fail('Admin request failed.');
  }
});
