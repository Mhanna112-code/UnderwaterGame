# Post-Tethys maze navigation

## Fix

- Screen-space, camera-relative **Maze ramp** arrow plus distance points just inside the actual shared maze boundary, along the central ramp (z=16), not the earlier decorative landmark or ramp mouth.
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

The first exported browser route succeeded at movement/entry but its distance rose after passing the ramp mouth (56→4→9→20). It is rejected as acceptance: following that arrow would turn a player back. `ramp-mouth-red.log` captures the strengthened failing native test. Final verification must use the corrected boundary target, require a forward pointer through the native crossing and decreasing browser distance until maze entry. The provisional preview was never promoted.

## Concurrent main intake and browser observer

Marc's `e572a55` and `4dd2a47` changes were merged before final export. His persistent maze health/party HUD, objective layout helper, combat pacing, ending checkpoints and 12-Oxygen Shockwave are preserved. The older embedded-maze assertion requiring the entire World CanvasLayer to disappear was updated to require exclusive exploration controls/camera while retaining the shared health HUD.

A fixed-duration camera turn was rejected as an observer: its slight heading error drifted into a ramp rail. The final browser observer reads the rendered cyan arrow pixels, adjusts ordinary arrow-key look controls, and swims with W. It verifies decreasing distance and the actual visible Control Room handoff, not merely disappearance of the guide. No internal position/entry mutation occurs during the crossing.

The latest native headless route and bidirectional embedded-maze test pass with Marc's intake. A concurrent windowed visual run did not reach the maze within its travel budget; it is not accepted as traversal evidence. Its layout captures can establish only the rendered layout. The final hosted keyboard/renderer crossing is the visual route acceptance check; no claim is made that this windowed test passed.

The first latest-source browser observer reached the maze in its retained frame but OCR read the perspective `Control Room` label as `Concrol Room`. That receipt is rejected as an automated pass. The observer now tolerates only the two observed t/c and o/a glyph confusions in that specific room name, alongside missing World route text and the retained visual handoff; it does not accept arbitrary disappearance as entry.

## Accepted hosted artifact

Source `153b2a59275969fb05e683b26141a48ef42e1182`, pack SHA-256 `f9264ce939a6c1d3d781ca4313d70859985edc3968df85dae609e694a9c09082`, 94,984,492 bytes. The streamed hosted pack matches. `hosted-final/receipt.json` has no findings; the rendered-arrow/W route counts down from 83 metres to 9 metres then hands off to the actual maze Control Room. Inspected retained frames show readable guidance at 1280/720/360 widths and a visible ramp corridor without the central rock blackout. The post-victory browser fixture is disclosed in the receipt; the separate native actual Tethys victory and cold Title Load check also pass.
