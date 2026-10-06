import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';

// One place that sends every ProSME email: 2FA codes, outbox notifications and
// admin broadcasts. SMTP is used when SMTP_PASSWORD is set; otherwise the
// Resend key is used so mail keeps flowing during a switch-over.
//
// Secrets (Supabase > Edge Functions > Secrets):
//   SMTP_HOST      box4021.bluehost.com
//   SMTP_PORT      465 (implicit TLS)
//   SMTP_USERNAME  noreply@prosme.blumebyte.com
//   SMTP_PASSWORD  the mailbox password
//   SMTP_FROM      ProSME <noreply@prosme.blumebyte.com>

export type MailMessage = {
  to: string;
  subject: string;
  text: string;
  html?: string;
};

const env = (key: string) => (Deno.env.get(key) ?? '').trim();

const defaultFrom = 'ProSME <noreply@prosme.blumebyte.com>';

export const smtpConfigured = () => env('SMTP_PASSWORD') !== '';

export const sendMail = async (message: MailMessage): Promise<string> => {
  const from = env('SMTP_FROM') || defaultFrom;

  if (smtpConfigured()) {
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
  }

  const apiKey = env('RESEND_API_KEY');
  if (!apiKey) {
    throw new Error('No mail transport is configured. Set SMTP_PASSWORD (or RESEND_API_KEY).');
  }
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: env('RESEND_FROM_EMAIL') || env('PROSME_FROM_EMAIL') || from,
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
