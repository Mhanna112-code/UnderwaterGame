# Local baseline receipts

These are narrow integration-baseline checks, not feedback-build or release acceptance.

The five baseline logs ran the reconciled PR97 merge on top of 493b1d8 before the merge checkpoint was committed. Runtime reconciliation is saved at 7a762ee135f198b6af38ca8191e96e8ed77cb94e (parents 493b1d8 and 55e8515). Whitespace-only cleanup followed the first five runs. The map check was rerun on that committed source and again exited 0 without script errors.

Engine: Godot 4.7.1.stable.official.a13da4feb. Commands: gtimeout 60 godot --headless --path /Users/tomriddle1/underwatergame-maze-campaign-integration --script res://verify/<gate>.gd, where gate is the log filename's named verifier.

The old scene-transition fixture checks that a maze scene/HUD appears after direct trigger placement. It cannot prove party conservation, normal navigation, persistence or recovery. The video check does not accept the new live-demo lifecycle. No screenshot, listening round, full campaign traversal or deployable package is represented here.

## INT-01 live handoff receipts

`handoff-red.log`: valid game reproduction on 2e19f29 plus the new gate (166 findings, exit 1, no script errors). `handoff-green.log`: same six-case gate after the live CampaignSession repair (exit 0). `handoff-transition.log`, `handoff-map.log`, `handoff-opening.log`: affected existing gates, exit 0. Engine unchanged; commands use `gtimeout 120 godot --headless --path . --script verify/maze_campaign_handoff.gd` and 60 seconds for existing gates.

This covers live party conservation across a real proximity scene replacement only. It does not accept cold maze saves, secret return, traversal, battles, rendered presentation or deployable bytes. The initially invalid test fixture is not the red receipt and is not counted as a game defect.
