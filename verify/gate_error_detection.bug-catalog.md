# Bug catalog: verification runner engine-error false greens

October5, design-tests. Read the complete shared run wrapper and its callers.
Public contract: gates.sh exits nonzero for a failed command or a Godot engine/
script error even if the child exits0; healthy children remain accepted.
IO: child stdout/stderr, exit status, log files and bounded process timeout.
Branches: timed versus direct runner, early error stop, clean/error log, exit0/
nonzero/timeout. Godot's freed-lambda message starts ERROR, not SCRIPT ERROR.

| Bug | Impact / plausibility | Evidence |
|---|---|---|
| ENGINE-1: a freed-node engine ERROR survives a successful child exit and is reported clean | High: release verification conceals runtime errors; original wrapper only checked SCRIPT ERROR | Real whirlpool actor deletion emitted freed-lambda ERROR. Public CLI probes now reject engine and script witnesses at exact exit1, while accepting a healthy child at0. |

Test is a negative-path/decision table at the public shell CLI. No function is
copied/extracted and no regex is mirrored in the test. Always-fail output fails
the healthy control; always-pass fails both error controls. Refactoring the
wrapper preserves the CLI behavior. It does not establish game behavior or
the full-suite result. Probe logs are intentionally suppressed inside the
self-test so expected errors aren't mistaken for live game errors by callers.

Skipped: unrelated browser/asset/gameplay correctness; full-suite timeout
acceptance remains part of final integration verification, not this witness.
Evaluation: ENGINE-1 caught from a real runtime log; unrelated first shell
process-substitution observer did not load the wrapper and is not evidence.
