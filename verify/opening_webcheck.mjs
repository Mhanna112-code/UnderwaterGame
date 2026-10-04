// OPEN-004/014/020: exported ordinary entry, complete movies, real mouse input.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const target = process.argv[2];
const output = process.argv[3] || '/tmp/opening-browser';
fs.mkdirSync(output, { recursive: true });
const live = target.startsWith('http');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const name = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(target, name === '/' ? 'index.html' : name);
  if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
  fs.createReadStream(file).pipe(res);
});
if (!live) await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const phases = [], errors = [], timestamps = {};
page.on('console', msg => {
  const line = msg.text();
  const match = line.match(/PROLOGUE_PHASE\|([a-z_]+)/);
  if (match) { phases.push(match[1]); timestamps[match[1]] = Date.now(); console.log(line); }
  if (msg.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(line)) errors.push(line);
});
page.on('pageerror', error => errors.push(String(error)));
const waitPhase = async (phase, timeout = 45000) => {
  const deadline = Date.now() + timeout;
  while (!phases.includes(phase) && Date.now() < deadline) await page.waitForTimeout(100);
  if (!phases.includes(phase)) throw new Error(`missing ${phase}; observed ${phases.join(',')}`);
};
const shot = async name => page.screenshot({ path: path.join(output, name + '.png') });
const attack = async () => {
  await page.mouse.click(160, 544);
  await page.waitForTimeout(400);
  await page.mouse.click(160, 604);
  await page.waitForTimeout(400);
  await page.mouse.click(160, 666);
};
let failure;
try {
  await page.goto(live ? target : `http://127.0.0.1:${server.address().port}/`, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await shot('01-title');
  const started = Date.now();
  await page.mouse.click(640, 367);
  await waitPhase('opening_video');
  await page.waitForTimeout(5000);
  await shot('02-mermaid');
  await waitPhase('spawn_exploration');
  await page.keyboard.down('w');
  await waitPhase('angler', 12000);
  await page.keyboard.up('w');
  await page.waitForTimeout(700);
  await shot('03-angler');
  await attack();
  await waitPhase('octopus_introduction', 15000);
  await page.waitForTimeout(6000);
  await shot('04-octopus-introduction');
  await waitPhase('octopus_response');
  if (timestamps.octopus_reveal - timestamps.octopus_introduction < 25000) throw new Error('Introduction did not play the full 25 seconds');
  await page.waitForTimeout(300);
  await shot('05-cordys');
  await attack();
  await waitPhase('scripted_defeat', 15000);
  await page.waitForTimeout(600);
  await shot('06-finisher');
  await waitPhase('octopus_aftermath', 15000);
  await page.waitForTimeout(5000);
  await shot('07-aftermath');
  await waitPhase('recovery', 45000);
  await page.waitForTimeout(300);
  await shot('08-recovery');
  await page.mouse.click(640, 393);
  await waitPhase('complete', 5000);
  await page.waitForTimeout(600);
  await shot('09-optional-training');
  console.log(`Normal browser New Game to control: ${(Date.now() - started) / 1000}s`);
  const expected = ['opening_video', 'spawn_exploration', 'angler', 'octopus_introduction', 'octopus_reveal', 'octopus_response', 'scripted_defeat', 'octopus_aftermath', 'recovery', 'complete'];
  if (phases.join(',') !== expected.join(',')) throw new Error('Unexpected/duplicate public journey phases');
  if (errors.length) throw new Error(errors.join('\n'));
} catch (error) { failure = String(error); await shot('failure'); }
finally {
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ target, phases, timestamps, errors, failure: failure || null }, null, 2));
  await browser.close();
  if (!live) server.close();
}
if (failure) { console.error(failure); process.exit(1); }
console.log('OPENING WEB: ordinary entry, full split movies, real mouse combat and recovered control clean');
