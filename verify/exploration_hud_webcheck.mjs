// HUD-2/3/4/5: real Title Load from a declared fresh-profile HUD fixture,
// actual TAB/Q/R/F/Escape/F1 and ordinary swimming into random combat.
// Fixture resources/milestones are NOT earned campaign/balance evidence.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { execFileSync } from 'node:child_process';

const [target, output = '/tmp/exploration-hud-web'] = process.argv.slice(2);
fs.mkdirSync(output, { recursive: true });
let server, url = target;
if (!target.startsWith('http')) {
  server = http.createServer((req, res) => {
    const file = path.join(target, req.url.split('?')[0] === '/' ? 'index.html' : req.url.split('?')[0]);
    if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
    const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream' };
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  url = `http://127.0.0.1:${server.address().port}/`;
}
const metadata = await (await fetch(new URL('build-info.json', url))).json();
const record = structuredClone(JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0]);
const fixture = record.data;
fixture.route_state.tutorial_complete = true;
fixture.route_state.prologue_complete = true;
fixture.route_state.opening_video_seen = true;
fixture.random_encounters_enabled = false;
fixture.save_point_tutorial_seen = true;
fixture.divers.forEach((d, i) => {
  d.position = [30 + i * 2, 3, 30]; d.sonar_active = false;
  d.stats.hp = [8, 6, 4][i]; d.stats.oxygen = [72, 53, 31][i];
});
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [], findings = [], observations = [], logs = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => {
  if (/PROLOGUE_PHASE|RANDOM_COMBAT|CHECKPOINT_/.test(message.text())) logs.push(message.text());
  if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(message.text())) errors.push(message.text());
});
const expect = (ok, message) => { if (!ok) throw Error(message); };
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  observations.push({ name, text: rows.map(row => row.text).join('\n') });
  return rows;
};
const click = async (pattern, name) => {
  const rows = await capture(name), row = rows.find(row => pattern.test(row.text.trim()));
  expect(row, `Missing ${pattern}: ${rows.map(row => row.text).join(' | ')}`);
  await page.mouse.click(row.x, row.y); await page.waitForTimeout(700);
};
const title = async name => {
  await page.waitForTimeout(10000);
  for (let i = 0; i < 16; i++) {
    const rows = await capture(name + '-' + i);
    if (rows.some(row => /^New Game$/.test(row.text.trim()))) return;
    expect(errors.length === 0, errors.join('\n'));
    await page.waitForTimeout(2000);
  }
  throw Error('Title never rendered');
};
const text = async name => (await capture(name)).map(row => row.text).join('\n');
try {
  if (process.env.EXPECTED_SOURCE_SHA) expect(metadata.source_commit === process.env.EXPECTED_SOURCE_SHA, 'Stale source identity');
  await page.goto(url, { waitUntil: 'load' }); await title('fresh-title');
  await click(/^New Game$/, 'new-game');
  const bootDeadline = Date.now() + 12000;
  while (!logs.some(row => row.includes('PROLOGUE_PHASE|opening_video')) && Date.now() < bootDeadline) await page.waitForTimeout(200);
  expect(logs.some(row => row.includes('PROLOGUE_PHASE|opening_video')), 'Normal New Game did not acknowledge checkpoint/opening');
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const r = indexedDB.open(record.database); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      tx.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
    }); db.close();
  }, record);
  await page.reload(); await title('load-title');
  await click(/^Load Game$/, 'load-menu');
  await click(/^Slot 1.*Latest save$/i, 'load-slot'); await page.waitForTimeout(1500);
  for (const [width, height] of [[1280, 720], [960, 540], [720, 480], [360, 640]]) {
    await page.setViewportSize({ width, height }); await page.waitForTimeout(650);
    const screen = await text(`world-${width}x${height}`);
    for (const token of ['Maxilani', 'Musashi', 'Bucky', 'Health', 'Oxygen', 'Swim', 'Look']) expect(screen.includes(token), `HUD-4 missing ${token} at ${width}`);
    expect(/8\s*\/\s*10/.test(screen) && /72\s*\/\s*100/.test(screen), 'HUD-2 restored active resources incorrect');
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.keyboard.press('Tab'); await page.waitForTimeout(500);
  expect(/Health\s*6\s*\/\s*10/.test(await text('musashi-active')), 'HUD-2 TAB did not move Musashi resources into active card');
  await page.keyboard.press('f'); await page.waitForTimeout(500);
  expect(/Aiming Grapple/i.test(await text('grapple-aim')), 'HUD-5 existing aim/cancel instructions lost');
  await page.keyboard.press('Escape'); await page.waitForTimeout(500);
  await page.keyboard.press('Tab'); await page.waitForTimeout(500);
  expect(/Health\s*4\s*\/\s*10/.test(await text('bucky-active')), 'HUD-2 TAB did not move Bucky resources into active card');
  await page.keyboard.press('Tab'); await page.waitForTimeout(500);
  await page.keyboard.press('q'); await page.waitForTimeout(500);
  expect(/Sonar On/i.test(await text('sonar-on')), 'HUD-5 Sonar hint lost');
  await page.keyboard.press('q');
  await page.keyboard.press('Escape'); await page.waitForTimeout(500);
  const menu = await text('pause-menu');
  expect(/Party Spells|Combat Help/.test(menu) && !/Random encounters:|TAB\s+Switch diver|ACTIVE/.test(menu), 'HUD-3 pause menu competes with exploration HUD');
  await page.keyboard.press('Escape'); await page.waitForTimeout(500);
  await page.keyboard.press('F1'); await page.waitForTimeout(500);
  await capture('guide-open');
  await click(/^Close$/, 'guide-close');
  await page.keyboard.press('r'); await page.waitForTimeout(500);
  expect(/Random encounters:\s*ON/i.test(await text('encounters-on')), 'HUD-5 R status lost');
  await page.keyboard.down('w');
  const fightDeadline = Date.now() + 45000;
  while (!logs.some(row => row.includes('RANDOM_COMBAT')) && Date.now() < fightDeadline) await page.waitForTimeout(100);
  await page.keyboard.up('w');
  expect(logs.some(row => row.includes('RANDOM_COMBAT')), 'Ordinary swimming never triggered real random battle');
  await page.waitForTimeout(2400);
  const battle = await text('actual-random-battle');
  expect(!/Random encounters:|TAB\s+Switch diver|WASD\s+Swim/.test(battle), 'HUD-3 exploration HUD remains on actual battle screen');
  expect(/Attack|Run|Items/.test(battle), 'Battle controls were not visible');
  // Public Run is allowed to fail; repeated real attempts do not fake a result.
  let returned = false;
  for (let i = 0; i < 12; i++) {
    const screen = await text('battle-return-' + i);
    if (/Random encounters:/.test(screen)) { returned = true; break; }
    const rows = observations.at(-1).text;
    if (/Continue from Latest Save/.test(rows)) { await click(/^Continue from Latest Save$/i, 'death-recovery'); await page.waitForTimeout(1800); }
    else if (/^Run$/m.test(rows)) { await click(/^Run$/, 'run-attempt-' + i); await page.waitForTimeout(1100); }
    else await page.waitForTimeout(1100);
  }
  expect(returned, 'HUD-3 exploration HUD did not return after actual Run/death recovery');
  await capture('returned-world');
  expect(errors.length === 0, errors.join('\n'));
} catch (error) { findings.push(String(error)); }
finally {
  await browser.close(); if (server) server.close();
  fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ target, source_commit: metadata.source_commit, pck_sha256: metadata.pck_sha256, logs, observations, findings, errors, scope: 'Declared fresh-profile injured-party checkpoint, ordinary cold Load, real TAB/Q/R/F/Escape/F1, viewport resize, real random encounter and Run/death recovery. Not earned campaign, balance, or native-target launch verification.' }, null, 2));
}
console.log(findings.length ? 'EXPLORATION HUD WEB: failed' : 'EXPLORATION HUD WEB: clean');
process.exit(findings.length ? 1 : 0);
