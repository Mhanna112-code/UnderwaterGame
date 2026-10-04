// Browser boundary for the Slice-4 maze map. The GDScript regression proves
// geometry/data truth; this drives the exported Web build as a reviewer does:
// load the direct maze route, open M, then press H and record the visible
// closed-to-open navigation change.
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const dir = process.argv[2] || 'docs';
const mapOut = process.argv[3] || '/tmp/maze-map-closed.png';
const openOut = process.argv[4] || '/tmp/maze-map-open.png';
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json' };

const live = dir.startsWith('http');
const server = http.createServer((request, response) => {
  let file = decodeURIComponent(request.url.split('?')[0]);
  if (file === '/') file = '/index.html';
  const localPath = path.join(dir, file);
  if (!fs.existsSync(localPath)) { response.writeHead(404); response.end('no'); return; }
  response.writeHead(200, {
    'Content-Type': TYPES[path.extname(localPath)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  fs.createReadStream(localPath).pipe(response);
});
if (!live) await new Promise(resolve => server.listen(0, resolve));

const browser = await chromium.launch({
  executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
    '--ignore-gpu-blocklist', '--enable-gpu-rasterization'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
page.on('pageerror', error => errors.push(String(error)));
const base = live ? dir : `http://localhost:${server.address().port}/`;
const url = base + (base.includes('?') ? '&maze=1' : '?maze=1');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);
// Do not click the canvas here. Godot's pointer-lock request is useful for
// swimming, but this review route only exercises the keyboard map controls;
// Chromium reports a WrongDocumentError for a headless pointer-lock request
// even when the page itself renders correctly. Keyboard focus after load is
// sufficient for M/H and keeps a browser-console failure meaningful.
await page.keyboard.press('KeyM');
await page.waitForTimeout(800);
await page.screenshot({ path: mapOut });

const sample = () => page.evaluate(() => {
  const canvas = document.querySelector('canvas');
  if (!canvas) return { ok: false, why: 'no canvas' };
  const copy = document.createElement('canvas');
  copy.width = 160; copy.height = 90;
  const context = copy.getContext('2d');
  context.drawImage(canvas, 0, 0, copy.width, copy.height);
  const pixels = Array.from(context.getImageData(0, 0, copy.width, copy.height).data);
  const colours = new Set();
  for (let index = 0; index < pixels.length; index += 4) {
    colours.add(`${pixels[index] >> 3},${pixels[index + 1] >> 3},${pixels[index + 2] >> 3}`);
  }
  return { ok: true, colours: colours.size, pixels };
});
const closed = await sample();
await page.keyboard.press('KeyH');
await page.waitForTimeout(1600);
await page.screenshot({ path: openOut });
const opened = await sample();
let changed = 0;
if (closed.ok && opened.ok) {
  for (let index = 0; index < closed.pixels.length; index += 4) {
    const difference = Math.abs(closed.pixels[index] - opened.pixels[index])
      + Math.abs(closed.pixels[index + 1] - opened.pixels[index + 1])
      + Math.abs(closed.pixels[index + 2] - opened.pixels[index + 2]);
    if (difference > 24) changed++;
  }
}
console.log(`maze map canvas ${JSON.stringify({ closed: { ok: closed.ok, colours: closed.colours }, opened: { ok: opened.ok, colours: opened.colours }, changed })}`);
if (errors.length) console.log('console ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();

if (!closed.ok || !opened.ok || closed.colours < 20 || opened.colours < 20 || changed < 120 || errors.length) {
  console.log('MAZE WEB: direct maze route did not visibly render M and H navigation states');
  process.exit(1);
}
console.log(`MAZE WEB: ?maze=1 rendered map-before/map-after-H (${changed} changed samples)`);
