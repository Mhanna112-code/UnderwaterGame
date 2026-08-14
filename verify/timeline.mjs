// Where do the 45 seconds go? Poll the page twice a second and record the
// first moment each milestone lands: canvas element, canvas sized, engine
// console output, pixels drawn.
import { firefox, chromium } from 'playwright';
const url = process.argv[2];
const engine = (process.argv[3] || 'firefox') === 'chromium' ? chromium : firefox;
const browser = await engine.launch({ headless: false });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const t0 = Date.now();
const mark = {};
const at = k => { if (!mark[k]) mark[k] = ((Date.now() - t0) / 1000).toFixed(1); };
page.on('console', m => { at('first_console'); if (/godot|opengl|vulkan|webgl/i.test(m.text())) at('engine_console'); });
await page.goto(url, { waitUntil: 'commit' });
at('navigated');
for (let i = 0; i < 240; i++) {
  const s = await page.evaluate(() => {
    const c = document.querySelector('canvas');
    if (!c) return { canvas: false };
    const g = document.createElement('canvas'); g.width = 100; g.height = 56;
    const x = g.getContext('2d');
    try { x.drawImage(c, 0, 0, 100, 56); } catch (e) { return { canvas: true, sized: c.width > 400, colours: -1 }; }
    const d = x.getImageData(0, 0, 100, 56).data;
    const seen = new Set();
    for (let j = 0; j < d.length; j += 4) seen.add(`${d[j]>>3},${d[j+1]>>3},${d[j+2]>>3}`);
    return { canvas: true, sized: c.width > 400, colours: seen.size,
             loader: !!document.querySelector('#status, .godot, #status-progress') };
  }).catch(() => ({}));
  if (s.canvas) at('canvas_element');
  if (s.sized) at('canvas_sized');
  if (s.colours >= 4) at('first_pixels');
  if (s.colours >= 12) { at('scene_drawn'); break; }
  await page.waitForTimeout(500);
}
console.log(JSON.stringify(mark, null, 0));
await browser.close();
