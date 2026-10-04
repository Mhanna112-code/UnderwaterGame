# Escape encounter-toggle cue

## Contract

After a real successful Run returns to exploration, show the current R encounter
setting and a brief recovery hint. Pulse gently for **at most three seconds**;
hide even if the player never changes the setting. No forced toggle, heal, pause,
save, combat-rule change, or permanent flashing. If already Off, show a steady
confirmation, not an invitation to turn encounters back on.

## Boundary and callers

Battle's real Run button resolves its existing 60% escape roll. Only `fled`
reaches World. Failed Run remains in combat and may incur an enemy attack.
World's existing R input owns the setting; the cue only observes it. New battles,
title/load, defeat and save-point recovery retire any old cue. Informational HUD
controls must ignore mouse input, including while special minigames are active.

## Bug catalog / cheapest effective gates

| ID | Defect | Observable check |
| --- | --- | --- |
| ESC-001 | No usable teaching cue after escape | Real World encounter event, real enabled Run button, successful RNG fixture; visible R setting on returning to exploration |
| ESC-002 | Cue flashes indefinitely without pressing R | Leave On untouched; visible pulse changes while readable, then hidden after three seconds |
| ESC-003 | Hint changes encounters or heals/persists the party | Same On state and HP/O2 immediately after escape; real R changes Off and real subsequent encounter event is ignored |
| ESC-004 | Failed escape/win/tutorial exit teaches the wrong event | Actual failed Run remains combat with no cue; normal result/lifecycle coverage; no tutorial/prologue hook |
| ESC-005 | Off setting invites turning encounters On, or keeps pulsing | Update via real R; observe Off and steady contrast, same original deadline; repeat escape with Off fixture |
| ESC-006 | Old cue leaks into combat/menu/load or blocks mouse | Real next encounter dismisses; Load restores state without cue; every cue Control ignores pointer input |
| ESC-007 | Cue overlaps controls/minimap, clips or hides text | Render real World at 1280x720 and 720x480; inspect screenshots and bounds; do not alter existing world HUD |

## Execution order

One red ESC-001 integration witness, implementation, then expiry/R/failure and
lifecycle checks. Seed fixtures choose Run probability only, never inject a
`fled` result. A completed checkpoint is an explicit setup fixture, not proof of
the opening itself. Existing opening, local-guidance and checkpoint gates guard
unrelated behavior. Native rendered evidence plus hosted real-input escape
verification if available; report any unverified path honestly.

## Limits / self-critique

This cue does not guarantee immunity to authored bosses, hazards or Oxygen loss.
It does not direct the route to a specific save point or retune encounter rates.
Tests must not call the private result handler to manufacture acceptance proof.
No base combat balance changes. No player save files may be overwritten.
