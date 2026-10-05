// Declared completed-lab checkpoint, fresh browser profile only. Ordinary
// Title Load + keyboard swimming exercise the actual exported route/renderer.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { execFileSync } from 'node:child_process';

const target = process.argv[2], output = process.argv[3] || '/tmp/lab-maze-navigation-web';
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
record.data = JSON.parse(fs.readFileSync('/tmp/lab-maze-navigation-fixture.json'));
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
  await page.waitForTimeout(1800);
  for (const width of [1280, 720, 360]) {
    await page.setViewportSize({ width, height: 720 }); await page.waitForTimeout(700);
    const rows = await capture('lab-exit-' + width);
    expect(rows.some(row => /^Maze ramp$/i.test(row.text.trim())), 'NAV-W1 compass unreadable at lab exit, width ' + width);
    const label = rows.find(row => /^Maze ramp$/i.test(row.text.trim()));
    expect(label.x > 0 && label.x < width && label.y > 160 && label.y < 590, 'NAV-W4 compass overlaps map/controls or bottom health');
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  // Normal Load starts with yaw zero: A swims east toward the left-pointing
  // compass. No direct camera, actor, phase, encounter or result injection.
  await page.keyboard.down('KeyA');
  const deadline = Date.now() + 25000;
  let entered = false;
  let previousDistance = Infinity;
  for (let step = 0; Date.now() < deadline; step++) {
    await page.waitForTimeout(1600);
    const rows = await capture('actual-swim-' + step), text = rows.map(row => row.text).join('\n');
    if (!/Maze ramp|Laboratory cleared/i.test(text)) { entered = true; break; }
    const label = rows.find(row => /^Maze ramp$/i.test(row.text.trim()));
    const distance = label && rows.find(row => /^\d+\s*m/i.test(row.text.trim()) && row.y > label.y && row.y < label.y + 40);
    expect(distance, 'NAV-W6 visible compass lost its distance during the approach');
    const metres = Number(distance.text.match(/^\d+/)[0]);
    expect(metres <= previousDistance + 1, 'NAV-W6 distance increases before entry: compass points back to the ramp mouth');
    previousDistance = metres;
  }
  await page.keyboard.up('KeyA');
  expect(entered, 'NAV-W2 actual lab-to-ramp swimming never relinquished World HUD to the maze');
  await capture('actual-maze-entry');
  expect(errors.length === 0, 'NAV-W3 exported flow contains browser/script errors');
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close(); if (server) server.close();
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ source_commit: metadata.source_commit, pck_sha256: metadata.pck_sha256, observations, findings,
  scope: 'Fresh-profile supplied completed-lab checkpoint; normal Title Load, visible compass at three widths, actual browser A swimming through the lab exit/ramp into maze ownership. Not an earned Tethys victory or full-campaign balance claim.' }, null, 2));
console.log(findings.length ? 'LAB MAZE NAVIGATION WEB: failed' : 'LAB MAZE NAVIGATION WEB: clean');
process.exit(findings.length ? 1 : 0);
