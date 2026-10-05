# Optional tutorial victory handoff

Public behavior: an actual killing attack must lead to a visible, clickable
Continue action, then emit `won`; World restores the party, saves tutorial
completion independently of opening completion, and returns control.

## OPEN-039: victory freezes before a usable Continue

- Evidence: player screenshot shows defeated Angler and victory log, but no
  action. The previous optional-training test only covered declared losses
  and Skip, not a real win.
- Risk boundaries: asynchronous attack/animation completion, victory delay,
  recovery overlays, caption layout, and World result/save handling.
- Cheapest test: real Battle button attack from a completed-lesson fixture,
  followed by rendered Continue bounds and result assertions. Full curriculum
  and World/browser composition are separate verification requirements.
- Critique: do not call `_win` or emit `finished` to prove winning. Lesson
  progress and one-HP enemy are explicitly fixture setup; the killing move
  and subsequent handoff run production code.

## Skipped

- Changing tutorial wording or curriculum: outside this repair.
- Existing loss/Skip cases: retain their existing gates.
- Model aesthetics: no asset replacement needed for this failure.

## Evaluation

### 2026-10-05 current-main observer correction

The fresh full-lesson runner produced infinite-tween errors, but investigation
found it was emitting `pressed` on a hover-only target whose public mouse mask
was zero. Current tutorials deliberately leave those targets enabled-looking
while rejecting clicks. The observer's old `disabled` check bypassed that
guard, skipped the required hover lesson and replaced its target while the
lesson awaited hover. This is not evidence of a real user clicking through.
The observer now honors both public input guards and supplies the required
hover before clicking. Preserve the red receipt; do not count this as a new
production bug or silently remove the engine-error gate. A fresh complete
five-move/victory run remains required. Actual Skip/cancellation/browser input
are separate checks, not proved by this native signal-driven curriculum run.

Root cause confirmed: `_apply_tutorial_move_gate` creates a Battle-owned
infinite tween targeting a generated Button. `_populate_move_menu` frees that
Button without stopping its tween. The next guided step normally replaces the
tween, concealing the problem; the final guided-to-free menu transition does
not. Native debug prints `Infinite loop detected` and stops the tween; the
release browser can spin without reaching its victory continuation.

Captured exported reproduction: normal Load of an actual completed-opening
snapshot in a disposable browser profile, W into the optional beacon, all five
guided moves. Opening the free-fight move menu then made the browser renderer
spin at 100% CPU and cease responding to input/screenshots. No player save was
modified. Native `menu-replacement-red.log` independently captures the engine
error even though the old verifier's exit status was zero.

The fix stops and releases the old tween before destroying its targets. The
gate now rejects the engine error instead of accepting a success message or
zero exit status.

Green: rendered real win/Continue, narrow layout, all five lessons, actual
World beacon entry and victory/restoration/save/movement, existing optional
loss/Skip branches, status/QTE layout. No script or infinite-loop errors.
Exported Chromium at 1004×847 completed all five guided moves using actual
mouse/keyboard input, killed the Angler, clicked visible Continue, dismissed
all onboarding pages, returned to unobstructed swimming, and read persisted
`tutorial_complete=true` and `prologue_complete=true`. Zero browser errors.
Evidence: `docs/evidence/tutorial-win-handoff/README.md`.

Harness defects were corrected, not treated as game passes: headless dummy
viewport bounds, preview-header versus target-button OCR, final Close button,
and controls visible behind a blocking onboarding modal. Rendered bounds and
actual victory/save checks remain required. Fix verified on runtime `9778296`;
existing review alias refreshed, main unchanged. OPEN-039 is fixed; the larger
opening goal still requires its final full visual/audio audit.
