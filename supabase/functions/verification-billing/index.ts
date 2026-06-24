import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.106.2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-paystack-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const clean = (value: unknown) => String(value ?? '').trim();
const lower = (value: unknown) => clean(value).toLowerCase();
const requiredEnv = (key: string) => {
  const value = clean(Deno.env.get(key));
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};
const validChannels = new Set([
  'card',
  'bank',
  'bank_transfer',
  'mobile_money',
  'ussd',
  'qr',
]);

const amountUsdFor = (role: string, interval: string) => {
  const monthly = role === 'artisan' ? 5 : 2;
  return interval === 'yearly' ? monthly * 12 : monthly;
};

const periodEnd = (interval: string) => {
  const now = new Date();
  const next = new Date(now);
  if (interval === 'yearly') {
    next.setUTCFullYear(next.getUTCFullYear() + 1);
  } else {
    next.setUTCMonth(next.getUTCMonth() + 1);
  }
  return next.toISOString();
};

const chargeAmount = (amountUsd: number, currency: string) => {
  if (currency === 'USD') return Math.round(amountUsd * 100);
  const usdToGhs = Number(Deno.env.get('USD_TO_GHS_RATE') || '15.5');
  if (currency === 'GHS') return Math.round(amountUsd * usdToGhs * 100);
  const rate = Number(Deno.env.get(`USD_TO_${currency}_RATE`) || '0');
  if (rate > 0) return Math.round(amountUsd * rate * 100);
  return Math.round(amountUsd * usdToGhs * 100);
};

const hex = (buffer: ArrayBuffer) =>
  [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');

const paystackSignature = async (secret: string, body: string) => {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  return hex(
    await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body)),
  );
};

const verifyReferenceWithPaystack = async (
  secret: string,
  reference: string,
) => {
  const response = await fetch(
    `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
    { headers: { Authorization: `Bearer ${secret}` } },
  );
  const payload = await response.json();
  if (!response.ok || payload?.status !== true) {
    throw new Error(payload?.message || 'Paystack verification failed.');
  }
  return payload.data;
};

const chargeAuthorization = async ({
  secret,
  authorizationCode,
  email,
  amount,
  currency,
  reference,
  metadata,
}: {
  secret: string;
  authorizationCode: string;
  email: string;
  amount: number;
  currency: string;
  reference: string;
  metadata: Record<string, unknown>;
}) => {
  const response = await fetch(
    'https://api.paystack.co/transaction/charge_authorization',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        authorization_code: authorizationCode,
        email,
        amount,
        currency,
        reference,
        metadata,
      }),
    },
  );
  const payload = await response.json();
  if (!response.ok || payload?.status !== true) {
    throw new Error(
      payload?.message || 'Paystack authorization charge failed.',
    );
  }
  return payload.data;
};

const paymentMethodLabel = (authorization: Record<string, unknown>) => {
  const channel = clean(authorization.channel);
  const bank = clean(authorization.bank);
  const cardType = clean(authorization.card_type || authorization.brand);
  const last4 = clean(authorization.last4);
  const accountName = clean(authorization.account_name);
  if (last4)
    return [bank, cardType, `ending ${last4}`].filter(Boolean).join(' ');
  if (accountName) return [bank, accountName].filter(Boolean).join(' ');
  return channel || 'Paystack payment method';
};

const reusableAuthorizationPatch = (paymentData: Record<string, unknown>) => {
  const authorization =
    paymentData.authorization && typeof paymentData.authorization === 'object'
      ? (paymentData.authorization as Record<string, unknown>)
      : {};
  const reusable = authorization.reusable === true;
  const authorizationCode = clean(authorization.authorization_code);
  if (!reusable || !authorizationCode) return {};
  const customer =
    paymentData.customer && typeof paymentData.customer === 'object'
      ? (paymentData.customer as Record<string, unknown>)
      : {};
  return {
    auto_renew: true,
    paystack_customer_code: clean(customer.customer_code),
    paystack_email: clean(customer.email || paymentData.email),
    paystack_authorization_code: authorizationCode,
    paystack_authorization_signature: clean(authorization.signature),
    paystack_authorization: authorization,
    payment_method_channel: clean(authorization.channel || paymentData.channel),
    payment_method_label: paymentMethodLabel(authorization),
    renewal_attempt_count: 0,
    last_renewal_error: null,
    next_renewal_attempt_at: null,
  };
};

const activateSubscription = async ({
  adminClient,
  subscription,
  paymentData,
}: {
  adminClient: ReturnType<typeof createClient>;
  subscription: Record<string, unknown>;
  paymentData: Record<string, unknown>;
}) => {
  const reference = clean(
    paymentData.reference || subscription.paystack_reference,
  );
  const expectedAmount = Number(subscription.charge_amount || 0);
  const actualAmount = Number(paymentData.amount || 0);
  const expectedCurrency = clean(subscription.charge_currency).toUpperCase();
  const actualCurrency = clean(
    paymentData.currency || expectedCurrency,
  ).toUpperCase();
  if (clean(paymentData.status) !== 'success') {
    throw new Error('Payment is not successful.');
  }
  if (actualAmount !== expectedAmount || actualCurrency !== expectedCurrency) {
    throw new Error(
      'Payment amount or currency does not match the subscription.',
    );
  }

  const now = new Date().toISOString();
  const end = periodEnd(clean(subscription.plan_interval));
  const subscriptionId = clean(subscription.id);
  const userId = clean(subscription.user_id);
  const authorizationPatch = reusableAuthorizationPatch(paymentData);

  await adminClient.from('verification_payments').upsert(
    {
      subscription_id: subscriptionId,
      user_id: userId,
      role: clean(subscription.role),
      plan_interval: clean(subscription.plan_interval),
      status: 'success',
      amount_usd: Number(subscription.amount_usd),
      charge_currency: expectedCurrency,
      charge_amount: expectedAmount,
      paystack_reference: reference,
      paystack_transaction_id: clean(paymentData.id),
      gateway_response: clean(paymentData.gateway_response),
      paid_at: clean(paymentData.paid_at) || now,
      raw_payload: paymentData,
    },
    { onConflict: 'paystack_reference' },
  );

  await adminClient
    .from('verification_subscriptions')
    .update({
      status: 'active',
      paystack_transaction_id: clean(paymentData.id),
      current_period_start: now,
      current_period_end: end,
      last_payment_at: clean(paymentData.paid_at) || now,
      last_renewal_attempt_at: null,
      last_renewal_error: null,
      updated_at: now,
      ...authorizationPatch,
    })
    .eq('id', subscriptionId);

  await adminClient
    .from('profiles')
    .update({
      verification_status: 'verified',
      verification_expires_at: end,
      verification_reviewed_at: now,
    })
    .eq('id', userId);

  await adminClient.from('admin_notifications').insert({
    type: 'verification_payment',
    title: 'Verification payment received',
    body: `${clean(subscription.role)} verification ${clean(subscription.plan_interval)} payment ${reference} succeeded.`,
    related_user_id: userId,
    related_table: 'verification_subscriptions',
    related_id: subscriptionId,
  });

  await adminClient.from('email_outbox').insert({
    to_email: null,
    subject: 'Your ProSME verification is active',
    body: `Your verification badge is active until ${new Date(end).toDateString()}.`,
    related_user_id: userId,
  });

  return { subscriptionId, currentPeriodEnd: end };
};

const syncExpired = async (adminClient: ReturnType<typeof createClient>) => {
  const { error } = await adminClient.rpc('expire_verification_subscriptions');
  if (error) throw new Error(error.message);
};

const isDispatchSecret = (req: Request) => {
  const expected =
    clean(Deno.env.get('EMAIL_DISPATCH_SECRET')) ||
    clean(Deno.env.get('BILLING_DISPATCH_SECRET'));
  return Boolean(
    expected && req.headers.get('x-email-dispatch-secret') === expected,
  );
};

const assertAdmin = async ({
  req,
  supabaseUrl,
  anonKey,
}: {
  req: Request;
  supabaseUrl: string;
  anonKey: string;
}) => {
  if (isDispatchSecret(req)) return { userId: null, profile: null };
  const authorization = req.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer '))
    throw new Error('Missing admin session.');
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();
  if (userError || !user) throw new Error('Invalid admin session.');
  const { data: profile, error: profileError } = await userClient
    .from('profiles')
    .select('id,role,email')
    .eq('id', user.id)
    .maybeSingle();
  if (profileError) throw new Error(profileError.message);
  if (profile?.role !== 'admin')
    throw new Error('Only admin accounts can use this billing action.');
  return { userId: user.id, profile };
};

const renewDueSubscriptions = async ({
  adminClient,
  paystackSecret,
  limit,
}: {
  adminClient: ReturnType<typeof createClient>;
  paystackSecret: string;
  limit: number;
}) => {
  const now = new Date().toISOString();
  const { data: rows, error } = await adminClient
    .from('verification_subscriptions')
    .select('*')
    .in('status', ['active', 'renewal_failed'])
    .eq('auto_renew', true)
    .not('paystack_authorization_code', 'is', null)
    .or(`current_period_end.lte.${now},next_renewal_attempt_at.lte.${now}`)
    .limit(limit);
  if (error) throw new Error(error.message);

  const renewed: string[] = [];
  const failed: Array<{ id: string; error: string }> = [];
  for (const subscription of rows ?? []) {
    const subscriptionId = clean(subscription.id);
    const role =
      clean(subscription.role) === 'artisan' ? 'artisan' : 'customer';
    const interval =
      clean(subscription.plan_interval) === 'yearly' ? 'yearly' : 'monthly';
    const currency = clean(
      subscription.charge_currency ||
        Deno.env.get('PAYSTACK_CURRENCY') ||
        'GHS',
    ).toUpperCase();
    const amountUsd = amountUsdFor(role, interval);
    const amount = chargeAmount(amountUsd, currency);
    const reference = `prosme_renew_${clean(subscription.user_id).replaceAll('-', '').slice(0, 12)}_${Date.now()}`;
    const email = clean(subscription.paystack_email);
    const authorizationCode = clean(subscription.paystack_authorization_code);
    try {
      if (!email || !authorizationCode)
        throw new Error('Saved reusable payment method is missing.');
      await adminClient
        .from('verification_subscriptions')
        .update({
          paystack_reference: reference,
          amount_usd: amountUsd,
          charge_currency: currency,
          charge_amount: amount,
          last_renewal_attempt_at: now,
          updated_at: now,
        })
        .eq('id', subscriptionId);
      await adminClient.from('verification_payments').insert({
        subscription_id: subscriptionId,
        user_id: clean(subscription.user_id),
        role,
        plan_interval: interval,
        status: 'pending',
        amount_usd: amountUsd,
        charge_currency: currency,
        charge_amount: amount,
        paystack_reference: reference,
      });
      const paymentData = await chargeAuthorization({
        secret: paystackSecret,
        authorizationCode,
        email,
        amount,
        currency,
        reference,
        metadata: {
          purpose: 'verification_subscription_renewal',
          user_id: clean(subscription.user_id),
          role,
          interval,
          amount_usd: amountUsd,
        },
      });
      await activateSubscription({
        adminClient,
        subscription: {
          ...subscription,
          paystack_reference: reference,
          amount_usd: amountUsd,
          charge_currency: currency,
          charge_amount: amount,
        },
        paymentData,
      });
      renewed.push(subscriptionId);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      failed.push({ id: subscriptionId, error: message });
      await adminClient.from('verification_payments').upsert(
        {
          subscription_id: subscriptionId,
          user_id: clean(subscription.user_id),
          role,
          plan_interval: interval,
          status: 'renewal_failed',
          amount_usd: amountUsd,
          charge_currency: currency,
          charge_amount: amount,
          paystack_reference: reference,
          gateway_response: message,
          raw_payload: { error: message },
        },
        { onConflict: 'paystack_reference' },
      );
      await adminClient
        .from('verification_subscriptions')
        .update({
          status: 'expired',
          auto_renew: false,
          renewal_attempt_count:
            Number(subscription.renewal_attempt_count || 0) + 1,
          last_renewal_attempt_at: now,
          last_renewal_error: message,
          updated_at: now,
        })
        .eq('id', subscriptionId);
      await adminClient
        .from('profiles')
        .update({
          verification_status: 'pending',
          verification_expires_at: subscription.current_period_end,
          updated_at: now,
        })
        .eq('id', clean(subscription.user_id));
      await adminClient.from('admin_notifications').insert({
        type: 'verification_renewal_failed',
        title: 'Verification renewal failed',
        body: `${role} verification renewal failed: ${message}`,
        related_user_id: clean(subscription.user_id),
        related_table: 'verification_subscriptions',
        related_id: subscriptionId,
      });
    }
  }
  await syncExpired(adminClient);
  return { renewed, failed };
};

const backfillVerifiedSubscriptions = async (
  adminClient: ReturnType<typeof createClient>,
) => {
  const now = new Date().toISOString();
  const end = new Date();
  end.setUTCFullYear(end.getUTCFullYear() + 1);
  const { data: profiles, error } = await adminClient
    .from('profiles')
    .select('id,role,verification_status')
    .in('role', ['customer', 'artisan'])
    .eq('verification_status', 'verified');
  if (error) throw new Error(error.message);
  let created = 0;
  for (const profile of profiles ?? []) {
    const { data: existing, error: existingError } = await adminClient
      .from('verification_subscriptions')
      .select('id')
      .eq('user_id', profile.id)
      .maybeSingle();
    if (existingError) throw new Error(existingError.message);
    if (existing) continue;
    const role = clean(profile.role) === 'artisan' ? 'artisan' : 'customer';
    const amountUsd = amountUsdFor(role, 'yearly');
    const { error: insertError } = await adminClient
      .from('verification_subscriptions')
      .insert({
        user_id: profile.id,
        role,
        plan_interval: 'yearly',
        status: 'active',
        amount_usd: amountUsd,
        charge_currency: clean(
          Deno.env.get('PAYSTACK_CURRENCY') || 'GHS',
        ).toUpperCase(),
        charge_amount: 0,
        current_period_start: now,
        current_period_end: end.toISOString(),
        last_payment_at: now,
        auto_renew: false,
        updated_at: now,
      });
    if (insertError) throw new Error(insertError.message);
    await adminClient
      .from('profiles')
      .update({
        verification_expires_at: end.toISOString(),
        updated_at: now,
      })
      .eq('id', profile.id);
    created += 1;
  }
  return { created };
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS')
    return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseUrl = requiredEnv('SUPABASE_URL');
    const anonKey = requiredEnv('SUPABASE_ANON_KEY');
    const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
    const paystackSecret = requiredEnv('PAYSTACK_SECRET_KEY');
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const rawBody = await req.text();
    const signature = req.headers.get('x-paystack-signature');
    if (signature) {
      const expected = await paystackSignature(paystackSecret, rawBody);
      if (expected !== signature)
        return json(401, { ok: false, error: 'Invalid webhook signature.' });
      const event = JSON.parse(rawBody);
      if (event?.event !== 'charge.success')
        return json(200, { ok: true, ignored: true });
      const reference = clean(event?.data?.reference);
      const { data: subscription, error } = await adminClient
        .from('verification_subscriptions')
        .select('*')
        .eq('paystack_reference', reference)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!subscription) return json(200, { ok: true, ignored: true });
      const activated = await activateSubscription({
        adminClient,
        subscription,
        paymentData: event.data,
      });
      return json(200, { ok: true, ...activated });
    }

    const body = rawBody ? JSON.parse(rawBody) : {};
    const action = clean(body.action || 'initialize');

    if (['renewDue', 'syncExpirations', 'backfillVerified'].includes(action)) {
      await assertAdmin({ req, supabaseUrl, anonKey });
      if (action === 'syncExpirations') {
        await syncExpired(adminClient);
        return json(200, { ok: true });
      }
      if (action === 'backfillVerified') {
        const result = await backfillVerifiedSubscriptions(adminClient);
        return json(200, { ok: true, ...result });
      }
      const result = await renewDueSubscriptions({
        adminClient,
        paystackSecret,
        limit: Math.min(Math.max(Number(body.limit || 25), 1), 100),
      });
      return json(200, { ok: true, ...result });
    }

    if (action === 'adminVerifyReference') {
      await assertAdmin({ req, supabaseUrl, anonKey });
      const reference = clean(body.reference);
      if (!reference)
        return json(400, {
          ok: false,
          error: 'Payment reference is required.',
        });
      const { data: subscription, error } = await adminClient
        .from('verification_subscriptions')
        .select('*')
        .eq('paystack_reference', reference)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!subscription)
        return json(404, {
          ok: false,
          error: 'Subscription payment was not found.',
        });
      const paymentData = await verifyReferenceWithPaystack(
        paystackSecret,
        reference,
      );
      const activated = await activateSubscription({
        adminClient,
        subscription,
        paymentData,
      });
      return json(200, { ok: true, ...activated });
    }

    const authorization = req.headers.get('Authorization') || '';
    if (!authorization.startsWith('Bearer '))
      return json(401, { ok: false, error: 'Missing session.' });
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user)
      return json(401, { ok: false, error: 'Invalid session.' });

    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('id,email,role,verification_status')
      .eq('id', user.id)
      .maybeSingle();
    if (profileError) throw new Error(profileError.message);
    if (!profile) return json(404, { ok: false, error: 'Profile not found.' });

    if (action === 'verify') {
      const reference = clean(body.reference);
      if (!reference)
        return json(400, {
          ok: false,
          error: 'Payment reference is required.',
        });
      const { data: subscription, error } = await adminClient
        .from('verification_subscriptions')
        .select('*')
        .eq('user_id', user.id)
        .eq('paystack_reference', reference)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!subscription)
        return json(404, {
          ok: false,
          error: 'Subscription payment was not found.',
        });
      const paymentData = await verifyReferenceWithPaystack(
        paystackSecret,
        reference,
      );
      const activated = await activateSubscription({
        adminClient,
        subscription,
        paymentData,
      });
      return json(200, { ok: true, ...activated });
    }

    if (action !== 'initialize')
      return json(400, { ok: false, error: 'Unknown billing action.' });

    const role = lower(profile.role);
    if (role !== 'customer' && role !== 'artisan') {
      return json(400, {
        ok: false,
        error: 'Only customer and artisan accounts can buy verification.',
      });
    }
    const interval = lower(body.interval) === 'yearly' ? 'yearly' : 'monthly';
    const requestedChannel = lower(body.channel);
    const amountUsd = amountUsdFor(role, interval);
    const chargeCurrency = clean(
      Deno.env.get('PAYSTACK_CURRENCY') || 'GHS',
    ).toUpperCase();
    const amount = chargeAmount(amountUsd, chargeCurrency);
    const reference = `prosme_ver_${user.id.replaceAll('-', '').slice(0, 12)}_${Date.now()}`;
    const callbackUrl = clean(
      body.callbackUrl || Deno.env.get('PAYSTACK_CALLBACK_URL'),
    );

    const transactionPayload: Record<string, unknown> = {
      email: clean(profile.email || user.email),
      amount,
      currency: chargeCurrency,
      reference,
      metadata: {
        purpose: 'verification_subscription',
        user_id: user.id,
        role,
        interval,
        amount_usd: amountUsd,
      },
    };
    if (validChannels.has(requestedChannel))
      transactionPayload.channels = [requestedChannel];
    if (callbackUrl) transactionPayload.callback_url = callbackUrl;

    const initResponse = await fetch(
      'https://api.paystack.co/transaction/initialize',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${paystackSecret}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(transactionPayload),
      },
    );
    const initPayload = await initResponse.json();
    if (!initResponse.ok || initPayload?.status !== true) {
      throw new Error(
        initPayload?.message || 'Could not initialize Paystack transaction.',
      );
    }

    const now = new Date().toISOString();
    const { data: subscription, error: subscriptionError } = await adminClient
      .from('verification_subscriptions')
      .upsert(
        {
          user_id: user.id,
          role,
          plan_interval: interval,
          status: 'pending_payment',
          amount_usd: amountUsd,
          charge_currency: chargeCurrency,
          charge_amount: amount,
          paystack_reference: reference,
          paystack_access_code: clean(initPayload.data?.access_code),
          paystack_authorization_url: clean(
            initPayload.data?.authorization_url,
          ),
          updated_at: now,
        },
        { onConflict: 'user_id' },
      )
      .select('*')
      .maybeSingle();
    if (subscriptionError) throw new Error(subscriptionError.message);

    await adminClient.from('verification_payments').insert({
      subscription_id: subscription?.id,
      user_id: user.id,
      role,
      plan_interval: interval,
      status: 'pending',
      amount_usd: amountUsd,
      charge_currency: chargeCurrency,
      charge_amount: amount,
      paystack_reference: reference,
    });

    return json(200, {
      ok: true,
      reference,
      accessCode: clean(initPayload.data?.access_code),
      authorizationUrl: clean(initPayload.data?.authorization_url),
      amountUsd,
      chargeCurrency,
      chargeAmount: amount,
    });
  } catch (error) {
    return json(500, {
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
