# Sonar pickup lifetime — October 5, 2026

## Module and public contract

The Sonar pickup module in MazeLevel builds a spinning cyan lens, awards the
`sonar_vision` inventory item on actual Diver/Area3D contact, and removes the
lens for a party that already owns it. Q sonar still needs the item for 3D
hazard vision; it does not need a separate G toggle. Marker-only sonar remains
available without the lens. Construction, contact, per-frame ownership cleanup,
and `sonar_on_in_maze`/`sonar_vision_active` were read together with scene startup,
shutdown, CampaignSession, SceneHandoff, and SwirlRoom's reveal/damage contract.

Public boundaries: real Tab input and physical overlap, inventory result and
visible pickup disappearance, JSON CampaignCheckpoint encode/decode and fresh
scene restore. Time: native physics and the repeating two-second spin. No disk
save files, production player slots, HTTP or balance policy are touched.

Branches: fresh unowned lens versus previously owned/restored lens; all three
real selected divers; duplicate overlap after removal; full owner teardown.
Load-bearing invariant: a visual animation cannot outlive its freed target.
Existing Q/legacy-flag checks cover reveal semantics, but reported "clean" after
an engine infinite-loop error. The strict gate runner correctly rejected that.

## Bug / test

**SV-6 — collected or restored lens leaves a maze-owned infinite spin targeting
a freed mesh.** Medium/high: normal collection and Load emit engine errors and
invalidate release acceptance. Plausible because MazeLevel's `create_tween`
binds to the still-live maze, while the target is a child of the removed lens.

Captured-bug/invariant test: three actors × real collection and fresh JSON
restore. Enter the actual pickup Area3D; assert exactly one item and removed
lens. Run longer than one spin, destroy the maze, and restore the actual saved
ownership into a new scene. Assert no resurrected pickup or resource changes.
Use `bash verify/gates.sh --sonar-pickup-lifetime`: the actual shared runner
rejects engine errors independently of the SceneTree script's exit status.

Self-critique: a silently removed/unawarded lens fails semantic checks; an
unchanged crashing animation fails the error oracle. No assertion names the
Tween owner or counts private callbacks, so a behavior-preserving animation
refactor passes. The six generated actor/path cases cover the bounded class.

## Skipped

- Earned navigation to the lens, full maze strategy and combat balance: separate
  campaign journey requirement, not proved by a physical-placement fixture.
- Browser storage durability: this is an in-memory JSON scene lifecycle test.
- No changes to the item requirement, G controls, damage or Oxygen billing.
- Other repeating animations: investigate separately if strict logs identify
  their failure; do not suppress all Tween errors or change global timing.

## Evaluation

Captured red: actual actor0 contact awarded the lens but emitted the engine's
`Infinite loop detected` error. The shared runner exited1, rejecting the
SceneTree's otherwise successful semantic path.

Green: bind the spin to the pickup's lifetime, not the maze. All six actual
collection/fresh JSON restore cases pass through the unchanged strict runner,
exit0 with no engine/script errors. The pre-existing twelve legacy-flag/actor
Sonar reveal cases also exit0 without the previously reproduced engine error.
This is native lifecycle acceptance, not hosted or whole-campaign acceptance.
