# Individual Cordys defeats, with player turns preserved

Gameplay source: `ff078ba2c8e7a01e391cfbb72b10a5f2802a38a3`.
Browser harness additionally admits Bucky's ordinary 9–11 damage variance.

The original Poison Breath changed all three divers' HP in one frame. The first
draft replaced that with three individual hits, but automatically chained them
after one player choice. The user clarified that player attacks must remain
between the deaths. Both failing reproductions are retained: `aoe-red.log` and
`turns-red.log`. The automatic-chain draft was never published to the review URL.

Current fresh-party flow:

1. Maxilani chooses a normal move; Cordys uses **Octo Stab** on Maxilani.
2. Musashi receives the real move/target menu; **Head Bash** targets Musashi.
3. Bucky receives the real move/target menu; **Electric Shooting** targets Bucky.

Each boss hit uses the shared ACC/EVA and STR/DEF resolver. Opening STR80 and
ACC30 yield 80/78/76 damage against the fresh party. No AoE poison, forced HP-zero,
damage clamp or guaranteed-hit override. Status ticks occur once per actual boss
turn. High-HP, high-EVA and high-DEF witnesses genuinely survive and can act again.
Waiting at the returned menu does not cause the next boss attack. The final
special defeat emits only after no living diver remains. Existing recovery,
optional training, checkpoint completion and normal game remain unchanged.

## Verification and visual repairs

- `turns-green.log`, `wide.log`, `narrow.log`: actual Attack/move/target controls,
  per-frame single-target HP changes, living counts 2/1/0, three distinct imported
  clips, correct NOW actor, no controls during the enemy response, three player
  choices and one sound per strike. Held menus retain HP until another action.
- `rules.log`: three genuine 200-HP survivors, untouched non-target HP, real
  ACC/EVA miss and DEF100 zero-damage witnesses, plus the existing 15-case normal
  player-rule differential matrix. No fake battle results or HP-zero writes.
- `actor.log`, `framing-wide.log`, `framing-narrow.log`: admitted clips deform the
  real mesh; bounds use the matching FBX SHA; live-skin projections sample all
  three target facings at wide/narrow resolutions.
- The first combined action hull made Cordys miniature. The initial 19 temporal
  samples also missed Octo Stab's fast excursion. The mechanical derivative now
  samples 61 points per clip. Each attack gets a fixed fitted view, then the
  next player turn returns to its readable view; there is no per-frame zoom.
- `individual-turns.gif` and narrow stills: actual native viewport recordings,
  inspected with no new clipping/text/turn-control defect observed in this
  bounded response sequence. The GIF is sampled playback; logs establish time.
- `journey.log`, `real-recovery.log`, `state.log`: full native combat handoff,
  independent opening/training milestones and cold Load. The first journey's
  ordinary-loss boundary is synthetic; `real-recovery.log` separately drives
  actual enemy damage to later Game Over, Restart and title Load.
- Tests use an isolated custom user directory and owned slot. The running player
  Godot process and player saves are not touched.

## Hosted artifact

Candidate `dpl_HLde6GiW2TgP7zsePDRcmGjPYVLe` is READY:
https://underwatergame-nl6ozcoml-immortaldemongods-projects.vercel.app/

PCK: 104,602,252 bytes. SHA-256:
`8bdeb24e859b57c36bd0949d6cf2dfe42aa68a4b46c32ddef9b530de5feb6d6c`.
Unauthenticated hosted download matches the clean export. No test-user override
ships. Candidate was deployed with `--skip-domain`; public main is untouched.

`browser-first-accounting/` preserves the first actual normal-entry Chromium/
Metal run: full movies, real mouse clicks from all three divers, individual real
damage, complete recovery and cold title Load, zero script/browser errors. It
reported 120.740 seconds, but incorrectly included the two explicit one-second
no-input probes in its engaged budget. The timing gate stayed failing; its
result was not rewritten. The harness now separately measures those deliberate
waits, just as it measures its existing idle/look probe. Total wall time remains
reported; no render time, movie time or normal input time is deducted.

The repeated normal-entry run (`browser/`) passed with **119.376 seconds total**,
**117.371 seconds engaged**, and 2.005 seconds explicitly held at returned player
menus. The total also fits under two minutes without needing those deductions.
All three mouse-driven player attacks landed, each followed by exactly one real
boss hit and living counts 2/1/0. Cold title Load restored complete normal play,
Sonar/encounters On, training incomplete, without replay. Zero browser/script
errors. Native actual later enemy defeats/Restart/title Load also pass.

Published only to the existing stable review URL:
https://underwatergame-opening-prologue-review.vercel.app/
Alias/provenance JSON records the candidate and unchanged public main.

## Limits

This is verification of the changed Cordys encounter, not final whole-game
acceptance, new campaign boss balancing or proof of a particular emotional
reaction. Existing OPEN-032/046 world-label/save-crystal occlusions remain outside
this change. No movies, ordinary combat rules, player volume or subsequent route
were shortened or redesigned to fit a test. Local commits are not a claim of a
GitHub push or main merge.
