// OPEN-026/035: normal full movie, prolonged idle/camera-only input, then
// actual held W. Record continuously; never inject a phase or result.
import { chromium, webkit } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const target = process.argv[2];
const output = process.argv[3] || '/tmp/opening-free-swim-video';
fs.mkdirSync(output, { recursive: true });
const browserEngine = process.env.OPENING_BROWSER_ENGINE || 'chromium';
const browser = browserEngine === 'webkit' ? await webkit.launch() : await chromium.launch({
  executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined,
  args: ['--use-gl=angle', `--use-angle=${process.env.OPENING_BROWSER_GPU || (process.platform === 'darwin' ? 'metal' : 'swiftshader')}`, '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const context = await browser.newContext({
  viewport: { width: 1280, height: 720 },
  recordVideo: { dir: output, size: { width: 1280, height: 720 } },
});
const page = await context.newPage();
const recordingStarted = Date.now();
const timestamps = {}, errors = [];
page.on('console', message => {
  const text = message.text();
  const phase = text.match(/PROLOGUE_PHASE\|([a-z_]+)/)?.[1];
  if (phase) { timestamps[phase] = Date.now(); console.log(text); }
  if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(text)) errors.push(text);
});
page.on('pageerror', error => errors.push(String(error)));
const waitPhase = async (phase, timeout = 45000) => {
  const deadline = Date.now() + timeout;
  while (!timestamps[phase] && Date.now() < deadline) await page.waitForTimeout(20);
  if (!timestamps[phase]) throw new Error(`Missing ${phase}`);
};
let failure, keydownAt, idleSeconds, swimmingSeconds, recording;
try {
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await page.mouse.click(640, 367);
  await waitPhase('opening_video');
  await waitPhase('spawn_exploration');
  await page.waitForTimeout(15000);
  idleSeconds = (Date.now() - timestamps.spawn_exploration) / 1000;
  await page.screenshot({ path: path.join(output, 'idle-world.png') });
  if (timestamps.angler) throw new Error('OPEN-035 Angler started while stationary before any swimming');
  await page.keyboard.down('ArrowRight');
  await page.waitForTimeout(800);
  await page.keyboard.up('ArrowRight');
  await page.keyboard.down('ArrowLeft');
  await page.waitForTimeout(800);
  await page.keyboard.up('ArrowLeft');
  if (timestamps.angler) throw new Error('OPEN-035 camera-only input started the Angler');
  await page.keyboard.down('w');
  keydownAt = Date.now();
  await waitPhase('angler', 12000);
  await page.keyboard.up('w');
  swimmingSeconds = (timestamps.angler - keydownAt) / 1000;
  if (swimmingSeconds < 4 || swimmingSeconds >= 10) throw new Error(`OPEN-035 actual swimming interval ${swimmingSeconds}s is premature or stalls`);
  await page.screenshot({ path: path.join(output, 'after-swimming-angler.png') });
  if (errors.length) throw new Error(errors.join('\n'));
  await page.waitForTimeout(500);
} catch (error) { failure = String(error); }
finally {
  await context.close();
  recording = await page.video().path();
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({
    target, browserEngine, recording, recordingStarted, keydownAt, idleSeconds, swimmingSeconds, timestamps, errors, failure: failure || null,
  }, null, 2));
  await browser.close();
}
if (failure) { console.error(failure); process.exit(1); }
console.log('OPENING FREE SWIM WEB: idle/camera-only stays free; late actual swimming starts one Angler after four seconds; inspect continuous recording for displacement');
