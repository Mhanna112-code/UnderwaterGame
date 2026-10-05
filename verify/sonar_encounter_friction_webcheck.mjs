// Owned fresh-profile checkpoint supplies completed opening/first-site lesson
// and a nearby reef position. Cold World Load faces +Z, so S approaches
// this checkpoint's -Z site and W leaves. Only real Q/R/W/S and modal inputs;
// no special URL flag, engine calls, teleports or authored victory injection.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { execFileSync } from 'node:child_process';
const target = process.argv[2], output = process.argv[3] || '/tmp/sonar-friction-web';
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
record.data = JSON.parse(fs.readFileSync('/tmp/sonar-friction-world-fixture.json'));
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [], findings = [], observations = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => {
  if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(message.text())) errors.push(message.text());
});
const expect = (ok, message) => { if (!ok) throw Error(message); };
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  observations.push({ name, text: rows.map(row => row.text).join('\n') });
  console.log(name + '|' + rows.map(row => row.text).join(' | '));
  return rows;
};
const click = async (pattern, name) => {
  const row = (await capture(name)).find(row => pattern.test(row.text.trim()));
  expect(row, 'Missing visible control ' + pattern);
  await page.mouse.click(row.x, row.y); await page.waitForTimeout(500);
};
const title = async label => {
  const deadline = Date.now() + 90000;
  await page.waitForTimeout(6000);
  for (let poll = 0; Date.now() < deadline; poll++) {
    const rows = await capture(label + '-boot-' + poll);
    if (rows.some(row => /^New Game$/.test(row.text.trim()))) return;
    expect(errors.length === 0, 'Browser failed during boot: ' + errors.join(' | '));
    await page.waitForTimeout(3000);
  }
  throw Error('Title never rendered');
};
const swimToPrompt = async label => {
  let found = false;
  await page.keyboard.down('KeyS');
  try {
    for (let step = 0; step < 12; step++) {
      await page.waitForTimeout(250);
      const rows = await capture(label + '-' + step);
      if (rows.some(row => /Something Guards This Place/i.test(row.text))) { found = true; break; }
    }
  } finally { await page.keyboard.up('KeyS'); }
  expect(found, 'FR-2 real S approach with Q/R off failed to open the guarded site');
};
try {
  if (process.env.EXPECTED_SOURCE_SHA) expect(metadata.source_commit === process.env.EXPECTED_SOURCE_SHA, 'Stale exported source');
  await page.goto(url, { waitUntil: 'load' }); await title('fresh');
  await click(/^New Game$/, 'create-fresh-storage');
  await page.waitForTimeout(2000);
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const r = indexedDB.open(record.database); r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      tx.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
    }); db.close();
  }, record);
  await page.reload(); await title('fixture');
  await click(/^Load Game$/, 'normal-title-load');
  await click(/^Slot 1.*Latest save$/i, 'normal-slot-load');
  await page.waitForTimeout(1200);
  const quiet = (await capture('quiet-travel')).map(row => row.text).join('\n');
  expect(/Sonar \(Off\)/i.test(quiet) && /Random Encounters \(Off\)/i.test(quiet), 'FR-2 saved Q/R choices not rendered');
  await page.keyboard.press('KeyQ');
  await page.waitForTimeout(6600);
  const scanning = (await capture('one-real-sonar-tick')).map(row => row.text).join('\n');
  expect(/Sonar \(On\)/i.test(scanning) && /99\s*\/\s*100/i.test(scanning), 'FR-1 real six-second scan did not spend exactly one Oxygen');
  await page.keyboard.press('KeyQ');
  await swimToPrompt('first-real-approach');
  await click(/^Not Now$/i, 'cancel-site');
  await page.waitForTimeout(900);
  const canceled = (await capture('no-prompt-loop')).map(row => row.text).join('\n');
  expect(!/Something Guards This Place/i.test(canceled) && /Random Encounters \(Off\)/i.test(canceled), 'FR-3 cancel immediately retriggers or loses quiet travel');
  await page.keyboard.down('KeyW'); await page.waitForTimeout(1200); await page.keyboard.up('KeyW');
  await swimToPrompt('real-reentry');
  await click(/^Enter$/i, 'enter-site');
  const chooser = (await capture('real-diver-chooser')).map(row => row.text).join('\n');
  expect(/Choose who goes/i.test(chooser), 'FR-2 normal site never opened the diver carousel');
  await page.keyboard.press('ArrowRight');
  await click(/^Send Them In$/i, 'send-musashi');
  await page.waitForTimeout(1800);
  const battle = (await capture('actual-special-battle')).map(row => row.text).join('\n');
  expect(/Musashi's turn/i.test(battle) && /NOW/.test(battle) && /Angler/.test(battle)
    && !/Choose who goes/i.test(battle) && !/Maxilani|Bucky/.test(battle), 'FR-2 site selection failed to enter the actual solo challenge');
  expect(errors.length === 0, 'Exported route has script/browser errors');
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close(); if (server) server.close();
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ source_commit: metadata.source_commit, pck_sha256: metadata.pck_sha256, observations, findings,
  scope: 'Fresh-profile supplied completed opening/first-site lesson checkpoint near reef. Normal Title Load, Q-on one actual 6-second billing interval, Q-off/R-off real S approach (cold Load faces +Z), cancel/no-loop, W exit/S reentry, visible chooser and real solo dispatch. No earned campaign/minigame victory or two-minute browser measurement claim.' }, null, 2));
console.log(findings.length ? 'SONAR FRICTION WEB: failed' : 'SONAR FRICTION WEB: clean');
process.exit(findings.length ? 1 : 0);
