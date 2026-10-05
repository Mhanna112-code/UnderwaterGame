// Room-only fixture in a disposable profile; actual Title Load/W/N/S/W/Y.
// Does not claim full maze traversal, key earning or browser save durability.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const target = process.argv[2], output = process.argv[3] || '/tmp/cordys-station-web';
fs.mkdirSync(output, { recursive: true });
const record = structuredClone(JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0]);
record.data = JSON.parse(fs.readFileSync('/tmp/cordys-maze-browser-fixture.json'));
const metadata = await (await fetch(new URL('build-info.json', target))).json();
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page = await context.newPage(), errors = [], observations = [], findings = [];
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => { if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(message.text())) errors.push(message.text()); });
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const text = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' })).map(row => row.text).join('\n');
  observations.push({ name, text }); console.log(name + '|' + text.replaceAll('\n', ' | ')); return text;
};
const expect = (condition, description) => { if (!condition) throw new Error(description); };
const move = async (key, ms) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(200); };
const approach = async prefix => {
  for (let step = 0; step < 12; step++) {
    await move('KeyW', 250);
    const text = await capture(prefix + '-' + step);
    if (/great danger/i.test(text)) return text;
    expect(!/Attack|Pick a move|Cordys waits for you/i.test(text), 'Approach bypassed confirmation and started combat');
  }
  throw new Error('Real browser swim never reached danger confirmation');
};
try {
  expect(!process.env.EXPECTED_SOURCE_SHA || metadata.source_commit === process.env.EXPECTED_SOURCE_SHA, 'Stale deployed source');
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await page.mouse.click(640, 367); await page.waitForTimeout(3000);
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
    await new Promise((resolve, reject) => {
      const transaction = db.transaction('FILE_DATA', 'readwrite');
      transaction.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      transaction.oncomplete = resolve; transaction.onerror = () => reject(transaction.error);
    }); db.close();
  }, record);
  await page.reload(); await page.waitForTimeout(20000);
  await page.mouse.click(640, 405); await page.waitForTimeout(700);
  await page.mouse.click(640, 267); await page.waitForTimeout(1500);
  const station = await capture('station');
  expect(/Cordys/i.test(station) && !/great danger|Attack/i.test(station), 'Title Load did not expose waiting Cordys before approach');
  await approach('approach');
  for (const [width, height] of [[720, 480], [360, 640]]) {
    await page.setViewportSize({ width, height }); await page.waitForTimeout(400);
    const text = await capture(`confirmation-${width}x${height}`);
    expect(/great danger/i.test(text) && /proceed/i.test(text) && /Yes/i.test(text) && /No/i.test(text), 'Responsive danger popup lost question or choices');
  }
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.keyboard.press('KeyN'); await page.waitForTimeout(2400);
  const declined = await capture('declined');
  expect(!/great danger|Attack|Pick a move/i.test(declined), 'No started combat or repeatedly prompted');
  await move('KeyS', 1500);
  await approach('reapproach');
  await page.keyboard.press('KeyY'); await page.waitForTimeout(1500);
  const battle = await capture('confirmed-battle');
  expect(/Cordys/i.test(battle) && /Attack|Pick a move|turn/i.test(battle) && !/great danger/i.test(battle), 'Yes did not start actual Cordys battle');
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close();
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ source_commit: metadata.source_commit, fixture: 'recovered campaign room; supplied key spent through native E; disposable profile', observations, findings, scope: 'exported Title Load/W/N/S/W/Y and responsive popup, not full campaign or browser durability' }, null, 2));
console.log(findings.length ? 'CORDYS STATION WEB: failed' : 'CORDYS STATION WEB: clean');
process.exit(findings.length ? 1 : 0);
