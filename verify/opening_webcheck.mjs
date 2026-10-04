// OPEN-004/014/020: exported ordinary entry, complete movies, real mouse input.
import { chromium, webkit } from 'playwright';
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
const gpuMode = process.env.OPENING_BROWSER_GPU || (process.platform === 'darwin' ? 'metal' : 'swiftshader');
const browserEngine = process.env.OPENING_BROWSER_ENGINE || 'chromium';
const browser = browserEngine === 'webkit' ? await webkit.launch() : await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE || undefined, args: ['--use-gl=angle', `--use-angle=${gpuMode}`, '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
console.log('Browser launched');
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
const attack = async (name, moveY = 604) => {
  await page.mouse.click(160, 544);
  await page.waitForTimeout(400);
  await shot(name + '-move-menu');
  await page.mouse.click(160, moveY);
  await page.waitForTimeout(400);
  await shot(name + '-target-menu');
  await page.mouse.click(160, 666);
};
let failure, renderer, elapsedSeconds, freeSwimKeydown, freeSwimMs, saveRecheck;
try {
  await page.goto(live ? target : `http://127.0.0.1:${server.address().port}/`, { waitUntil: 'load' });
  console.log('Export page loaded');
  console.log('Requested ANGLE backend: ' + gpuMode);
  await page.waitForTimeout(25000);
  renderer = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const gl = canvas?.getContext('webgl2');
    const debug = gl?.getExtension('WEBGL_debug_renderer_info');
    return debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : 'renderer unavailable';
  });
  console.log('Observed WebGL renderer: ' + renderer);
  await shot('01-title');
  const started = Date.now();
  await page.mouse.click(640, 367);
  await waitPhase('opening_video');
  await page.waitForTimeout(5000);
  await shot('02-mermaid');
  await waitPhase('spawn_exploration');
  if (timestamps.spawn_exploration - timestamps.opening_video < 33000) throw new Error('Mermaid opening was shortened instead of completing playback');
  // Keep keydown adjacent to the real handoff. A screenshot readback here
  // can consume several seconds and turn a movement test into idle fallback.
  await page.keyboard.down('w');
  freeSwimKeydown = Date.now();
  if (freeSwimKeydown - timestamps.spawn_exploration >= 4000) throw new Error('Harness sent movement only after the exploration window');
  await waitPhase('angler', 12000);
  await page.keyboard.up('w');
  freeSwimMs = timestamps.angler - timestamps.spawn_exploration;
  if (freeSwimMs < 4000) throw new Error('Free-swim interval interrupts before four seconds');
  // Wall time alone cannot identify movement vs idle under renderer slowdown.
  // Native displacement plus the dedicated continuous browser recording prove
  // actual swimming; this complete-flow gate pins the minimum and two-minute cap.
  await page.waitForTimeout(700);
  await shot('03-angler');
  await attack('03a-angler');
  await waitPhase('octopus_introduction', 15000);
  await page.waitForTimeout(6000);
  await shot('04-octopus-introduction');
  await waitPhase('octopus_response');
  if (timestamps.octopus_reveal - timestamps.octopus_introduction < 25000) throw new Error('Introduction did not play the full 25 seconds');
  await page.waitForTimeout(300);
  await shot('05-cordys');
  await attack('05a-cordys', 544);
  await waitPhase('scripted_defeat', 15000);
  await page.waitForTimeout(600);
  await shot('06-finisher');
  await waitPhase('octopus_aftermath', 15000);
  await page.waitForTimeout(5000);
  await shot('07-aftermath');
  await waitPhase('recovery', 45000);
  const endingMs = timestamps.recovery - timestamps.octopus_aftermath;
  if (endingMs < 6000 || endingMs > 15000) throw new Error('Approved boss-title ending was skipped or the long monologue remains');
  await page.waitForTimeout(300);
  await shot('08-recovery');
  await page.mouse.click(640, 393);
  await waitPhase('complete', 5000);
  await page.waitForTimeout(600);
  await shot('09-optional-training');
  elapsedSeconds = (Date.now() - started) / 1000;
  console.log(`Normal browser New Game to control: ${elapsedSeconds}s`);
  if (elapsedSeconds >= 120) throw new Error('Normal opening exceeds the two-minute acceptance limit');
  const expected = ['opening_video', 'spawn_exploration', 'angler', 'octopus_introduction', 'octopus_reveal', 'octopus_response', 'scripted_defeat', 'octopus_aftermath', 'recovery', 'complete'];
  if (phases.join(',') !== expected.join(',')) throw new Error('Unexpected/duplicate public journey phases');
  if (process.env.OPENING_SAVE_RECHECK === '1') {
    // OPEN-027: inspect the browser's actual persisted checkpoint after the
    // ordinary journey. This is our fresh test context, never player storage.
    const readSaves = async () => page.evaluate(async () => {
      const saves = [];
      for (const info of await indexedDB.databases()) {
        const db = await new Promise((resolve, reject) => {
          const req = indexedDB.open(info.name);
          req.onsuccess = () => resolve(req.result);
          req.onerror = () => reject(req.error);
        });
        if (db.objectStoreNames.contains('FILE_DATA')) {
          await new Promise((resolve, reject) => {
            const request = db.transaction('FILE_DATA').objectStore('FILE_DATA').openCursor();
            request.onsuccess = () => {
              const cursor = request.result;
              if (!cursor) { resolve(); return; }
              if (String(cursor.key).includes('/saves/slot_')) {
                saves.push({ database: info.name, key: cursor.key,
                  data: JSON.parse(new TextDecoder().decode(cursor.value.contents)) });
              }
              cursor.continue();
            };
            request.onerror = () => reject(request.error);
          });
        }
        db.close();
      }
      return saves;
    });
    await page.waitForTimeout(2000);
    saveRecheck = { beforeReload: await readSaves() };
    console.log('BROWSER CHECKPOINT|' + JSON.stringify(saveRecheck.beforeReload));
    await page.reload({ waitUntil: 'load' });
    await page.waitForTimeout(20000);
    await shot('10-reloaded-title');
    // The real Load Game button and slot picker, not a prologue bypass flag.
    await page.mouse.click(640, 405);
    await page.waitForTimeout(700);
    await shot('11-load-slots');
    await page.mouse.click(640, 327);
    await page.waitForTimeout(4000);
    await shot('12-loaded-world');
    saveRecheck.afterReload = await readSaves();
    if (phases.slice(expected.length).includes('opening_video') || phases.slice(expected.length).includes('spawn_exploration')) {
      throw new Error('OPEN-027 cold Load Game replayed the completed opening');
    }
    if (phases.slice(expected.length).join(',') !== 'complete') throw new Error('OPEN-027 Load Game did not restore completed normal play');
  }
  if (errors.length) throw new Error(errors.join('\n'));
} catch (error) { failure = String(error); await shot('failure'); }
finally {
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ target, browserEngine, renderer, elapsedSeconds, freeSwimKeydown, freeSwimMs, phases, timestamps, saveRecheck, errors, failure: failure || null }, null, 2));
  await browser.close();
  if (!live) server.close();
}
if (failure) { console.error(failure); process.exit(1); }
console.log('OPENING WEB: ordinary entry, full split movies, real mouse combat and recovered control clean');
