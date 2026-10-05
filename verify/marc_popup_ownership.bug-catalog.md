# Bug catalog: Marc battle/popup reconciliation

October 4, 2026. Read CharacterAbilityPopup end-to-end (427 lines), Slot and its
scene, World post-tutorial caller, Maze portrait/strong-room callers, and Battle
tree entry/start/turn/caption lifecycle. Scope is ownership, not battle balance.

## Responsibility / interface / boundaries

Autoload `open(pages)` presents supplied instructional pages, Next/Close/Escape
and a highlighted Slot. It pauses exploration and runs a constrained video/live
demo while paused. Battle must own the screen until it leaves the tree. The
autoload outlives World/Maze; supplied Slots/callables may not. `closed` releases
callers awaiting the lesson. IO: actual Theora decoder/render frames, global
pause/mouse mode, scene lifespan, event ordering. Branches: empty pages, battle
active, panel open/hidden, remaining page vs final close, explicit media vs Slot
ability, callable vs file vs no clip, missing/freed Slot/owner, and another modal
holding pause when combat ends. Existing ability_popup_video exercises the real
World Grapple page, stream advancement, 16:9 size and no duplicate stream.

## Catalog and tests

| ID | Failure / blast radius | Plausibility | Oracle/status |
| --- | --- | --- | --- |
| M97-P1 | Opening info over real Battle pauses combat and covers controls. High. | Current open unconditionally pauses/shows; upstream queues using a Battle group. | Real Battle + public open: no visible popup, no new pause; resumes after node exits. Pending. |
| M97-P2 | Battle interrupts a walkthrough and loses remaining pages or leaves a hidden clip decoding. High. | Singleton survives combat; upstream hides panel but retains playing media. | Advance real World walkthrough to Grapple; enter real Battle; assert no visible/playing media; remove Battle and continue remaining pages. Pending. |
| M97-P3 | Held pages reopen over Game Over/title or dereference destroyed World Slots. High. | Autoload queue outlives scene and raw Slot values are not null after free. | Pause owner blocks resume; destroyed owner drops held batch without errors/pause. Pending. |
| M97-P4 | Captured mouse prevents Next/Close clicks or close steals another modal's pause. Medium. | Popup currently does not release/restore cursor; global pause is unconditional. | Actual open/Close restores its prior cursor/pause, not a nested owner's. Pending. |
| M97-P5 | A second queued explainer overwrites an interrupted first lesson. Medium. | Upstream has only one `_held_pages` array. | Distinct queued public page batches resume FIFO and close separately. Pending. |
| M97-P6 | Rapid Next replaces a paragraph before WASD render completes, and the continuation writes into freed UI. Medium. | Existing asynchronous texture render resumes after page controls are freed. | Native ability_popup_video rapid real-page progression + script-error rejection; discovered/caught. |

Tests use real Battle tree lifecycle and rendered/public popup state, not a dummy
group marker. Removing a Battle is an ownership boundary, **not** proof of victory
or complete campaign flow. Real World page input provides the clip. Controls are
found by visible text/type, no private state assertion. Owner weak reference is
only a lifetime seam; it does not mock gameplay. No snapshots, exact punctuation
or mirrors of queue internals. A wrong stable modal over combat fails; equivalent
queue/layout refactors pass. Video decoder and cursor are also native-checked.

## Skipped

- Popup narrow layout: existing 720px panel is a separate presentation scope;
  this admission preserves the reviewed embedded clip, not new onboarding.
- Complete battle outcomes/checkpoints: existing journey and recovery gates;
  separate maze admission must exercise those again.
- Keyboard-enter caption layout: next distinct Battle increment.
- Exact informational text: latest upstream content, not this lifecycle oracle.

## Evaluation

Baseline reproduced M97-P1 over an actual Battle. Native lifecycle run then
passed battle interruption/resume, FIFO lessons, destroyed owner, paused recovery
and captured cursor. Headless cannot capture an OS pointer: revised its oracle
to preserve the actually supported mode; native independently checks capture.
An integration typo caused a compile error before the first rerun; that run is
rejected, not accepted because the script later printed a result.
Native video regression exposed M97-P6 even though its old runner printed clean:
script errors reject a run. Added continuation lifetime guard; fresh native
ability_popup_video rerun passed without script errors. Headless ownership run
passed; native ownership captures were inspected: real Battle unobstructed and
the same clean 16:9 Grapple lesson resumed. Tutorial victory handoff passed.
M97-P1/2/4 required implementation; P3/5 extend Marc's one-batch port for actual
autoload lifespan/multiple callers; P6 required a discovered async repair.
No full campaign or browser acceptance is claimed for this local increment.
