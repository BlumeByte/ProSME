import { createClient } from "https://esm.sh/@supabase/supabase-js@2.106.2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const clean = (value: unknown) => String(value ?? "").trim();
const env = (key: string) => clean(Deno.env.get(key));
const requiredEnv = (key: string) => {
  const value = env(key);
  if (!value) throw new Error(`${key} is not configured`);
  return value;
};

const validEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

const isAdultDate = (value: string) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return false;
  }
  const today = new Date();
  const cutoff = new Date(
    Date.UTC(
      today.getUTCFullYear() - 18,
      today.getUTCMonth(),
      today.getUTCDate(),
    ),
  );
  return date <= cutoff;
};

const allowedRoles = new Set(["customer", "artisan"]);
const allowedGenders = new Set([
  "female",
  "male",
  "non_binary",
  "prefer_not_to_say",
]);

const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const phoneForTwilio = (phone: string) => {
  const compact = clean(phone).replace(/[\s()-]/g, "");
  if (/^\+[1-9]\d{7,14}$/.test(compact)) return compact;
  if (/^0\d{8,13}$/.test(compact)) return `+233${compact.slice(1)}`;
  return "";
};

const twilioVerifyConfig = () => {
  const serviceSid =
    env("TWILIO_VERIFY_SERVICE_SID") ||
    (env("TWILIO_ACCOUNT_SID").startsWith("VA")
      ? env("TWILIO_ACCOUNT_SID")
      : "");
  const username =
    env("TWILIO_API_KEY_SID") ||
    (env("TWILIO_ACCOUNT_SID").startsWith("AC")
      ? env("TWILIO_ACCOUNT_SID")
      : "");
  const password = env("TWILIO_API_KEY_SECRET") || env("TWILIO_AUTH_TOKEN");
  if (!serviceSid || !username || !password) return null;
  return { serviceSid, username, password };
};

const sendPhoneVerification = async (to: string) => {
  const config = twilioVerifyConfig();
  if (!config) {
    return "Twilio Verify is not configured.";
  }
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${config.serviceSid}/Verifications`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${config.username}:${config.password}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: to, Channel: "sms" }),
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    return (
      clean(payload?.message) ||
      clean(payload?.error_message) ||
      "SMS verification request failed."
    );
  }
  return "";
};

const sendSignupEmail = async ({
  to,
  fullName,
  actionLink,
  emailOtp,
}: {
  to: string;
  fullName: string;
  actionLink: string;
  emailOtp: string;
}) => {
  const apiKey = requiredEnv("RESEND_API_KEY");
  const from =
    env("RESEND_FROM_EMAIL") ||
    env("PROSME_FROM_EMAIL") ||
    "ProSME <noreply@prosme.blumebyte.com>";
  const safeName = escapeHtml(fullName || "there");
  const safeLink = escapeHtml(actionLink);
  const safeOtp = escapeHtml(emailOtp);
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Confirm your ProSME account",
      text:
        `Hi ${fullName || "there"}, confirm your ProSME account: ${actionLink}` +
        (emailOtp ? `\n\nYour 6-digit confirmation code is ${emailOtp}.` : ""),
      html: `
        <p>Hi ${safeName},</p>
        <p>Confirm your ProSME account to finish signing up.</p>
        <p><a href="${safeLink}">Confirm ProSME account</a></p>
        ${safeOtp ? `<p>Your 6-digit confirmation code is <strong>${safeOtp}</strong>.</p>` : ""}
        <p>If you did not create this account, ignore this email.</p>
      `,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      clean(payload?.message) ||
        clean(payload?.error) ||
        "Confirmation email could not be sent.",
    );
  }
};

const queueWelcomeEmail = async ({
  adminClient,
  userId,
  email,
  fullName,
  role,
}: {
  adminClient: ReturnType<typeof createClient>;
  userId: string;
  email: string;
  fullName: string;
  role: string;
}) => {
  const steps =
    role === "artisan"
      ? [
          "1. Add your service categories and location on your Profile so customers can find you.",
          "2. Upload your ID for verification — verified artisans get more bookings.",
          "3. Browse open job requests near you and place bids.",
          "4. Once a customer accepts your bid, chat and track the job right in the app.",
          "5. Get paid to your wallet the moment a job is marked complete.",
        ]
      : [
          "1. Post a job or browse verified artisans by category.",
          "2. Compare bids and chat with artisans before you hire.",
          "3. Track job progress and message the artisan from one screen.",
          "4. Confirm when the work is complete to release payment and leave a rating.",
          "5. Need help? The Support tab has answers and a way to reach us.",
        ];
  const body =
    `Welcome to ProSME, ${fullName || "there"}!\n\n` +
    `Here's how to get started:\n${steps.join("\n")}\n\n` +
    `Turn on notifications in Settings so you never miss a bid, message, or job update.`;

  await adminClient.from("email_outbox").insert({
    to_email: email,
    subject: "Welcome to ProSME — quick start guide",
    body,
    related_user_id: userId,
  });
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false, error: "Method not allowed" });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const action = clean(body.action);
    const email = clean(body.email).toLowerCase();
    const password = String(body.password ?? "");
    const role = clean(body.role) === "artisan" ? "artisan" : "customer";
    const fullName =
      clean(body.full_name) || clean(body.username) || email.split("@")[0];
    const username = clean(body.username) || fullName;
    const gender = clean(body.gender) || "prefer_not_to_say";
    const dateOfBirth = clean(body.date_of_birth);
    const country = clean(body.country) || "Ghana";
    const countryCode = clean(body.country_code) || "+233";
    const appLanguage = clean(body.app_language) || "English";
    const currencyCode = clean(body.currency_code) || "GHS";
    const phone = phoneForTwilio(clean(body.phone));
    const redirectTo =
      clean(body.redirectTo) || "https://prosme.blumebyte.com/login";

    if (!validEmail(email)) {
      return json(200, { ok: false, error: "Enter a valid email address." });
    }

    const adminClient = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    if (action === "resend") {
      const { data, error } = await adminClient.auth.admin.generateLink({
        type: "magiclink",
        email,
        options: { redirectTo },
      });
      if (error) return json(200, { ok: false, error: error.message });
      const actionLink = clean(data.properties?.action_link);
      const emailOtp = clean(data.properties?.email_otp);
      if (!actionLink) {
        return json(200, {
          ok: false,
          error: "Confirmation link could not be generated.",
        });
      }
      await sendSignupEmail({
        to: email,
        fullName: email.split("@")[0],
        actionLink,
        emailOtp,
      });
      return json(200, { ok: true, emailSent: true });
    }

    if (password.length < 8) {
      return json(200, {
        ok: false,
        error: "Password must be at least 8 characters.",
      });
    }
    if (!allowedRoles.has(role)) {
      return json(200, { ok: false, error: "Invalid account type." });
    }
    if (!allowedGenders.has(gender)) {
      return json(200, { ok: false, error: "Invalid gender." });
    }
    if (!isAdultDate(dateOfBirth)) {
      return json(200, {
        ok: false,
        error: "You must be at least 18 years old to create an account.",
      });
    }

    const metadata = {
      full_name: fullName,
      username,
      role,
      gender,
      date_of_birth: dateOfBirth,
      country,
      country_code: countryCode,
      app_language: appLanguage,
      currency_code: currencyCode,
      phone,
    };

    const { data, error } = await adminClient.auth.admin.generateLink({
      type: "signup",
      email,
      password,
      options: {
        data: metadata,
        redirectTo,
      },
    });

    if (error) {
      const message = error.message.toLowerCase().includes("registered")
        ? "This email is already registered. Please sign in."
        : error.message;
      return json(200, { ok: false, error: message });
    }

    const user = data.user;
    const actionLink = clean(data.properties?.action_link);
    const emailOtp = clean(data.properties?.email_otp);
    if (!user?.id || !actionLink) {
      return json(200, {
        ok: false,
        error: "Confirmation link could not be generated.",
      });
    }

    const { error: profileError } = await adminClient.from("profiles").upsert({
      id: user.id,
      email,
      full_name: fullName,
      username,
      phone,
      role,
      gender,
      date_of_birth: dateOfBirth,
      country,
      country_code: countryCode,
      app_language: appLanguage,
      currency_code: currencyCode,
      verification_status: "pending",
      email_verified: false,
      phone_verified: false,
    });

    if (profileError) {
      return json(200, { ok: false, error: profileError.message });
    }

    await sendSignupEmail({ to: email, fullName, actionLink, emailOtp });
    await queueWelcomeEmail({ adminClient, userId: user.id, email, fullName, role });

    let smsWarning = "";
    if (phone) smsWarning = await sendPhoneVerification(phone);

    return json(200, {
      ok: true,
      userId: user.id,
      emailSent: true,
      phoneOtpSent: Boolean(phone && !smsWarning),
      warning: smsWarning || undefined,
    });
  } catch (error) {
    return json(200, {
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "Account could not be created.",
    });
  }
});
