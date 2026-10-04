// OPEN-043/044: focused browser boundary. Disposable profile seeded from an
// actual recovered opening checkpoint; only positions/protected test settings
// are fixtures. Normal title Load, real keyboard movement/Tab/E, rendered OCR.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const target = process.argv[2];
const output = process.argv[3] || '/tmp/local-world-guidance-web';
fs.mkdirSync(output, { recursive: true });
const stored = JSON.parse(fs.readFileSync('docs/evidence/opening-exploration-defaults/browser-result.json')).saveRecheck.beforeReload[0];
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page = await context.newPage();
const errors = [], steps = [], observations = [], fixtures = [];
page.on('console', msg => {
  if (msg.type() === 'error' || /SCRIPT ERROR:|Infinite loop detected|^ERROR:/.test(msg.text())) errors.push(msg.text());
});
page.on('pageerror', err => errors.push(String(err)));
const hold = async (key, milliseconds) => {
  steps.push({ key, milliseconds });
  await page.keyboard.down(key);
  await page.waitForTimeout(milliseconds);
  await page.keyboard.up(key);
};
const observe = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  const text = rows.map(row => row.text).join('\n');
  observations.push({ name, text });
  console.log(`VIEW|${name}|${text.replaceAll('\n', ' | ')}`);
  return text;
};
const expect = (condition, message) => { if (!condition) throw new Error(message); };
const loadFixture = async (name, position) => {
  const fixture = structuredClone(stored);
  fixture.data.divers[0].position = position;
  fixture.data.divers[2].position = [14.2, 2, 10];
  fixture.data.random_encounters_enabled = false;
  fixture.data.save_point_tutorial_seen = true;
  fixture.data.route_state.objective_id = 'find_lab';
  fixture.data.route_state.zone_id = position[0] >= 60 ? 'deep' : 'shallows';
  fixture.data.route_state.deep_warning_seen = true;
  fixtures.push({ name, data: fixture.data });
  await page.evaluate(async record => {
    const db = await new Promise((resolve, reject) => {
      const req = indexedDB.open(record.database);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
    await new Promise((resolve, reject) => {
      const tx = db.transaction('FILE_DATA', 'readwrite');
      tx.objectStore('FILE_DATA').put({ timestamp: new Date(), mode: 33206,
        contents: new TextEncoder().encode(JSON.stringify(record.data)) }, record.key);
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  }, fixture);
  await page.reload();
  await page.waitForTimeout(20000);
  await page.mouse.click(640, 405); // actual Load Game
  await page.waitForTimeout(700);
  await page.mouse.click(640, 327); // actual slot 0
  await page.waitForTimeout(1500);
};
let failure;
try {
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  await page.mouse.click(640, 367); // creates real save directories in this profile
  await page.waitForTimeout(3000);
  await loadFixture('deep-checkpoint', [60.8, 2, 30]);
  expect(/find the laboratory/i.test(await observe('deep-loaded')), 'OPEN-043 Deep Load lacks visible lab instruction');
  await hold('ArrowRight', 800); // turn west
  await hold('w', 800);
  expect(!/find the laboratory/i.test(await observe('shallows')), 'OPEN-043 lab instruction sticks in Shallows');
  await hold('s', 1500);
  expect(/find the laboratory/i.test(await observe('deep-return')), 'OPEN-043 same-objective Deep return lacks instruction');

  await loadFixture('puzzle-approach', [11.4, 2, 10]);
  expect(!/find the laboratory/i.test(await observe('puzzle-outside')), 'OPEN-043 Shallows Load shows sticky lab instruction');
  await hold('ArrowLeft', 800); // turn east
  await hold('w', 600);
  expect(/Bucky.*Shockwave.*break the wall/i.test(await observe('puzzle-contact')), 'OPEN-044 actual contact lacks Bucky wall instruction');
  await hold('s', 1600);
  expect(!/break the wall/i.test(await observe('puzzle-left')), 'OPEN-044 puzzle instruction follows into open water');
  await hold('w', 1600);
  expect(/break the wall/i.test(await observe('puzzle-return')), 'OPEN-044 returning to intact wall loses hint');
  await page.keyboard.press('Tab');
  await page.keyboard.press('Tab');
  await page.keyboard.press('e'); // actual Bucky Shockwave
  await page.waitForTimeout(900);
  const broken = await observe('wall-broken');
  expect(/Bucky/i.test(broken), 'OPEN-044 Shockwave was not performed by Bucky');
  expect(!/break the wall/i.test(broken), 'OPEN-044 wall hint survives real Shockwave');
  expect(errors.length === 0, 'Runtime errors: ' + errors.join('\n'));
  console.log('LOCAL WORLD GUIDANCE WEB: clean');
} catch (error) {
  failure = String(error);
  console.error(failure);
} finally {
  fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ target,
    fixtureBoundary: 'disposable actual recovered checkpoint; explicit positions, no injected victory/consumption',
    fixtures, steps, observations, errors, failure: failure || null }, null, 2));
  await context.close();
  await browser.close();
}
if (failure) process.exit(1);
