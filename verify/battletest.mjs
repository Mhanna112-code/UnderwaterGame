// Does the fight render and take clicks in a browser? Loads the battle
// directly, shoots it, clicks the first action button, shoots again.
import { firefox } from 'playwright';
const url = process.argv[2], out = process.argv[3];
const b = await firefox.launch({ headless: false });
const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
const errs = [];
p.on('pageerror', e => errs.push(String(e)));
await p.goto(url, { waitUntil: 'commit' });
for (let i = 0; i < 160; i++) {
  const n = await p.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c || c.width < 400) return 0;
    const g = document.createElement('canvas'); g.width = 100; g.height = 56;
    const x = g.getContext('2d');
    try { x.drawImage(c, 0, 0, 100, 56); } catch (e) { return 0; }
    const d = x.getImageData(0, 0, 100, 56).data; const s = new Set();
    for (let j = 0; j < d.length; j += 4) s.add(`${d[j]>>3},${d[j+1]>>3},${d[j+2]>>3}`);
    return s.size;
  }).catch(() => 0);
  if (n >= 12) break;
  await p.waitForTimeout(1000);
}
await p.screenshot({ path: `${out}/fight_1.png` });
await p.mouse.click(76, 252);      // first action button
await p.waitForTimeout(1200);
await p.screenshot({ path: `${out}/fight_2.png` });
await p.mouse.click(280, 287);     // end turn
await p.waitForTimeout(2500);
await p.screenshot({ path: `${out}/fight_3.png` });
if (errs.length) console.log('console  ' + errs.slice(0, 3).join(' | '));
console.log('shot three frames of the fight');
await b.close();
