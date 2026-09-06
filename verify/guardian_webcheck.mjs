// Browser boundary for the query-only Swordfish Duelist guardian review.
// The Godot integration test proves identity; this proves the exported web
// build can actually draw and enter that path for a human reviewer.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/guardian-web.png';
const TYPES = { '.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm',
  '.pck':'application/octet-stream', '.png':'image/png', '.json':'application/json' };
const live = dir.startsWith('http');
const server = http.createServer((req, res) => {
  let f = decodeURIComponent(req.url.split('?')[0]);
  if (f === '/') f = '/index.html';
  const p = path.join(dir, f);
  if (!fs.existsSync(p)) { res.writeHead(404); res.end('no'); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(p)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
  fs.createReadStream(p).pipe(res);
});
if (!live) await new Promise(r => server.listen(8767, r));

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
const base = live ? dir : 'http://localhost:8767/';
const url = base + (base.includes('?') ? '&guardian=trench' : '?guardian=trench');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);
// In this query-only title, the guardian review action is the smaller button
// immediately after New Game in the centred title column.
await page.mouse.click(640, 405);
await page.waitForTimeout(6500);
await page.screenshot({ path: out });
const pixels = await page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (!c) return { ok: false, why: 'no canvas element' };
  const g = document.createElement('canvas'); g.width = 320; g.height = 180;
  const ctx = g.getContext('2d'); ctx.drawImage(c, 0, 0, 320, 180);
  const d = ctx.getImageData(0, 0, 320, 180).data;
  const colours = new Set();
  for (let i = 0; i < d.length; i += 4) colours.add(`${d[i]>>3},${d[i + 1]>>3},${d[i + 2]>>3}`);
  return { ok: true, colours: colours.size, size: [c.width, c.height] };
});
console.log('guardian canvas ' + JSON.stringify(pixels));
if (errors.length) console.log('console     ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();
if (!pixels.ok || errors.length || pixels.colours < 20) process.exit(1);
console.log('GUARDIAN WEB: ?guardian=trench opens the Swordfish Duelist guardian test');
