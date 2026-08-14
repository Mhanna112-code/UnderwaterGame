// Godot caches compiled shaders in the browser between visits. If that works,
// the ugly number is a first-visit-only number and the team should hear that
// rather than a single 45s figure that reads as permanent.
import { firefox } from 'playwright';
const url = process.argv[2];
const browser = await firefox.launch({ headless: false });
const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });

async function load(label) {
  const page = await ctx.newPage();
  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'commit' });
  let drew = 0;
  for (let i = 0; i < 200; i++) {
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
    if (n >= 12) { drew = (Date.now() - t0) / 1000; break; }
    await page.waitForTimeout(500);
  }
  console.log(`${label}: ${drew ? drew.toFixed(1) + 's' : 'never drew'}`);
  await page.close();
  return drew;
}

await load('first visit ');
await load('second visit');
await browser.close();
