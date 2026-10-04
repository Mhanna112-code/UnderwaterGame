// OPEN-047/048: actual ordinary-title pointer input and final WebAudio output.
// Passive capture branch retains the production destination connection and
// outputs silence; it does not replace the audio asset or synthesize events.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const target = process.argv[2];
const output = process.argv[3] || '/tmp/menu-hover-web';
fs.mkdirSync(output, { recursive: true });
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [];
page.on('console', msg => { if (msg.type() === 'error' || /SCRIPT ERROR:|^ERROR:|Infinite loop detected/.test(msg.text())) errors.push(msg.text()); });
page.on('pageerror', error => errors.push(String(error)));
await page.addInitScript(() => {
  window.menuCapture = { active: false, blocks: [], sampleRate: 0 };
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function(destination, ...rest) {
    const result = connect.call(this, destination, ...rest);
    if (destination instanceof AudioDestinationNode && !this.__menuCaptureConnected) {
      this.__menuCaptureConnected = true;
      const processor = this.context.createScriptProcessor(1024, 2, 2);
      const silent = this.context.createGain();
      silent.gain.value = 0;
      processor.onaudioprocess = event => {
        if (!window.menuCapture.active) return;
        window.menuCapture.sampleRate = event.inputBuffer.sampleRate;
        window.menuCapture.blocks.push(Array.from(event.inputBuffer.getChannelData(0)));
      };
      connect.call(this, processor);
      connect.call(processor, silent);
      connect.call(silent, destination);
    }
    return result;
  };
});
let failure, measurement;
try {
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  const image = path.join(output, 'title.png');
  await page.screenshot({ path: image });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [image], { encoding: 'utf8' }));
  const button = rows.find(row => row.text === 'New Game');
  if (!button) throw new Error('Normal title has no New Game button');
  // Trusted click on cover outside the menu unlocks the ordinary browser
  // audio gesture without starting a run or using URL/engine shortcuts.
  await page.mouse.click(100, 680);
  await page.mouse.move(100, 680);
  await page.waitForTimeout(500);
  await page.evaluate(() => { window.menuCapture.active = true; window.menuCapture.blocks = []; });
  for (let index = 0; index < 20; index++) {
    await page.mouse.move(button.x, button.y);
    await page.waitForTimeout(12);
    await page.mouse.move(button.x - 260, button.y);
    await page.waitForTimeout(12);
  }
  await page.waitForTimeout(600);
  const recording = await page.evaluate(() => {
    window.menuCapture.active = false;
    return { sampleRate: window.menuCapture.sampleRate, samples: window.menuCapture.blocks.flat() };
  });
  if (!recording.samples.length || !recording.sampleRate) throw new Error('No real browser audio was captured');
  let peak = 0;
  const pulses = [];
  let lastActive = -1;
  const threshold = 0.0001;
  for (let i = 0; i < recording.samples.length; i++) {
    peak = Math.max(peak, Math.abs(recording.samples[i]));
    if (Math.abs(recording.samples[i]) <= threshold) continue;
    if (lastActive < 0 || i - lastActive > recording.sampleRate * 0.06) pulses.push({ start: i / recording.sampleRate });
    pulses[pulses.length - 1].end = i / recording.sampleRate;
    lastActive = i;
  }
  measurement = { peakDb: 20 * Math.log10(Math.max(peak, 1e-8)), pulses, sampleRate: recording.sampleRate };
  const bytes = Buffer.alloc(44 + recording.samples.length * 2);
  bytes.write('RIFF'); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(recording.sampleRate, 24); bytes.writeUInt32LE(recording.sampleRate * 2, 28);
  bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34); bytes.write('data', 36);
  bytes.writeUInt32LE(recording.samples.length * 2, 40);
  recording.samples.forEach((value, i) => bytes.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value)) * 32767), 44 + i * 2));
  fs.writeFileSync(path.join(output, 'rapid-hover.wav'), bytes);
  if (measurement.peakDb > -24 || measurement.peakDb < -65) throw new Error('OPEN-047 browser hover absent or too loud: ' + measurement.peakDb);
  if (!pulses.length || pulses.some(pulse => pulse.end - pulse.start > 0.25)) throw new Error('OPEN-047 browser cue not brief');
  if (pulses.some((pulse, i) => i > 0 && pulse.start - pulses[i - 1].start < 0.20)) throw new Error('OPEN-048 browser rapid hover retriggers too frequently');
  if (errors.length) throw new Error(errors.join('\n'));
  console.log('MENU HOVER WEB: clean | ' + JSON.stringify(measurement));
} catch (error) { failure = String(error); console.error(failure); }
finally {
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ target, boundary: 'ordinary title, trusted cover click, real mouse input, passive WebAudio output tap', measurement, errors, failure: failure || null }, null, 2));
  await browser.close();
}
if (failure) process.exit(1);
