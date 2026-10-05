// Exact export, real title, and earned map through actual browser swim/E/L.
// Diagnostic entrance only: NOT New Game, full navigation, combat or persistence.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const target = process.argv[2];
const output = process.argv[3] || '/tmp/maze-feedback-web';
fs.mkdirSync(output, { recursive: true });
const live = target.startsWith('http');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json' };
const server = http.createServer((request, response) => {
  const file = path.join(target, decodeURIComponent(request.url.split('?')[0]) === '/' ? 'index.html' : decodeURIComponent(request.url.split('?')[0]));
  if (!fs.existsSync(file)) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Content-Length': fs.statSync(file).size });
  fs.createReadStream(file).pipe(response);
});
if (!live) await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = live ? target : `http://127.0.0.1:${server.address().port}/`;
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const errors = [], downloads = [], findings = [];
const metadata = live ? await (await fetch(new URL('build-info.json', base))).json()
  : JSON.parse(fs.readFileSync(path.join(target, 'build-info.json'), 'utf8'));
const capture = async (page, name) => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  return JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' })).map(row => row.text).join('\n');
};
try {
  if (process.env.EXPECTED_SOURCE_SHA && metadata.source_commit !== process.env.EXPECTED_SOURCE_SHA)
    throw new Error('Deployment has not reached requested source: ' + metadata.source_commit);
  // Hash the actual served endpoint as a stream, outside Chromium's body cache.
  // Browser requests below must complete against this same identified URL.
  const packResponse = await fetch(new URL('index.pck', base));
  if (!packResponse.ok) throw new Error('Pack endpoint HTTP ' + packResponse.status);
  const hash = crypto.createHash('sha256');
  let bytes = 0;
  for await (const chunk of packResponse.body) { bytes += chunk.length; hash.update(chunk); }
  downloads.push({ bytes, sha256: hash.digest('hex'), endpoint: new URL('index.pck', base).href });
  if (bytes !== metadata.pck_bytes || downloads[0].sha256 !== metadata.pck_sha256) throw new Error('Served pack differs from identified source export');
  for (const route of ['', '?maze=1&entry=entrance']) {
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const page = await context.newPage();
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(message.text())) errors.push(message.text());
    });
    const downloaded = new Promise(resolve => page.on('requestfinished', async request => {
      if (new URL(request.url()).pathname.endsWith('/index.pck')) {
        const response = await request.response();
        if (!response?.ok()) errors.push('Browser pack request failed');
        console.log('BROWSER PACK REQUEST COMPLETE|' + route + '|' + request.url());
        resolve();
      }
    }));
    await page.goto(new URL(route, base).href, { waitUntil: 'load' });
    await Promise.race([downloaded, new Promise((_, reject) => setTimeout(() => reject(new Error('Pack download did not finish in 90 seconds')), 90000))]);
    await page.waitForTimeout(25000);
    if (!route) {
      const text = await capture(page, 'title');
      if (!/New Game/i.test(text)) findings.push('Export ordinary entry did not render the real New Game title');
      console.log('EXPORTED TITLE|' + text.replaceAll('\n', ' | '));
    } else {
      const world = await capture(page, 'maze-entry');
      if (!/navigation map|WASD|Hallway|L: map/i.test(world)) throw new Error('Export direct maze route did not render gameplay controls');
      if (!/find the navigation map[\s\S]*Control Room/i.test(world))
        throw new Error('GOAL-1 exported entrance hides its actionable Control Room destination');
      await page.keyboard.press('KeyL');
      await page.waitForTimeout(500);
      const unearned = await capture(page, 'map-unearned');
      if (/MAZE NAVIGATION/i.test(unearned)) throw new Error('Diagnostic entrance fabricated navigation map ownership');
      // The authored entrance faces +Z. Real D/S follows the clear west/north
      // approach into the Control Room; no item/state grant or engine injection.
      await page.keyboard.press('KeyR');
      await page.keyboard.down('KeyD');
      await page.waitForTimeout(1800);
      await page.keyboard.up('KeyD');
      await page.waitForTimeout(200);
      // This diagnostic entrance already starts at Y=2; rising again can
      // hit the door lintel. Native real-key reproduction confirms the
      // route at Y=2. Stop on the actual reach prompt, not wall-clock travel:
      // heavily contended browser rendering can advance fewer physics ticks.
      let reached = false;
      for (let step = 0; step < 14; step++) {
        await page.keyboard.down('KeyS');
        await page.waitForTimeout(500);
        await page.keyboard.up('KeyS');
        await page.waitForTimeout(300);
        const text = await capture(page, 'chest-step-' + step);
        if (/Press E to open/i.test(text)) { reached = true; break; }
      }
      const approach = await capture(page, 'chest-approach');
      console.log('EXPORTED CHEST APPROACH|' + approach.replaceAll('\n', ' | '));
      if (!reached) throw new Error('Browser route did not reach the actual chest interaction prompt');
      await page.keyboard.press('KeyE');
      await page.waitForTimeout(2500);
      const reward = await capture(page, 'map-acquired');
      if (!/Key Item Acquired/i.test(reward)) throw new Error('Browser swimming/E did not earn the Control Room navigation map');
      await page.keyboard.press('Escape');
      await page.keyboard.press('KeyL');
      await page.waitForTimeout(700);
      const intro = await capture(page, 'map-first-open');
      const strictIntro = process.env.EXPECT_MAP_INTRO !== '0';
      if (strictIntro && !/discovered/i.test(intro)) throw new Error('First earned L did not teach discovered-only navigation');
      if (/Maze Navigation/i.test(intro) && /discovered|select hallway/i.test(intro)) {
        for (const [width, height] of [[720, 480], [360, 640]]) {
          await page.setViewportSize({ width, height });
          await page.waitForTimeout(500);
          const lesson = await capture(page, `map-first-open-${width}x${height}`);
          if (!/Maze Navigation/i.test(lesson) || !/discovered/i.test(lesson) || !/closes\s+the\s+map/i.test(lesson))
            throw new Error('Paused navigation lesson clipped or missing at ' + width + 'x' + height);
        }
        await page.setViewportSize({ width: 1280, height: 720 });
        await page.keyboard.press('Escape');
        await page.waitForTimeout(500);
      }
      const map = await capture(page, 'maze-map');
      if (!/MAZE NAVIGATION/i.test(map) || !/rotate/i.test(map)) throw new Error('Real earned L did not reveal exported maze map controls');
      if (/Maze:\s*find|Open the hallway|Ancient Relic recovered/i.test(map))
        throw new Error('GOAL-4 exploration destination paints through the actual map overview');
      if (!/Left/i.test(map) || !/Right/i.test(map) || !/Ctrl/i.test(map) || !/Encounters/i.test(map)) throw new Error('MAP-8 exported map keys are unreadable or missing portable Left/Right/Ctrl/R controls');
      if (strictIntro && (!/LEGEND/i.test(map) || !/Chest/i.test(map) || /Boss|Special encounter/i.test(map)))
        throw new Error('Earned map legend is absent, omits the discovered chest or reveals unknown boss/site types');
      console.log('EXPORTED MAZE MAP|' + map.replaceAll('\n', ' | '));
      for (const [width, height] of [[720, 480], [360, 640]]) {
        await page.setViewportSize({ width, height });
        await page.waitForTimeout(500);
        const overview = await capture(page, `maze-map-${width}x${height}`);
        if (!/MAZE NAVIGATION/i.test(overview) || !/Left/i.test(overview) || !/Right/i.test(overview)
          || !/Ctrl/i.test(overview) || !/Encounters/i.test(overview) || (strictIntro && !/LEGEND/i.test(overview)))
          throw new Error('Actual earned map/help/legend is unreadable at ' + width + 'x' + height);
      }
      await page.keyboard.press('KeyL');
      await page.waitForTimeout(4500);
      for (const [width, height] of [[1280, 720], [720, 480], [360, 640]]) {
        await page.setViewportSize({ width, height });
        await page.waitForTimeout(500);
        const goal = await capture(page, `earned-map-goal-${width}x${height}`);
        if (!/Open the hallway/i.test(goal) || !/relic/i.test(goal) || !/Cordys/i.test(goal))
          throw new Error('GOAL-1 earned map does not restore a readable next destination at ' + width + 'x' + height);
        if (/E:\s*interact[\s\S]*F:\s*ability/i.test(goal))
          throw new Error('GOAL-4 restored destination revives retired generic bottom controls');
      }
      await page.setViewportSize({ width: 1280, height: 720 });
      await page.keyboard.press('Escape');
      await page.waitForTimeout(500);
      const inventory = await capture(page, 'goal-inventory-owner');
      if (/Open the hallway/i.test(inventory) || !/Inventory/i.test(inventory))
        throw new Error('GOAL-4 actual Inventory does not exclusively own the reading screen');
      await page.keyboard.press('Escape');
      await page.keyboard.press('Tab');
      await page.waitForTimeout(4500);
      await page.keyboard.press('KeyF');
      await page.waitForTimeout(500);
      const aim = await capture(page, 'goal-aim-owner');
      if (/Open the hallway/i.test(aim) || !/Left click/i.test(aim) || !/cancel/i.test(aim))
        throw new Error('GOAL-4 actual grapple aim does not own the HUD');
      await page.keyboard.press('Escape');
      await page.waitForTimeout(500);
      const canceled = await capture(page, 'goal-after-aim');
      if (!/Open the hallway/i.test(canceled) || /Inventory/i.test(canceled))
        throw new Error('GOAL-4 aim cancel loses destination or opens Inventory');
      await page.keyboard.press('KeyL');
      await page.waitForTimeout(500);
      const reopened = await capture(page, 'maze-map-repeat');
      if (/discovered|closes\s+the\s+map/i.test(reopened)) throw new Error('Navigation lesson repeated on the next L open');
    }
    await context.close();
  }
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close();
if (!live) await new Promise(resolve => server.close(resolve));
const receipt = { source_commit: metadata.source_commit, downloads, findings, scope: 'served pack checksum, completed browser pack requests, ordinary title, diagnostic entrance unearned-L rejection, actual swimming/E map acquisition, earned L controls and next destination at three widths, actual Inventory/aim/cancel reading ownership; no New Game full campaign or durability claim' };
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify(receipt, null, 2));
console.log(JSON.stringify(receipt));
console.log(findings.length ? 'MAZE FEEDBACK WEB: failed' : 'MAZE FEEDBACK WEB: clean');
process.exit(findings.length ? 1 : 0);
