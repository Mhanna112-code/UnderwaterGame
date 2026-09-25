#!/usr/bin/env bash
# Every check, in the order that makes a failure easiest to read: the ones
# that ask the art files a question first, then the ones that play the game,
# then the ones that need a browser.
#
# Exits non-zero if any gate does. Run it before pushing.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
# A review/export gate must be able to exercise the *exact* source export
# before generated docs/ is refreshed. CI and final release can use docs/;
# focused slices pass an isolated export directory through WEB_DIR instead.
WEB_DIR="${WEB_DIR:-docs}"
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

# Project-wide script classes are cached by the Godot editor and that cache is
# intentionally ignored. A brand-new worktree therefore needs one ordinary
# headless editor scan before individual `--script` gates can resolve classes
# such as Battle and Diver. Keep failure output, but avoid flooding a healthy
# gate log with import progress.
prepare_godot_classes() {
	local scan_log
	scan_log="$(mktemp "${TMPDIR:-/tmp}/underwater-class-scan.XXXXXX")"
	"$GODOT" --headless --editor --path . --quit >"$scan_log" 2>&1
	local scan_status=$?
	if [ "$scan_status" -ne 0 ] || grep -q "SCRIPT ERROR:" "$scan_log"; then
		cat "$scan_log"
		rm -f "$scan_log"
		return 1
	fi
	rm -f "$scan_log"
}

run "Godot class cache: can direct gates resolve project scripts" prepare_godot_classes

run "clips: does every clip the game asks for exist"  "$GODOT" --headless --path . --script verify/clips.gd
run "animations: does every rig change state correctly" "$GODOT" --headless --path . --script verify/animations.gd
run "swim: do they move, and animate while moving"    "$GODOT" --headless --path . --script verify/swim.gd
run "current: can full upstream input cross the flow" "$GODOT" --headless --path . --script verify/current_barrier.gd
run "Glassgoat combat: do the authored V2 rules hold" "$GODOT" --headless --path . --script verify/glassgoat_combat.gd
run "Glassgoat follow-up: do roster and result-first presentation match Discord" "$GODOT" --headless --path . --script verify/glassgoat_discord_followup.gd
run "combat Quick Read: do result choices, context, and all-target previews agree" "$GODOT" --headless --path . --script verify/combat_quick_read.gd
run "combat content: do timing and actor lifetime contracts hold" "$GODOT" --headless --path . --script verify/combat_content_reconciliation.gd
run "Tethys boss: does Glassgoat's final boss import and fight separately" "$GODOT" --headless --path . --script verify/tethys_boss.gd
run "combat feedback: are V2 results and target stats visible" "$GODOT" --headless --path . --script verify/combat_feedback.gd
run "defeated overhead: does dead UI leave with its actor" "$GODOT" --headless --path . --script verify/defeated_overhead.gd
run "balance: do casual and skilled policies clear the artifact route" "$GODOT" --headless --path . --script verify/balance.gd
run "core route contract: is one authored objective exposed in the declared order" "$GODOT" --headless --path . --script verify/progression_route.gd
run "core route battles: do declared route encounters build exact rosters" "$GODOT" --headless --path . --script verify/route_authored_battles.gd
run "core route checkpoint: do capstone saves restore full party and next objective" "$GODOT" --headless --path . --script verify/progression_checkpoint.gd
run "core route safe spaces: do all authored phases reject ordinary rolls" "$GODOT" --headless --path . --script verify/progression_safe_spaces.gd
run "core route playthrough: do real Battle victories advance every authored phase" "$GODOT" --headless --path . --script verify/progression_playthrough.gd
run "core route traversal: can normal swimming physically enter the first beacon" "$GODOT" --headless --path . --script verify/progression_world_traversal.gd
run "deep counter actors: does Swordfish/Sea Urchin counterplay change combat" "$GODOT" --headless --path . --script verify/sea_urchin_route_actor.gd
run "core route balance: do quick-read and skilled policies meet published bands" "$GODOT" --headless --path . --script verify/progression_balance.gd
run "opening packs: are first-route formation probabilities intentional" "$GODOT" --headless --path . --script verify/opening_pack_tuning.gd
run "sites: are item locations unmarked and physically reachable" "$GODOT" --headless --path . --script verify/sites.gd
run "encounters: does a fight start from anywhere"     "$GODOT" --headless --path . --script verify/encounters.gd
run "guardian zones: does the artifact encounter stay distinct" "$GODOT" --headless --path . --script verify/guardian_encounter_exclusion.gd
run "guardian/item integration: do claimed sites stay retired after save/load" "$GODOT" --headless --path . --script verify/guardian_item_integration.gd
run "intro beam: does entering its visible column start tutorial combat" "$GODOT" --headless --path . --script verify/intro_sequence.gd
run "tutorial QTE: does the first Angler swing show and accept the timing dodge" "$GODOT" --headless --path . --script verify/tutorial_qte.gd
run "tutorial exit: does a completed lesson win and return to world" "$GODOT" --headless --path . --script verify/tutorial_exit.gd
run "tutorial continue: can mouse users advance a live caption" "$GODOT" --headless --path . --script verify/tutorial_continue_button.gd
run "tutorial onboarding: does combat hand off world controls safely" "$GODOT" --headless --path . --script verify/tutorial_ability_onboarding.gd
run "tutorial onboarding review route: can a reviewer inspect its actual UI" "$GODOT" --headless --path . --script verify/tutorial_onboarding_review_route.gd
run "tutorial loss: can a player retry or safely exit to world" "$GODOT" --headless --path . --script verify/tutorial_loss_choice.gd
run "tutorial skip: does explicit skip restore the playable world" "$GODOT" --headless --path . --script verify/tutorial_skip.gd
run "menus/spells/title: do help, safe tutorial replay, review routing, and title composition hold" "$GODOT" --headless --path . --script verify/menus_spell_title.gd
run "persistence: do inventory and world rewards round-trip through a save" "$GODOT" --headless --path . --script verify/persistence.gd
run "environmental oxygen: can an empty tank still complete the route" "$GODOT" --headless --path . --script verify/environmental_oxygen.gd
run "special encounters: do solo loss/win contracts hold" "$GODOT" --headless --path . --script verify/special_encounters.gd
run "optional guardian prompt: are purpose, controls, practice, entry, and leave explicit" "$GODOT" --headless --path . --script verify/optional_guardian_prompt.gd
run "special dispatch: do swap and shockwave launch and restore" "$GODOT" --headless --path . --script verify/special_minigame_dispatch.gd
run "grapple intercept: can aimed shots clear every projectile" "$GODOT" --headless --path . --script verify/grapple_intercept.gd
run "grapple battle: do HP, camera, and actor contracts hold" "$GODOT" --headless --path . --script verify/grapple_battle_integration.gd
run "maze: do both walls rotate 90 degrees and meet their targets" "$GODOT" --headless --path . --script verify/maze.gd
run "maze traversal: can the player cross the opened CSGBox3D6/7 passage" "$GODOT" --headless --path . --script verify/maze_traversal.gd
run "maze completion: can a player reach and recover the final relic" "$GODOT" --headless --path . --script verify/maze_completion.gd
run "maze minimap: do walls and live currents match the navigation overlay" "$GODOT" --headless --path . --script verify/maze_minimap.gd
run "maze review route: does the direct playtest link enter MazeLevel cleanly" "$GODOT" --headless --path . --script verify/maze_review_route.gd -- --maze-playtest
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
run "Swordfish moves: does the authored three-move kit resolve as specified" "$GODOT" --headless --path . --script verify/swordfish_moves.gd
run "artifact guardians: do both models persist from map to one-enemy battle" "$GODOT" --headless --path . --script verify/artifact_guardians.gd
run "ordinary roster: do random encounters use both delivered enemies" "$GODOT" --headless --path . --script verify/ordinary_roster.gd
run "battle: does the fight screen build"             "$GODOT" --headless --path . --script tools/test_battle.gd

# The browser gate needs an exported build in docs/ and node with playwright.
# Skipped rather than failed when either is missing: a machine with only
# Godot should still get a useful run out of this script, and "playwright is
# not installed" is not a finding about the game.
if [ ! -f "$WEB_DIR/index.wasm" ]; then
	echo
	echo "=== webcheck: skipped, no $WEB_DIR/index.wasm to serve ==="
	skips=$((skips + 1))
elif ! node -e "import('playwright')" >/dev/null 2>&1; then
	echo
	echo "=== webcheck: skipped, playwright not resolvable ==="
	echo "    npm i playwright && npx playwright install chromium"
	skips=$((skips + 1))
else
	run "webcheck: does the build boot in Chromium" node verify/webcheck.mjs "$WEB_DIR" /tmp/gate-chromium.png
	run "maze navigation webcheck: does ?maze=1 visibly update after H" node verify/maze_webcheck.mjs "$WEB_DIR" /tmp/gate-maze-map-closed.png /tmp/gate-maze-map-open.png
	run "boss webcheck: does ?boss=1 open Glassgoat's fight" node verify/boss_webcheck.mjs "$WEB_DIR" /tmp/gate-tethys.png /tmp/gate-tethys-title.png
	run "guardian webcheck: does ?guardian=trench open the Swordfish Duelist" node verify/guardian_webcheck.mjs "$WEB_DIR" /tmp/gate-guardian.png
	run "special webcheck: does ?special=1 reach the chooser" node verify/special_webcheck.mjs "$WEB_DIR" /tmp/gate-special.png
	run "spell review webcheck: does ?spells=1 reach the real spell UI" node verify/spell_review_webcheck.mjs "$WEB_DIR" /tmp/gate-spell-review.png /tmp/gate-spell-review-title.png
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
