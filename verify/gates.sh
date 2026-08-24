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
	if "$@"; then
		return 0
	fi
	fails=$((fails + 1))
	return 0
}

run "clips: does every clip the game asks for exist"  "$GODOT" --headless --path . --script verify/clips.gd
run "animations: does every rig change state correctly" "$GODOT" --headless --path . --script verify/animations.gd
run "swim: do they move, and animate while moving"    "$GODOT" --headless --path . --script verify/swim.gd
run "current: can full upstream input cross the flow" "$GODOT" --headless --path . --script verify/current_barrier.gd
run "balance: do careless and greedy policies land in band" "$GODOT" --headless --path . --script verify/balance.gd
run "encounters: does a fight start from anywhere"     "$GODOT" --headless --path . --script verify/encounters.gd
run "special encounters: do solo loss/win contracts hold" "$GODOT" --headless --path . --script verify/special_encounters.gd
run "maze: do both walls rotate 90 degrees and meet their named targets" "$GODOT" --headless --path . --script verify/maze.gd
run "fight: play one to the end and come back"        "$GODOT" --headless --path . --script verify/fight.gd
run "goblin: does the grunt load and size correctly"  "$GODOT" --headless --path . --script tools/test_goblin.gd
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
