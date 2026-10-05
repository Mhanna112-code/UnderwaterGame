# Earned map, discovery and first-open lesson

October 5, 2026. Focused continuation of PR #100, based on `703fa50`.
This is not full integration or release acceptance.

The map now has a discovered-only external legend, visited-boss icons, boxed
room labels and a first-open navigation lesson. Geometry is projected before
the lesson pauses gameplay. Map/help/legend and text-only lesson respond to
viewport resize while paused. Optional saved lesson history accepts old saves.

## Accepted source checks

- Native `maze_map_discovery`: 12 paused sizes, 64 public discovery subsets,
  new/legacy JSON and five invalid lesson-history values; inspected wide,
  short, narrow and paused-lesson captures in `native/`.
- `marc_earned_map --world-acquisition`: real ramp entry, same World/three
  actors, capsule/current-valid swimming, real E acquisition and L lesson,
  return to entry; no map grant. Near-ramp starting fixture, not New Game.
- `marc_earned_map --maze-playtest`: actual diagnostic flag, unearned L
  rejection, real chest route and acquisition/return. Diagnostic entry, not
  an ordinary campaign completion proof.
- `marc_earned_map_persistence`: isolated-slot actual Save/cold Title Load and
  legacy load preserve map and separate door keys/relics under embedded World.
- Coordinate frame and outgoing/return draft regressions remain clean.
- Authored Grapple video regression and narrow-text-to-desktop-video public
  popup transition pass. The file named `media-transition-red` passed on its
  first run: it characterizes behavior, not a captured defect.

## Browser observer baseline—not this batch's export

`observer-baseline/receipt.json` identifies the unchanged `703fa50` pack:
93,260,780 bytes, SHA-256
`56a0b666bdd9f59ca2a34cb2af402fea01eda3498157abb82274c0314dea8b95`.
Real browser swimming/E/L now earns the map. This proves the observer's route,
not the new legend/intro. Initial timed steering and an unnecessary rise did
not reach the interaction correctly; these are excluded as product defects.
The observer now requires the real E prompt and the fresh batch requires
first-open lesson and wide/short/narrow browser evidence separately.

## Current batch browser acceptance

`browser/receipt.json` identifies runtime `2054d11`, 93,267,452-byte PCK,
SHA-256 `2030c084ebfb77242c93e899b468cbdd5f51dd34e192800c54cde2569bf49a1a`.
Chromium 151 / macOS M1 / Metal completes the identified pack request, ordinary
title, actual swimming to the E prompt, acquisition, first earned L lesson,
paused lesson resizing, discovered-only legend and repeat-open behavior.
1280x720, 720x480 and 360x640 screenshots inspected. No console script errors.
Narrow prose wraps “closes the map” over two OCR lines; the observer accepts
whitespace without weakening the semantic assertion. The initial OCR rejection
is not a clipped UI or product defect. This exact export remains local;
public review alias and final same-source platform exports are still pending.

Captured genuine reds: absent legend/visited-boss POI and narrow text lesson
clipping. Full catalog: `verify/maze_map_discovery.bug-catalog.md`.

Full campaign, remaining maze hazards/controls/Sonar/special-site admission,
browser durability, final exports and merge readiness remain open.
