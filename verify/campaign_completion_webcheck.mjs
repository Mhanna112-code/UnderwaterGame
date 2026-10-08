// END-2/3/4/6: real browser fight -> pre-boss autosave -> ending -> cold Load;
// optional rejected durability must offer only session Restart. Legal level-five
// kit/key/room isolates ending; this is NOT earned campaign/balance evidence.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const target = process.argv[2], output = process.argv[3] || '/tmp/campaign-ending-web';
const laboratory = process.argv.includes('--laboratory');
const deniedPreBoss = process.argv.includes('--deny-pre-boss');
fs.mkdirSync(output, { recursive: true });
const live = target.startsWith('http');
let server, url = target;
if (!live) {
  server = http.createServer((req, res) => {
    const filename = req.url.split('?')[0];
    const file = path.join(target, filename === '/' ? 'index.html' : filename);
    if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
    const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  url = `http://127.0.0.1:${server.address().port}/`;
}
const record = structuredClone(JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0]);
record.data = JSON.parse(fs.readFileSync(laboratory ? '/tmp/campaign-lab-browser-fixture.json' : '/tmp/campaign-ending-browser-fixture.json'));
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
let page = await context.newPage();
const errors = [], observations = [], findings = [];
let actions = 0, committed, before, metadata, servedPack;
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const observePage = active => {
  active.on('pageerror', error => errors.push(String(error)));
  active.on('console', message => {
    const text = message.text();
    if (!laboratory && text.includes('Failed to save IDB file system:')) { observations.push({ injectedStorageError: text }); return; }
    if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(text)) errors.push(text);
  });
};
observePage(page);
if (!laboratory) await page.addInitScript(() => {
  window.rejectPreBoss = false;
  window.rejectedPreBossWrites = 0;
  const put = IDBObjectStore.prototype.put;
  IDBObjectStore.prototype.put = function(value, key) {
    const result = put.call(this, value, key);
    let beforeBoss = false;
    try {
      const data = JSON.parse(new TextDecoder().decode(value.contents));
      beforeBoss = data.campaign_scene === 'maze' && data.route_state?.octopus_state !== 'defeated'
        && data.campaign_checkpoint?.maze?.boss_triggers?.includes('main_boss');
    } catch (_) {}
    if (window.rejectPreBoss && beforeBoss && String(key).endsWith('/saves/slot_0_auto.json')) {
      window.rejectedPreBossWrites++;
      this.transaction.abort();
    }
    return result;
  };
});
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  const text = rows.map(row => row.text).join('\n');
  observations.push({ name, text });
  console.log(name + '|' + text.replaceAll('\n', ' | '));
  return rows;
};
const expect = (condition, message) => { if (!condition) throw new Error(message); };
const click = async row => { await page.mouse.click(row.x, row.y); await page.waitForTimeout(400); };
const clickText = async (pattern, name) => {
  const rows = await capture(name), row = rows.find(row => pattern.test(row.text.trim()));
  expect(row, `Missing ${pattern}: ${rows.map(row => row.text).join(' | ')}`);
  await click(row);
};
const readSlot = async (autosave = false) => page.evaluate(async record => {
  const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
  const bytes = await new Promise((resolve, reject) => { const tx = db.transaction('FILE_DATA', 'readonly'); const request = tx.objectStore('FILE_DATA').get(record.key); request.onsuccess = () => resolve(request.result ? new TextDecoder().decode(request.result.contents) : null); request.onerror = () => reject(request.error); });
  db.close(); return bytes;
}, { database: record.database, key: autosave ? record.key.replace(/slot_0\.json$/, 'slot_0_auto.json') : record.key });
const load = async label => {
  await clickText(/^Load Game$/, label + '-title');
  await clickText(/^Slot 1\s*[-–]/, label + '-slot');
  await page.waitForTimeout(2000);
};
// BOOT-1: network/asset import time is variable. Do not click a nonexistent
// Load control on the Godot splash just because a fixed delay elapsed.
const waitTitle = async (label, needsLoad = false) => {
  const deadline = Date.now() + 90000;
  await page.waitForTimeout(4000);
  for (let poll = 0; Date.now() < deadline; poll++) {
    const rows = await capture(label + '-boot-' + poll);
    if (rows.some(row => /^New Game$/.test(row.text.trim()))
      && (!needsLoad || rows.some(row => /^Load Game$/.test(row.text.trim())))) return;
    expect(errors.length === 0, 'BOOT-1 browser/script error before title: ' + errors.join(' | '));
    await page.waitForTimeout(3000);
  }
  throw new Error('BOOT-1 title controls never became ready within 90 seconds');
};
try {
  metadata = await (await fetch(new URL('build-info.json', url))).json();
  if (process.env.EXPECTED_SOURCE_SHA) expect(metadata.source_commit === process.env.EXPECTED_SOURCE_SHA, 'Wrong runtime source identity');
  const pack = await fetch(new URL('index.pck', url));
  expect(pack.ok, 'Pack download HTTP ' + pack.status);
  const digest = crypto.createHash('sha256');
  let bytes = 0;
  for await (const chunk of pack.body) { bytes += chunk.length; digest.update(chunk); }
  servedPack = { bytes, sha256: digest.digest('hex') };
  expect(bytes === metadata.pck_bytes && servedPack.sha256 === metadata.pck_sha256, 'Served pack does not match identified runtime');
  await page.goto(url, { waitUntil: 'load' }); await waitTitle('cold');
  await clickText(/^New Game$/, 'cold-title'); await page.waitForTimeout(2000);
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      tx.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
    }); db.close();
  }, record);
  await page.reload(); await waitTitle('fixture', true);
  await load('fixture-load'); before = await readSlot();
  expect(before && JSON.parse(before).route_state.octopus_state !== 'defeated', 'No incomplete durable baseline');
  for (let step = 0; step < 16; step++) {
    const key = laboratory ? 'KeyA' : 'KeyW';
    await page.keyboard.down(key); await page.waitForTimeout(250); await page.keyboard.up(key);
    const rows = await capture('approach-' + step), text = rows.map(row => row.text).join('\n');
    // Guidance also names the Broken Office. Require the movie's actual
    // heading/control, not that destination appearing in the World HUD.
    if (laboratory ? rows.some(row => /^The Broken Office$|^Skip Cutscene$/.test(row.text.trim())) : /great danger/i.test(text)) break;
    expect(step < 15, 'Real swim never reached ' + (laboratory ? 'laboratory movie' : 'confirmation'));
  }
  if (laboratory) await clickText(/^Skip Cutscene$/, 'actual-lab-movie-skip');
  else {
    await page.evaluate(reject => { window.rejectPreBoss = reject; }, deniedPreBoss);
    await page.keyboard.press('KeyY');
  }
  await page.waitForTimeout(2000);
  const deadline = Date.now() + 240000;
  let ending = false;
  while (Date.now() < deadline && actions < 70) {
    const rows = await capture('fight-' + actions + '-' + observations.length);
    const text = rows.map(row => row.text).join('\n');
    if (laboratory ? /Computer recovered/i.test(text) : /Game complete/i.test(text)) { ending = true; break; }
    expect(!/party is overwhelmed/i.test(text), 'END-1 supplied legal-kit browser strategy lost; ending not reached');
    // The current lesson says "Press Space, Enter, or click Continue";
    // older lessons say "Press Enter to continue". Both are a reading
    // acknowledgment, not an X timing success or a game-state injection.
    if (rows.some(row => /Press.*Enter/i.test(row.text))) { await page.keyboard.press('Enter'); await page.waitForTimeout(800); continue; }
    const attack = rows.find(row => /^Attack$/.test(row.text.trim()) && row.y > 400);
    if (!attack) { await page.waitForTimeout(800); continue; }
    const who = /Maxilani.s turn/i.test(text) ? 'Maxilani' : /Musashi.s turn/i.test(text) ? 'Musashi' : /Bucky.s turn/i.test(text) ? 'Bucky' : '';
    if (!who) { await page.waitForTimeout(500); continue; }
    let targetName = laboratory ? 'Tethys' : 'Cordys', desired = who === 'Maxilani' ? 'Swift Strike' : who === 'Musashi' ? 'Precise Jab' : 'Guard Bash';
    // Alternate refreshes keep Blindness active with ordinary non-perfect
    // input. Legal level-five kit is supplied; no enemy/turn state injected.
    if (laboratory && who === 'Maxilani' && actions % 6 < 3) desired = 'Flash Blast';
    if (laboratory && who === 'Musashi' && actions < 3) desired = 'Weaken';
    if (who === 'Maxilani') {
      for (const name of ['Maxilani', 'Musashi', 'Bucky']) {
        const label = rows.find(row => row.text.trim() === name && row.x < 300 && row.y > 60 && row.y < 400);
        const health = label && rows.find(row => row.x < 300 && row.y > label.y && row.y < label.y + 30 && /\d+\s*\/\s*10/.test(row.text));
        const hp = health && Number(health.text.match(/(\d+)\s*\/\s*10/)[1]);
        if (hp > 0 && hp <= 6) { desired = 'Healing Current'; targetName = name; break; }
      }
    }
    await click(attack);
    let chosen;
    for (let scroll = 0; scroll < 10; scroll++) {
      const moves = await capture('moves-' + actions + '-' + scroll);
      chosen = moves.find(row => row.text.trim() === desired && row.y > 400);
      if (chosen) break;
      const down = moves.find(row => /Down$/.test(row.text.trim()) && row.y > 400);
      expect(down, 'END-1 no move-scroll control for ' + desired);
      await click(down);
    }
    expect(chosen, 'END-1 learned legal move missing: ' + desired);
    await click(chosen);
    const targets = await capture('targets-' + actions);
    const selected = targets.find(row => row.text.trim() === targetName && row.y > 400);
    expect(selected, 'END-1 target missing: ' + targetName);
    await click(selected); actions++;
    await page.waitForTimeout(1300);
  }
  expect(ending, 'END-1 no actual browser victory/ending before deadline');
  await page.waitForTimeout(5000);
  if (laboratory) {
    const payoff = (await capture('laboratory-payoff')).map(row => row.text).join('\n');
    expect(/Computer recovered/i.test(payoff) && /influenced/i.test(payoff) && /ramp/i.test(payoff), 'LAB-W2 missing computer/controller/ramp payoff');
    committed = await readSlot();
    const saved = JSON.parse(committed);
    expect(saved.route_state.lab_state === 'cleared' && saved.route_state.tethys_state === 'defeated'
      && saved.route_state.octopus_state !== 'defeated', 'LAB-W3 durable lab victory missing or falsely completes Cordys');
    await page.keyboard.down('KeyW'); await page.keyboard.press('Tab'); await page.keyboard.press('KeyP'); await page.waitForTimeout(600); await page.keyboard.up('KeyW');
    for (const width of [720, 360]) {
      await page.setViewportSize({ width, height: 720 }); await page.waitForTimeout(400);
      const text = (await capture('lab-payoff-' + width)).map(row => row.text).join('\n');
      expect(/Computer recovered/i.test(text) && /Close/i.test(text) && !/WASD|Your turn|Something grunts/i.test(text), 'LAB-W2 payoff clips controls or leaks gameplay HUD');
    }
    await page.setViewportSize({ width: 1280, height: 720 });
    await clickText(/^Close$/, 'actual-lab-payoff-close');
    const resumed = (await capture('lab-resumed-guidance')).map(row => row.text).join('\n');
    expect(/Laboratory cleared/i.test(resumed) && /maze/i.test(resumed) && !/Computer recovered/i.test(resumed), 'LAB-W2 Close does not resume useful maze direction');
    expect(!/Tethys rises/i.test(resumed), 'LAB-W4 payoff Close replays the obsolete boss-arrival notice');
    await page.close(); page = await context.newPage(); observePage(page);
    await page.goto(url, { waitUntil: 'load' }); await waitTitle('cold-lab', true);
    await load('cold-lab-load');
    const loaded = (await capture('cold-lab-completed')).map(row => row.text).join('\n');
    expect(/Laboratory cleared/i.test(loaded) && /maze/i.test(loaded) && !/Computer recovered|Your turn|Broken Office/i.test(loaded), 'LAB-W3 cold Load replays lab fight/payoff or loses maze direction');
    expect(await readSlot() === committed, 'LAB-W3 cold Load rewrote bytes, resources or reward');
  } else {
  const endingText = (await capture('pre-boss-ending')).map(row => row.text).join('\n');
  expect(/Restart from Auto Save/i.test(endingText) && /Return to Title/i.test(endingText), 'END-1 ending lacks Marc\'s requested choices');
  expect(await readSlot() === before, 'END-1 ending changed the existing manual checkpoint');
  committed = await readSlot(true);
  if (deniedPreBoss) {
    expect(/Autosave failed/i.test(endingText) && /session/i.test(endingText) && !/autosaved right before/i.test(endingText), 'END-6 rejected durability falsely promises persistent Restart');
    expect(await page.evaluate(() => window.rejectedPreBossWrites > 0), 'END-6 fault never reached the actual pre-boss autosave');
    expect(committed === null, 'END-6 rejection retained unconfirmed durable autosave bytes');
  } else {
    expect(/autosaved/i.test(endingText) && !/failed|session only|being confirmed/i.test(endingText), 'END-1 ending has no honest saved pre-boss confirmation');
    expect(committed, 'END-1 pre-boss autosave never reached IndexedDB');
    const saved = JSON.parse(committed);
    expect(saved.route_state.octopus_state !== 'defeated' && saved.campaign_checkpoint.maze.boss_triggers.includes('main_boss'), 'END-1 pre-boss autosave records completion or removes the station');
    expect(saved.route_state.tethys_state === 'locked' && saved.campaign_checkpoint.maze.boss_triggers.includes('secret_boss'), 'END-1 ending completed independent lab/puppets');
  }
  await page.keyboard.down('KeyW'); await page.keyboard.press('Tab'); await page.keyboard.press('KeyP'); await page.waitForTimeout(600); await page.keyboard.up('KeyW');
  for (const width of [720, 360]) {
    await page.setViewportSize({ width, height: 720 }); await page.waitForTimeout(400);
    const text = (await capture('ending-' + width)).map(row => row.text).join('\n');
    expect(/Game complete/i.test(text) && /Return to Title/i.test(text) && !/Save Point|WASD|Your turn/i.test(text), 'END-4 narrow ending clips controls or leaks gameplay HUD');
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  if (deniedPreBoss) {
    // Same-session Restart must still be usable without claiming cold persistence.
    await page.evaluate(() => { window.rejectPreBoss = false; });
    await clickText(/^Restart from Auto Save$/, 'actual-session-restart');
    await page.waitForTimeout(2000);
    const resumed = (await capture('session-pre-boss-restored')).map(row => row.text).join('\n');
    expect(!/Game complete|party is overwhelmed/i.test(resumed) && /WASD|Cordys|Maze/i.test(resumed), 'END-6 session Restart did not return to playable pre-boss maze');
    expect(await readSlot() === before && await readSlot(true) === null, 'END-6 session Restart rewrote persistent checkpoint bytes');
  } else {
  await clickText(/^Return to Title$/, 'actual-title-exit'); await page.waitForTimeout(2000);
  expect((await capture('returned-title')).some(row => /^Load Game$/.test(row.text)), 'END-3 actual title exit did not return to title');
  await page.close(); page = await context.newPage(); observePage(page);
  await page.goto(url, { waitUntil: 'load' }); await waitTitle('cold-ending', true);
  await load('cold-load');
  const loaded = (await capture('cold-pre-boss')).map(row => row.text).join('\n');
  expect(!/Game complete|New Game/i.test(loaded) && /WASD|Cordys|Maze/i.test(loaded), 'END-3 cold latest Load did not restore the pre-boss maze');
  expect(await readSlot() === before && await readSlot(true) === committed, 'END-3 cold Load rewrote manual or autosave bytes');
  }
  }
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close(); if (server) await new Promise(resolve => server.close(resolve));
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ target: url, source_commit: metadata?.source_commit, servedPack, scenario: laboratory ? 'laboratory' : deniedPreBoss ? 'pre-boss denied durability/session restart' : 'pre-boss durable/cold Load', fixture: laboratory ? 'new disposable profile, supplied legal level-five kit/cleared blockers; actual swim/movie/fight/payoff/Close/cold Load; NOT earned route' : 'new disposable profile, supplied legal level-five kit/key/isolated room; actual swim/confirmation/fight; NOT earned route', actions, previous_sha256: before && hash(before), pre_boss_sha256: committed && hash(committed), observations, findings }, null, 2));
console.log((laboratory ? 'LABORATORY PAYOFF WEB: ' : 'CAMPAIGN COMPLETION WEB: ') + (findings.length ? 'failed' : 'clean'));
for (const finding of findings) console.log('FINDING ' + finding);
process.exit(findings.length ? 1 : 0);
