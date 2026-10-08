// SAVE-1/2/4/5: real hosted UI, actual random-enemy defeat, cold reload and IDB.
// Declared older manual/newer autosave fixtures in a fresh browser profile only.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { execFileSync } from 'node:child_process';

const target = process.argv[2], output = process.argv[3] || '/tmp/latest-save-web';
fs.mkdirSync(output, { recursive: true });
let server, url = target;
if (!target.startsWith('http')) {
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
const metadata = await (await fetch(new URL('build-info.json', url))).json();
const record = structuredClone(JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0]);
const manual = structuredClone(record.data);
manual.active = 0;
manual.random_encounters_enabled = true;
manual.save_point_tutorial_seen = true;
manual.route_state.tutorial_complete = true;
manual.route_state.prologue_complete = true;
manual.route_state.opening_video_seen = true;
manual.inventory = { potion: 1 };
manual.save_sequence = 10;
manual.divers.forEach((diver, i) => {
  // Stay away from save points: current main restores HP/O2 on contact, which
  // would legitimately heal the injured fixture before we inspect its HUD.
  diver.position = [30, 3, 30 + i * 2]; diver.sonar_active = false;
  Object.assign(diver.stats, { hp: 10, hp_max: 10, evasion: 0, defense: 0, agility: 0, oxygen: 60 });
});
const automatic = structuredClone(manual);
automatic.save_sequence = 11; automatic.inventory = { potion: 7 };
automatic.divers.forEach(diver => { diver.stats.hp = 1; });
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [], findings = [], observations = [], logs = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => {
  if (/CHECKPOINT_|RANDOM_COMBAT|PROLOGUE_PHASE/.test(message.text())) logs.push(message.text());
  if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(message.text())) errors.push(message.text());
});
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  observations.push({ name, text: rows.map(row => row.text).join('\n') });
  return rows;
};
const click = async (pattern, name) => {
  const rows = await capture(name), row = rows.find(row => pattern.test(row.text.trim()));
  if (!row) throw Error(`Missing ${pattern}: ${rows.map(row => row.text).join(' | ')}`);
  await page.mouse.click(row.x, row.y); await page.waitForTimeout(700);
};
const seed = async corrupt => page.evaluate(async ({ record, manual, automatic, corrupt }) => {
  const db = await new Promise((resolve, reject) => { const r = indexedDB.open(record.database); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
  await new Promise((resolve, reject) => {
    const tx = db.transaction('FILE_DATA', 'readwrite'), store = tx.objectStore('FILE_DATA');
    for (const [suffix, data] of [['slot_0.json', manual], ['slot_0_auto.json', corrupt ? { save_sequence: 12, divers: 'broken' } : automatic]]) {
      store.put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(data)) }, record.key.replace('slot_0.json', suffix));
    }
    tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
  }); db.close();
}, { record, manual, automatic, corrupt });
const expect = (ok, message) => { if (!ok) throw Error(message); };
try {
  if (process.env.EXPECTED_SOURCE_SHA) expect(metadata.source_commit === process.env.EXPECTED_SOURCE_SHA, 'Stale runtime source');
  await page.goto(url, { waitUntil: 'load' }); await page.waitForTimeout(24000);
  await click(/^New Game$/, 'fresh-title'); await page.waitForTimeout(2500);
  await seed(false);
  await page.reload(); await page.waitForTimeout(22000);
  await click(/^Load Game$/, 'cold-title');
  await click(/^Slot 1.*Latest save$/i, 'latest-picker');
  await page.waitForTimeout(1500);
  expect(logs.some(row => /CHECKPOINT_LATEST_LOADED.*slot=0.*autosave=true/.test(row)), 'Default Load did not choose autosave');
  const loaded = (await capture('latest-loaded')).map(row => row.text).join('\n');
  expect(/1\s*\/\s*10/.test(loaded), 'Autosaved injured health not restored visibly');
  // Real swimming earns a random encounter; no injected battle result/phase.
  await page.keyboard.down('KeyW');
  const revealDeadline = Date.now() + 45000;
  while (!logs.some(row => row.includes('RANDOM_COMBAT')) && Date.now() < revealDeadline) await page.waitForTimeout(100);
  await page.keyboard.up('KeyW');
  expect(logs.some(row => row.includes('RANDOM_COMBAT')), 'Normal swimming never started random combat');
  const deathDeadline = Date.now() + 85000;
  let death = false;
  while (Date.now() < deathDeadline) {
    const rows = await capture('combat-current');
    if (rows.some(row => /Continue from Last Autosave/i.test(row.text))) { death = true; break; }
    const next = rows.find(row => /^Continue(?:\s|$)/i.test(row.text.trim()))
      || rows.find(row => /^Attack$/i.test(row.text.trim()))
      // A selected move's readout remains on screen during target selection.
      // Choose the actual target button before that non-interactive readout.
      || rows.find(row => /^(Angler|Frilled Shark|Swordfish(?: Duelist)?)(?:\s*\d)?$/i.test(row.text.trim()) && row.y > 480)
      || rows.find(row => /^(Precise Tap|Electric Touch|Guard Bash|Sonic Lance)/i.test(row.text.trim()) && row.y > 580);
    if (next) await page.mouse.click(next.x, next.y);
    await page.waitForTimeout(650);
  }
  expect(death, 'Actual enemies did not reach Game Over through ordinary combat input');
  await capture('actual-defeat');
  const previousLoads = logs.filter(row => /CHECKPOINT_LATEST_LOADED.*autosave=true/.test(row)).length;
  await click(/^Continue from Last Autosave$/i, 'continue-latest');
  await page.waitForTimeout(7000);
  expect(logs.filter(row => /CHECKPOINT_LATEST_LOADED.*autosave=true/.test(row)).length > previousLoads, 'Actual death recovery did not reload autosave');
  const restored = (await capture('death-recovered')).map(row => row.text).join('\n');
  expect(/1\s*\/\s*10/.test(restored), 'Death recovery did not preserve saved HP');
  // Cold-load explicit manual alternative remains available and restores HP10.
  await page.reload(); await page.waitForTimeout(22000);
  await click(/^Load Game$/, 'manual-title');
  await click(/^Slot 1 Save Point/i, 'manual-picker');
  await page.waitForTimeout(1000);
  expect(/10\s*\/\s*10/.test((await capture('manual-loaded')).map(row => row.text).join('\n')), 'Explicit save-point load selected auto');
  await seed(true); await page.reload(); await page.waitForTimeout(22000);
  await click(/^Load Game$/, 'fallback-title');
  await click(/^Slot 1.*Latest save$/i, 'fallback-picker');
  await page.waitForTimeout(1000);
  expect(logs.some(row => /CHECKPOINT_LATEST_LOADED.*slot=0.*autosave=false/.test(row)), 'Invalid newer snapshot blocked manual fallback');
  expect(/10\s*\/\s*10/.test((await capture('fallback-loaded')).map(row => row.text).join('\n')), 'Fallback restored wrong resources');
  await page.setViewportSize({ width: 360, height: 640 });
  await page.reload(); await page.waitForTimeout(22000);
  await click(/^Load Game$/, 'narrow-title'); await capture('narrow-picker');
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close(); if (server) server.close();
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ source_commit: metadata.source_commit, pck_sha256: metadata.pck_sha256, logs, observations, findings, scope: 'Fresh-profile declared save fixtures; actual swimming/random-enemy defeat/default recovery; explicit cold manual load and invalid-auto fallback. No earned autosave cadence or full campaign claim.' }, null, 2));
console.log(findings.length ? 'LATEST SAVE WEB: failed' : 'LATEST SAVE WEB: clean');
process.exit(findings.length ? 1 : 0);
