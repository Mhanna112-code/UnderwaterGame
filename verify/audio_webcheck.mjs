// Browser WebAudio boundary: a cold load must not begin audible playback,
// while the real New Game click must unlock Godot's AudioContext and start
// the delivered Start Game sound. Headless state/asset gates cover cue
// selection; this catches browser autoplay failures they cannot observe.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/audio-web.png';
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
if (!live) await new Promise(r => server.listen(0, r));

const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const cdp = await page.context().newCDPSession(page);
const contexts = new Map();
cdp.on('WebAudio.contextCreated', ({ context }) => contexts.set(context.contextId, context));
cdp.on('WebAudio.contextChanged', ({ context }) => contexts.set(context.contextId, context));
await cdp.send('WebAudio.enable');

const errors = [];
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', e => errors.push(String(e)));
const base = live ? dir : `http://localhost:${server.address().port}/`;
await page.goto(base, { waitUntil: 'load' });
await page.waitForTimeout(25000);
const before = [...contexts.values()].map(c => c.contextState);

// Fresh browser storage gives the normal one-button title. This trusted click
// is the production path that plays UI START GAME and opens the intro crawl.
await page.mouse.click(640, 390);
await page.waitForTimeout(2000);
const after = [...contexts.values()].map(c => c.contextState);
await page.screenshot({ path: out });

console.log('audio before ' + JSON.stringify(before));
console.log('audio after  ' + JSON.stringify(after));
if (errors.length) console.log('console      ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();

if (before.includes('running')) {
  console.log('AUDIO WEB: cold load started a running AudioContext before user interaction');
  process.exit(1);
}
if (!after.includes('running')) {
  console.log('AUDIO WEB: New Game click did not unlock a running AudioContext');
  process.exit(1);
}
if (errors.length) {
  console.log('AUDIO WEB: browser errors');
  process.exit(1);
}
console.log('AUDIO WEB: cold title stays gated and New Game unlocks WebAudio');
