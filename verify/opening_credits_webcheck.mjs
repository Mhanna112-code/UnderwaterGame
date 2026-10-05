// TITLE-008: normal New Game/complete actual movie in a disposable profile.
// Does not inject game phase, accelerate playback or access a player's saves.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const target = process.argv[2], output = process.argv[3] || '/tmp/opening-credits-web';
fs.mkdirSync(output, { recursive: true });
const metadata = await (await fetch(new URL('build-info.json', target))).json();
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errors = [], findings = [], observations = [];
let handoff = false;
page.on('pageerror', error => errors.push(String(error)));
page.on('console', message => {
  if (message.text().includes('PROLOGUE_PHASE|opening_handoff')) handoff = true;
  if (message.type() === 'error' || /SCRIPT ERROR:|^ERROR:/.test(message.text())) errors.push(message.text());
});
const capture = async name => {
  const file = path.join(output, name + '.png');
  await page.screenshot({ path: file });
  const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [file], { encoding: 'utf8' }));
  observations.push({ name, text: rows.map(row => row.text).join('\n') });
  return rows;
};
try {
  if (process.env.EXPECTED_SOURCE_SHA && metadata.source_commit !== process.env.EXPECTED_SOURCE_SHA) throw Error('Stale runtime source');
  await page.goto(target, { waitUntil: 'load' });
  await page.waitForTimeout(25000);
  const start = (await capture('title')).find(row => /^New Game$/i.test(row.text.trim()));
  if (!start) throw Error('Rendered New Game action missing');
  await page.mouse.click(start.x, start.y);
  const deadline = Date.now() + 55000;
  while (!handoff && Date.now() < deadline) await page.waitForTimeout(50);
  if (!handoff) throw Error('Actual movie never entered opening title');
  await page.waitForTimeout(850);
  const copy = (await capture('credits')).map(row => row.text).join('\n');
  for (const name of ['ImmortalDemonGod', 'Mhanna', 'Glass_Goat', 'Phoenix Down Music']) {
    if (!copy.includes(name)) throw Error('TITLE-008 rendered credit missing: ' + name);
  }
} catch (error) { findings.push(String(error)); }
findings.push(...errors);
await browser.close();
fs.writeFileSync(path.join(output, 'receipt.json'), JSON.stringify({ source_commit: metadata.source_commit, observations, findings, scope: 'Normal hosted New Game and complete Mermaid movie to visible credits; no full campaign claim' }, null, 2));
console.log(findings.length ? 'OPENING CREDITS WEB: failed' : 'OPENING CREDITS WEB: clean');
process.exit(findings.length ? 1 : 0);
