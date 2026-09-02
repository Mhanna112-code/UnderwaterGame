// Browser boundary for the opt-in Glassgoat route. It proves that ?boss=1
// exposes the one-click title action and that clicking it reaches a drawn
// red Tethys battle, rather than merely proving the exported WASM boots.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/tethys-web.png';
const titleOut = process.argv[4] || '/tmp/tethys-web-title.png';
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
if (!live) await new Promise(r => server.listen(8766, r));

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));

const base = live ? dir : 'http://localhost:8766/';
const url = base + (base.includes('?') ? '&boss=1' : '?boss=1');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);
await page.screenshot({ path: titleOut });

// The query-only boss button is the smaller action immediately below the
// primary New Game button in the centred 360px title column.
await page.mouse.click(640, 405);
await page.waitForTimeout(6500); // entrance Start -> Loop -> End -> first turn
await page.screenshot({ path: out });

const pixels = await page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (!c) return { ok: false, why: 'no canvas element' };
  const g = document.createElement('canvas'); g.width = 320; g.height = 180;
  const ctx = g.getContext('2d'); ctx.drawImage(c, 0, 0, 320, 180);
  const d = ctx.getImageData(0, 0, 320, 180).data;
  const colours = new Set(); let red = 0;
  for (let i = 0; i < d.length; i += 4) {
    const r = d[i], green = d[i + 1], b = d[i + 2];
    colours.add(`${r>>3},${green>>3},${b>>3}`);
    if (r > 45 && r > green * 1.35 && r > b * 1.15) red++;
  }
  return { ok: true, colours: colours.size, red, size: [c.width, c.height] };
});

console.log('boss canvas ' + JSON.stringify(pixels));
if (errors.length) console.log('console     ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();

if (!pixels.ok) { console.log('BOSS WEB: ' + pixels.why); process.exit(1); }
if (errors.length) { console.log('BOSS WEB: browser errors'); process.exit(1); }
if (pixels.colours < 20) { console.log('BOSS WEB: encounter did not draw'); process.exit(1); }
if (pixels.red < 20) { console.log('BOSS WEB: no red Tethys visible; query button may not have opened the boss fight'); process.exit(1); }
console.log(`BOSS WEB: ?boss=1 opens the playable Tethys fight (${pixels.red} red samples)`);
