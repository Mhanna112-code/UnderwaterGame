# Marc maze map intake: input, selection, and readable flow

2026-10-04. Sources refreshed through #97 `c035c20` and #99 `86878fa`. This bounded batch admits the latest Ctrl controls, clockwise selection, readable flow symbols, title band and responsive overview. It does not admit the new map chest, right-side discovery legend, ready-door priority, underpass, caption queue, or embedded-world geometry yet.

## Module understanding

`MazeMiniMap` projects live maze walls and current Areas, discovers them from the active diver, and owns L/arrow/E input while its overview is visible. `MazeLevel` owns exploration, inventory/checkpoint/Swap input, battle admission, the forced strong-room policy, and campaign snapshots. Both modules were read end-to-end, with `WaterCurrent` and `CampaignSession` followed as contracts. The selected current identifies its physical Area, not its controller's previous position or a wall-pair alias.

Public surfaces are real key events, rendered map lines/highlights, physical diver traversal, and campaign persistence. No network IO occurs in map selection. Physics, frame order, deferred signals, rotating-wall Tweens, and scene destruction are important boundaries; saves must capture stable state rather than an in-flight movement. Campaign encounter preference is distinct from Marc's local forced-room encounter switch.

Branch inventory: battle/modal/Swap reject map keys; a visible overview rejects unrelated exploration/menu keys; L opens/closes; Ctrl+arrows select currents separately from walls; Ctrl+E moves a current; E/Enter rotates walls (ready-door priority pending); R changes encounter preference without moving either outside the forced room; strong-room admission ignores the campaign preference and rejects R; discovery filters selection; zero/one/multiple candidates differ; short lines need symbolic extension while long lines retain their extent.

## Ranked bugs and tests

| ID | Failure mode | Risk / reason | Test and self-critique | Status |
|---|---|---|---|---|
| MAP-1 | Ctrl+E rotates walls or does nothing; R still moves currents or becomes a dead key when the overview is open. | High: players cannot follow Marc's new controls. Existing map/maze early returns disagree. | Real input in `maze_input_ownership.gd` across all three active divers; observe the same live current moving, unchanged walls, campaign preference and session synchronization. Physical first-channel route uses Ctrl+E and crosses the actual push area. No private rotate helper is invoked by the test. | repaired; real input and physical route pass |
| MAP-2 | R leaks through Save/Swap/battle owners, or disables the forced strong room. | High: overlapping owners and lost maze challenge. | Real key events with exclusive owners, then actual encounter admission with global Off/local On. Test does not equate preference Off with local policy Off. | guarded; actual input/admission pass |
| MAP-3 | Arrows still select in scene/alphabetic order instead of clockwise on the displayed map. | Medium: input does not match spatial presentation. | 24 generated discovery subsets and complete real-key cycles; independent quadrant/cross-product winding checks coverage, one wrap, and reverse traversal. Does not call product angle/sort helper. | old wall sort fails valid negative; repaired cases pass |
| MAP-4 | Short flow symbols remain unreadable, or stretching moves/reverses their center/facing. | Medium: misleading map despite working collision. | Inspect live rendered endpoints against independently projected collision centers, physical orientation, 44px overview minimum and physical extent. Native wide/short views supplement geometry. | old Corridor3 stroke 16.10px fails; repaired gate passes |
| MAP-5 | The overview/help run below a short window or beyond its right edge; its legend/title are clipped; exploration HUD shows through. | High: correct keys exist but cannot be read. Fixed 500px map plus long help exceeds supported viewports. | Actual widget bounds/text extents at four fixed and eight generated desktop/portrait shapes; native rendered inspection catches HUD bleed-through and narrow orphaned R copy. | repaired; native 12 shapes pass; wide/short/portrait captures inspected |
| MAP-6 | Holding Ctrl sinks a diver while selecting a current or after closing the map. | High: new input silently changes depth. | Actual held-key differential over physics frames in both World and Maze; Shift must still descend. | valid old Ctrl red; repaired two-owner test passes |
| MAP-7 | Restored discovered rooms draw before reveal groups exist and emit a script error. | High: cold/restored overview may be broken despite printed clean result. | Public restore-discovery followed by actual rendered frames, rejecting script errors. | reproduced during layout gate; initialize reveal groups before restoring rooms; clean native rerun |

## Skipped / suspect boundaries

- Do not preserve old R-current behavior or obsolete two-lever access rules; those are deliberately superseded.
- Exact displayed line endpoints are no longer collision-volume endpoints for short zones. Minimum-length symbols are presentation, not enlarged physical push zones. Existing endpoint assertions must be updated explicitly, not silently weakened.
- Earned map chest/discovery legend and embedded-world ownership are separate pending admission batches. This test cannot prove either.
- Save writes are not needed for preference synchronization; test the live campaign session and existing save/return regressions without touching a user's slots.
- Whole-maze completion, browser input, and final visual polish remain separate gates; first-channel success is not campaign success.

## Evaluation

Receipts: `/tmp/underwater-marc-map-input-final.log`, `-order-final.log`,
`-flow-final.log`, `-route-final.log`, `-modifier-green.log` and
`-layout-native.log` (same `/tmp/underwater-marc-map` prefix). All finish clean
without captured script errors. Checkpoint cold-load/defeat gate and twelve
World-return cases also pass in `-checkpoint-final.log`/`-world-return-final.log`.
Native evidence: `/Volumes/Totallynotaharddrive/underwater-marc-map.azaA0G`.
Inspected 1280x720, 803x893, 720x480 and 360x640, including latest four-line
Ctrl/R help and no exploration HUD showing through the overview.

Valid red probes: old sorting rerun `-order-red-final.log`, short current stroke
`-flow-red-final.log`, and actual modifier red. The first Shift-based input red
preceded Marc's newer Ctrl contract; the final test follows Ctrl, not that obsolete key.

Excluded oracle/fixture mistakes: requiring every clockwise cycle to start at
screen-right (nearest initial selection is valid), exact full collision-box
stroke length (deliberate diagram padding), headless 64px default viewport,
and a misspelled strong-room method. None is a claimed production defect/pass.
First responsive attempt cached a huge zero-width RichTextLabel minimum; native
rejection prompted explicit measured help height. Existing wall-map tests retain
a helper-coupled geometry assertion; that is not independent full-maze proof.

Current-order coverage is initial geometry; a generated sequence after every
current relocation is a worthwhile additional adversarial case, not yet covered.
Native map checks are not a browser or earned-chest test. No whole-maze clean
polish round or deployment acceptance follows from this bounded admission.

## Subsequent intake: c035c20 / 86878fa

`04bc26e` supersedes Shift-based current bindings with Ctrl+arrows/Ctrl+E;
`0d55685`/`86878fa` reserve only Shift for sinking in both World and Maze.
Tests and copy must follow this latest contract, not the earlier frozen batch.
MAP-6: holding the current modifier physically sinks the diver when the map is
closed (or the key remains held after closing it). A real-input differential
in both exploration owners must observe no vertical travel for Ctrl and actual
downward travel for Shift. Do not test `_player_rise` in isolation or inject a
fake swimming result. This bounded two-owner contract needs no save writes.
Latest map chest/door priority, caption queue, presentation bands and lower
sphere density are recorded separately; no blanket admission is implied.
