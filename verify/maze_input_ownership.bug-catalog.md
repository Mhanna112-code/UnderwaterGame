# INT-06: one maze interaction owns each input

October 4, 2026. Complete targeted modules read: MazeLevel, MazeMiniMap,
TargetSelector, Diver and SavePoint/Menu. Fixture placement is not traversal proof.

## Module contract

1. Public surface: parsed key press/release events, overview map L/E/R/arrows,
   checkpoint P/Esc, swap selection arrows/Enter/Esc, active diver encounter event.
2. Load-bearing comments: Marc forces encounters inside the strong room despite
   World Off. Map E must rotate walls, not activate abilities; R rotates currents,
   not the campaign encounter preference. TargetSelector owns selection/cancellation.
3. IO: Godot child-before-parent unhandled-input dispatch, process/physics frames,
   deferred collision/contact signals, wall rotation tweens and random encounters.
   No save writes; test dismisses genuine first-visit warning via its visible button.
4. Branches: map/save/swap/battle/modal/ordinary exploration; checkpoint contact
   versus absent; three active divers; local strong-room developer toggle On/Off
   and outside region. Owned input must not open a second surface or switch diver.
5. Contracts: campaign encounters preference and local room_encounters_enabled are
   intentionally separate booleans. Map's main_map.visible and TargetSelector's
   selecting express active ownership; neither was included in any_modal_open.
6. Existing checks: map gate calls handlers directly and asserts geometry; checkpoint
   gate tests P alone. Neither composes real dispatch across map/save/swap owners.

## Catalog

| Bug | Impact / plausibility | Test / status |
| --- | --- | --- |
| P or Esc stacks save/inventory on an open map | High: conflicting modal/input ownership; parent save guard omits map | Caught: actual L then P opens both; repaired and generated cases pass |
| L/P/Tab steal ownership while choosing Swap | High: broken camera/ability flow; map omits selecting and parent save guard runs first | Source-inspected exclusion repaired; actual generated input cases pass, no separate pre-repair Swap reproduction claimed |
| Campaign Off disables Marc's forced room or room policy leaks outside | High: content bypass/unwanted fights; separated preferences can be conflated | Characterized: three active divers × outside/local-Off/local-On, actual public encounter events |

Self-critique: assert actual visible surfaces, active/selected targets, live wall/current
change and Battle construction, not helper call counts. Bounded owner × active
generator exceeds five cases. Unchanged behavior survives refactoring. Stable
incorrect double-surface state fails regardless of screenshot appearance.

## Skipped

Full puzzle route, held movement/camera ergonomics, rendered overview layout,
browser pointer behavior, post-fight audio and native saves are separate gates.

## Evaluation

Valid red receipt on c58b26f: actual L/P at checkpoint left map and SavePointMenu
visible simultaneously. New exclusion/selection priority repairs the ownership
contract. Nine generated owner × active-diver cases and nine encounter-policy
cases pass; actual E rotates a discovered wall and R relocates the same current
without changing campaign Off for all three divers. Public swap activation for
non-Maxilani cases is a selection-owner fixture, not a new player ability.

Map, actual checkpoint/recovery and twelve World return/history regressions pass.
Native 360x640/1280x720 P/mouse slot-picker reruns pass; six resulting views were
inspected for clipping/overlap. This does not accept full route, overview art or
all four presentation sizes on this increment. No user save was written by the
input/presentation gates. A first wrongly named fixture checkpoint caused a
script error; corrected and excluded, not counted as a game defect/pass.
