// Browser evidence harness for the first physical step of the route.
//
// This deliberately starts at the public title screen in a fresh browser
// profile.  It clicks the visible New Game button, skips the optional crawl
// through the same E input a player uses, then holds the indicated movement
// key toward the tutorial beam.  The artefacts make a failed title handoff or an invisible first
// objective reviewable without relying on a query-string start state.
//
// Usage:
//   node verify/normal_entry_walkthrough.mjs <public-url> <out-dir> [approach-ms] [movement-key]
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const url = process.argv[2];
const outDir = process.argv[3] || '/tmp/normal-entry-walkthrough';
// A fresh title start now places the tutorial beam directly along W.  The
// previous default A/1.2-second probe could leave the player beside the beam
// and still publish a screenshot, which proved only that a canvas rendered,
// not that a newcomer can enter the first fight.
const approachMs = Number(process.argv[4] || 6000);
const movementKey = process.argv[5] || 'KeyW';
if (!url) throw new Error('usage: normal_entry_walkthrough.mjs <public-url> <out-dir>');
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({ args: [
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization',
] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });

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

await page.screenshot({ path: path.join(outDir, '01-title.png') });
await page.mouse.click(640, 366); // visible New Game action at 1280x720
await page.waitForTimeout(900);
await page.screenshot({ path: path.join(outDir, '02-intro.png') });

await page.keyboard.press('e'); // player-visible "Press E or click to skip"
await page.waitForTimeout(1000);
await page.screenshot({ path: path.join(outDir, '03-tutorial-approach.png') });

await page.keyboard.down(movementKey);
await page.waitForTimeout(approachMs);
await page.keyboard.up(movementKey);
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(outDir, '04-after-physical-approach.png') });

console.log(JSON.stringify({ url, colours, approachMs, movementKey, screenshots: 4, errors }, null, 2));
await browser.close();
if (errors.length) process.exit(1);
