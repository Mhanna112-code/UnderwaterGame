// Browser boundary for the public Door FBX reviewer route.  The semantic
// interaction is covered natively by key_door.gd; this makes sure the exact
// exported web URL actually enters the unpaused visual route a reviewer uses.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/key-door-web.png';
const TYPES = { '.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm',
  '.pck':'application/octet-stream', '.png':'image/png' };
const server = http.createServer((req, res) => {
  let file = decodeURIComponent(req.url.split('?')[0]);
  if (file === '/') file = '/index.html';
  const target = path.join(dir, file);
  if (!fs.existsSync(target)) { res.writeHead(404); res.end('missing'); return; }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(target)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  fs.createReadStream(target).pipe(res);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const { port } = server.address();

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
page.on('pageerror', error => errors.push(String(error)));
await page.goto(`http://127.0.0.1:${port}/?keydoor=1`, { waitUntil: 'load' });
await page.waitForTimeout(25000);
await page.screenshot({ path: out });

const canvas = await page.evaluate(() => {
  const source = document.querySelector('canvas');
  if (!source) return { ok: false, why: 'no canvas' };
  const copy = document.createElement('canvas');
  copy.width = 160; copy.height = 90;
  const ctx = copy.getContext('2d');
  ctx.drawImage(source, 0, 0, 160, 90);
  const pixels = ctx.getImageData(0, 0, 160, 90).data;
  const colors = new Set();
  for (let i = 0; i < pixels.length; i += 4) colors.add(`${pixels[i] >> 3},${pixels[i + 1] >> 3},${pixels[i + 2] >> 3}`);
  return { ok: true, colors: colors.size, dimensions: [source.width, source.height] };
});
console.log('key door canvas ' + JSON.stringify(canvas));
if (errors.length) console.log('key door console ' + errors.slice(0, 6).join(' | '));
await browser.close();
server.close();
if (!canvas.ok || canvas.colors < 12) process.exit(1);
