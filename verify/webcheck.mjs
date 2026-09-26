// Does the exported build actually run in a browser?
// "The files exist" is not "Marc can play it". This serves docs/, loads the
// page, waits for the engine to start, screenshots, and fails if the canvas
// is still a blank field of one colour.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/web.png';
const TYPES = { '.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm',
  '.pck':'application/octet-stream', '.png':'image/png', '.json':'application/json' };

// point it at a live URL to check the thing Marc will actually open, or at a
// local directory to check the build before it ships
const live = dir.startsWith('http');
const server = http.createServer((req, res) => {
  let f = decodeURIComponent(req.url.split('?')[0]);
  if (f === '/') f = '/index.html';
  const p = path.join(dir, f);
  if (!fs.existsSync(p)) { res.writeHead(404); res.end('no'); return; }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(p)] || 'application/octet-stream',
    // harmless here, and matches what a real host should send
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  fs.createReadStream(p).pipe(res);
});
if (!live) await new Promise(r => server.listen(8765, r));

// headless Chromium ships without WebGL2, and Godot's web build needs it.
// SwiftShader gives us a real GL2 context in software so this gate tests the
// build rather than the browser's default flags.
const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
// Vercel preview links can be deployment-protected even when the main-game
// alias is public. `vercel env run` supplies this short-lived token only to
// the smoke process; keep it origin-scoped and never print or persist it.
const headers = process.env.VERCEL_OIDC_TOKEN
  ? { 'x-vercel-trusted-oidc-idp-token': process.env.VERCEL_OIDC_TOKEN }
  : {};
const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, extraHTTPHeaders: headers });
const page = await context.newPage();
const errors = [];
const worklets = [];
const failedWorklets = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
page.on('response', response => {
  if (/\.audio(?:\.position)?\.worklet\.js$/.test(response.url())) {
    const headers = response.headers();
    worklets.push({
      url: response.url().split('/').pop(), status: response.status(),
      type: headers['content-type'] || '',
      coop: headers['cross-origin-opener-policy'] || '',
      coep: headers['cross-origin-embedder-policy'] || '',
      corp: headers['cross-origin-resource-policy'] || '',
    });
  }
});
page.on('requestfailed', request => {
  if (/\.audio(?:\.position)?\.worklet\.js$/.test(request.url())) {
    failedWorklets.push({ url: request.url().split('/').pop(), failure: request.failure()?.errorText || 'unknown' });
  }
});

await page.goto(live ? dir : 'http://localhost:8765/', { waitUntil: 'load' });
await page.waitForTimeout(25000);          // wasm compile + engine boot + first frames

// A fresh browser context has no save, so the title's primary action starts
// a normal run immediately. This deliberately avoids query-string review
// shortcuts and proves the canvas receives real title-screen input.
const titleSignature = await page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (!c) return null;
  const g = document.createElement('canvas');
  g.width = 64; g.height = 36;
  const ctx = g.getContext('2d');
  ctx.drawImage(c, 0, 0, 64, 36);
  const d = ctx.getImageData(0, 0, 64, 36).data;
  let total = 0;
  for (let i = 0; i < d.length; i += 4) total += d[i] + d[i + 1] + d[i + 2];
  return total;
});
await page.mouse.click(640, 366);          // visible New Game center at 1280x720
await page.waitForTimeout(1500);
const focusAndHandoff = await page.evaluate(before => {
  const c = document.querySelector('canvas');
  if (!c) return { focused: false, changed: false };
  const g = document.createElement('canvas');
  g.width = 64; g.height = 36;
  const ctx = g.getContext('2d');
  ctx.drawImage(c, 0, 0, 64, 36);
  const d = ctx.getImageData(0, 0, 64, 36).data;
  let total = 0;
  for (let i = 0; i < d.length; i += 4) total += d[i] + d[i + 1] + d[i + 2];
  return { focused: document.activeElement === c, changed: before !== null && Math.abs(total - before) > 25000 };
}, titleSignature);
await page.keyboard.down('w');
await page.waitForTimeout(2500);
await page.keyboard.up('w');
await page.waitForTimeout(500);
await page.screenshot({ path: out });

// is anything actually drawn? sample the canvas for colour variety
const spread = await page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (!c) return { ok: false, why: 'no canvas element' };
  const g = document.createElement('canvas');
  g.width = 160; g.height = 90;
  const ctx = g.getContext('2d');
  ctx.drawImage(c, 0, 0, 160, 90);
  const d = ctx.getImageData(0, 0, 160, 90).data;
  const seen = new Set();
  for (let i = 0; i < d.length; i += 4) seen.add(`${d[i]>>3},${d[i+1]>>3},${d[i+2]>>3}`);
  return { ok: true, colours: seen.size, size: [c.width, c.height] };
});

console.log('canvas    ' + JSON.stringify(spread));
console.log('input     ' + JSON.stringify(focusAndHandoff));
if (live) console.log('isolation ' + JSON.stringify(await page.evaluate(() => ({ isolated: window.crossOriginIsolated, secure: window.isSecureContext }))));
if (worklets.length) console.log('worklets  ' + JSON.stringify(worklets));
if (failedWorklets.length) console.log('worklet failures ' + JSON.stringify(failedWorklets));
if (errors.length) console.log('console   ' + errors.slice(0, 6).join(' | '));
await browser.close();
if (!live) server.close();

if (!spread.ok) { console.log('WEB: ' + spread.why); process.exit(1); }
if (spread.colours < 12) { console.log('WEB: canvas shows only ' + spread.colours + ' colours, the build is not drawing'); process.exit(1); }
if (!focusAndHandoff.focused || !focusAndHandoff.changed) {
  console.log('WEB: normal-entry New Game did not take canvas focus and visibly leave title');
  process.exit(1);
}
if (errors.some(error => /Failed to load worklet module script/.test(error)) || failedWorklets.length) {
  console.log('WEB: deployed audio worklet failed to load');
  process.exit(1);
}
console.log('WEB: the exported build boots and draws (' + spread.colours + ' distinct colours)');
