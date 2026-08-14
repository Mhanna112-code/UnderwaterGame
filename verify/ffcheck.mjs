// How long does the build take to actually draw, in the browser the team uses?
// Chromium is not the test: the report was Firefox, so this measures Firefox,
// polls the canvas until it draws, and prints the time it took.
import { firefox } from 'playwright';

const url = process.argv[2];
const out = process.argv[3] || '/tmp/ff.png';
const budget = Number(process.argv[4] || 90000);

const browser = await firefox.launch({ headless: process.env.HEADED ? false : true, firefoxUserPrefs: {
  'webgl.force-enabled': true,
  'webgl.disabled': false,
  'webgl.disable-fail-if-major-performance-caveat': true,
  'gfx.webrender.all': true,
  'layers.acceleration.force-enabled': true,
} });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

const t0 = Date.now();
await page.goto(url, { waitUntil: 'commit' });

let drew = 0;
while (Date.now() - t0 < budget) {
  const n = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c) return -1;
    const g = document.createElement('canvas');
    g.width = 120; g.height = 68;
    const ctx = g.getContext('2d');
    try { ctx.drawImage(c, 0, 0, 120, 68); } catch (e) { return -2; }
    const d = ctx.getImageData(0, 0, 120, 68).data;
    const seen = new Set();
    for (let i = 0; i < d.length; i += 4) seen.add(`${d[i]>>3},${d[i+1]>>3},${d[i+2]>>3}`);
    return seen.size;
  }).catch(() => -3);
  if (n >= 12) { drew = Date.now() - t0; break; }
  await page.waitForTimeout(1000);
}

// where did the time go? download, compile, or the first frame after that
const timing = await page.evaluate(() => {
  const out = {};
  for (const e of performance.getEntriesByType('resource')) {
    if (/\.wasm|\.pck/.test(e.name)) {
      out[e.name.split('/').pop()] = {
        transferred_mb: +(e.transferSize / 1048576).toFixed(1),
        seconds: +(e.duration / 1000).toFixed(1),
      };
    }
  }
  return out;
}).catch(() => ({}));
console.log('resources ' + JSON.stringify(timing));
await page.screenshot({ path: out });
if (errors.length) console.log('console   ' + errors.slice(0, 4).join(' | '));
await browser.close();

if (!drew) { console.log(`FIREFOX: never drew within ${budget / 1000}s`); process.exit(1); }
console.log(`FIREFOX: first drawn frame after ${(drew / 1000).toFixed(1)}s`);
