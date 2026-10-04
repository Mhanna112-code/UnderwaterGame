# Local baseline receipts

These are narrow integration-baseline checks, not feedback-build or release acceptance.

The five baseline logs ran the reconciled PR97 merge on top of 493b1d8 before the merge checkpoint was committed. Runtime reconciliation is saved at 7a762ee135f198b6af38ca8191e96e8ed77cb94e (parents 493b1d8 and 55e8515). Whitespace-only cleanup followed the first five runs. The map check was rerun on that committed source and again exited 0 without script errors.

Engine: Godot 4.7.1.stable.official.a13da4feb. Commands: gtimeout 60 godot --headless --path /Users/tomriddle1/underwatergame-maze-campaign-integration --script res://verify/<gate>.gd, where gate is the log filename's named verifier.

The old scene-transition fixture checks that a maze scene/HUD appears after direct trigger placement. It cannot prove party conservation, normal navigation, persistence or recovery. The video check does not accept the new live-demo lifecycle. No screenshot, listening round, full campaign traversal or deployable package is represented here.
