// END-2/3/4: real browser fight -> rejected durable checkpoint -> Retry ->
// Return to Title -> fresh-page chosen-slot Load. Supplied legal level-five
// kit/key/room isolates ending; this is NOT earned campaign/balance evidence.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const target = process.argv[2], output = process.argv[3] || '/tmp/campaign-ending-web';
const laboratory = process.argv.includes('--laboratory');
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
let actions = 0, committed, before;
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const observePage = active => {
  active.on('pageerror', error => errors.push(String(error)));
  active.on('console', message => {
    const text = message.text();
    if (text.includes('Failed to save IDB file system:')) { observations.push({ injectedStorageError: text }); return; }
    if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(text)) errors.push(text);
  });
};
observePage(page);
if (!laboratory) await page.addInitScript(() => {
  window.rejectCompletion = true;
  window.rejectedCompletionWrites = 0;
  const put = IDBObjectStore.prototype.put;
  IDBObjectStore.prototype.put = function(value, key) {
    const result = put.call(this, value, key);
    let completed = false;
    try { completed = JSON.parse(new TextDecoder().decode(value.contents)).route_state?.octopus_state === 'defeated'; } catch (_) {}
    if (window.rejectCompletion && completed && String(key).endsWith('/saves/slot_0.json')) {
      window.rejectedCompletionWrites++;
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
const readSlot = async () => page.evaluate(async record => {
  const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
  const bytes = await new Promise((resolve, reject) => { const tx = db.transaction('FILE_DATA', 'readonly'); const request = tx.objectStore('FILE_DATA').get(record.key); request.onsuccess = () => resolve(request.result ? new TextDecoder().decode(request.result.contents) : null); request.onerror = () => reject(request.error); });
  db.close(); return bytes;
}, { database: record.database, key: record.key });
const load = async label => {
  await clickText(/^Load Game$/, label + '-title');
  await clickText(/^Slot 1\s*[-–]/, label + '-slot');
  await page.waitForTimeout(2000);
};
try {
  await page.goto(url, { waitUntil: 'load' }); await page.waitForTimeout(24000);
  await clickText(/^New Game$/, 'cold-title'); await page.waitForTimeout(2000);
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      tx.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
    }); db.close();
  }, record);
  await page.reload(); await page.waitForTimeout(22000);
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
  else await page.keyboard.press('KeyY');
  await page.waitForTimeout(2000);
  const deadline = Date.now() + 180000;
  let ending = false;
  while (Date.now() < deadline && actions < 70) {
    const rows = await capture('fight-' + actions + '-' + observations.length);
    const text = rows.map(row => row.text).join('\n');
    if (laboratory ? /Computer recovered/i.test(text) : /Game complete/i.test(text)) { ending = true; break; }
    expect(!/party is overwhelmed/i.test(text), 'END-1 supplied legal-kit browser strategy lost; ending not reached');
    if (/Press Enter to continue/i.test(text)) { await page.keyboard.press('Enter'); await page.waitForTimeout(800); continue; }
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
    expect(/Computer recovered/i.test(payoff) && /controlling/i.test(payoff) && /ramp/i.test(payoff), 'LAB-W2 missing computer/controller/ramp payoff');
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
    await page.goto(url, { waitUntil: 'load' }); await page.waitForTimeout(23000);
    await load('cold-lab-load');
    const loaded = (await capture('cold-lab-completed')).map(row => row.text).join('\n');
    expect(/Laboratory cleared/i.test(loaded) && /maze/i.test(loaded) && !/Computer recovered|Your turn|Broken Office/i.test(loaded), 'LAB-W3 cold Load replays lab fight/payoff or loses maze direction');
    expect(await readSlot() === committed, 'LAB-W3 cold Load rewrote bytes, resources or reward');
  } else {
  const failure = (await capture('rejected-ending')).map(row => row.text).join('\n');
  expect(/Completion could not be saved/i.test(failure) && /Retry Save/i.test(failure), 'END-2 rejection falsely acknowledged saved ending');
  expect(await page.evaluate(() => window.rejectedCompletionWrites > 0), 'END-2 fault never reached completed durable write');
  expect(await readSlot() === before, 'END-2 rejection changed exact previous durable bytes');
  await clickText(/^Return to Title$/, 'disabled-title');
  expect((await capture('title-still-disabled')).some(row => /Game complete/i.test(row.text)), 'END-2 failed save allowed exit');
  await page.evaluate(() => { window.rejectCompletion = false; });
  await clickText(/^Retry Save$/, 'retry-ending'); await page.waitForTimeout(5500);
  const savedText = (await capture('confirmed-ending')).map(row => row.text).join('\n');
  expect(/Completed journey saved to Slot 1/i.test(savedText) && !/Retry Save/i.test(savedText), 'END-2 retry lacks durable confirmation');
  committed = await readSlot();
  const saved = JSON.parse(committed);
  expect(saved.route_state.octopus_state === 'defeated' && !saved.campaign_checkpoint.maze.boss_triggers.includes('main_boss'), 'END-1 completion retains boss or unfinished milestone');
  expect(saved.route_state.tethys_state === 'locked' && saved.campaign_checkpoint.maze.boss_triggers.includes('secret_boss'), 'END-1 completion incorrectly requires/finishes independent lab/puppets');
  await page.keyboard.down('KeyW'); await page.keyboard.press('Tab'); await page.keyboard.press('KeyP'); await page.waitForTimeout(600); await page.keyboard.up('KeyW');
  for (const width of [720, 360]) {
    await page.setViewportSize({ width, height: 720 }); await page.waitForTimeout(400);
    const text = (await capture('ending-' + width)).map(row => row.text).join('\n');
    expect(/Game complete/i.test(text) && /Return to Title/i.test(text) && !/Save Point|WASD|Your turn/i.test(text), 'END-4 narrow ending clips controls or leaks gameplay HUD');
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  await clickText(/^Return to Title$/, 'actual-title-exit'); await page.waitForTimeout(2000);
  expect((await capture('returned-title')).some(row => /^Load Game$/.test(row.text)), 'END-3 actual title exit did not return to title');
  await page.close(); page = await context.newPage(); observePage(page);
  await page.goto(url, { waitUntil: 'load' }); await page.waitForTimeout(23000);
  await load('cold-load');
  const loaded = (await capture('cold-completed')).map(row => row.text).join('\n');
  expect(/Game complete/i.test(loaded) && /Completed journey saved to Slot 1/i.test(loaded), 'END-3 cold Load did not restore completed ending');
  expect(await readSlot() === committed, 'END-3 cold Load rewrote bytes, resources or reward');
  }
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close(); if (server) await new Promise(resolve => server.close(resolve));
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ target: url, scenario: laboratory ? 'laboratory' : 'ending', fixture: laboratory ? 'new disposable profile, supplied legal level-five kit/cleared blockers; actual swim/movie/fight/payoff/Close/cold Load; NOT earned route' : 'new disposable profile, supplied legal level-five kit, supplied key spent through E, isolated recovered room; NOT earned route', actions, previous_sha256: before && hash(before), completed_sha256: committed && hash(committed), observations, findings }, null, 2));
console.log((laboratory ? 'LABORATORY PAYOFF WEB: ' : 'CAMPAIGN COMPLETION WEB: ') + (findings.length ? 'failed' : 'clean'));
for (const finding of findings) console.log('FINDING ' + finding);
process.exit(findings.length ? 1 : 0);
