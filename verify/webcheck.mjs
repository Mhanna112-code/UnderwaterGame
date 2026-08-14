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
const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));

await page.goto(live ? dir : 'http://localhost:8765/', { waitUntil: 'load' });
await page.waitForTimeout(25000);          // wasm compile + engine boot + first frames
await page.mouse.click(640, 400);          // the click that takes the pointer
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
if (errors.length) console.log('console   ' + errors.slice(0, 6).join(' | '));
await browser.close();
if (!live) server.close();

if (!spread.ok) { console.log('WEB: ' + spread.why); process.exit(1); }
if (spread.colours < 12) { console.log('WEB: canvas shows only ' + spread.colours + ' colours, the build is not drawing'); process.exit(1); }
console.log('WEB: the exported build boots and draws (' + spread.colours + ' distinct colours)');
