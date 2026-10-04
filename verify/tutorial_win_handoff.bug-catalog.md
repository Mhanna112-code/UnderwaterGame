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
zero exit status. Green rendered/native/exported verification pending.
