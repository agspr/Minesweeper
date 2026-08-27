// Renders Nona's legal Markdown into the sendapr.com page template and writes
// the result into the sendapr-landing repo, so the public pages are GENERATED
// from the same source the app links to instead of hand-transcribed.
//
// Output (consumed by the sendapr-landing Vercel deploy):
//   public/privacy/nona/index.html            (ES, privacy-policy.md)
//   public/privacy/nona/en/index.html         (EN, privacy-policy.en.md)
//   public/terms/nona/index.html              (ES, terms-of-service.md)
//   public/terms/nona/en/index.html           (EN, terms-of-service.en.md)
//   public/delete-account/nona/index.html     (ES, account-deletion.md)
//   public/delete-account/nona/en/index.html  (EN, account-deletion.en.md)
//
// Descends from two earlier generators, and deliberately takes one thing from
// each: the BILINGUAL structure (hreflang pairs, per-page language switcher)
// from PRende's, and the LEDE-AWARE parseDoc from CINCO's. Cloning PRende's
// alone would have silently eaten account-deletion's intro paragraph — see the
// comment on parseDoc.
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

// Cobalto — Nona's default palette (`nona_config.dart: defaultPalette`), so the
// pages read as the same product as the app. If that default ever changes,
// change it here too.
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

// Splits "# Title / **Effective:** … / **Last updated:** … / [lede] / --- / body".
//
// The `lede` exists because account-deletion.md puts an intro paragraph — plus
// a bullet list and a blockquote — between the date lines and the first `---`.
// PRende's version of this function treated everything before the separator as
// "header" and kept only the `**`-bearing lines from it, which SILENTLY DROPPED
// that paragraph while still producing a valid-looking page. Keep this shape.
function parseDoc(md) {
  const sepIdx = md.indexOf('\n---');
  const header = md.slice(0, sepIdx);
  const body = md.slice(md.indexOf('\n', md.indexOf('\n---') + 1) + 1);

  const titleMatch = header.match(/^#\s+(.+)$/m);
  const title = titleMatch ? titleMatch[1].trim() : 'Nona';

  const metaLines = [];
  const ledeLines = [];
  for (const line of header.split('\n')) {
    if (/^#\s+/.test(line)) continue;                 // the H1, rendered separately
    if (/^\*\*[^*]+:\*\*/.test(line)) {               // "**Effective:** …"
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

// Both language variants of a section point at the same pair of URLs, so search
// engines treat them as translations of each other rather than duplicates.
const PRIVACY_HREF = { hreflangEs: 'https://sendapr.com/privacy/nona/', hreflangEn: 'https://sendapr.com/privacy/nona/en/' };
const TERMS_HREF   = { hreflangEs: 'https://sendapr.com/terms/nona/',   hreflangEn: 'https://sendapr.com/terms/nona/en/' };
const DELETE_HREF  = { hreflangEs: 'https://sendapr.com/delete-account/nona/', hreflangEn: 'https://sendapr.com/delete-account/nona/en/' };

const PAGES = [
  {
    src: 'privacy-policy.md', out: 'privacy/nona/index.html', lang: 'es', ...PRIVACY_HREF,
    pageTitle: 'Política de Privacidad — Nona',
    canonical: 'https://sendapr.com/privacy/nona/',
    description: 'Política de privacidad de Nona — el sudoku del día de SENDA LLC, parte de Juegos Senda.',
    crumbHref: '/privacy/', crumbLabel: '← Políticas de Privacidad',
    langCurrent: 'Español', langOtherHref: '/privacy/nona/en/', langOther: 'English',
  },
  {
    src: 'privacy-policy.en.md', out: 'privacy/nona/en/index.html', lang: 'en', ...PRIVACY_HREF,
    pageTitle: 'Privacy Policy — Nona',
    canonical: 'https://sendapr.com/privacy/nona/en/',
    description: "Privacy policy for Nona — SENDA LLC's daily sudoku, part of Juegos Senda.",
    crumbHref: '/privacy/', crumbLabel: '← Privacy Policies',
    langCurrent: 'English', langOtherHref: '/privacy/nona/', langOther: 'Español',
  },
  {
    src: 'terms-of-service.md', out: 'terms/nona/index.html', lang: 'es', ...TERMS_HREF,
    pageTitle: 'Términos de Servicio — Nona',
    canonical: 'https://sendapr.com/terms/nona/',
    description: 'Términos de Servicio de Nona — el sudoku del día de SENDA LLC, parte de Juegos Senda.',
    crumbHref: '/terms/', crumbLabel: '← Términos de Servicio',
    langCurrent: 'Español', langOtherHref: '/terms/nona/en/', langOther: 'English',
  },
  {
    src: 'terms-of-service.en.md', out: 'terms/nona/en/index.html', lang: 'en', ...TERMS_HREF,
    pageTitle: 'Terms of Service — Nona',
    canonical: 'https://sendapr.com/terms/nona/en/',
    description: "Terms of Service for Nona — SENDA LLC's daily sudoku, part of Juegos Senda.",
    crumbHref: '/terms/', crumbLabel: '← Terms of Service',
    langCurrent: 'English', langOtherHref: '/terms/nona/', langOther: 'Español',
  },
  {
    // Play and Apple both expect a reachable account-deletion URL. Nona's is
    // generated from Markdown like the rest, so refining it is an edit plus a
    // re-run rather than a hand transcription.
    src: 'account-deletion.md', out: 'delete-account/nona/index.html', lang: 'es', ...DELETE_HREF,
    pageTitle: 'Eliminar tu cuenta — Nona',
    canonical: 'https://sendapr.com/delete-account/nona/',
    description: 'Cómo salir de Nona o eliminar tu cuenta de Juegos Senda entera, qué se borra en cada caso y cuánto tarda.',
    crumbHref: '/privacy/nona/', crumbLabel: '← Política de Privacidad',
    langCurrent: 'Español', langOtherHref: '/delete-account/nona/en/', langOther: 'English',
  },
  {
    src: 'account-deletion.en.md', out: 'delete-account/nona/en/index.html', lang: 'en', ...DELETE_HREF,
    pageTitle: 'Delete your account — Nona',
    canonical: 'https://sendapr.com/delete-account/nona/en/',
    description: 'How to leave Nona or delete your whole Juegos Senda account, what is erased in each case, and how long it takes.',
    crumbHref: '/privacy/nona/en/', crumbLabel: '← Privacy Policy',
    langCurrent: 'English', langOtherHref: '/delete-account/nona/', langOther: 'Español',
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
