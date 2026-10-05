# Bug catalog: authored whirlpool ownership and physical safety

October5, design-tests. Whirlpool's complete module and its World/Maze setup,
physics and warning consumers were read, alongside Marc's upstream differential.

## Responsibility / public interface

Real Area3D overlaps warn and pull a shared Diver through a timed spiral,
then return it to an authored approach with bounded nonlethal damage. Public
settings describe warning/suction/pull geometry, bypass and reset position;
signals report warning and actual HP lost. SceneTree lifecycle, actor physics,
model visibility and resource state are observable interfaces, not private
helper call expectations.

Load-bearing contracts: grapple/suction owners are exempt; an inactive area
must not control shared actors; whirlpool damage is a scare, never knockout
or resurrection. Ordinary World/maze camera/HUD/save ownership remains singular.
IO includes engine shapes/rays, physics/render/Tween time, random damage and
static root warning state. No player-file IO is necessary for the first test.

Branches: armed/bypass, sphere versus tall cylinder, warning membership,
grapple/suction locks, missing/freed actor, drag versus catch, sink/vanish/reset,
owner exit and battle/menu/inactive state. An Actor cannot be cast safely
before validating a retained reference. Current code has no durable hazard
motion owner or cancellation boundary; that must be investigated explicitly.

| ID | Failure | Impact/plausibility | Test and status |
|---|---|---|---|
| WHIRL-1 | A warning/suction shape crossing a solid wall catches or drags a diver in the adjacent passage. | High: unavoidable damage/reset bypasses physical corridors; both callbacks lack upstream line-of-sight protection. | Fixed: original real World overlap red,24 generated obstructed/open pairs and native Metal repeat. |
| WHIRL-2 | Inactive maze, battle or exclusive reading/menu state still pulls actors or draws root-owned warnings. | High: two input/resource/HUD owners; scene-child areas/Tweens/static labels can outlive owning gameplay. | Original revision reading/reveal reds fixed; six World Inventory, six Battle and actual embedded Inventory/first-L/Save compositions pass. Final browser/campaign acceptance remains separate. |
| WHIRL-3 | Restore, killed Tween or owner/actor teardown leaves a shared model hidden, rolled or suction-locked, or emits freed-reference errors. | High: irreversible gameplay stall; the original Tween was local/untracked and exit only cleared captions. | Captured reds repaired:18 World interruptions,6 active-maze handoffs,24 blocked returns,6 actor deletions and3 external-owner cases. Standalone restore/World save guard and battle/modal ownership acceptance remain separate. |
| WHIRL-4 | Nonlethal damage revives a downed diver or reports negative damage. | High: corrupts combat/resource contract; max(1,hp-damage) unconditionally raises0HP. | Actual0HP→1HP/−1loss red repaired;36 completed overlap/resource/signal cases pass. |
| WHIRL-5 | Hall layout/deep-shaft port blocks all safe lanes or regresses grapple visibility. | High: final route becomes impossible; current hall tuning/layout and deep visuals differ upstream. | Real avoidance/arrival/reset traversal plus physical columns/ceilings, native shaft/floor/ring/anchor view. Pending after first safety red. |
| WHIRL-6 | A normal Corridor4 reset immediately catches the actor again before they can swim away. | High: inevitable idle HP drain/stall; the authored reset is within its outer pull and completion lacked cancellation's reentry grace. | Actual embedded overlap/menu/resume red fixed: settled safe return, actual escape and deliberate reentry pass; final whole-route matrix remains separate. |
| WHIRL-7 | A visual observer mistakes a scaled preview for missing native Inventory foreground. | Medium: false bug/repair claims and unreliable visual acceptance; node-visible/layout alone still cannot prove pixels. | Production-bug claim retracted: both allegedly missing and final PNGs independently contain1128 opaque heading pixels; original-size/cropped inspection confirms readable UI. Render witness characterized. |

## First test / self-critique

WHIRL-1 places a real shared diver at a capsule-clear approach in World. A
real BoxShape wall separates it from a real Whirlpool's suction cylinder;
an independent ray verifies obstruction before checking lock, HP and position.
Removing the wall must then permit a real catch/reset/damage signal. No
synthetic body-enter callback or private LOS helper is called.

Wrong-but-stable always-disabled suction fails the positive leg; missing or
ineffective ray protection fails the negative leg. A callback/helper refactor
preserving real behavior keeps passing. The first case uses measured capsule
clearance, not an illegally overlapping actor or mocked environment. Once it
is green, generate three actors, two blocking orientations, solid StaticBody
versus CSG walls and sphere versus cylinder suction (24 paired cases). A
separate height/deep-hall generator belongs to WHIRL-5.

## Skipped / deferred

- No shape/node-name-only evidence; actual overlaps/rays/input are required.
- Hall deep holes, visual port and gentle lane tuning remain separate required
  acceptance, not claimed by the first LOS test.
- No new narration, enemy kit or ordinary victory recovery in this module.
- Final browser/campaign/audio and desktop packages remain in the full ledger.

## WHIRL-2 exclusive-screen probe

First reproduce actual World suction, then press Escape to open the real
Inventory. Snapshot the caught actor's pose, model visibility and HP/Oxygen
after opening. Wait beyond the original pull/vanish deadline: none may change,
and the root warning must be hidden. Close with Escape; the same catch must
resume, finish exactly once with the authored damage and return, and permit
real swimming. This pins a reading suspension, not an invisible cancellation.
Always-disabled hazards fail the initial catch and resumed completion;
unconditionally canceled motion fails the resumed completion; mutable resources
or a drawing warning fail exclusive ownership. No private hazard callback or
synthetic menu visibility assignment is used. Start with one captured case;
only after fixing it generate three actors, spiral/vanish, and other actual
modal/battle/area handoffs. Layout, autosaves and full campaign remain deferred
to their ledger rows, not counted as coverage from this ownership test.

The next public-signal test enters the actual paused random encounter reveal
and real Battle while caught. It requires cancellation before that new owner
can use the party, no delayed HP/O2 mutation or warning during the battle,
and cleared model/lock at the checked departure. This is not a battle win or
balance proof. A separate real embedded-Maze handoff/Inventory test checks the
same caption/suspension contract in the other exploration owner.

The first-map test uses explicit owned-map/near-chest presentation state,
not a claim of earning that item. Actual L opens the real paused lesson;
Escape dismisses only the lesson, leaving the unpaused map as an exclusive
reader until another L. Both phases must retain caught pose/HP/O2 and hide
the root warning, then one normal completion follows closing the map.
The separate Save case physically swims into the authored Save Point and
presses P while a real local hazard owns the actor. It opens/closes reading
without issuing any save request or writing a player slot.

## WHIRL-3 first interruption probe

WHIRL-7 native self-critique: sample the rendered Inventory title's actual
rectangle after frame_post_draw, not a golden snapshot. At least100 visible
foreground pixels must contrast against this dark reading surface. Blank menu
passes every node-visible/layout check but fails this pixel witness. The title
is independently located by its public text; no internal menu field is used.
Cosmetic reflow/position/font refactors preserve the rendered contrast witness;
an empty or invisible heading cannot masquerade as completed visual evidence.

Use the actual authored World whirlpool and a capsule-clear shared actor.
Wait for a real Area3D catch, remove only the hazard owner mid-spiral, then
require release of lock/model/roll ownership, unchanged HP/Oxygen and real
W swimming. The World and actor survive; no callback is called by the test.
Always-disabled suction fails the precondition. A helper/Tween refactor keeps
passing if the surviving actor remains controllable. After this first red is
fixed, generate all three capsules and spiral/vanish interruption phases,
then test live restore, killed scheduler, inactive area and blocked approaches.

## Evaluation / investigation

Current-main integration, October5:

Five actual reading/reveal probes independently fail on73c2d72. The pending
repair was semantically ported onto17e4705, then artifact-only1dc675c, preserving
deep shafts/down-current particles, global Battle warning suppression, recent
autosaves/rests/scaling and reward-rock guidance. Six Inventory and six Battle
handoff cases, actual embedded Inventory, first-L and Save reading pass on
the combined source. Native Metal captures a readable1128-pixel title witness
and no danger warning behind Inventory. This is local verification, not yet
canonical promotion or whole-route acceptance. Later final-source receipts
must identify their exact commit/pack rather than reuse the earlier green.

October5 ownership follow-up:

- Admitted red comparisons repeat all five public reading/handoff flags against
  a separate unmodified-production a37253e checkout with visible gameplay HUD.
  All exit1 with real findings and no engine/script ERROR, including the first
  dispatched L frame. Final repair source passes13 headless ownership/safety
  commands plus native Metal; four independent preservation scripts pass too.

- Actual Escape/Inventory red: pose advanced to the return, HP7 became5,
  caught count1 and the root danger warning remained visible behind reading.
  Activity ownership now pauses the owned Tween for reading and synchronously
  hides the warning; actual battle/area handoff cancels instead of resuming it.
- Six Inventory cases cover three live capsules × spiral/vanish, followed by
  one exact damage completion, capsule-clear nearby return and real W.
- Six public encounter-signal cases enter the actual paused preview and real
  Battle in both phases. Release happens before preview; the first playable
  menu retains a settled actor/resource baseline and no hazard completion.
  This is not combat/balance acceptance or a real campaign fight win.
- Actual embedded-area handoff and Escape reading caught WHIRL-6: the old
  Corridor4 return was inside the outer pull, so the actor completed once
  then immediately spiraled/vanished again. A broad protective outer-zone
  grace was rejected because it could become an immunity route through the
  obstacle. The authored reset now lies outside pull influence for all party
  capsules; ordinary core grace remains bounded. The returned actor can swim,
  and deliberate reentry still catches. This is not a hall-layout port.
- Observer corrections, not product repairs: cold-title-close fixtures left
  HUD hidden; the active diagnostic fixture now explicitly shows gameplay
  HUD without claiming New Game or writing slots. Exact World reset-marker
  equality ignored valid capsule-clear nearby fallback (up to0.5m for these
  three capsules); the test requires a bounded clear return plus actual swim.
  A Swordfish can act before the first player and deal genuine battle damage;
  observe resource conservation at the first playable menu rather than
  demanding invulnerability from actual combat. The hazard completion signal
  still must remain0 throughout. A duplicate test-key helper/indentation
  parse error was corrected before runtime evidence was accepted.
- Native Metal Inventory capture is inspected for absence of the danger
  caption and accompanies the actual freeze/resume run. The existing dim HUD
  behind Inventory is visible in that capture; this is not final UI polish,
  browser proof, hall safety, stable-save admission or campaign readiness.
- Native adversarial inspection initially mistook scaled previews for missing
  menu foreground. Reopening the saved PNG independently finds1128 opaque
  heading pixels even in the alleged rejected capture, and original-size plus
  cropped inspection visibly confirms the title/tabs. Retract the production
  renderer-regression claim, not merely its supposed cause. The new rendered
  witness still usefully guards real blank UI that visibility/rectangles would
  miss, and repeated Metal plus Compatibility draws pass. The warning canvas
  now follows its label's visibility as explicit ownership, not a renderer fix.

Final-source rerun: nine commands exit0 and logs contain no engine/script
ERROR, infinite loop or FINDING. The complete actor/source hash receipt and
red/rejected-observer logs are in docs/evidence/whirlpool-motion-safety-oct5.
The current-route, grapple and shared-ramp gates also pass. This is bounded
motion/damage acceptance, not battle/menu warning or full campaign readiness.

- WHIRL-3 owner-removal red is now reproduced and repaired: the actual World
  hazard caught a living shared diver; freeing only that hazard left the
  surviving actor locked and real W made no progress. Tracked motion cleanup
  now returns it to its physically checked departure, keeps7HP/0O2 and permits
  actual W swimming. This first green is not live-save/deactivation acceptance.
- Next generated interruption family: three actors × spiral/vanish × owner
  removal/killed SceneTree scheduler/validated JSON live checkpoint restore.
  Actual overlap must first own the actor; all cases require visible model,
  restored rotation/roll, unchanged resources (or exactly restored save values),
  clear capsule and real W after interruption. Restore must remain stable
  beyond the original timer deadline. Killing engine timers tests interruption,
  not private callback calls or expectations about implementation dictionaries.
  Always-disabled suction fails catch; late callbacks/locks fail conservation.
- Rejected observer: exact whole model rotation after75 resumed frames falsely
  blamed cleanup for model X returning to0. Diver._animate owns that lean on
  normal swimming. The surviving yaw and hazard-owned Z roll are checked
  separately; this is not a production fix or relaxed pose/visibility gate.
- Next live-area probe: three shared actors × spiral/vanish at the actual
  authored Corridor4 whirlpool, active through World's normal ownership
  handoff. Disabling/re-enabling Maze must relinquish its lock/model and
  resources, refuse a stable checkpoint while caught, and allow actual swim
  on resumption. This is different from the already-green fresh inactive
  Area overlap. It must catch first and bypass/current preconditions must
  be checked rather than disabled to manufacture a test.
- Blocked departure probe: actual overlap, then introduce a real solid CSG
  box around the old departure before freeing the hazard. Require release
  outside the box's independently known solid volume and a clear capsule;
  resumed W must be possible without any HP/O2 charge. CSG triangle-only
  queries can return empty for a fully buried actor, so a surface-query-only
  green cannot prove this negative path. After first red, generate three
  capsules × Static/CSG ×0/90° yaw × spiral/vanish.
- Rotated-block observer correction: W pointed straight into the newly
  introduced wall at the north landing. A successful release is not a
  noclip contract. The generator now selects a real WASD direction using
  independent capsule cast_motion clearance, then requires actual swimming.
  No-clear-direction remains a failure, not a skipped movement assertion.
- WHIRL-4 damage-family probe: three live capsules × HP0/1/2/7 × authored
  damage0/2/10 through actual overlaps and completion signals. Independent
  expected loss is bounded by damage and living HP above1; a downed actor
  remains0 and reports0, not negative loss. Require an actual completion,
  unlocked/visible clear reset and unchanged0O2. Always-disabled suction
  fails completion; formula-only/helper tests cannot establish this contract.
- Final lifetime/non-stealing probe: actual new Diver nodes with all three
  delivered rigs leave during spiral/vanish, and new actors then complete the
  same hazard normally (not an always-disabled cleanup). Separately overlap
  the shared party's three actors with preexisting suction locks and hidden
  models; the hazard must neither claim nor clear those external owners.
  This verifies hazard lifetime, not support for deleting World party slots.
- This probe caught two genuine extra failures: captured Node lambdas emit
  engine ERROR before the callback's own validity guard after actor deletion;
  callbacks now resolve a WeakRef. Also, freshly created Areas can report an
  overlap from a teleported actor's old physical pose and catch it20m away.
  Warning/suction entry now verifies the current capsule/zone geometry. The
  latter was not an external-lock theft: the externally locked actor itself
  remained untouched, but the previous actor was wrongly captured remotely.
- LOS preservation's40-frame positive leg observed damage-flash blinking
  rather than settled visibility. The .4s pull/.1s vanish plus .64s flash
  require a longer observation;90 physics frames preserve the same exact
  reset/HP/O2/catch and visibility assertions after the authored flash ends.
- Preservation gate observer: current-route chest waypoint allowed .45m
  early stopping at1.8m nominal horizontal distance. The tall diver is raised
  to2.956m by the real plinth; combined3D distance can exceed CHEST_REACH2.4.
  The route now approaches to1.4m nominal horizontal distance and prints the
  actual3D distance before E. It still physically earns the map and returns;
  no interaction-radius change, map grant or removed assertion is permitted.

- WHIRL-1 caught at7ced43e: an intervening real wall did not prevent suction;
  the diver locked, lost2HP and reset from228.8 to226. LOS protection now
  leaves its pose/HP/lock unchanged. Removing that same wall permits actual
  catch/reset/release and2HP damage without spending Oxygen.
- 24 generated paired cases pass with each capsule, both wall types, both
  suction shapes and both wall orientations. Independent physical oracles
  require a clear approach/reset and a real intervening wall, then clear
  open sightline. Native Metal repeats the captured case. Existing real
  current-route and first-person grapple gates pass.
- Rejected fixture findings are retained, not presented as product repairs:
  rotating the reset direction put it in a lab ramp side rail; relocation to
  another alleged open-water area crossed a real World boundary. The final
  generator stays in validated water and uses the independently clear normal
  approach as reset. A still-blocked positive sightline is now a fixture
  failure, never an excuse to disable the production LOS check.
- LOS receipts alone never admitted WHIRL-2/3/4/5. Later ownership/damage
  probes below admit only their stated runtime cases. Battle/modal/root
  caption ownership, hall layout/deep shafts, browser/full campaign and
  final platform acceptance remain open.
- Next ownership probe: the actual inactive authored Corridor4 hazard does
  not catch a parked shared Musashi while World remains the selected owner.
  This retracts the assumption that this fresh disabled-subtree overlap
  necessarily fires a capture callback. It does not cover deactivation during
  an existing spiral, battle/menu warning lifetime or interrupted teardown;
  probe those next rather than adding a redundant fresh-inactive fix.
