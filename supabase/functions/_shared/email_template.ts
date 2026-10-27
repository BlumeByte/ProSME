// Shared branded HTML shell for every ProSME email (verification codes,
// transactional notifications, admin broadcasts). One place to keep the
// look consistent, instead of each function hand-rolling its own markup.
//
// Table-based layout on purpose: Gmail/Outlook strip <style> blocks and
// flex/grid CSS from HTML email, so everything here is inline styles on
// <table>/<td>, which is the one layout model every mail client renders
// the same way.

const BRAND_GREEN = '#0F6B4A';
const LOGO_URL = 'https://prosme.blumebyte.com/prosme_logo.png';
const SITE_URL = 'https://prosme.blumebyte.com';

export const escapeHtml = (value: string) =>
  value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

export type EmailTemplateOptions = {
  /** Short text shown as the inbox preview line, before the email opens. */
  preheader?: string;
  /** Headline inside the card, above the body. */
  heading: string;
  /** Pre-escaped HTML for the body — build it with escapeHtml()/esc_html() first. */
  bodyHtml: string;
  /** Optional hero image (must be https). */
  imageUrl?: string;
  /** Optional call-to-action button. Defaults to "Open ProSME" / the site home. */
  ctaLabel?: string;
  ctaUrl?: string;
  /** Extra link rows under the body, e.g. broadcast links ({ label, url }[] as HTML already built by the caller). */
  extraHtml?: string;
};

export const wrapEmailHtml = ({
  preheader,
  heading,
  bodyHtml,
  imageUrl,
  ctaLabel,
  ctaUrl,
  extraHtml,
}: EmailTemplateOptions): string => {
  const safeImage =
    imageUrl && /^https:\/\//i.test(imageUrl)
      ? `<tr><td style="padding:0 0 20px"><img src="${escapeHtml(
          imageUrl,
        )}" alt="" width="536" style="width:100%;max-width:536px;border-radius:12px;display:block" /></td></tr>`
      : '';
  const cta =
    ctaUrl && /^https:\/\//i.test(ctaUrl)
      ? `<tr><td style="padding:8px 0 4px">
          <table role="presentation" cellpadding="0" cellspacing="0"><tr>
            <td style="border-radius:8px;background:${BRAND_GREEN}">
              <a href="${escapeHtml(ctaUrl)}" style="display:inline-block;padding:13px 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px">${escapeHtml(
          ctaLabel || 'Open ProSME',
        )}</a>
            </td>
          </tr></table>
        </td></tr>`
      : '';

  return `<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">
    ${preheader ? `<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(preheader)}</div>` : ''}
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;padding:28px 16px;">
      <tr><td align="center">
        <table role="presentation" width="100%" style="max-width:568px;" cellpadding="0" cellspacing="0">
          <tr><td align="center" style="padding:0 0 20px">
            <img src="${LOGO_URL}" width="48" height="48" alt="ProSME" style="border-radius:10px;display:block" />
          </tr></td>
          <tr><td style="background:#ffffff;border-radius:16px;padding:32px 28px;box-shadow:0 1px 3px rgba(0,0,0,0.06)">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
              <tr><td style="font-family:Arial,Helvetica,sans-serif;font-size:21px;font-weight:bold;color:#0f1b3d;padding:0 0 14px">${escapeHtml(heading)}</td></tr>
              ${safeImage}
              <tr><td style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#1f2937;padding:0 0 4px">${bodyHtml}</td></tr>
              ${extraHtml ? `<tr><td style="padding:4px 0 0">${extraHtml}</td></tr>` : ''}
              ${cta}
            </table>
          </td></tr>
          <tr><td align="center" style="padding:22px 12px 0;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:#9ca3af">
            ProSME &middot; Find trusted professionals fast<br/>
            <a href="${SITE_URL}" style="color:${BRAND_GREEN};text-decoration:none">${SITE_URL.replace('https://', '')}</a><br/>
            You're receiving this because of your ProSME notification settings. Manage them any time in the app under Profile &rarr; App settings.
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
};
