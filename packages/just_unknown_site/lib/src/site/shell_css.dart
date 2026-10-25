import '../model/assets.dart';
import '../model/palette.dart';

/// CSS for the static SEO shell, in the same colours (from [JuPalette]),
/// type and spacing as the Flutter theme. Fonts point at the URLs Flutter web
/// loads them from ([JuAssets.fontBase]) so the browser downloads each face
/// once; a site that serves its own (smaller) copies passes their
/// `@font-face` rules as [fontFaces]. A site adds its own rules with
/// [extra].
String shellCss({String extra = '', String? fontFaces}) {
  const p = JuPalette.hex;
  const f = JuAssets.fontBase;
  final faces =
      fontFaces ??
      '''
@font-face{font-family:'SpaceGrotesk';font-weight:700;font-display:swap;src:url($f/SpaceGrotesk-Bold.ttf) format('truetype')}
@font-face{font-family:'SpaceGrotesk';font-weight:500;font-display:swap;src:url($f/SpaceGrotesk-Medium.ttf) format('truetype')}
@font-face{font-family:'Inter';font-weight:400;font-display:swap;src:url($f/Inter-Regular.ttf) format('truetype')}
@font-face{font-family:'Inter';font-weight:500;font-display:swap;src:url($f/Inter-Medium.ttf) format('truetype')}
@font-face{font-family:'Inter';font-weight:600;font-display:swap;src:url($f/Inter-SemiBold.ttf) format('truetype')}
@font-face{font-family:'JetBrainsMono';font-weight:400;font-display:swap;src:url($f/JetBrainsMono-Regular.ttf) format('truetype')}
''';
  return '''
$faces:root{--bg:${p(JuPalette.background)};--surface:${p(JuPalette.surface)};--surface-soft:${p(JuPalette.surfaceSoft)};--text:${p(JuPalette.text)};--muted:${p(JuPalette.textMuted)};--border:${p(JuPalette.border)};--primary:${p(JuPalette.primary)};--on-primary:${p(JuPalette.onPrimary)};--code:${p(JuPalette.codeBackground)};--error:${p(JuPalette.error)};color-scheme:dark}
html.light{--primary:${p(JuPalette.lightPrimary)};--on-primary:${p(JuPalette.lightOnPrimary)};--bg:${p(JuPalette.lightBackground)};--surface:${p(JuPalette.lightSurface)};--surface-soft:${p(JuPalette.lightSurfaceSoft)};--text:${p(JuPalette.lightText)};--muted:${p(JuPalette.lightTextMuted)};--border:${p(JuPalette.lightBorder)};--code:${p(JuPalette.lightCodeBackground)};color-scheme:light}
html,body{margin:0;padding:0;background:var(--bg);color:var(--text)}
body{font-family:'Inter',system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;font-size:16px;line-height:1.6;-webkit-font-smoothing:antialiased}
#static-shell{position:relative;min-height:100vh;transition:opacity .16s ease}
#static-shell.is-hidden{opacity:0;pointer-events:none}
/* No specificity, so a classed link's own colour wins. */
:where(#static-shell) a{color:inherit}
.s-wrap{max-width:1120px;margin:0 auto;padding:0 20px}
@media(min-width:600px){.s-wrap{padding:0 32px}}
@media(min-width:1024px){.s-wrap{padding:0 48px}}
.s-header{height:68px;display:flex;align-items:center;justify-content:space-between}
.s-brand{display:flex;align-items:center;gap:10px;text-decoration:none;font-family:'SpaceGrotesk',sans-serif;font-weight:700;font-size:19px}
.s-brand img{width:28px;height:28px;border-radius:6px}
.s-nav{display:none;gap:4px}
@media(min-width:1024px){.s-nav{display:flex}}
.s-nav a{color:var(--muted);text-decoration:none;padding:10px 12px;font-weight:600;font-size:15px}
.s-nav a[aria-current=page]{color:var(--text);box-shadow:inset 0 -2px 0 var(--primary)}
.s-hero{padding:96px 0 48px;background:radial-gradient(1100px 600px at 90% -10%,${JuPalette.rgba(JuPalette.primary, .2)},transparent 70%)}
@media(max-width:599px){.s-hero{padding:48px 0 32px}}
.s-eyebrow{color:var(--primary);text-transform:uppercase;letter-spacing:.1em;font-size:12px;font-weight:600;margin:0 0 16px}
h1,h2,h3{font-family:'SpaceGrotesk',sans-serif;font-weight:700;line-height:1.1;letter-spacing:-.02em;margin:0}
h1{font-size:clamp(36px,6vw,64px);max-width:820px}
h2{font-size:clamp(28px,3.5vw,36px);max-width:760px}
h3{font-size:20px;font-weight:500;letter-spacing:-.01em;margin-bottom:8px}
.s-lede{font-size:18px;color:var(--muted);max-width:640px;margin:24px 0 0}
.s-actions{display:flex;flex-wrap:wrap;gap:12px;margin-top:32px}
.s-btn{display:inline-flex;align-items:center;gap:6px;padding:14px 22px;border-radius:8px;border:1px solid var(--border);text-decoration:none;font-weight:600;font-size:15px;color:var(--text)}
.s-btn.primary{background:var(--primary);border-color:var(--primary);color:var(--on-primary)}
.s-section{padding:64px 0}
@media(max-width:1023px){.s-section{padding:40px 0}}
.s-body{color:var(--muted);font-size:18px;max-width:680px;margin:16px 0 0}
.s-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:24px;margin-top:32px}
.s-card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:24px}
.s-card p{color:var(--muted);margin:8px 0 0}
.s-card .s-badge{float:right}
.s-badge{display:inline-block;padding:4px 10px;border-radius:999px;border:1px solid var(--border);background:var(--surface-soft);font-size:13px;font-weight:600;color:var(--text)}
.s-list{list-style:none;margin:32px 0 0;padding:0}
.s-list li{padding:20px 0;border-bottom:1px solid var(--border)}
.s-list li p{color:var(--muted);margin:4px 0}
.s-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px;margin-top:32px}
.s-stat{background:var(--surface-soft);border:1px solid var(--border);border-radius:14px;padding:20px}
.s-stat b{display:block;font-family:'SpaceGrotesk',sans-serif;font-size:28px;color:var(--primary)}
.s-stat span{font-size:13px;color:var(--muted);font-weight:600}
.s-code{margin-top:32px;background:var(--code);border:1px solid var(--border);border-radius:14px;padding:14px 20px;font-family:'JetBrainsMono',ui-monospace,monospace;font-size:14px;overflow-x:auto}
.s-code::before{content:'\$ ';color:var(--primary)}
.s-links{display:flex;flex-wrap:wrap;gap:12px;margin-top:32px}
.s-links .s-btn{padding:10px 14px}
.s-more{color:var(--primary);text-decoration:none;font-weight:600;font-size:15px;display:inline-block;margin-top:16px}
.s-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:32px}
.s-chips a{text-decoration:none;font-size:13px;font-weight:600;padding:6px 12px;border-radius:999px;border:1px solid var(--border);background:var(--surface-soft)}
.s-chips a[aria-current=page]{border-color:var(--primary);color:var(--primary)}
.s-post-list{max-width:800px;margin-top:32px}
.s-post-list article{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:24px;margin-bottom:16px}
.s-post-list article h3{font-size:22px;font-weight:700}
.s-post-list article a{text-decoration:none}
.s-meta{font-size:13px;color:var(--muted);font-weight:600}
.s-prose{max-width:720px;margin:0 auto;padding-bottom:64px}
.s-prose h1{font-size:clamp(32px,5vw,44px)}
.s-prose h2{font-size:28px;margin-top:32px}
.s-prose h3{font-size:22px;font-weight:700;margin-top:24px}
.s-prose p,.s-prose li{font-size:18px;color:var(--text)}
.s-prose a{color:var(--primary)}
.s-prose pre{background:var(--code);border:1px solid var(--border);border-radius:14px;padding:16px;overflow-x:auto;font-family:'JetBrainsMono',ui-monospace,monospace;font-size:14px}
.s-prose code{font-family:'JetBrainsMono',ui-monospace,monospace;font-size:.92em}
.s-prose blockquote{margin:0;padding:8px 16px;border-left:3px solid var(--primary);color:var(--muted)}
.s-footer{background:var(--surface);border-top:1px solid var(--border);padding:48px 0;margin-top:48px}
.s-footer-cols{display:grid;grid-template-columns:2fr 1fr 1fr;gap:32px}
@media(max-width:1023px){.s-footer-cols{grid-template-columns:1fr}}
.s-footer h4{margin:0 0 12px;font-size:15px}
.s-footer a{display:block;color:var(--muted);text-decoration:none;font-size:14px;padding:3px 0}
.s-footer p{color:var(--muted);font-size:14px;max-width:320px;margin:12px 0 0}
.s-footer .s-copy{max-width:none;border-top:1px solid var(--border);margin-top:40px;padding-top:16px;color:var(--muted);font-size:14px}
$extra''';
}
