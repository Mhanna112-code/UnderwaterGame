// Focused fixture: real recovered World snapshot in a disposable browser
// profile. Actual Title Load/W/Tab/F and rendered feedback, not fresh-opening
// or browser-save-durability acceptance. No free reward/state completion signal.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const target = process.argv[2], output = process.argv[3] || '/tmp/reward-rock-web';
fs.mkdirSync(output, { recursive: true });
const fixture = structuredClone(JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0]);
fixture.data.active = 0;
fixture.data.divers[0].position = [6, 2, -12];
fixture.data.divers[2].position = [6, 2, -9];
fixture.data.consumed_world_ids = [];
fixture.data.pending_world_drops = {};
fixture.data.inventory = {};
fixture.data.random_encounters_enabled = false;
fixture.data.save_point_tutorial_seen = true;
fixture.data.route_state.tutorial_complete = false;
fixture.data.route_state.objective_id = 'find_lab';
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
const metadata = await (await fetch(new URL('build-info.json', target))).json();
try {
  expect(!process.env.EXPECTED_SOURCE_SHA || metadata.source_commit === process.env.EXPECTED_SOURCE_SHA, 'Stale deployed source');
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await page.mouse.click(640, 367); // New Game creates real save directories.
  await page.waitForTimeout(3000);
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => { const request = indexedDB.open(record.database); request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error); });
    await new Promise((resolve, reject) => {
      const transaction = db.transaction('FILE_DATA', 'readwrite');
      transaction.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206, contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      transaction.oncomplete = resolve; transaction.onerror = () => reject(transaction.error);
    }); db.close();
  }, fixture);
  await page.reload(); await page.waitForTimeout(20000);
  await page.mouse.click(640, 405); await page.waitForTimeout(700); // Load Game.
  // Current Title includes separate autosave rows; the manual slot is the
  // first 44px button at y=267, not the retired menu's y=327 autosave row.
  await page.mouse.click(640, 267); await page.waitForTimeout(1500); // Manual slot 0.
  await page.keyboard.down('KeyW'); await page.waitForTimeout(1100); await page.keyboard.up('KeyW');
  await page.waitForTimeout(300);
  const approaching = await capture('approach');
  expect(/Break rocks for items/i.test(approaching) && /TAB/i.test(approaching) && /Bucky/i.test(approaching) && /Shockwave/i.test(approaching), 'ROCK-1 exported approach lacks switch/ability/reward instruction');
  for (let i = 0; i < 2; i++) { await page.keyboard.press('Tab'); await page.waitForTimeout(250); }
  const selected = await capture('bucky');
  expect(/Break this rock for items/i.test(selected) && /\(F\).*Shockwave/i.test(selected), 'ROCK-3 real browser Tab did not provide selected Bucky prompt');
  await page.keyboard.press('KeyF'); await page.waitForTimeout(400);
  const broken = await capture('broken');
  expect(!/Break (this rock|rocks) for items/i.test(broken), 'ROCK-3 hint survived real browser Shockwave');
  // Breaking spawns a pickup; it does not auto-grant one from two metres
  // away. Walk the actual next boundary instead of assuming instant pickup.
  let collected = /Picked up a/i.test(broken);
  for (let step = 0; step < 4 && !collected; step++) {
    await page.keyboard.down('KeyW'); await page.waitForTimeout(350); await page.keyboard.up('KeyW');
    await page.waitForTimeout(200);
    collected = /Picked up a/i.test(await capture('pickup-' + step));
  }
  expect(collected, 'ROCK-3 actual swim-to-pickup has no rendered collection confirmation');
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close();
const receipt = { source_commit: metadata.source_commit, fixture: 'disposable recovered World checkpoint; selected positions and encounters isolated; inventory starts empty', observations, findings, scope: 'actual hosted Title Load/W/Tab/F and visible reward confirmation, not fresh opening or durability' };
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify(receipt, null, 2));
console.log(findings.length ? 'REWARD ROCK WEB: failed' : 'REWARD ROCK WEB: clean');
process.exit(findings.length ? 1 : 0);
