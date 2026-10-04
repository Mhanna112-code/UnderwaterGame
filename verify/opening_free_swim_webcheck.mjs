// OPEN-026: normal hosted movie handoff and actual held W, recorded continuously.
// Do not put blocking screenshots between control restoration and keydown:
// GPU readback can consume the exploration interval and silently test idle instead.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const target = process.argv[2];
const output = process.argv[3] || '/tmp/opening-free-swim-video';
fs.mkdirSync(output, { recursive: true });
const browser = await chromium.launch({
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
let failure, keydownAt, recording;
try {
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await page.mouse.click(640, 367);
  await waitPhase('opening_video');
  await waitPhase('spawn_exploration');
  await page.keyboard.down('w');
  keydownAt = Date.now();
  await waitPhase('angler', 12000);
  await page.keyboard.up('w');
  const seconds = (timestamps.angler - timestamps.spawn_exploration) / 1000;
  if (keydownAt - timestamps.spawn_exploration >= 4000) throw new Error('Harness sent movement only after the exploration window');
  if (seconds < 4 || seconds >= 7) throw new Error(`Movement interval ${seconds}s is premature or only proves idle fallback`);
  if (errors.length) throw new Error(errors.join('\n'));
  await page.waitForTimeout(500);
} catch (error) { failure = String(error); }
finally {
  await context.close();
  recording = await page.video().path();
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({
    target, recording, recordingStarted, keydownAt, timestamps, errors, failure: failure || null,
  }, null, 2));
  await browser.close();
}
if (failure) { console.error(failure); process.exit(1); }
console.log('OPENING FREE SWIM WEB: immediate real key input and bounded movement-trigger interval clean; inspect continuous recording for visible displacement');
