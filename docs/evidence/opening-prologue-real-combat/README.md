# Cordys is overwhelming, not fake combat

Runtime candidate: `953b92f1b93a50998954dabdec8ca06a4e6c384d`, based on PR #96
`27a5b5253256a26733f8a320c3c6b4f97c64dece`.

Exact export: 93,306,940 bytes; SHA-256
`8327d0f440281d847485b4f559cad62a8fcbb36e1c4a55b195f997083f1baba2`.
Unauthenticated immutable deployment:
https://underwatergame-lxdvfaf8x-immortaldemongods-projects.vercel.app/

Diagnosis: there was no fixed-one-damage player clamp. Maxilani's actual
starting STR is 1; Electric Touch, Stabbing and Knee Combo all use that stat.
Axe Kick uses STR + ACC and deals 4. The actual defects were the shared
Angler/Cordys move-accuracy rewrite and a direct party-HP-zero finisher.

Repaired: Cordys exposes normal choices (including Flash Blast), without
modified accuracy. Normal damage, status, self-cost and Oxygen resolution
remain owned by the existing combat system. Opening-only HP 1,000 / STR 80 /
ACC 30 make Poison Breath overwhelming through real DEF/EVA mitigation.
The ordinary fresh party receives 80/78/76 damage. A 200-HP diagnostic party
actually survives at 120/122/124 HP. Bleed ticks on Cordys's turn, Blindness
reduces his effective combat stats, and an accuracy tie can genuinely miss.
The normal 1.6-second result-reading delay replaces the old 0.55-second rush.

The attack's cinematic choreography and special recovery stay intentional;
campaign boss stats, rewards and the later game are not retuned.

Red evidence is retained for the forced-death bug and a duplicate impact cue
discovered while switching to normal feedback. One breath now owns one audible
impact instead of the explicit old cue plus simultaneous per-target cues.

Native verification: nine independent hand-computed button witnesses plus six
seeded ordinary-resolver differential cases; three real-stat survivors; actual
later enemy-caused deaths/Restart/title Load; voluntary training Skip then
death; checkpoint write failure/Retry; ordinary combat rules, Quick Read, SFX,
Angler isolation and rendered 720×480 moving-pose framing. Logs distinguish
the earlier `56f5123` intermediate candidate from final `953b92f`.

Final browser evidence and stable-alias verification are recorded after their
complete normal-entry runs below. This focused repair is not the larger
opening plan's final zero-defect visual/audio audit or a blind comprehension
test; those remain pending. Public main is not replaced by this candidate.

## Final exported results

- Chromium/ANGLE Metal, 1280×720, ordinary New Game and complete movies, real
  mouse Axe Kick: damage 4, Cordys HP 996, retaliation 80/78/76. Engaged opening
  89.010 seconds; total 106.839 includes explicitly deliberate idle/look.
  No idle encounter; actual W-to-Angler interval 4.074 seconds.
- Real completed checkpoint survives cold Load, two subsequent enemy-caused
  ordinary deaths, Restart and title Load. Five `complete` observations, no
  replayed opening phases and no browser/runtime errors.
- Separate fresh browser context deliberately aborts the completed IndexedDB
  save. Real Retry succeeds; cold Load preserves completion. Total 107.461
  seconds includes the deliberate fault/retry. Only the injected transaction
  error is exempt; no unexpected errors are present.
- Inspected `browser-axe-kick-4.png`: visible 4-damage result, 996/1,000 HP,
  correct Axe Kick EVA self-cost. Native logs independently cover Bleed,
  Blindness, normal accuracy failures, and stat changes.
- Same stable alias updated, not a replacement review URL:
  https://underwatergame-opening-prologue-review.vercel.app/
