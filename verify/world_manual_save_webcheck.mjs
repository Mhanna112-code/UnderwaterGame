// SAVE-2: actual Save UI / rejected IndexedDB / retry / cold Load.
// A recovered checkpoint is a declared fixture in a NEW browser context;
// this proves the manual writer, not earning recovery or the entire campaign.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { execFileSync } from 'node:child_process';

const target = process.argv[2], output = process.argv[3] || '/tmp/world-manual-save-web';
fs.mkdirSync(output, { recursive: true });
const live = target.startsWith('http');
let server;
let url = target;
if (!live) {
  server = http.createServer((req, res) => {
    const file = path.join(target, req.url.split('?')[0] === '/' ? 'index.html' : req.url.split('?')[0]);
    if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
    const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  url = `http://127.0.0.1:${server.address().port}/`;
}
const record = structuredClone(JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0]);
record.data.active = 0;
record.data.divers[0].position = [10, 2, 10];
record.data.random_encounters_enabled = false;
record.data.save_point_tutorial_seen = true;
record.data.route_state.tutorial_complete = false;
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page = await context.newPage(), errors = [], observations = [], findings = [];
await page.addInitScript(() => {
  window.rejectManualTarget = false;
  window.rejectedManualWrites = 0;
  const put = IDBObjectStore.prototype.put;
  IDBObjectStore.prototype.put = function(value, key) {
    const result = put.call(this, value, key);
    if (window.rejectManualTarget && String(key).endsWith('/saves/slot_1.json')) {
      window.rejectedManualWrites++;
      this.transaction.abort();
    }
    return result;
  };
});
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => {
  const text = message.text();
  if (text.includes('Failed to save IDB file system:')) { observations.push({ injectedStorageError: text }); return; }
  if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(text)) errors.push(text);
});
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  observations.push({ name, text: rows.map(row => row.text).join('\n') });
  return rows;
};
const clickText = async (pattern, name) => {
  const rows = await capture(name);
  const row = rows.find(row => pattern.test(row.text.trim()));
  if (!row) throw new Error(`Missing ${pattern}: ${rows.map(row => row.text).join(' | ')}`);
  await page.mouse.click(row.x, row.y);
  await page.waitForTimeout(600);
};
const readSlot = async slot => page.evaluate(async ({ database, key }) => {
  const db = await new Promise((resolve, reject) => { const request = indexedDB.open(database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
  const bytes = await new Promise((resolve, reject) => { const tx = db.transaction('FILE_DATA', 'readonly'); const request = tx.objectStore('FILE_DATA').get(key); request.onsuccess = () => resolve(request.result ? new TextDecoder().decode(request.result.contents) : null); request.onerror = () => reject(request.error); });
  db.close(); return bytes;
}, { database: record.database, key: record.key.replace('slot_0.json', `slot_${slot}.json`) });
const expect = (ok, message) => { if (!ok) throw new Error(message); };
try {
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(24000);
  await clickText(/^New Game$/, 'cold-title');
  await page.waitForTimeout(2500);
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      for (const slot of [0, 1]) tx.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key.replace('slot_0.json', `slot_${slot}.json`));
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
    }); db.close();
  }, record);
  await page.reload(); await page.waitForTimeout(22000);
  await clickText(/^Load Game$/, 'load-title');
  await clickText(/^Slot 1\s*[-–]/, 'load-slot');
  await page.waitForTimeout(5000);
  const before = [await readSlot(0), await readSlot(1)];
  expect(before.every(Boolean), 'Missing real disposable durable baseline');
  await page.evaluate(() => { window.rejectManualTarget = true; });
  await page.keyboard.press('KeyP'); await page.waitForTimeout(500);
  await clickText(/^Save$/, 'save-menu');
  await clickText(/^Slot 2\s*[-–]/, 'save-target');
  await clickText(/^Yes$/, 'overwrite-confirm');
  await page.waitForTimeout(5500);
  const rejected = (await capture('rejected-save')).map(row => row.text).join('\n');
  expect(await page.evaluate(() => window.rejectedManualWrites > 0), 'SAVE-2 fault never reached the actual IndexedDB write');
  expect(/Could not save/i.test(rejected) && !/Progress saved/i.test(rejected), 'SAVE-2 rejected browser persistence falsely acknowledged success: ' + rejected);
  expect(await readSlot(0) === before[0] && await readSlot(1) === before[1], 'SAVE-2 rejected browser write changed durable previous bytes');
  await page.evaluate(() => { window.rejectManualTarget = false; });
  await page.keyboard.press('KeyP'); await page.waitForTimeout(400);
  await clickText(/^Save$/, 'retry-menu');
  await clickText(/^Slot 2\s*[-–]/, 'retry-target');
  await clickText(/^Yes$/, 'retry-confirm');
  // Observe while the notice is actually live, not after its four-second
  // display expires and the authored Save prompt legitimately replaces it.
  let success = '';
  const successDeadline = Date.now() + 6500;
  for (let attempt = 0; Date.now() < successDeadline; attempt++) {
    success = (await capture(`confirmed-save-${attempt}`)).map(row => row.text).join('\n');
    if (/Progress saved to Slot 2/i.test(success)) break;
    await page.waitForTimeout(150);
  }
  const committed = await readSlot(1);
  expect(/Progress saved to Slot 2/i.test(success), 'SAVE-2 confirmed retry lacks success notice: ' + success);
  expect(committed && committed !== before[1] && JSON.parse(committed).route_state.prologue_complete, 'SAVE-2 retry did not durably replace the recovered checkpoint');
  expect(await readSlot(0) === before[0], 'SAVE-2 confirmed cross-slot retry overwrote source');
  await page.reload(); await page.waitForTimeout(22000);
  await clickText(/^Load Game$/, 'cold-reload-title');
  await clickText(/^Slot 2\s*[-–]/, 'cold-reload-target');
  await page.waitForTimeout(2500);
  await page.keyboard.press('KeyP'); await page.waitForTimeout(500);
  const loaded = (await capture('cold-loaded-save-point')).map(row => row.text).join('\n');
  expect(/Save Point/i.test(loaded) && !/Opening|Continue/i.test(loaded), 'SAVE-2 cold Load failed to restore playable save-point pose');
  expect(await readSlot(1) === committed, 'SAVE-2 cold Load mutated confirmed durable bytes');
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close();
if (server) await new Promise(resolve => server.close(resolve));
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ target: url, fixture: 'new disposable browser context, recovered World checkpoint at authored Save Point; not full campaign route', observations, findings }, null, 2));
console.log(findings.length ? 'WORLD MANUAL SAVE WEB: failed' : 'WORLD MANUAL SAVE WEB: clean');
for (const finding of findings) console.log('FINDING ' + finding);
process.exit(findings.length ? 1 : 0);
