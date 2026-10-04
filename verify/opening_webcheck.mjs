// OPEN-004/014/020: exported ordinary entry, complete movies, real mouse input.
import { chromium, webkit } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

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
const storageFault = process.env.OPENING_STORAGE_FAILURE === '1';
if (storageFault) await page.addInitScript(() => {
  // Fault only our disposable context's completed saves. Initial checkpoints
  // remain writable; no player's IndexedDB or game state is ever touched.
  window.rejectCompletedCheckpoint = true;
  window.rejectedCheckpointWrites = 0;
  const put = IDBObjectStore.prototype.put;
  IDBObjectStore.prototype.put = function(value, key) {
    const result = put.call(this, value, key);
    if (window.rejectCompletedCheckpoint && String(key).endsWith('/saves/slot_0.json')) {
      const snapshot = JSON.parse(new TextDecoder().decode(value.contents));
      if (snapshot.route_state?.prologue_complete) {
        window.rejectedCheckpointWrites++;
        this.transaction.abort();
      }
    }
    return result;
  };
});
const phases = [], errors = [], timestamps = {}, combatHits = [], bossResponses = [];
let checkpointFailureObserved = false;
const deaths = [];
page.on('console', msg => {
  const line = msg.text();
  if (line.startsWith('PROLOGUE_HIT|')) { combatHits.push(line); console.log(line); }
  if (line.startsWith('PROLOGUE_BREATH|')) { bossResponses.push(line); console.log(line); }
  const match = line.match(/PROLOGUE_PHASE\|([a-z_]+)/);
  if (match) { phases.push(match[1]); timestamps[match[1]] = Date.now(); console.log(line); }
  if (line.includes('CHECKPOINT_SAVE_FAILED|')) { checkpointFailureObserved = true; console.log(line); }
  if (line.includes('CHECKPOINT_GAME_OVER|')) { deaths.push(line); console.log(line); }
  if (storageFault && line.includes('Failed to save IDB file system:')) { console.log('INJECTED STORAGE FAILURE|' + line); return; }
  if (msg.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(line)) errors.push(line);
});
page.on('pageerror', error => errors.push(String(error)));
const waitPhase = async (phase, timeout = 45000) => {
  const deadline = Date.now() + timeout;
  while (!phases.includes(phase) && Date.now() < deadline) await page.waitForTimeout(100);
  if (!phases.includes(phase)) throw new Error(`missing ${phase}; observed ${phases.join(',')}`);
};
const shot = async name => page.screenshot({ path: path.join(output, name + '.png') });
const expectShallows = name => {
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [path.join(output, name + '.png')], { encoding: 'utf8' }));
  const text = rows.map(row => row.text).join('\n');
  if (!/Shallows.*stronger/i.test(text)) throw new Error('SHALLOW-001 normal recovered/loaded world lacks visible Shallows purpose: ' + text);
  console.log('SHALLOWS VIEW|' + name + '|' + text.replaceAll('\n', ' | '));
};
const attack = async (name, moveY = 604) => {
  await page.mouse.click(160, 544);
  await page.waitForTimeout(400);
  await shot(name + '-move-menu');
  // Restoring the full Angler kit changes menu height. Select the rendered
  // label, not the old four-move menu's coordinates or injected game state.
  const moveName = name.includes('second-angler') ? 'Precise Tap'
    : name.includes('cordys') && moveY === 604 ? 'Axe Kick' : 'Electric Touch';
  const menuRows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [path.join(output, name + '-move-menu.png')], { encoding: 'utf8' }));
  const renderedMove = menuRows.find(row => row.text.trim() === moveName && row.y > 400);
  if (!renderedMove) throw new Error('Expected rendered move missing: ' + moveName);
  await page.mouse.click(renderedMove.x, renderedMove.y);
  await page.waitForTimeout(400);
  await shot(name + '-target-menu');
  await page.mouse.click(160, 666);
};
let failure, renderer, elapsedSeconds, engagedSeconds, deliberateIdleMs = 0, freeSwimKeydown, freeSwimMs, saveRecheck, deathRecheck;
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
  if (process.env.OPENING_IDLE_RECHECK === '1') {
    await page.waitForTimeout(15000);
    await shot('02a-idle-world');
    if (phases.includes('angler')) throw new Error('OPEN-035 Angler started before any swimming');
    for (const key of ['ArrowRight', 'ArrowLeft']) {
      await page.keyboard.down(key);
      await page.waitForTimeout(800);
      await page.keyboard.up(key);
    }
    if (phases.includes('angler')) throw new Error('OPEN-035 looking around started the Angler');
    deliberateIdleMs = Date.now() - timestamps.spawn_exploration;
  }
  // Keep keydown adjacent to the real handoff. A screenshot readback here
  // can consume several seconds and hide the actual movement interval.
  await page.keyboard.down('w');
  freeSwimKeydown = Date.now();
  if (phases.includes('angler')) throw new Error('OPEN-035 encounter started before swimming input');
  await waitPhase('angler', 12000);
  await page.keyboard.up('w');
  freeSwimMs = timestamps.angler - freeSwimKeydown;
  if (freeSwimMs < 4000) throw new Error('OPEN-035 actual swimming interrupts before four seconds');
  // Wall time alone cannot prove displacement under renderer slowdown.
  // Native displacement plus the dedicated continuous browser recording prove
  // actual swimming; this complete-flow gate pins the minimum and two-minute cap.
  await page.waitForTimeout(700);
  await shot('03-angler');
  await attack('03a-angler');

  // ANGLE-003: first real Electric Touch deals 1, not a guaranteed kill.
  // Wait for an actual next-turn Attack menu, then use its ordinary move.
  await page.waitForTimeout(1800);
  await shot('03b-nonlethal-angler');
  if (phases.includes('octopus_introduction')) throw new Error('ANGLE-003 Electric Touch still forced an opening one-shot');
  const nextTurnDeadline = Date.now() + 18000;
  let nextTurnReady = false;
  while (!nextTurnReady && Date.now() < nextTurnDeadline) {
    await shot('03c-next-turn');
    const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [path.join(output, '03c-next-turn.png')], { encoding: 'utf8' }));
    nextTurnReady = rows.some(row => /Pick a move/i.test(row.text));
    if (!nextTurnReady) await page.waitForTimeout(500);
  }
  if (!nextTurnReady) throw new Error('ANGLE-003 nonlethal attack did not return usable next-turn controls');
  await attack('03d-second-angler-action');
  await waitPhase('octopus_introduction', 15000);
  await page.waitForTimeout(6000);
  await shot('04-octopus-introduction');
  await waitPhase('octopus_response');
  if (timestamps.octopus_reveal - timestamps.octopus_introduction < 25000) throw new Error('Introduction did not play the full 25 seconds');
  await page.waitForTimeout(300);
  await shot('05-cordys');
  const axe = process.env.OPENING_CORDYS_MOVE === 'axe';
  await attack('05a-cordys', axe ? 604 : 544);
  const hitDeadline = Date.now() + 10000;
  while (!combatHits.length && Date.now() < hitDeadline) await page.waitForTimeout(50);
  const expectedHit = axe ? 'move=Axe Kick|damage=4|hit=true|hp=996' : 'move=Electric Touch|damage=1|hit=true|hp=999';
  if (combatHits.length !== 1 || !combatHits[0].includes(expectedHit)) throw new Error('OPEN-037 real browser move failed normal stat-based damage: ' + combatHits.join(';'));
  await shot('05b-real-impact');
  await waitPhase('scripted_defeat', 15000);
  await page.waitForTimeout(600);
  await shot('06-finisher');
  await waitPhase('octopus_aftermath', 15000);
  if (bossResponses.length !== 1 || !bossResponses[0].includes('Maxilani -80; Musashi -78; Bucky -76')) throw new Error('OPEN-036 browser boss response did not resolve actual STR/DEF: ' + bossResponses.join(';'));
  await page.waitForTimeout(5000);
  await shot('07-aftermath');
  await waitPhase('recovery', 45000);
  const endingMs = timestamps.recovery - timestamps.octopus_aftermath;
  if (endingMs < 6000 || endingMs > 15000) throw new Error('Approved boss-title ending was skipped or the long monologue remains');
  await page.waitForTimeout(300);
  await shot('08-recovery');
  if (storageFault) {
    await page.waitForTimeout(7000);
    await shot('08a-storage-failure');
    if (!await page.evaluate(() => window.rejectedCheckpointWrites > 0)) throw new Error('OPEN-033 storage fault was not exercised');
    if (!checkpointFailureObserved) throw new Error('OPEN-033 durable browser write failed but recovery offered successful Continue');
    if (phases.includes('complete')) throw new Error('OPEN-033 storage failure released normal play');
    await page.evaluate(() => { window.rejectCompletedCheckpoint = false; });
    await page.mouse.click(640, 417); // Centre of the visible Retry Save action.
    await page.waitForTimeout(2500);
    await shot('08b-retry-save');
  }
  // Recovery now starts with a visibly disabled Saving checkpoint action.
  // A click before its real durable acknowledgement must be ignored, not
  // treated as a failed Continue. Retry ordinary mouse input once enabled;
  // never synthesize a result or bypass the storage wait.
  const continueDeadline = Date.now() + 6000;
  while (!phases.includes('complete') && Date.now() < continueDeadline) {
    await page.mouse.click(640, 393);
    await page.waitForTimeout(200);
  }
  await waitPhase('complete', 5000);
  await page.waitForTimeout(600);
  await shot('09-optional-training');
  expectShallows('09-optional-training');
  elapsedSeconds = (Date.now() - started) / 1000;
  engagedSeconds = elapsedSeconds - deliberateIdleMs / 1000;
  console.log(`Normal browser New Game to control: ${elapsedSeconds}s; engaged=${engagedSeconds}s; deliberate idle/look=${deliberateIdleMs / 1000}s`);
  if (!storageFault && engagedSeconds >= 120) throw new Error('Engaged opening exceeds the two-minute acceptance limit');
  const expected = ['opening_video', 'opening_handoff', 'spawn_exploration', 'angler', 'octopus_introduction', 'octopus_reveal', 'octopus_response', 'scripted_defeat', 'octopus_aftermath', 'recovery', 'complete'];
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
    const explorationCheckpoint = saveRecheck.beforeReload.find(save => String(save.key).endsWith('/slot_0.json'));
    if (!explorationCheckpoint?.data.random_encounters_enabled || !explorationCheckpoint.data.divers[0].sonar_active) {
      throw new Error('OPEN-040/041 actual opening did not persist enabled Sonar and encounters');
    }
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
    expectShallows('12-loaded-world');
    saveRecheck.afterReload = await readSaves();
    const loadedExploration = saveRecheck.afterReload.find(save => String(save.key).endsWith('/slot_0.json'));
    if (!loadedExploration?.data.random_encounters_enabled || !loadedExploration.data.divers[0].sonar_active) {
      throw new Error('OPEN-041 cold Load lost enabled exploration settings');
    }
    if (phases.slice(expected.length).includes('opening_video') || phases.slice(expected.length).includes('spawn_exploration')) {
      throw new Error('OPEN-027 cold Load Game replayed the completed opening');
    }
    if (phases.slice(expected.length).join(',') !== 'complete') throw new Error('OPEN-027 Load Game did not restore completed normal play');
    if (process.env.OPENING_DEATH_RECHECK === '1') {
      const stored = saveRecheck.afterReload.find(save => String(save.key).endsWith('/slot_0.json'));
      if (!stored?.data.route_state.prologue_complete) throw new Error('OPEN-034 real completed checkpoint missing before attrition fixture');
      deathRecheck = { completionBeforeFixture: stored.data.route_state, deaths };
      // Explicit attrition fixture in this test profile only. Never manufacture
      // completion, a battle result, damage, or dead actors. Place the diver
      // OUTSIDE the normal Swordfish guardian so real W input enters the site.
      await page.evaluate(async stored => {
        const snapshot = structuredClone(stored.data);
        snapshot.active = 0;
        snapshot.divers.forEach((diver, index) => {
          // World's default camera-forward W maps to +Z. Approach the
          // trench (-42 Z) from its SOUTH edge, not away from its north edge.
          diver.position = [12 + index * 3, 2.6, -54];
          Object.assign(diver.stats, { hp: 1, defense: 0, evasion: 0, strength: 0, accuracy: 0 });
        });
        const db = await new Promise((resolve, reject) => {
          const request = indexedDB.open(stored.database);
          request.onsuccess = () => resolve(request.result);
          request.onerror = () => reject(request.error);
        });
        await new Promise((resolve, reject) => {
          const transaction = db.transaction('FILE_DATA', 'readwrite');
          const store = transaction.objectStore('FILE_DATA');
          const request = store.get(stored.key);
          request.onsuccess = () => {
            const value = request.result;
            value.contents = new TextEncoder().encode(JSON.stringify(snapshot));
            value.timestamp = new Date();
            store.put(value, stored.key);
          };
          transaction.oncomplete = resolve;
          transaction.onabort = transaction.onerror = () => reject(transaction.error);
        });
        db.close();
      }, stored);
      const coldLoad = async () => {
        await page.reload({ waitUntil: 'load' });
        await page.waitForTimeout(20000);
        await page.mouse.click(640, 405);
        await page.waitForTimeout(700);
        await page.mouse.click(640, 327);
        await page.waitForTimeout(1500);
      };
      const loseNormally = async expectedDeaths => {
        await page.keyboard.down('w');
        await page.waitForTimeout(1200);
        await page.keyboard.up('w');
        const deadline = Date.now() + 75000;
        while (deaths.length < expectedDeaths && Date.now() < deadline) {
          await page.mouse.click(165, 544); // Attack in the root action menu.
          await page.waitForTimeout(100);
          await page.mouse.click(165, 604); // First move (below the stats panel).
          await page.waitForTimeout(100);
          await page.mouse.click(165, 666); // Actual enemy target.
          await page.waitForTimeout(500); // Let enemy damage/QTE timeouts resolve.
        }
        if (deaths.length !== expectedDeaths) throw new Error('OPEN-034 real enemy combat did not reach Game Over');
      };
      await coldLoad();
      await loseNormally(1);
      await shot('13-actual-ordinary-death');
      await page.mouse.click(640, 356); // Visible Restart from Save Point.
      await page.waitForTimeout(3000);
      await shot('14-actual-restarted-world');
      if (phases.at(-1) !== 'complete' || phases.filter(p => p === 'complete').length !== 4) throw new Error('OPEN-034 death-screen Restart did not restore completed world');
      await loseNormally(2);
      await shot('15-second-actual-death');
      await page.mouse.click(640, 414); // Visible Return to Title.
      await page.waitForTimeout(2000);
      await shot('16-death-returned-title');
      await page.mouse.click(640, 405);
      await page.waitForTimeout(700);
      await page.mouse.click(640, 327);
      await page.waitForTimeout(2000);
      await shot('17-death-title-loaded-world');
      deathRecheck.afterDeaths = await readSaves();
      const finalCheckpoint = deathRecheck.afterDeaths.find(save => String(save.key).endsWith('/slot_0.json'));
      if (!finalCheckpoint?.data.route_state.prologue_complete || finalCheckpoint.data.route_state.tutorial_complete) throw new Error('OPEN-034 actual deaths changed the durable completion/training milestones');
      if (phases.slice(expected.length).some(p => p !== 'complete') || phases.filter(p => p === 'complete').length !== 5) throw new Error('OPEN-034 later death/title Load replayed or failed to restore completed world');
      if (deaths.some(line => !line.includes('slot=0|complete=true'))) throw new Error('OPEN-034 actual death lost its selected completed checkpoint');
    }
  }
  if (errors.length) throw new Error(errors.join('\n'));
  if (checkpointFailureObserved && !storageFault) throw new Error('Normal browser completion unexpectedly required Retry Save');
} catch (error) { failure = String(error); await shot('failure'); }
finally {
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ target, browserEngine, renderer, elapsedSeconds, engagedSeconds, deliberateIdleMs, freeSwimKeydown, freeSwimMs, phases, timestamps, combatHits, bossResponses, saveRecheck, deathRecheck, errors, failure: failure || null }, null, 2));
  await browser.close();
  if (!live) server.close();
}
if (failure) { console.error(failure); process.exit(1); }
console.log('OPENING WEB: ordinary entry, full split movies, real mouse combat and recovered control clean' + (deathRecheck ? '; actual ordinary deaths / Restart / title Load clean' : '') + (storageFault ? '; rejected browser persistence / Retry / cold Load clean' : ''));
