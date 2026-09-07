// Browser boundary for PR #50's opt-in review route. It proves that
// ?special=1 exposes the one-click special-encounter action and that the
// action reaches both the real guardian warning and diver carousel.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/special-web.png';
const TYPES = { '.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm',
  '.pck':'application/octet-stream', '.png':'image/png', '.json':'application/json' };
const live = dir.startsWith('http');
const server = http.createServer((req, res) => {
  let f = decodeURIComponent(req.url.split('?')[0]);
  if (f === '/') f = '/index.html';
  const p = path.join(dir, f);
  if (!fs.existsSync(p)) { res.writeHead(404); res.end('no'); return; }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(p)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  fs.createReadStream(p).pipe(res);
});
// Use an OS-assigned port: 8767 is commonly occupied by a developer's live
// local playtest, and this isolated static server has no reason to collide.
if (!live) await new Promise(r => server.listen(0, r));

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));

const base = live ? dir : `http://localhost:${server.address().port}/`;
const url = base + (base.includes('?') ? '&special=1' : '?special=1');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);

const sample = () => page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (!c) return null;
  const g = document.createElement('canvas'); g.width = 160; g.height = 90;
  const ctx = g.getContext('2d'); ctx.drawImage(c, 0, 0, 160, 90);
  return Array.from(ctx.getImageData(0, 0, 160, 90).data);
});
const changed = (a, b) => {
  if (!a || !b) return 0;
  let count = 0;
  for (let i = 0; i < a.length; i += 4) {
    if (Math.abs(a[i] - b[i]) + Math.abs(a[i + 1] - b[i + 1]) + Math.abs(a[i + 2] - b[i + 2]) > 18) count++;
  }
  return count;
};

const title = await sample();
await page.mouse.click(640, 405); // Play Special Encounter Test
await page.waitForTimeout(1200);
const warning = await sample();
await page.mouse.click(640, 427); // Enter
await page.waitForTimeout(3000);
const carousel = await sample();
await page.screenshot({ path: out });

const warningDelta = changed(title, warning);
const carouselDelta = changed(warning, carousel);
console.log(`special canvas {"warning_delta":${warningDelta},"carousel_delta":${carouselDelta}}`);
if (errors.length) console.log('console        ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();

if (!title || !warning || !carousel) { console.log('SPECIAL WEB: no canvas element'); process.exit(1); }
if (errors.length) { console.log('SPECIAL WEB: browser errors'); process.exit(1); }
if (warningDelta < 250 || carouselDelta < 250) {
  console.log('SPECIAL WEB: review action did not traverse title -> warning -> diver carousel');
  process.exit(1);
}
console.log('SPECIAL WEB: ?special=1 reaches the guardian warning and diver carousel');
