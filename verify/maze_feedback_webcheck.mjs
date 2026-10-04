// Feedback artifact boundary: exact downloaded pack, real title and L-map UI.
// This is NOT full maze navigation, combat, persistence or listening acceptance.
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
      if (!/Hallway|Open the map|Shallows|L: map/i.test(world)) findings.push('Export direct maze route did not render gameplay controls');
      await page.keyboard.press('KeyL');
      await page.waitForTimeout(1000);
      const map = await capture(page, 'maze-map');
      if (map === world || !/MAZE NAVIGATION/i.test(map) || !/rotate/i.test(map)) findings.push('Real L did not reveal exported maze map controls');
      console.log('EXPORTED MAZE MAP|' + map.replaceAll('\n', ' | '));
      await page.keyboard.press('KeyL');
    }
    await context.close();
  }
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close();
if (!live) await new Promise(resolve => server.close(resolve));
const receipt = { source_commit: metadata.source_commit, downloads, findings, scope: 'served pack checksum, completed browser pack requests, rendered ordinary title and real direct-maze L controls only' };
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify(receipt, null, 2));
console.log(JSON.stringify(receipt));
console.log(findings.length ? 'MAZE FEEDBACK WEB: failed' : 'MAZE FEEDBACK WEB: clean');
process.exit(findings.length ? 1 : 0);
