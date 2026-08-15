// Can a browser actually reach the fight?
//
// The loop gate proves the logic in headless Godot. It says nothing about
// whether the battle scene renders in WebGL or whether its buttons take a
// click. This holds W and D, which points straight at the guarded salvage
// from the spawn, and shoots the screen before and after.
import { firefox } from 'playwright';

const url = process.argv[2];
const outDir = process.argv[3] || '/tmp';
const browser = await firefox.launch({ headless: false });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));

const t0 = Date.now();
await page.goto(url, { waitUntil: 'commit' });

// wait for the overworld to draw
let up = false;
for (let i = 0; i < 160; i++) {
  const n = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c || c.width < 400) return 0;
    const g = document.createElement('canvas'); g.width = 100; g.height = 56;
    const x = g.getContext('2d');
    try { x.drawImage(c, 0, 0, 100, 56); } catch (e) { return 0; }
    const d = x.getImageData(0, 0, 100, 56).data;
    const s = new Set();
    for (let j = 0; j < d.length; j += 4) s.add(`${d[j]>>3},${d[j+1]>>3},${d[j+2]>>3}`);
    return s.size;
  }).catch(() => 0);
  if (n >= 12) { up = true; break; }
  await page.waitForTimeout(1000);
}
if (!up) { console.log('BROWSER: never drew'); await browser.close(); process.exit(1); }
console.log(`overworld  drawn after ${((Date.now() - t0) / 1000).toFixed(1)}s`);
await page.screenshot({ path: `${outDir}/play_1_world.png` });

await page.mouse.click(640, 400);
// W is -Z and D is +X, and the guarded salvage sits at +14, -12 from spawn,
// so W and D together point at it without needing to steer
await page.keyboard.down('w');
await page.keyboard.down('d');
await page.waitForTimeout(9000);
await page.keyboard.up('w');
await page.keyboard.up('d');
await page.waitForTimeout(2500);
await page.screenshot({ path: `${outDir}/play_2_after.png` });

// try clicking where the first action button sits in the battle readout
await page.mouse.click(76, 252);
await page.waitForTimeout(1500);
await page.screenshot({ path: `${outDir}/play_3_action.png` });

if (errors.length) console.log('console   ' + errors.slice(0, 3).join(' | '));
console.log('BROWSER: drove for 9s and shot three frames, look at them');
await browser.close();
