# Post-Tethys maze navigation

## Fix

- Screen-space, camera-relative **Maze ramp** arrow plus distance points at the actual ramp mouth (x=231, z=16), not the earlier decorative landmark.
- It derives from persisted lab/Tethys completion, so saved completed runs also receive it. It is restricted to Deep exploration; battle, menu, aim, maze and completed-campaign owners do not share the guide.
- The two large visual exit-cover formations disappear only in `cleared` lab state. Physical side shell, pre-fight hiding rocks/door, independent maze access and collision rules are retained.
- Objective/compass layout reserves the party-bars column where their horizontal areas overlap.

## Verification scope

`lab_maze_navigation.gd` supplies the completed-lab milestone, starts at the actual lab return point (175,2,16), then uses ordinary W movement all the way into the embedded maze. No entry/scene/won signal or position injection is used during that swim. It round-trips the checkpoint, checks 18 camera/width combinations, menu/battle ownership and screenshots at 1280,720,360 by 720.

`lab_payoff.gd` independently wins the actual Tethys fight with a disclosed legal level-five kit (24 actions), dismisses the payoff and cold-loads its victory checkpoint. It now also requires visible maze-direction guidance after both transitions.

Pre-fight `lab_exterior.gd` and bidirectional shared-party `embedded_maze.gd` regressions pass. Browser and delivered-pack receipts accompany this directory once verified.

## Rejected/provisional evidence

The first missing-guide fixture also had its HUD hidden and was rejected. `corrected-red.log` is the subsequent wiring-mutation witness: HUD/camera active, tree unpaused, guide absent. It fails, and restoring the wiring passes.

The compass-only native run exposed a blacked-out exit, prompting the geometry correction. Its original temporary swim screenshot was overwritten during the next run, so no retained before PNG is claimed. `exit-swim-after.png` is explicitly the corrected scene, not a before image.

The first narrow render exposed health-bar overlap even though the initial bounds check passed. The final intersection assertions and inspected images use the repaired layout. Green tests alone were not accepted as visual proof.

This is focused navigation/recovery verification, not a full earned campaign/balance or all-platform audit. No existing player saves were modified; any test slot is uniquely owned and removed by its harness.
