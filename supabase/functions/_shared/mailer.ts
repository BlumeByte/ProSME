import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';

// One place that sends every ProSME email: 2FA codes, outbox notifications and
// admin broadcasts.
//
// Resend is primary (fast, dedicated transactional delivery, verified
// domain — no more sandbox restriction once the domain is verified on
// Resend's side). Bluehost SMTP is the fallback: cPanel/shared-hosting mail
// queues can take minutes to actually hand off to the recipient's server,
// which is exactly wrong for a 10-minute OTP code, and repeated attempts to
// get SMTP_PASSWORD reliably recognized here have not stuck across several
// weeks — so it no longer gets first attempt on anything time-sensitive.
//
// Secrets (Supabase > Edge Functions > Secrets):
//   RESEND_API_KEY     Resend API key
//   RESEND_FROM_EMAIL  e.g. "ProSME <noreply@prosme.blumebyte.com>" (must be
//                      on the verified Resend domain)
//   SMTP_HOST          box4021.bluehost.com
//   SMTP_PORT          465 (implicit TLS)
//   SMTP_USERNAME      noreply@prosme.blumebyte.com
//   SMTP_PASSWORD      the mailbox password
//   SMTP_FROM          ProSME <noreply@prosme.blumebyte.com>

export type MailMessage = {
  to: string;
  subject: string;
  text: string;
  html?: string;
};

const env = (key: string) => (Deno.env.get(key) ?? '').trim();

const defaultFrom = 'ProSME <noreply@prosme.blumebyte.com>';

export const smtpConfigured = () => env('SMTP_PASSWORD') !== '';
export const resendConfigured = () => env('RESEND_API_KEY') !== '';

const sendViaResend = async (message: MailMessage): Promise<string> => {
  const apiKey = env('RESEND_API_KEY');
  const from = env('RESEND_FROM_EMAIL') || env('PROSME_FROM_EMAIL') || defaultFrom;
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [message.to],
      subject: message.subject,
      text: message.text,
      html: message.html ?? `<p>${message.text}</p>`,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      String(payload?.message || payload?.error || `Resend returned HTTP ${response.status}`),
    );
  }
  return String(payload?.id ?? 'resend');
};

const sendViaSmtp = async (message: MailMessage): Promise<string> => {
  const from = env('SMTP_FROM') || defaultFrom;
  const port = Number(env('SMTP_PORT') || 465);
  const client = new SMTPClient({
    connection: {
      hostname: env('SMTP_HOST') || 'box4021.bluehost.com',
      port,
      tls: port === 465,
      auth: {
        username: env('SMTP_USERNAME') || 'noreply@prosme.blumebyte.com',
        password: env('SMTP_PASSWORD'),
      },
    },
  });
  try {
    await client.send({
      from,
      to: message.to,
      subject: message.subject,
      content: message.text,
      html: message.html ?? undefined,
    });
  } finally {
    await client.close();
  }
  return 'smtp';
};

export const sendMail = async (message: MailMessage): Promise<string> => {
  const resendReady = resendConfigured();
  const smtpReady = smtpConfigured();

  if (!resendReady && !smtpReady) {
    throw new Error(
      'No mail transport is configured. Set RESEND_API_KEY (preferred) or SMTP_PASSWORD.',
    );
  }

  if (resendReady) {
    try {
      return await sendViaResend(message);
    } catch (resendError) {
      if (!smtpReady) throw resendError;
      console.error(
        'Resend send failed, falling back to SMTP',
        resendError instanceof Error ? resendError.message : String(resendError),
      );
      return await sendViaSmtp(message);
    }
  }

  return await sendViaSmtp(message);
};
