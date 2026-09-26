// Browser evidence for the query-only reproduction route of the former
// highway collision plane. It opens the same public URL a reviewer receives,
// chooses its visible title action, then holds D through the once-blocked
// open-water crossing and captures before/after frames.
//
// Usage:
//   node verify/open_water_webcheck.mjs <public-url> <out-dir>
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const baseUrl = process.argv[2];
const outDir = process.argv[3] || '/tmp/open-water-webcheck';
if (!baseUrl) throw new Error('usage: open_water_webcheck.mjs <public-url> <out-dir>');
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });

const url = baseUrl.includes('?') ? `${baseUrl}&open-water=1` : `${baseUrl}?open-water=1`;
await page.goto(url, { waitUntil: 'load' });
const deadline = Date.now() + 60000;
let colours = 0;
while (Date.now() < deadline) {
  colours = await page.evaluate(() => {
    const source = document.querySelector('canvas');
    if (!source) return 0;
    const sample = document.createElement('canvas');
    sample.width = 160; sample.height = 90;
    const ctx = sample.getContext('2d');
    ctx.drawImage(source, 0, 0, sample.width, sample.height);
    const data = ctx.getImageData(0, 0, sample.width, sample.height).data;
    const palette = new Set();
    for (let i = 0; i < data.length; i += 4) palette.add(`${data[i] >> 3}/${data[i + 1] >> 3}/${data[i + 2] >> 3}`);
    return palette.size;
  }).catch(() => 0);
  if (colours >= 12) break;
  await page.waitForTimeout(1000);
}
if (colours < 12) throw new Error(`public build never drew a usable canvas (${colours} colours)`);

await page.screenshot({ path: path.join(outDir, '01-open-water-title.png') });
// The review action is the second and only secondary button in this query
// state. It is positioned directly below New Game in the centred title card.
await page.mouse.click(640, 430);
await page.waitForTimeout(1200);
await page.screenshot({ path: path.join(outDir, '02-before-crossing.png') });

await page.keyboard.down('KeyD');
await page.waitForTimeout(2800);
await page.keyboard.up('KeyD');
await page.waitForTimeout(400);
await page.screenshot({ path: path.join(outDir, '03-after-crossing.png') });

console.log(JSON.stringify({ url, colours, screenshots: 3, errors }, null, 2));
await browser.close();
if (errors.length) process.exit(1);
