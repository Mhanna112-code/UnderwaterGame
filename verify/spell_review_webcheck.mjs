// Browser boundary for Slice 3's opt-in spell-review route. Source tests
// prove the temporary key items and point gates; this proves a human can load
// the exported build, see the title action at ?spells=1, and traverse the
// real Save / Update Spells surface into the actual Learn Spells tree by
// following the same two deliberate menu actions a player uses.
import { chromium } from 'playwright';
import http from 'http';
import fs from 'fs';
import path from 'path';

const dir = process.argv[2] || 'docs';
const out = process.argv[3] || '/tmp/spell-review-web.png';
const titleOut = process.argv[4] || '/tmp/spell-review-title.png';
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json' };
const live = dir.startsWith('http');
const server = http.createServer((req, res) => {
  let file = decodeURIComponent(req.url.split('?')[0]);
  if (file === '/') file = '/index.html';
  const localPath = path.join(dir, file);
  if (!fs.existsSync(localPath)) { res.writeHead(404); res.end('no'); return; }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(localPath)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  });
  fs.createReadStream(localPath).pipe(res);
});
if (!live) await new Promise(resolve => server.listen(0, resolve));

const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
page.on('pageerror', error => errors.push(String(error)));
const base = live ? dir : `http://localhost:${server.address().port}/`;
const url = base + (base.includes('?') ? '&spells=1' : '?spells=1');
await page.goto(url, { waitUntil: 'load' });
await page.waitForTimeout(25000);

const sample = () => page.evaluate(() => {
  const canvas = document.querySelector('canvas');
  if (!canvas) return { ok: false, why: 'no canvas element' };
  const copy = document.createElement('canvas');
  copy.width = 160; copy.height = 90;
  const context = copy.getContext('2d');
  context.drawImage(canvas, 0, 0, 160, 90);
  const data = context.getImageData(0, 0, 160, 90).data;
  const colours = new Set();
  for (let index = 0; index < data.length; index += 4) {
    colours.add(`${data[index] >> 3},${data[index + 1] >> 3},${data[index + 2] >> 3}`);
  }
  return { ok: true, colours: colours.size, pixels: Array.from(data) };
});
const changed = (before, after) => {
  if (!before?.ok || !after?.ok) return 0;
  let count = 0;
  for (let index = 0; index < before.pixels.length; index += 4) {
    const delta = Math.abs(before.pixels[index] - after.pixels[index])
      + Math.abs(before.pixels[index + 1] - after.pixels[index + 1])
      + Math.abs(before.pixels[index + 2] - after.pixels[index + 2]);
    if (delta > 18) count++;
  }
  return count;
};

const title = await sample();
await page.screenshot({ path: titleOut });
// The opt-in action is the smaller second title button, directly under New
// Game. This is the same canvas-first coordinate contract used by the boss,
// guardian, and special-review browser gates.
await page.mouse.click(640, 405);
await page.waitForTimeout(1500);
const saveMenu = await sample();
const saveMenuOut = out.replace(/(\.[^.]+)?$/, '.save-menu$1');
await page.screenshot({ path: saveMenuOut });

// The actual SavePoint menu intentionally exposes Update Spells beneath Save.
// The review route's no-slot state must keep the normal menu usable while
// letting a reviewer traverse into the existing spell tree.
await page.mouse.click(110, 105);
await page.waitForTimeout(1500);
const updateMenu = await sample();
const updateMenuOut = out.replace(/(\.[^.]+)?$/, '.update-menu$1');
await page.screenshot({ path: updateMenuOut });

// Update Spells deliberately offers Equip and Learn before entering a tree.
// Choosing Learn Spells is the public path under review, not an implementation
// shortcut into the underlying scene.
await page.mouse.click(110, 105);
await page.waitForTimeout(1500);
const spellTree = await sample();
await page.screenshot({ path: out });

const menuTransition = changed(title, saveMenu);
const updateTransition = changed(saveMenu, updateMenu);
const treeTransition = changed(updateMenu, spellTree);
console.log(`spell review canvas ${JSON.stringify({
  title: { ok: title.ok, colours: title.colours },
  saveMenu: { ok: saveMenu.ok, colours: saveMenu.colours },
  updateMenu: { ok: updateMenu.ok, colours: updateMenu.colours },
  spellTree: { ok: spellTree.ok, colours: spellTree.colours },
  menuTransition,
  updateTransition,
  treeTransition,
})}`);
if (errors.length) console.log('console             ' + errors.slice(0, 8).join(' | '));
await browser.close();
if (!live) server.close();

if (!title.ok || !saveMenu.ok || !updateMenu.ok || !spellTree.ok) { console.log('SPELL REVIEW WEB: no canvas element'); process.exit(1); }
if (errors.length) { console.log('SPELL REVIEW WEB: browser errors'); process.exit(1); }
if (title.colours < 20 || saveMenu.colours < 20 || updateMenu.colours < 20 || spellTree.colours < 20 || menuTransition < 250 || updateTransition < 250 || treeTransition < 250) {
  console.log('SPELL REVIEW WEB: title action did not visibly traverse the Save / Update Spells tree');
  process.exit(1);
}
console.log(`SPELL REVIEW WEB: ?spells=1 traversed Save / Update / Learn Spells (${menuTransition}/${updateTransition}/${treeTransition} changed samples)`);
