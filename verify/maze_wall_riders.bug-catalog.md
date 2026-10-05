# Bug catalog: retained moving-wall riders

October 5, design-tests. This follows WALL-3 in maze_wall_motion's catalog.

## Responsibility / public interface

The navigation map's `rotatable_wall_sets().rotate` actions move three wall
pairs. A capsule struck outside C5 must remain a passenger until its wall stops,
then be placed on a clear usable face. World owns the actors; motion is transient
and must not survive a restored checkpoint or removed/inactive maze.

The inspected motion module has hinge and straight Tween paths, home/open
branches, already-moving rejection, C5 exclusion, attached collision suspension,
completion/killed-scheduler cancellation, restore and removed-owner cleanup.
Maze and World each dispatch real `Diver.swim`; currents and whirlpools can also
move actors. `is_grappling` and `is_suction_locked` are public transient-owner
contracts. Collision masks/layers are physics contracts, not arbitrary IDs.
IO boundaries are SceneTree time/Tweens, CSG physics and checkpoint JSON. No
player save files are needed for this fixture. Existing C5/draft tests park
actors or exempt them; they do not establish outside-C5 passenger behavior.

| ID | Failure | Impact / plausible cause | Test / status |
|---|---|---|---|
| RIDER-1 | An intercepted diver slides off its wall instead of retaining its local offset through the swing. | High: authored passage can strand the party; current overlap-only push loses ownership between contacts. | Captured red at frame8; repaired. Six walls × three capsules × two directions pass. |
| RIDER-2 | A passenger is released inside another wall, skirt or actor. | High: invalid playable state; concave CSG surface queries accept buried capsules and upstream fallback returns a blocked point. | 36 real capsule/solid-volume landings and actual swimming; newly blocked CSG landing also passes. Verified adaptation, not a separate original-baseline red. |
| RIDER-3 | Restore, killed Tween, inactive or removed owner leaves a lock/mask or overwrites restored actor positions. | High: freezes player or corrupts load; World applies party before Maze cancellation. | Public JSON restore/lifecycle, pose/mask/resource conservation and actual input pass. Verified adaptation. |
| RIDER-4 | Currents or a competing grapple/suction owner fight the passenger, or cleanup clears another owner's lock. | High: wrong ownership; ZERO swim still applies currents. | Real current plus newly blocked landing, three downed bodies and three preexisting locks pass; C5 arrival releases in place. Verified adaptation. |

## Test self-critique

RIDER-1 observes real contact and conservation of an offset recorded after
contact, not a private registry or duplicated capture formula. Wrong stable
position and push-only behavior fail; a renamed/replaced motion helper does not.
Generate actor, wall pair, direction and face after the first captured red is
fixed, validating every starting capsule rather than tolerating buried fixtures.
RIDER-2 must reject both surface collisions and full solid-volume penetration;
post-release real input catches forgotten locks. RIDER-3 restores plain JSON,
removes actual owners or kills registered scheduler Tweens. RIDER-4 must retain
the C5 exception and reject a preexisting motion owner rather than stealing it.

## Skipped

- Whole-campaign earned map acquisition and browser/release artifacts: final
  campaign acceptance, not proven by an isolated physical placement fixture.
- Poster barrier, whirlpool redesign and autosaves: separate pending intake.
- Snapshotting the internal rider dictionary: implementation coupling.

## Evaluation

- Caught: original overlap-only pushing loses along-wall offset at frame8
  after genuine contact. Saved original observer and red log are preserved.
- Adapted and verified: safe landing, mask/lock lifecycle, downed-body resources,
  live current and competing public motion-lock contract. These did not get
  separate original-baseline reds and are not inflated into caught-bug counts.
- Investigated composition: an arriving passenger must stop riding on entering
  C5, not merely be exempt from first capture. Three arrival cases exercise that
  release while the existing C5 collision/current matrix remains preserved.
- Verifier corrections: initial fixture used the receding side; a second
  fixture opened the authored first-visit strong-room lesson and paused motion.
  Direction, processed-frame observation and already-seen lesson flags were
  corrected before accepting the original red. Neither is a product bug.
- One introduced `can_query` inference parse error was rejected and fixed;
  its cascade was not accepted as a gameplay result. One mistyped preservation
  script path returned0 with Godot ERROR lines; rejected and rerun at the real
  path. Receipts must be both terminal0 and script/engine-error-free.
- Native screenshots expose wall occlusion/close-wall camera cropping. They
  are disclosure, not proof of final visual polish or browser readiness.
- The blocked/current repeat exposed a solid-volume observer precision issue
  at resting wall contact: local face gap0.429565m versus radius0.429595m
  (approximately30µm at embedded x367). The independent solid-volume oracle
  permits0.1mm float32 contact precision; it still rejects meaningful interior
  placement and the real engine capsule query is unchanged. This is not a
  gameplay-sized tolerance or a product collision repair.
- The first C5-arrival observer demanded a perfectly stationary actor despite
  residual legitimate current velocity. Final per-frame displacement is
  bounded by observed physical velocity, while mask/lock relinquishment stays
  exact. Actual C5 motion is printed rather than hidden.
