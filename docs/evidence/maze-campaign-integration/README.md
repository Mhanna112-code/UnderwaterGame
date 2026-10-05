# Local baseline receipts

These are narrow integration-baseline checks, not feedback-build or release acceptance.

The five baseline logs ran the reconciled PR97 merge on top of 493b1d8 before the merge checkpoint was committed. Runtime reconciliation is saved at 7a762ee135f198b6af38ca8191e96e8ed77cb94e (parents 493b1d8 and 55e8515). Whitespace-only cleanup followed the first five runs. The map check was rerun on that committed source and again exited 0 without script errors.

Engine: Godot 4.7.1.stable.official.a13da4feb. Commands: gtimeout 60 godot --headless --path /Users/tomriddle1/underwatergame-maze-campaign-integration --script res://verify/<gate>.gd, where gate is the log filename's named verifier.

The old scene-transition fixture checks that a maze scene/HUD appears after direct trigger placement. It cannot prove party conservation, normal navigation, persistence or recovery. The video check does not accept the new live-demo lifecycle. No screenshot, listening round, full campaign traversal or deployable package is represented here.

## INT-01 live handoff receipts

`handoff-red.log`: valid game reproduction on 2e19f29 plus the new gate (166 findings, exit 1, no script errors). `handoff-green.log`: same six-case gate after the live CampaignSession repair (exit 0). `handoff-transition.log`, `handoff-map.log`, `handoff-opening.log`: affected existing gates, exit 0. Engine unchanged; commands use `gtimeout 120 godot --headless --path . --script verify/maze_campaign_handoff.gd` and 60 seconds for existing gates.

This covers live party conservation across a real proximity scene replacement only. It does not accept cold maze saves, secret return, traversal, battles, rendered presentation or deployable bytes. The initially invalid test fixture is not the red receipt and is not counted as a game defect.

## INT-02 secret return receipts

`secret-unreachable-red.log`: valid missing entrance reproduction on 96f6752 plus the new gate (exit 1). `secret-return-red.log`: after restoring the missing builder call, seven actual state-loss findings (exit 1). `secret-home-red.log`: opening geometry restored, but subsequent wall closing failed (exit 1). `secret-green.log`: same actual E/Esc gate extended across all three public wall sets, now clean (exit 0). `secret-handoff.log`, `secret-map.log`, `secret-opening.log`: affected regressions, exit 0. All valid receipts are free of script/parse errors. Commands use Godot 4.7.1, `gtimeout 90 godot --headless --path . --script verify/maze_secret_continuity.gd` (120 seconds for handoff).

Fixture placement, starting consumables and direct public rock/door/rotation actions are disclosed in the test: these prove live continuity, not human navigation or a complete puzzle solve. No durable cold load, real battle, rendering/listening or exported package is accepted here. `secret-traversal-unaccepted.log` retains the failing older completion check. Its H-era route/current assumptions are obsolete; complete current-input traversal remains required rather than being marked green.

## INT-04 native checkpoint receipts

Source before repair: dc2e207. `checkpoint-red.log` is the valid missing-save-point reproduction (exit 1, no script errors). `checkpoint-maze_checkpoint.log` covers normal entrance proximity, actual SavePoint contact/P/menu request, disk save, closed scene and Title Load, saved door collision/open wall/pending reward conservation, native FileAccess rejection with byte-for-byte prior checkpoint retention, and a real enemy-caused defeat followed by GameOver Restart (six player actions). No injected battle outcome or inflated HP is used. Fixture proximity, damaged party and public puzzle actions are disclosed; this is not full-route or balance proof.

`checkpoint-maze_checkpoint_io.log` covers 24 generated active/downed-party JSON combinations, 40 malformed records, and two actual Title Load rejections including a shape-valid nonexistent scene reference. Rejected records keep an actionable title, do not replay opening and leave checkpoint bytes unchanged. The remaining seven `checkpoint-*.log` files are affected handoff, secret, map, opening-state, World persistence, invalid-load and selected-slot regressions. All nine final runs exited 0 without script errors using `gtimeout 240 godot --headless --path . --script verify/<filename>.gd` on dc2e207 plus the checkpoint increment, engine 4.7.1.stable.official.a13da4feb.

Excluded from reproduction: the initial blocked-onboarding fixture and a JSON int/float dictionary-equality harness mismatch. Neither is counted as a game failure. Native checkpoint acceptance does not prove IndexedDB sync-denial rollback, target-platform launch, rendered checkpoint discoverability or full maze navigation. Maze return/re-entry and world checkpoint history remain required.

## INT-04 World return/history receipts

`world-return-red.log`: a5c8f15 plus new gate, no explicit physical World return, exit 1 without script errors. `world-return-green.log`: a5c8f15 plus the return repair, twelve generated combinations of active diver × companion downed state × independent lab state. Actual physical entrance/E exit, public door/key use, World save and cold Title Load/re-entry; unchanged live resource identity/resources/kit before rest, no entrance bounce, open door/spent key and independent lab state are checked. Fixture placement/lab flags are not full traversal or boss-victory evidence. `return-regression-*.log` retains all nine affected native passes. Same engine; `gtimeout 120 godot --headless --path . --script verify/maze_world_return.gd`, 240 seconds for regressions. All green processes exit 0 without script errors. No rendered checkpoint/exit/menu, browser durability or delivery acceptance is claimed.

## INT-08 native checkpoint UI receipts

Source: 529ba0d plus the checkpoint presentation increment. `ui-original-menu-narrow-red.log` and `checkpoint-menu-narrow-red.png` preserve the isolated old fixed-width menu's four clipped-button findings at 360x640. `ui-original-menu-wide-characterization.log` passes with the stabilized old menu; earlier missed mouse clicks were fixture timing/global-position defects, not game bugs.

`ui-native-<size>.log` and `ui-<size>-{entry,contact,slots}.png` cover all four declared sizes with Godot 4.7.1 Compatibility/OpenGL/macOS: `gtimeout 120 godot --path . --rendering-method gl_compatibility --resolution <size> --script verify/maze_checkpoint_presentation.gd`. The gate uses actual P and mouse events, asserts actionable slot-picker/button bounds and a single recovery caption, then closes without writing any user slot. Twelve final images were inspected. The `ui-regression-*.log` receipts cover related state/menu checks; checkpoint, map and World-return were rerun after the final landmark-only visibility adjustment. All accepting processes exit 0 without script errors.

These are sampled checkpoint/menu views, not complete maze navigation, every camera angle, web/IndexedDB behavior, Windows/Linux launch, battle animation/audio or the final zero-defect audit round. No deployable artifact is represented.

## INT-03 relic consumer receipts

Source before repair: e2d0024. `maze-relic-red.log` is a real three-action victory
that misses Tidal Revival and also emits a duplicate caption connection error.
`maze-relic-disconnected-red.log` removes only the repaired handoff assignment,
failing skill/menu availability without script/engine errors; explicitly a mutation
check. `maze-relic-green.log` passes eight relic-present/absent actual fights and
Party Spells availability. `maze-relic-checkpoint.log`/`maze-relic-menus.log` pass
affected regressions. Commands: Godot 4.7.1, `gtimeout 150 godot --headless --path .
--script verify/maze_relic_consumers.gd`, 100 seconds for regressions. XP preparation
and location fixtures are disclosed; this is not full-route or balance acceptance.

## INT-06 input ownership receipts

Source before repair: c58b26f. `maze-input-red.log` reproduces actual L/P stacking,
exit 1 without script errors. `maze-input-green.log` passes nine owner/active cases,
nine forced-room policy cases and actual wall/current E/R. `maze-input-map.log`,
`maze-input-checkpoint.log` and `maze-input-return.log` pass related regressions.
Commands: `gtimeout 100 godot --headless --path . --script
verify/maze_input_ownership.gd`, 120 seconds for regressions; same engine.

`maze-input-native-{narrow,wide}.log` and `input-ui-<size>-<phase>.png` rerun real
P/mouse input and three inspected views at 360x640/1280x720 with Compatibility
renderer. No user save was written. These are limited checkpoint/menu samples;
other sizes, full route, overview art, browser/audio and final polish remain open.

`maze-relic-public-ui.log` and `maze-input-shape.log` rerun the same suites on
8ba4c92 with hardened, refactor-tolerant oracles: visible caption rectangles,
not a private registry; actual collision type, not child order. Both exit 0 with
no script/engine errors. No gameplay/source changes in this test-only increment.
