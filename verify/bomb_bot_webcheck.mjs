// Exported-browser boundary for DZ-26. The focused query route is
// supplementary review plumbing; it enters the same authored World/Battle
// path as normal physical travel, then real canvas clicks advance far enough
// for Bomb Bot to take a production turn. Normal-entry reachability remains a
// separate mandatory journey.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const target = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/bomb-bot-web.png';
const live = target.startsWith('http');
const TYPES = { '.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm',
  '.pck':'application/octet-stream', '.png':'image/png', '.json':'application/json',
  '.ogg':'audio/ogg' };
const server = http.createServer((req, res) => {
  let file = decodeURIComponent(req.url.split('?')[0]);
  if (file === '/') file = '/index.html';
  const absolute = path.join(target, file);
  if (!fs.existsSync(absolute)) { res.writeHead(404); res.end('missing'); return; }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(absolute)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  fs.createReadStream(absolute).pipe(res);
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

const base = live ? target : `http://localhost:${server.address().port}/`;
const url = base + (base.includes('?') ? '&blocker=bomb_bot' : '?blocker=bomb_bot');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);

// The query route adds one focused action directly below New Game.
await page.mouse.click(640, 405);
await page.waitForTimeout(6000);

const canvasHealth = async () => page.evaluate(() => {
  const canvas = document.querySelector('canvas');
  if (!canvas) return { ok: false, why: 'no canvas' };
  const probe = document.createElement('canvas');
  probe.width = 320; probe.height = 180;
  const context = probe.getContext('2d');
  context.drawImage(canvas, 0, 0, 320, 180);
  const pixels = context.getImageData(0, 0, 320, 180).data;
  const colours = new Set();
  let enemyHp = 0;
  for (let y = 18; y < 31; y++) {
    for (let x = 266; x < 316; x++) {
      const i = (y * 320 + x) * 4;
      const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
      if (r > 80 && r > g * 1.6 && r > b * 1.25) enemyHp++;
    }
  }
  for (let i = 0; i < pixels.length; i += 4)
    colours.add(`${pixels[i]>>3},${pixels[i + 1]>>3},${pixels[i + 2]>>3}`);
  return { ok: true, width: canvas.width, height: canvas.height, colours: colours.size, enemyHp };
});

const entered = await canvasHealth();
if (!entered.ok || entered.enemyHp < 20) {
  await page.screenshot({ path: out });
  console.log('BOMB BOT WEB: focused route did not enter the authored fight ' + JSON.stringify(entered));
  await browser.close(); if (!live) server.close(); process.exit(1);
}

// Attack, first move, and first target all occupy the first 300 px menu cell.
// Repeated real clicks advance whichever of those three menus is presently
// active; clicks during animation/log holds are harmlessly ignored.
for (let i = 0; i < 120; i++) {
  await page.mouse.click(165, 550);
  await page.waitForTimeout(400);
}

const afterTurns = await canvasHealth();
await page.screenshot({ path: out });
if (errors.length) console.log('console ' + errors.slice(0, 10).join(' | '));
await browser.close();
if (!live) server.close();

if (errors.length) {
  console.log('BOMB BOT WEB: browser/Godot errors after entering or advancing the fight');
  process.exit(1);
}
if (!afterTurns.ok || afterTurns.colours < 20 || afterTurns.width !== 1280 || afterTurns.height !== 720) {
  console.log('BOMB BOT WEB: canvas died or stopped drawing ' + JSON.stringify(afterTurns));
  process.exit(1);
}
console.log('BOMB BOT WEB: exact exported route survives production fight turns without browser errors');
