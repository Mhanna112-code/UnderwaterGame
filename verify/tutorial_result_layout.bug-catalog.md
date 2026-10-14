# Tutorial result layout

QT12: the retained fixed-width loss/practice result popup clips Retry/Exit on a narrow viewport or pushes them offscreen with a long body. This prevents leaving optional instruction.

Public interface: TutorialResultPopup.open(title, body), the visible Retry and Exit to World buttons and their emitted signals. Test both normal practice text and a long explanation across four real viewport sizes and both actions (16 generated cases). Assert both button rectangles are inside the viewport, enabled and visible; the chosen actual button must close the modal, unpause its owner and emit only the chosen action. Inspect retained actual rendered captures separately. Container children/names are not the oracle; labels identify the intended action.

This fails for wrong-but-stable clipping but not for a behavior-preserving panel/container refactor. IO is layout frames/timers; no fake combat outcomes or saves. Prior paused-parent semantics are intentionally not asserted: this result is a terminal battle handoff that owns its pause, unlike the read-only reference overlay.

Evaluation pending first run. Global modal redesign and changing combat loss balance are skipped.
