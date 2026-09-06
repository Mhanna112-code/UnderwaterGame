#!/usr/bin/env bash
# Every check, in the order that makes a failure easiest to read: the ones
# that ask the art files a question first, then the ones that play the game,
# then the ones that need a browser.
#
# Exits non-zero if any gate does. Run it before pushing.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
fails=0
skips=0

# Godot scans everything under the project root, and playwright has to be
# installed here for node to resolve it from verify/*.mjs. A .gdignore stops
# the scan at the directory boundary, which is the difference between a clean
# run and a screenful of complaints about files inside npm packages.
[ -d node_modules ] && [ ! -f node_modules/.gdignore ] && touch node_modules/.gdignore

run() {
	echo
	echo "=== $1 ==="
	shift
	local gate_log
	gate_log="$(mktemp "${TMPDIR:-/tmp}/underwater-gate.XXXXXX")"
	"$@" 2>&1 | tee "$gate_log"
	local command_status=${PIPESTATUS[0]}
	local script_error=0
	if grep -q "SCRIPT ERROR:" "$gate_log"; then
		echo "GATE ERROR: Godot reported a script error even though the command may have exited successfully"
		script_error=1
	fi
	rm -f "$gate_log"
	if [ "$command_status" -eq 0 ] && [ "$script_error" -eq 0 ]; then
		return 0
	fi
	fails=$((fails + 1))
	return 0
}

run "clips: does every clip the game asks for exist"  "$GODOT" --headless --path . --script verify/clips.gd
run "animations: does every rig change state correctly" "$GODOT" --headless --path . --script verify/animations.gd
run "swim: do they move, and animate while moving"    "$GODOT" --headless --path . --script verify/swim.gd
run "Glassgoat combat: do the authored V2 rules hold" "$GODOT" --headless --path . --script verify/glassgoat_combat.gd
run "Tethys boss: does Glassgoat's final boss import and fight separately" "$GODOT" --headless --path . --script verify/tethys_boss.gd
run "combat feedback: are V2 results and target stats visible" "$GODOT" --headless --path . --script verify/combat_feedback.gd
run "defeated overhead: does dead UI leave with its actor" "$GODOT" --headless --path . --script verify/defeated_overhead.gd
run "balance: do casual and skilled policies clear the artifact route" "$GODOT" --headless --path . --script verify/balance.gd
run "sites: are item locations unmarked and physically reachable" "$GODOT" --headless --path . --script verify/sites.gd
run "encounters: does a fight start from anywhere"     "$GODOT" --headless --path . --script verify/encounters.gd
run "title: is cold launch readable and exclusive"     "$GODOT" --headless --path . --script verify/title_screen.gd
run "merge readiness: is defeat exclusive and identity consistent" "$GODOT" --headless --path . --script verify/pr54_merge_readiness.gd
run "fight: play one to the end and come back"        "$GODOT" --headless --path . --script verify/fight.gd
# The only gate here that must NOT be headless. It measures where combatants
# land on screen, and a headless run gets a 64x64 window, which makes every
# screen-space number it produces meaningless. Skipped rather than failed
# where no display is available, so CI does not report a false problem.
if [ -n "${DISPLAY:-}" ] || [ "$(uname)" = "Darwin" ]; then
	run "stage framing: can you see the fight past the HUD" "$GODOT" --path . --resolution 1280x720 --script verify/stage_framing.gd
else
	echo
	echo "=== stage framing: skipped, needs a display ==="
fi

run "goblin: does the grunt load and size correctly"  "$GODOT" --headless --path . --script tools/test_goblin.gd
run "angler grunt: is Glassgoat's replacement textured and animation-mapped" "$GODOT" --headless --path . --script verify/angler_grunt.gd
run "enemy moves: are Angler attacks reusable data and playable clips" "$GODOT" --headless --path . --script verify/enemy_moves.gd
run "artifact guardians: do both models persist from map to one-enemy battle" "$GODOT" --headless --path . --script verify/artifact_guardians.gd
run "battle: does the fight screen build"             "$GODOT" --headless --path . --script tools/test_battle.gd

# The browser gate needs an exported build in docs/ and node with playwright.
# Skipped rather than failed when either is missing: a machine with only
# Godot should still get a useful run out of this script, and "playwright is
# not installed" is not a finding about the game.
if [ ! -f docs/index.wasm ]; then
	echo
	echo "=== webcheck: skipped, no docs/index.wasm to serve ==="
	skips=$((skips + 1))
elif ! node -e "import('playwright')" >/dev/null 2>&1; then
	echo
	echo "=== webcheck: skipped, playwright not resolvable ==="
	echo "    npm i playwright && npx playwright install chromium"
	skips=$((skips + 1))
else
	run "webcheck: does the build boot in Chromium" node verify/webcheck.mjs docs /tmp/gate-chromium.png
	run "boss webcheck: does ?boss=1 open Glassgoat's fight" node verify/boss_webcheck.mjs docs /tmp/gate-tethys.png /tmp/gate-tethys-title.png
	run "guardian webcheck: does ?guardian=trench open the Swordfish Duelist" node verify/guardian_webcheck.mjs docs /tmp/gate-guardian.png
fi

echo
if [ "$fails" -eq 0 ]; then
	if [ "$skips" -gt 0 ]; then
		echo "GATES: gameplay clean; $skips skipped"
	else
		echo "GATES: all clean"
	fi
	exit 0
fi
echo "GATES: $fails failed"
exit 1
