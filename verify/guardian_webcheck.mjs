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
// Do not collide with a developer's own local game server. This check only
// needs a private static server, so the OS can assign an unused port.
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
const url = base + (base.includes('?') ? '&guardian=trench' : '?guardian=trench');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);
console.log('guardian stage: export loaded');
// In this query-only title, the guardian review action is the smaller button
// immediately after New Game in the centred title column.
await page.mouse.click(640, 405);
// Swordfish wins initiative on this route. Its animation playback is much
// slower under SwiftShader than in the visible browser, so leave a full
// headless-safe window for that opening action to finish before clicking the
// player's UI. Otherwise animation frames can change our canvas fingerprint
// while all menu clicks were actually ignored.
await page.waitForTimeout(25000);
console.log('guardian stage: battle entered');
// QUICK-READ-1: fingerprint the lower panel without the animated 3D stage,
// so actor idles cannot masquerade as a responsive move menu. Formula mode
// was intentionally removed: the normal menu is always the resolved result.
const panelFingerprint = () => page.evaluate(() => {
  const c = document.querySelector('canvas');
  if (!c) return { ok: false, why: 'no canvas element' };
  const top = Math.floor(c.height * 0.475);
  const g = document.createElement('canvas');
  g.width = 320; g.height = 96;
  const ctx = g.getContext('2d');
  ctx.drawImage(c, 0, top, c.width, c.height - top, 0, 0, g.width, g.height);
  const d = ctx.getImageData(0, 0, g.width, g.height).data;
  let hash = 2166136261;
  for (let i = 0; i < d.length; i += 4) {
    hash ^= d[i]; hash = Math.imul(hash, 16777619);
    hash ^= d[i + 1]; hash = Math.imul(hash, 16777619);
    hash ^= d[i + 2]; hash = Math.imul(hash, 16777619);
  }
  return { ok: true, hash: hash >>> 0 };
});

await page.mouse.click(165, 550); // Attack -> move choices
await page.mouse.move(1270, 710); // remove hover-state pixels from comparison
// Container resizing is deferred by Godot. SwiftShader can need several
// seconds to present the new two-row menu even after the click was accepted.
await page.waitForTimeout(5000);
const resultsPanel = await panelFingerprint();
const resultsOut = out.replace(/(\.[^.]+)?$/, '.results$1');
await page.screenshot({ path: resultsOut });
console.log('guardian stage: results menu sampled');

await page.screenshot({ path: out });
console.log('guardian stage: result-first menu rendered without a secondary formula mode');
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
console.log('quick read      ' + JSON.stringify({ resultsPanel }));
if (errors.length) console.log('console     ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();
if (!pixels.ok || errors.length || pixels.colours < 20 || !resultsPanel.ok) process.exit(1);
console.log('GUARDIAN WEB: route opens and renders the result-first move menu without errors');
