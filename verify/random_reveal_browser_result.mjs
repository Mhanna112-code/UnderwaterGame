// REVEAL-01/02: evaluate the affected feature using retained ordinary-entry
// browser evidence, without hiding separate whole-opening acceptance failures.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const folder = process.argv[2];
const result = JSON.parse(fs.readFileSync(path.join(folder, 'result.json'), 'utf8'));
if (result.errors.length) throw new Error('Browser runtime errors: ' + result.errors.join(';'));
const reveals = result.sourcePresentationEvents.filter(event => event.line.startsWith('RANDOM_REVEAL|'));
const fights = result.sourcePresentationEvents.filter(event => event.line.startsWith('RANDOM_COMBAT|'));
if (!reveals.length || reveals.length !== fights.length) throw new Error('REVEAL-01 missing/stacked handoff');
const checks = reveals.map((reveal, index) => {
  const fight = fights[index];
  if (reveal.line.split('|')[1] !== fight.line.split('|')[1]) throw new Error('REVEAL-02 identity drift');
  const durationMs = fight.time - reveal.time;
  if (durationMs < 1300 || durationMs > 2500) throw new Error('REVEAL-01 unreadable or overlong reveal: ' + durationMs);
  if (!fs.existsSync(path.join(folder, `random-world-${index + 1}.png`))) throw new Error('Missing actual world render');
  return { roster: reveal.line.split('|')[1].slice('enemies='.length).split(','), durationMs };
});
const rows = JSON.parse(execFileSync('/tmp/underwater-screen-ocr', [path.join(folder, '19-run-menu.png')], { encoding: 'utf8' }));
if (!rows.some(row => row.text.trim() === 'Run' && row.y > 400)) throw new Error('REVEAL-01 no usable actual battle controls');
const names = { angler: 'Angler', frilled_shark: 'Frilled Shark', swordfish_duelist: 'Swordfish Duelist' };
const expected = checks.at(-1).roster.map(id => names[id].replaceAll(' ', '')).sort();
const actual = rows.filter(row => row.x > 850 && row.y < 400)
  .map(row => row.text.replaceAll(' ', '').replace(/\d+$/, ''))
  .filter(name => Object.values(names).some(value => value.replaceAll(' ', '') === name)).sort();
if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error('REVEAL-02 real battle HUD differs: ' + JSON.stringify({ actual, expected }));
console.log(JSON.stringify({ randomReveal: 'PASS', checks, actualBattleHUD: actual,
  browserErrors: result.errors, separateWholeFlowFailure: result.failure,
  openingEngagedSeconds: result.engagedSeconds }, null, 2));
