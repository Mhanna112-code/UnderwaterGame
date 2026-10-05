# Radius-based Maze special sites

October 5, 2026. Frozen #97 4ec6598 adds seven invisible special sites:
one authored secret-item-room point, three spaced east of Break Rock and three
past its outgoing draft. PR100 had none before this port. Later bba8b80 alters geometry
and map lesson copy; that separate intake is not silently admitted here.

## Module understanding

Maze owns active actor/camera/input, local forced strong-room policy and shared
inventory/resources. Battle's special/guardian flags already dispatch the chosen
actor's swap/grapple/shockwave minigame. SpecialEncounterPrompt owns a paused
confirmation/carousel; its public chosen/cancel signals hand control back.
The campaign snapshot/validator/coordinate adapter are the durable boundary.
Minimap discovers only returned POIs, so hidden sites must not be returned
until Sonar discovers them and completed sites must disappear from live POIs.

Public interfaces to test: real Q/R/Tab/swimming and prompt buttons/signals,
actual Battle party/minigame flags, observable inventory/resources/map POIs,
campaign snapshot/JSON decode/restore and activation. IO: randomized placement,
physics clearance/rays, real cooldown/minigame timing, optional JSON fields;
no player-file writes in the focused harness.

Branches: setup before CSG collision exists; new versus legacy/rebased saves;
Sonar/non-Sonar/parked Sonar; R off/on while inside; prompt cancel/re-entry;
menus/chests/rotations/aim/battle/area ownership; living versus downed choice;
win/loss/flee; consumed versus available sites; collision occlusion/height.
Magic contracts: fixed item/enemy IDs from the authored seven entries;
special encounter source is distinct from ordinary/puppet/Cordys/lab bosses.

| ID | Bug and player impact | Independent oracle | Status |
|---|---|---|---|
| SITE-1 | Missing radius sites give no discoverable/earnable rewards. High: authored exploration content lost. | Actual Q at authored point yields a special POI, then approach yields the chosen-diver prompt even with R off; seven independent enemy/item expectations. | captured missing-content red; ported; R decoupled by FR-2 |
| SITE-2 | Inactive area, wrong actor, R-off, modal or through-wall/height proximity steals input or starts a fight. High: duplicate/unavoidable combat. | Actual owner/toggle inputs and physical wall/height fixtures; real paused shared lesson followed by component frame entry; valid re-entry. Separate Sonar gate covers parked/wrong actors. | paused-frame overlap caught and fixed; other paths characterized |
| SITE-3 | Cancel/loss retriggers every frame or win grants again on re-entry/load. High: trapped prompts/infinite items. | Real prompt cancel, physical exit/re-entry, lifecycle outcomes and all seven consumed-site re-entry/JSON restores. | characterized |
| SITE-4 | Chosen actor is replaced, downed selection crashes, or result resets other party resources. High: shared-state corruption. | All three chosen living/downed cases; actual Battle contains only that live actor/resource; inventory/resources independent checks after win/loss/flee. | characterized |
| SITE-5 | Random positions/discovery/consumption move or reset on cold/rebased load. High: farming or missing saved content. | 128 reveal masks × three origins, full checkpoint JSON, malformed/legacy cases, compare exact flags/items/IDs and serialized positions without mutation. | characterized |
| SITE-6 | Colliding/omitted placement or uninitialized snapshot silently removes sites. Medium/high: unreachable rewards or unstable save. | Twelve fresh/cold layouts and 252 actual capsule approaches; stable-save refusal before initialization, persisted positions override generation. | characterized; invalid initial approach retracted |
| SITE-7 | Fixed-width confirmation/carousel leaves buttons outside a narrow viewport or hidden video keeps decoding. High/medium: cannot choose/cancel, needless background load. | Actual paused prompt/Enter/Back/cancel at three viewport sizes; visible controls within viewport; close stops its decoder; inspected native captures. | captured layout red; responsive repair |

Tests must not call private trigger/reward handlers or use node-existence checks
as gameplay proof. Public finished signals may pin lifecycle outcomes, but are
not combat/minigame victory evidence. Separate existing minigame dispatch gates
and ordinary-route playthroughs remain required.

## Skipped

- No replacement of laboratory blockers, puppet waves or Cordys.
- No blanket stats/boss scaling or recovery policy port in this batch.
- No final map-lesson narration rewrite; bba8b80 copy stays a visible later intake.
- Full ordinary earned-resource route and hosted/browser acceptance remain on
  the completion ledger. Focused positions and outcomes are fixtures.

## Evaluation

- Caught: actual Q found no authored special POI on 3d60e1d; original fixed
  widths put buttons outside 720×480/360×640; corrected typed lesson probe
  showed a radius chooser stacking after a shared lesson paused mid-frame.
  Repairs: authored site component, responsive chooser, explicit paused-frame guard.
- Characterized: R on/off and once-per-visit, inactive/menu/wall/height owners,
  all three live chosen actors/downed selection, twelve lifecycle cases, seven
  independent item/enemy pairs and consumed re-entry, 384 rebased full-checkpoint
  JSON cases, ten invalid fields, legacy reset, twelve layouts/252 approaches.
- Lifecycle tests emit public Battle results; they do not defeat enemies or
  complete minigames. Existing dispatch/grapple integration gates were rerun.
  Puppet preservation separately plays two real waves with a disclosed level-5
  kit/combat seed; it does NOT count toward ordinary earned-resource balance.
- Rejected observers, not product repairs: an untyped Array could not call the
  typed lesson API (script-error run printed clean); closing a lesson while R
  remained enabled raced valid native radius entry; initial capsule centre left
  part of its body outside the promised 2.2m clearance. Test fixtures corrected.
- Cold comparisons: raw Array equality and float32 Vector3 comparisons at JSON
  rounding midpoints produced false differences. The final oracle compares all
  IDs/items/enemies/flags exactly and each serialized double within 1e-8; no
  production checkpoint precision/placement code was changed for that finding.
- Seven-item matrix initially selected the Bucky deliberately left downed by
  the previous test; the product correctly rejected her. Matrix now chooses the
  living approaching actor. Downed rejection remains an independent assertion.
- Puppet test expected the retired scene-changing entrance; now actual W swim
  crosses the physical shared-World ramp. Its concurrent cold-restoration fixture
  supplies the saved layout before asynchronous placement, avoiding artificial
  collisions with another live World. No production geometry changes for these.
- Adversarial cross-feature probe: the lesson-mid-frame ownership bug above.
  Independent controls/strong-room, map, chest, Sonar, queue, shared ramp and
  cold checkpoint preservation pass. Full browser/routes/exports remain pending.
