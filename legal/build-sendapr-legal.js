// Renders Minesweeper's legal Markdown into the sendapr.com page template and writes
// the result into the sendapr-landing repo, so the public pages are GENERATED
// from the same source the app links to instead of hand-transcribed.
//
// Output (consumed by the sendapr-landing Vercel deploy):
//   public/privacy/minesweeper/index.html            (ES, privacy-policy.md)
//   public/privacy/minesweeper/en/index.html         (EN, privacy-policy.en.md)
//   public/terms/minesweeper/index.html              (ES, terms-of-service.md)
//   public/terms/minesweeper/en/index.html           (EN, terms-of-service.en.md)
//   public/delete-account/minesweeper/index.html     (ES, account-deletion.md)
//   public/delete-account/minesweeper/en/index.html  (EN, account-deletion.en.md)
//
// NEVER hand-edit the generated HTML: the next run overwrites it without
// warning. Edit the Markdown and re-run.
//
// Run:  cd legal && node build-sendapr-legal.js
//       then commit + push sendapr-landing (Vercel auto-deploys on push).

const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

const LEGAL_DIR = __dirname;
const SENDAPR_PUBLIC = path.resolve(__dirname, '..', '..', 'sendapr-landing', 'public');

// Cobalto — Minesweeper's default palette (`nona_config.dart: defaultPalette`), so the
// pages read as the same product as the app.
const ACCENT = '#4FA8FF';

const STYLE = `
    :root { color-scheme: dark; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #0F1118;
      color: #E3E2E6;
      line-height: 1.65;
      padding: 48px 24px 96px;
    }
    main { max-width: 760px; margin: 0 auto; }
    .crumbs { font-size: 13px; color: #8E9099; margin-bottom: 12px; }
    .crumbs a { color: ${ACCENT}; text-decoration: none; }
    .crumbs a:hover { text-decoration: underline; }
    .lang-switch { font-size: 13px; color: #8E9099; margin-bottom: 32px; }
    .lang-switch a { color: ${ACCENT}; text-decoration: none; }
    .lang-switch a:hover { text-decoration: underline; }
    .lang-switch .current { color: #E3E2E6; font-weight: 600; }
    h1 { font-size: 36px; font-weight: 700; margin: 0 0 8px; letter-spacing: -0.01em; }
    .meta { color: #8E9099; font-size: 14px; margin: 0 0 40px; }
    .lede { margin: 0 0 40px; }
    .lede p, .lede li { color: #C4C6CF; font-size: 15px; }
    h2 { font-size: 22px; font-weight: 700; margin: 48px 0 12px; color: ${ACCENT}; }
    h3 { font-size: 17px; font-weight: 700; margin: 28px 0 8px; }
    h4 { font-size: 15px; font-weight: 700; margin: 22px 0 6px; color: #E3E2E6; }
    p, li { color: #C4C6CF; font-size: 15px; }
    ul, ol { padding-left: 22px; }
    li { margin-bottom: 6px; }
    a { color: ${ACCENT}; text-decoration: none; word-break: break-word; }
    a:hover { text-decoration: underline; }
    code { background: #1E2028; padding: 1px 6px; border-radius: 4px; font-size: 14px; font-family: ui-monospace, "SF Mono", Menlo, monospace; }
    pre { background: #1E2028; border: 1px solid #44464F; border-radius: 8px; padding: 14px 16px; overflow-x: auto; }
    pre code { background: none; padding: 0; }
    address { font-style: normal; background: #1E2028; border: 1px solid #44464F; border-radius: 12px; padding: 16px 20px; margin-top: 8px; }
    table { width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 14px; }
    th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid #44464F; color: #C4C6CF; vertical-align: top; }
    th { color: #E3E2E6; font-weight: 700; }
    blockquote { border-left: 3px solid ${ACCENT}; padding: 4px 16px; margin: 16px 0; color: #C4C6CF; background: #1E2028; border-radius: 4px; }
    hr { border: none; border-top: 1px solid #44464F; margin: 56px 0; }
`;

function parseDoc(md) {
  const sepIdx = md.indexOf('\n---');
  const header = md.slice(0, sepIdx);
  const body = md.slice(md.indexOf('\n', md.indexOf('\n---') + 1) + 1);

  const titleMatch = header.match(/^#\s+(.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : 'Minesweeper';

  const metaLines = [];
  const ledeLines = [];
  for (const line of header.split('\n')) {
    if (/^#\s+/.test(line)) continue;
    if (/^\*\*[^*]+:\*\*/.test(line)) {
      metaLines.push(line.replace(/\*\*/g, '').trim());
      continue;
    }
    ledeLines.push(line);
  }
  const metaLine = metaLines.join(' &nbsp;·&nbsp; ');

  const ledeMd = ledeLines.join('\n').trim();
  const ledeHtml = ledeMd ? marked.parse(ledeMd, { gfm: true }) : '';
  const bodyHtml = marked.parse(body, { gfm: true });

  return { title, metaLine, ledeHtml, bodyHtml };
}

function render(opts) {
  const { lang, pageTitle, canonical, description, crumbHref, crumbLabel,
    langCurrent, langOtherHref, langOther, title, metaLine, ledeHtml,
    bodyHtml, hreflangEs, hreflangEn } = opts;
  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${pageTitle}</title>
  <link rel="canonical" href="${canonical}">
  <link rel="alternate" hreflang="es" href="${hreflangEs}">
  <link rel="alternate" hreflang="en" href="${hreflangEn}">
  <link rel="alternate" hreflang="x-default" href="${hreflangEs}">
  <meta name="description" content="${description}">
  <link rel="icon" href="/assets/senda-avatar.svg" type="image/svg+xml">
  <link rel="icon" href="/assets/senda-avatar-400.png" type="image/png">
  <style>${STYLE}  </style>
</head>
<body>
<main>
  <p class="crumbs"><a href="${crumbHref}">${crumbLabel}</a></p>
  <p class="lang-switch"><span class="current">${langCurrent}</span> &nbsp;·&nbsp; <a href="${langOtherHref}">${langOther}</a></p>

  <h1>${title}</h1>
  <p class="meta">
    ${metaLine}
  </p>
${ledeHtml ? `\n  <div class="lede">\n${ledeHtml}  </div>\n` : ''}
${bodyHtml}
</main>
</body>
</html>
`;
}

const PRIVACY_HREF = { hreflangEs: 'https://sendapr.com/privacy/minesweeper/', hreflangEn: 'https://sendapr.com/privacy/minesweeper/en/' };
const TERMS_HREF   = { hreflangEs: 'https://sendapr.com/terms/minesweeper/',   hreflangEn: 'https://sendapr.com/terms/minesweeper/en/' };
const DELETE_HREF  = { hreflangEs: 'https://sendapr.com/delete-account/minesweeper/', hreflangEn: 'https://sendapr.com/delete-account/minesweeper/en/' };

const PAGES = [
  {
    src: 'privacy-policy.md', out: 'privacy/minesweeper/index.html', lang: 'es', ...PRIVACY_HREF,
    pageTitle: 'Política de Privacidad — Buscaminas (Minesweeper)',
    canonical: 'https://sendapr.com/privacy/minesweeper/',
    description: 'Política de privacidad de Buscaminas (Minesweeper) — el buscaminas del día de SENDA LLC, parte de Juegos Senda.',
    crumbHref: '/privacy/', crumbLabel: '← Políticas de Privacidad',
    langCurrent: 'Español', langOtherHref: '/privacy/minesweeper/en/', langOther: 'English',
  },
  {
    src: 'privacy-policy.en.md', out: 'privacy/minesweeper/en/index.html', lang: 'en', ...PRIVACY_HREF,
    pageTitle: 'Privacy Policy — Minesweeper',
    canonical: 'https://sendapr.com/privacy/minesweeper/en/',
    description: "Privacy policy for Minesweeper — SENDA LLC's daily minesweeper, part of Juegos Senda.",
    crumbHref: '/privacy/', crumbLabel: '← Privacy Policies',
    langCurrent: 'English', langOtherHref: '/privacy/minesweeper/', langOther: 'Español',
  },
  {
    src: 'terms-of-service.md', out: 'terms/minesweeper/index.html', lang: 'es', ...TERMS_HREF,
    pageTitle: 'Términos de Servicio — Buscaminas (Minesweeper)',
    canonical: 'https://sendapr.com/terms/minesweeper/',
    description: 'Términos de Servicio de Buscaminas (Minesweeper) — el buscaminas del día de SENDA LLC, parte de Juegos Senda.',
    crumbHref: '/terms/', crumbLabel: '← Términos de Servicio',
    langCurrent: 'Español', langOtherHref: '/terms/minesweeper/en/', langOther: 'English',
  },
  {
    src: 'terms-of-service.en.md', out: 'terms/minesweeper/en/index.html', lang: 'en', ...TERMS_HREF,
    pageTitle: 'Terms of Service — Minesweeper',
    canonical: 'https://sendapr.com/terms/minesweeper/en/',
    description: "Terms of Service for Minesweeper — SENDA LLC's daily minesweeper, part of Juegos Senda.",
    crumbHref: '/terms/', crumbLabel: '← Terms of Service',
    langCurrent: 'English', langOtherHref: '/terms/minesweeper/', langOther: 'Español',
  },
  {
    src: 'account-deletion.md', out: 'delete-account/minesweeper/index.html', lang: 'es', ...DELETE_HREF,
    pageTitle: 'Eliminar tu cuenta — Buscaminas (Minesweeper)',
    canonical: 'https://sendapr.com/delete-account/minesweeper/',
    description: 'Cómo salir de Buscaminas (Minesweeper) o eliminar tu cuenta de Juegos Senda entera, qué se borra en cada caso y cuánto tarda.',
    crumbHref: '/privacy/minesweeper/', crumbLabel: '← Política de Privacidad',
    langCurrent: 'Español', langOtherHref: '/delete-account/minesweeper/en/', langOther: 'English',
  },
  {
    src: 'account-deletion.en.md', out: 'delete-account/minesweeper/en/index.html', lang: 'en', ...DELETE_HREF,
    pageTitle: 'Delete your account — Minesweeper',
    canonical: 'https://sendapr.com/delete-account/minesweeper/en/',
    description: 'How to leave Minesweeper or delete your whole Juegos Senda account, what is erased in each case, and how long it takes.',
    crumbHref: '/privacy/minesweeper/en/', crumbLabel: '← Privacy Policy',
    langCurrent: 'English', langOtherHref: '/delete-account/minesweeper/', langOther: 'Español',
  },
];

let written = 0;
for (const p of PAGES) {
  const srcPath = path.join(LEGAL_DIR, p.src);
  if (!fs.existsSync(srcPath)) {
    console.log(`SKIP ${p.out} (no source ${p.src})`);
    continue;
  }
  const parsed = parseDoc(fs.readFileSync(srcPath, 'utf8'));
  const html = render({ ...p, ...parsed });
  const outPath = path.join(SENDAPR_PUBLIC, p.out);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, html);
  console.log(`Wrote ${p.out}`);
  written++;
}
console.log(`\n${written} page(s) written into ${SENDAPR_PUBLIC}`);
