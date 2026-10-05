# Maze grapple aim lifecycle

October 5, 2026. Authored #97 c943218/4ec6598 gives Maze grapple the same
first-person aim/fire/cancel sequence as World. Current PR100 fires on F.

## Module understanding

MazeLevel owns the active party, camera, input dispatch, map, checkpoint and
chest/cutscene locks. Diver owns actual grapple collision, free environmental
ability eligibility, cooldown and anchor-versus-item reeling. TargetSelector
owns Swap and must not become an aim owner simultaneously. Authored aim hides
the whole Diver, but the shared embedded party requires restoring only the
model it hid on cancel, handoff, battle or scene teardown. Existing World
already uses set_model_visible and distance-aware masked reticle raycasts.

Public boundaries: real F/Tab/E/P/L/Escape/mouse input; camera/visible model/
HUD/reticle, physical anchor traversal or item arrival; public activation and
snapshot eligibility. IO is no player files; time is real cooldown/physics.
Branches: fresh aim, cancel, fire hit/miss, cooldown, modal/map/chest/rotation/
battle/inactive handoff, shared versus standalone actors, ray masks/occlusion.
Types: Diver ability_id grapple; collision mask includes environment plus
lightweight layer-5 targets; Items implement reel_in_to instead of traversal.

| ID | Failure / impact | Oracle | Status |
|---|---|---|---|
| AIM-1 | F immediately fires rather than entering readable first-person aim. High: lost authored control and unexpected movement/cooldown. | Actual Tab/F at zero O2 with real anchor; model hidden, no traversal/cooldown, camera at eye facing intended ray, fire/cancel copy visible. | caught against 440285a; repaired |
| AIM-2 | Escape/right cancel spends cooldown, opens a second owner or leaves the shared actor invisible. High: stuck input/party presentation. | Actual cancel paths plus public deactivate/reactivate and surviving-actor teardown, unchanged HP/O2/ability readiness and visible model. | nine generated cancel cases and surviving actor pass headless/native |
| AIM-3 | Tab/E/P/L/F changes owner or saves unstable aim. High: shot comes from wrong diver, duplicate actions, hidden HUD. | Seven real blocked keys while aiming, stable snapshot refusal, actual contact P after cancel, subsequent earned-map modal and public JSON restore. | characterized after port; passes headless/native |
| AIM-4 | Reticle ignores layer-5 items or walls and shows a hit that actual fire cannot make. Medium: misleading feedback/failed progression. | Real item/anchor/wall fixtures, visible reticle at independently known target, real left-click travel/reel and cooldown. | characterized after port; passes headless/native |
| AIM-5 | Save-stability refusal also prevents physical ownership handoff while aiming, trapping the shared diver outside the maze boundary. High: cannot swim back to World. | Real Tab/F then actual first-person ramp swimming in embedded_maze; same actor restored and World resumes once, with no save/data reset. | caught during port reconciliation; repaired physical run passes |
| AIM-6 | A TorusMesh oriented with -Z look_at renders edge-on as a dash, not a readable aiming ring. Medium: valid target indicator unclear. | Native inspection plus independent local-Y normal versus eye direction assertion, no helper invocation. | caught during native port verification; repaired native ring inspected |

Semantic visibility/movement/resource oracles do not call private aim handlers
or assert their names. Far open-water fixtures isolate input/collision from
maze navigation; no normal progression or hosted claim. More than five owner/
cancel combinations require generated cases, not one happy-path screenshot.

## Skipped

- No World aim rewrite or new camera owner/autoload.
- No Oxygen charge for environmental grapple and no boss/stat changes.
- Full real-maze required-anchor route/browser save/campaign checks remain on
  the completion ledger; fixture traversal is not a substitute.

## Evaluation

- Caught: AIM-1 against unported 440285a; AIM-5 and AIM-6 during source
  reconciliation. A clean standalone aim test was insufficient to catch the
  physical World handoff. Its independent ramp test failed at x=256.25 with
  the correct Musashi owner established; repaired run reaches x=224.8353.
- Characterized after repair: cancellation/resource/cooldown, seven competing
  input keys, actual anchor travel versus layer-5 item reel, wall occlusion,
  checkpoint contact, canceled aim permitting map/save, public restore and
  surviving shared actor on subtree teardown. Nine generated cases combine
  three Oxygen values with three cancel paths.
- The AIM-6 red prints `AIM-4 torus reticle...` because the orientation oracle
  accompanies ray-preview checks; the catalog separates the rendered defect.
- Rejected observers are not product bugs: initial Save-menu lookup assumed
  a nonexistent node name; a first reticle assertion had untyped Vector3
  inference; the first physical ownership observation resumed before World
  physics. A native verifier quit before restored meshes completed render
  cleanup. These runs are not acceptance receipts. Assertions now use actual
  modal ownership, explicit types, settled owner frames and completed teardown.
- Final preservation: shared ramp/floor/input/inactive actor ownership,
  48 embedded checkpoint states plus legacy cold Title Load, 88 F/E/control
  checks, 12 Sonar legacy/actor cases, 64 map discovery subsets/12 paused
  viewports/new+legacy lesson history, six chest ownership cases, 484 notice
  model cases, and existing World aim. No whole-suite/browser claim.
