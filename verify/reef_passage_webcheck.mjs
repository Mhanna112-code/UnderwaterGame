// Browser evidence for the real Shallows capstone landmark.  The query only
// exposes the review action; selecting it advances the production route state
// through the two preceding wins, then renders the same reef passage that the
// normal capstone objective builds.
//
// Usage:
//   node verify/reef_passage_webcheck.mjs <public-url> <out-dir>
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const baseUrl = process.argv[2];
const outDir = process.argv[3] || '/tmp/reef-passage-webcheck';
if (!baseUrl) throw new Error('usage: reef_passage_webcheck.mjs <public-url> <out-dir>');
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });

const url = baseUrl.includes('?') ? `${baseUrl}&reef-passage=1` : `${baseUrl}?reef-passage=1`;
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

await page.screenshot({ path: path.join(outDir, '01-reef-review-title.png') });
// Query-only title state contains New Game then Review Shallows Reef Passage.
await page.mouse.click(640, 430);
await page.waitForTimeout(1500);
await page.screenshot({ path: path.join(outDir, '02-reef-passage.png') });

console.log(JSON.stringify({ url, colours, screenshots: 2, errors }, null, 2));
await browser.close();
if (errors.length) process.exit(1);
