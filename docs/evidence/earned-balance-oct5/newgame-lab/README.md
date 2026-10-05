# Genuine New Game laboratory probes — October 5

These are native exploratory **lab-first slices**, not a whole-campaign pass,
browser durability proof, or a success-rate matrix. Failed probes are retained.
The production runtime is unchanged from6b8ea07 (main1df697a during these runs).
Canonical Web remains the matching0c947735 pack; no runtime was deployed here.

## What the observer actually does

`verify/earned_campaign_journey.gd` constructs normal World without skip flags,
uses TitleScreen's public chosen-slot New Game signal for disposable slot918431,
waits for the real opening film/initial Angler/Cordys defeat/recovery, swims
with actual W/mouse inputs and retains ordinary encounters. It uses visible
enabled Attack/move/target/reading controls and actual Battle results. No
position, progression, victory, XP, spells, healing or party resources are
supplied. Native SaveManager/manual/auto/pending paths refuse preexisting files
or directories; only this run's fixture is cleaned up. Human save slots are
not used. A high-numbered chosen-slot signal is not a browser slot-picker test.

Time scale4 accelerates native timing; **no X dodge input is supplied**. The
opening's scripted defeat/recovery and later earned XP level-up recovery are
production behavior. Ordinary victory never receives the retired heal.

Production RNG is seeded, but video/frame timing changes shared consumption.
The logged seed is not a guarantee of an identical roster. Actual enemy
rosters, choices and carried party resources are recorded. Early development
logs precede the later action/cold-load observer additions; they are not
represented as executions of an identical final verifier revision.

## Completed baseline receipts

| Receipt | Policy / encounters / recovery | Actual terminal outcome | Exit |
|---|---|---|---|
| `skilled-direct-64000.log` | Prototype skilled blind-first; encounters On; no rest | Lab cleared,8 fight owners/42 moves, earned level3. Musashi entered Tethys downed; Scuba/Bucky won. No cold-load check in this earlier observer. |0|
| `casual-direct-64001.log` | Casual base attacks; encounters On; no rest | Lab cleared,8 fights/41 moves, earned level3. No cold-load check in this earlier observer. |0|
| `skilled-direct-64002-loss.log` | Same prototype skilled; On; no rest | Sword Slayer killed Scuba; Tethys defeated the remaining party.7 fights/33 moves. Cold-load check not reached. |1|
| `skilled-existing-rest-64002-loss.log` | Prototype skilled; On throughout; conditional shallow save-point return | Sword Slayer left Scuba/Musashi down and Bucky7HP. A real Swordfish killed Bucky on the return before rest contact.7 fights/28 moves. |1|
| `casual-direct-64003-loss.log` | Casual; On; no rest | Lab entry Scuba2HP/Musashi0HP/Bucky10HP; Tethys defeated the party.8 fights/35 moves. |1|
| `skilled-64004-earned-cold-load-no-detour.log` | Prototype skilled; On; conditional safe-return branch **not taken** |7 fights/34 moves; lab win and native cold Title Load conserve earned HP/XP/level/spells, independent Cordys state and exact manual bytes; no repeated payoff/fight. |0|
| `skilled-safe-rest-64005-earned-cold-load.log` | Prototype skilled; scheduled shallow rest; actual R/Q Off during round trip, restored before lab |8 fights/39 moves; actual rest contact restores all three HP/O2, defeated guards survive return; actual Tethys win and native cold Load conserve earned level3/XP60/kit/manual bytes with no replay. |0|

These samples show a real attrition risk. **Do not turn this table into a
formal success rate:** observer versions, seeds/rosters and recovery policies
differ, and the full campaign is not exercised. In particular,64004 does not
prove recovery traversal or the encounter-toggle branch merely because its
CLI requested that conditional policy.

## Observer failures, excluded from game/balance conclusions

- `observer-parse-failure.log`: multiline GDScript condition failed to parse;
  Godot nevertheless returned0. Engine/script errors invalidate any exit.
- `observer-controls-failure.log`: Continued modal was freed; the observer
  revisited it. It also looked for a named target rather than `All enemies`
  for Flash Blast. Both are repaired observer defects.
- `observer-approach-failure.log`: the physical planner targeted the center of
  Bomb Bot's closed pressure field. Corrected to actual approach coordinates
  inside the normal trigger volume, with collision/guardian/trigger retained.
- `observer-rest-sonar-cost-64005.log`: scheduled rest contact restored HP,
  but a strict Oxygen-max assertion sampled97 after normal Sonar billed3.
  This is not proof of partial game recovery. The explicit rest observer now
  uses actual Q to suspend Sonar for the round trip and restores the prior
  preference before the lab; the full-contact resource assertion stays exact.

## Policies and outstanding acceptance

Casual normally uses the first damaging base attack, occasionally another
affordable base attack. Prototype skilled prioritizes Flash Blast when
Blindness is expiring, earned Swift Strike/Precise Jab afterward, Guard Bash
and an actually earned healing spell if available. These are explicit
programmed choices, **not calibrated human skill measurements**. A more
tactical earned-offense policy and documented non-perfect QTE policy deserve
evaluation; changing one must receive a new label rather than hide old losses.

`existing-save-point` physically returns when party HP/O2 is low. The separate
`existing-save-point-safe-return` probe schedules a pre-boss rest visit and
uses real R inputs to disable encounters during that round trip, then restores
On before the lab. Both rest policies use Q to suspend Sonar drain during
travel and restore its prior preference afterward. These are existing player
risk-management options, not an
always-On balance repair. Neither calls `fill()` or a private heal/save/restore
handler. The scheduled64005 receipt proves actual contact and return, not an
always-On win. The final observer used for this receipt hashes to
`fc4641621525462e657457d955f3bc64e11f764a572cc3eb233f2888148c57d9`;
the raw receipt hashes to
`618bc29672cf0f00df8e9e5af7ca15ff3efadc882a84e4820ab63fb4aef00e8b`.
The source snapshot is retained as `observer-scheduled-rest.gd.txt`.

`unsupported-policy.log` is a negative CLI probe: unsupported policy exits1
before World creation or owned-slot writes, with a named observer finding and
no engine/script error. It is not a game loss or a balance sample.

Still required: whole lab-first and maze-first campaigns, ability/anchor path,
maze map/chest/puzzles/rests/relic/puppets/Cordys, real save/loss/return routes,
at least eight predetermined trials per casual/skilled route with unchanged
casual≥50%/skilled≥80% floors, current browser/Bomb Bot/audio/presentation and
matching native delivery. This tool is exploratory and not yet part of the
full runner: do not make a stochastic single-run win a blanket release gate.

The final Tethys opening/Cordys introduction relocation remains unchanged,
last and specifically review-gated by Miguel.
