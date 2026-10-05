#!/usr/bin/env bash
# Every check, in the order that makes a failure easiest to read: the ones
# that ask the art files a question first, then the ones that play the game,
# then the ones that need a browser.
#
# Exits non-zero if any gate does. Run it before pushing.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
GATE_TIMEOUT_SECONDS="${GATE_TIMEOUT_SECONDS:-240}"
TIMEOUT_BIN=""
if command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT_BIN="$(command -v gtimeout)"
elif command -v timeout >/dev/null 2>&1; then
	TIMEOUT_BIN="$(command -v timeout)"
fi
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
	if [ -n "$TIMEOUT_BIN" ] && [ "$(type -t "$1")" != "function" ]; then
		"$TIMEOUT_BIN" "$GATE_TIMEOUT_SECONDS" "$@" >"$gate_log" 2>&1 &
		local command_pid=$!
		local stopped_on_script_error=0
		while kill -0 "$command_pid" 2>/dev/null; do
			if grep -q "SCRIPT ERROR:" "$gate_log"; then
				# A SceneTree verifier can throw before reaching quit(), leaving
				# Godot alive forever. Stop immediately instead of waiting out the
				# full timeout; the captured error is already the useful evidence.
				kill "$command_pid" 2>/dev/null || true
				stopped_on_script_error=1
				break
			fi
			sleep 0.2
		done
		wait "$command_pid" 2>/dev/null
		local command_status=$?
		if [ "$stopped_on_script_error" -eq 1 ]; then
			command_status=1
		fi
	else
		"$@" >"$gate_log" 2>&1
		local command_status=$?
	fi
	cat "$gate_log"
	local script_error=0
	if rg -q 'SCRIPT ERROR:|Infinite loop detected' "$gate_log"; then
		echo "GATE ERROR: Godot reported a script error or a release-blocking infinite tween loop despite the exit status"
		script_error=1
	fi
	if [ "$command_status" -eq 124 ]; then
		echo "GATE ERROR: exceeded ${GATE_TIMEOUT_SECONDS}s timeout"
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
run "authored combat turns: do real stun skips and Angler damage/Bite history reach live Battle" "$GODOT" --headless --path . --script verify/authored_combat_turns.gd
run "Marc pause port: do all four tabs fit and block exploration without losing audio/training" "$GODOT" --headless --path . --script verify/marc_pause_presentation.gd
run "Marc popup port: do real battles defer lessons and resume surviving callers safely" "$GODOT" --headless --path . --script verify/marc_popup_ownership.gd
run "Marc status port: does authored Bleed persist/cap while timed statuses and readable units remain real" "$GODOT" --headless --path . --script verify/marc_status_contract.gd
run "Marc status layout: do all six multi-status cards fit through actual viewport resizing" "$GODOT" --headless --path . --script verify/marc_status_presentation.gd

run "opening migration: do all durable milestones normalize interrupted phases" "$GODOT" --headless --path . --script verify/opening_prologue_state.gd
run "opening video: are production and lab policies independent" "$GODOT" --headless --path . --script verify/opening_video.gd
run "opening video persistence: do success and decoder failure restore safely" "$GODOT" --headless --path . --script verify/opening_video_world.gd
run "opening trigger: does only actual horizontal swimming start once, without banking idle time" "$GODOT" --headless --path . --script verify/opening_prologue_trigger.gd
run "opening free swim: do idle and camera-only stay free before four seconds of real swimming" "$GODOT" --headless --path . --script verify/opening_prologue_free_swim.gd
run "opening world: are authored encounters protected and real-input reachable" "$GODOT" --headless --path . --script verify/opening_prologue_world.gd
run "opening Angler: do normal damage/miss/utility choices and real defeat preserve ordinary rules and rewards" "$GODOT" --headless --path . --script verify/prologue_angler.gd
run "opening Cordys: do actual stats, move effects and survivor outcomes remain real" "$GODOT" --headless --path . --script verify/prologue_combat.gd
run "opening Cordys: does the skinned actor preserve authored poses and facing" "$GODOT" --headless --path . --script verify/prologue_octopus.gd
run "opening mix: do cue envelopes preserve user preferences" "$GODOT" --headless --path . --script verify/prologue_audio_envelope.gd
run "opening split video: is one decoder retained silently across combat" "$GODOT" --headless --path . --script verify/prologue_cinematic.gd
run "opening cinematic edit: is the approved title ending retained without the monologue" "$GODOT" --headless --path . --script verify/prologue_cinematic_asset.gd
run "opening journey: do real moves reach atomic recovery and ordinary encounters" "$GODOT" --headless --path . --script verify/opening_prologue_journey.gd
run "opening fallback recovery: do death restart and title load preserve completed play without falsifying video viewing" "$GODOT" --headless --path . --script verify/opening_prologue_journey.gd -- --opening-fallback
run "opening real death: do enemy attacks and actual defeat preserve completed play across Restart and Load" "$GODOT" --headless --path . --script verify/opening_prologue_journey.gd -- --opening-real-loss
run "opening training continuity: does voluntary Skip preserve completion through actual later death" "$GODOT" --headless --path . --script verify/opening_prologue_journey.gd -- --opening-training-loss
run "opening save denial: does failed recovery retain the previous checkpoint and allow Retry Save" "$GODOT" --headless --path . --script verify/opening_prologue_journey.gd -- --opening-save-failure
run "checkpoint invalid load: do missing and malformed saves retain an actionable title instead of replaying opening" "$GODOT" --headless --path . --script verify/checkpoint_load_failures.gd
run "checkpoint slot switch: does denied replacement retain the active save and retry correctly" "$GODOT" --headless --path . --script verify/checkpoint_slot_switch.gd
run "optional training: do ignore, Retry, Return and Skip retain normal control" "$GODOT" --headless --path . --script verify/optional_training.gd
run "opening exploration: do Sonar/encounters enable at recovery and saved manual choices survive Load" "$GODOT" --headless --path . --script verify/opening_exploration_defaults.gd
run "menu audio comfort: is hover brief, rate-limited and subordinate to confirmations" "$GODOT" --headless --path . --script verify/menu_audio_comfort.gd -- --interaction --preferences
run "tutorial actual win: does menu replacement remain error-free and victory expose Continue" "$GODOT" --headless --path . --script verify/tutorial_win_handoff.gd
run "tutorial full lesson: do all five real guided moves and a real victory finish without infinite tweens" "$GODOT" --headless --path . --script verify/tutorial_win_handoff.gd -- --full-lesson
run "tutorial world win: does actual optional beacon entry and victory restore movement and persist both milestones" "$GODOT" --headless --path . --script verify/tutorial_win_handoff.gd -- --world-lesson

run "clips: does every clip the game asks for exist"  "$GODOT" --headless --path . --script verify/clips.gd
run "spell delivery: do authored spells deform the runtime rig without losing old motions" "$GODOT" --headless --path . --script verify/spell_animation_delivery.gd
run "spell support: do delivered casts heal/revive and return to usable turns" "$GODOT" --headless --path . --script verify/spell_support_delivery.gd
run "item message: do real rewards survive first-turn text without menu overlap" "$GODOT" --headless --path . --script verify/marc_reward_layout.gd
run "animations: does every rig change state correctly" "$GODOT" --headless --path . --script verify/animations.gd
run "swim: do they move, and animate while moving"    "$GODOT" --headless --path . --script verify/swim.gd
run "current: can full upstream input cross the flow" "$GODOT" --headless --path . --script verify/current_barrier.gd
run "Glassgoat combat: do the authored V2 rules hold" "$GODOT" --headless --path . --script verify/glassgoat_combat.gd
run "Marc Evasion Down: does a real status immediately cap remaining EVA without refilling or double subtraction" "$GODOT" --headless --path . --script verify/marc_evasion_pool.gd
run "Glassgoat follow-up: do roster and result-first presentation match Discord" "$GODOT" --headless --path . --script verify/glassgoat_discord_followup.gd
run "combat Quick Read: do result choices, context, and all-target previews agree" "$GODOT" --headless --path . --script verify/combat_quick_read.gd
run "combat content: do timing and actor lifetime contracts hold" "$GODOT" --headless --path . --script verify/combat_content_reconciliation.gd
run "initially downed combat: do real potions and earned revival restore normal actors, cards, resources and usable turns" "$GODOT" --headless --path . --script verify/combat_initially_downed.gd
run "Tethys boss: does Glassgoat's final boss import and fight separately" "$GODOT" --headless --path . --script verify/tethys_boss.gd
run "effect feedback: report actual EVA changes without inventing progress at zero or on a miss" "$GODOT" --headless --path . --script verify/combat_effect_feedback.gd
run "heavy payoff: can normal and earned heavy moves hit exhausted EVA, still miss unprepared EVA and spend real Oxygen" "$GODOT" --headless --path . --script verify/earned_heavy_slam.gd
GATE_TIMEOUT_SECONDS="${LAB_BALANCE_GATE_TIMEOUT_SECONDS:-600}" run "lab attainable victory: do three real earned-kit policies win through actual Battle outcomes" "$GODOT" --headless --path . --script verify/lab_boss_balance.gd
run "lab live route: do real guard victories, full film, Continue and boss victory carry rewards to level 3" "$GODOT" --headless --path . --script verify/lab_route_live.gd
run "deep-zone assets: do selected FBXs import with visible geometry and authored clips" "$GODOT" --headless --path . --script verify/deep_zone_assets.gd
run "lab door asset: is Glassgoat's separated door the exact visible entrance source" "$GODOT" --headless --path . --script verify/lab_door_asset.gd
run "lab exterior: does the rock shell conceal the office while preserving the entrance" "$GODOT" --headless --path . --script verify/lab_exterior.gd
run "deep-zone environment: are approved scenery sources visibly and safely placed" "$GODOT" --headless --path . --script verify/deep_zone_environment.gd
run "deep-zone blockers: do authored blocker actors use their real models, moves, and clips" "$GODOT" --headless --path . --script verify/deep_zone_blockers.gd
run "deep-zone blocker balance: are both mandatory fights approachable and meaningfully tactical" "$GODOT" --headless --path . --script verify/deep_zone_blocker_balance.gd
run "deep-zone Bomb Bot: does the full production fight survive attacks, victory, and world return" "$GODOT" --headless --path . --script verify/bomb_bot_battle.gd
run "deep-zone progression: does a real blocker victory level, learn, equip, and expose attacks" "$GODOT" --headless --path . --script verify/deep_zone_progression.gd
run "audio assets: do canonical Phoenix tracks import with reviewed duration and digest" "$GODOT" --headless --path . --script verify/audio_assets.gd
run "combat SFX assets: do reviewed derivatives import without raw reels" "$GODOT" --headless --path . --script verify/combat_sfx_assets.gd
run "combat SFX playback: do production combat results trigger overlap-safe audible feedback" "$GODOT" --headless --path . --script verify/combat_sfx_playback.gd
run "combat feedback: are V2 results and target stats visible" "$GODOT" --headless --path . --script verify/combat_feedback.gd
run "defeated overhead: does dead UI leave with its actor" "$GODOT" --headless --path . --script verify/defeated_overhead.gd
run "balance: do casual and skilled policies clear the artifact route" "$GODOT" --headless --path . --script verify/balance.gd
run "opening packs: are first-route formation probabilities intentional" "$GODOT" --headless --path . --script verify/opening_pack_tuning.gd
run "sites: are item locations unmarked and physically reachable" "$GODOT" --headless --path . --script verify/sites.gd
run "encounters: does a fight start from anywhere"     "$GODOT" --headless --path . --script verify/encounters.gd
run "guardian zones: does the artifact encounter stay distinct" "$GODOT" --headless --path . --script verify/guardian_encounter_exclusion.gd
run "guardian/item integration: do claimed sites stay retired after save/load" "$GODOT" --headless --path . --script verify/guardian_item_integration.gd
run "intro beam: does entering its visible column start tutorial combat" "$GODOT" --headless --path . --script verify/intro_sequence.gd
run "intro forward entry: does default forward swimming reach the visible tutorial target" "$GODOT" --headless --path . --script verify/tutorial_forward_entry.gd
run "open water: can a diver pass beside the visible entrance rocks" "$GODOT" --headless --path . --script verify/open_water_blockade.gd
run "legacy guidance: does the plate puzzle avoid competing with RouteState" "$GODOT" --headless --path . --script verify/legacy_highway_route_separation.gd
run "tutorial QTE: does the first Angler swing show and accept the timing dodge" "$GODOT" --headless --path . --script verify/tutorial_qte.gd
run "tutorial exit: does a completed lesson win and return to world" "$GODOT" --headless --path . --script verify/tutorial_exit.gd
run "tutorial continue: can mouse users advance a live caption" "$GODOT" --headless --path . --script verify/tutorial_continue_button.gd
run "input aliases: do Swap and narration accept additive controls without losing old keys" "$GODOT" --headless --path . --script verify/input_aliases.gd
run "tutorial onboarding: does combat hand off world controls safely" "$GODOT" --headless --path . --script verify/tutorial_ability_onboarding.gd
run "tutorial onboarding review route: can a reviewer inspect its actual UI" "$GODOT" --headless --path . --script verify/tutorial_onboarding_review_route.gd
run "tutorial loss: can a player retry or safely exit to world" "$GODOT" --headless --path . --script verify/tutorial_loss_choice.gd
run "tutorial skip: does explicit skip restore the playable world" "$GODOT" --headless --path . --script verify/tutorial_skip.gd
run "menus/spells/title: do help, safe tutorial replay, review routing, and title composition hold" "$GODOT" --headless --path . --script verify/menus_spell_title.gd
run "route state: does authored progression round-trip through its public contract" "$GODOT" --headless --path . --script verify/route_state.gd
run "deep-zone route: is the expanded dark route physically supported and state-driven" "$GODOT" --headless --path . --script verify/deep_zone_route.gd
run "deep-zone guidance: does water deepen continuously while the lab remains the main objective" "$GODOT" --headless --path . --script verify/deep_zone_guidance.gd
run "local world guidance: do lab and Bucky wall hints follow location, active diver and real wall destruction" "$GODOT" --headless --path . --script verify/local_world_guidance.gd -- --puzzle
run "lab route: do the Mermaid cutscene, Tethys handoff, recovery, and completion round-trip" "$GODOT" --headless --path . --script verify/lab_tethys_route.gd
run "deep-zone maze entry: does normal progression reach the current maze without a query flag" "$GODOT" --headless --path . --script verify/deep_zone_maze_transition.gd
run "maze campaign handoff: do six real entrance cases retain party, kit, inventory and progress" "$GODOT" --headless --path . --script verify/maze_campaign_handoff.gd
run "puzzle maze exit: does real plate completion and normal swimming enter the maze and return safely without lab victory" "$GODOT" --headless --path . --script verify/puzzle_maze_exit.gd
run "puzzle maze saved exit: do saved solved doors reopen and normal exit movement reach the maze" "$GODOT" --headless --path . --script verify/puzzle_maze_exit.gd -- --cold-load
run "maze secret continuity: do real E/Esc transitions retain resources, doors, walls and pending rewards" "$GODOT" --headless --path . --script verify/maze_secret_continuity.gd
run "maze checkpoint: do cold Load, failed writes and real defeat/Restart conserve saved puzzle and campaign state" "$GODOT" --headless --path . --script verify/maze_checkpoint.gd
run "maze checkpoint IO: do generated saves round-trip and malformed saves return an actionable title without mutation" "$GODOT" --headless --path . --script verify/maze_checkpoint_io.gd
run "maze checkpoint coordinates: do legacy/framed JSON restores preserve puzzle placement and replace pending rewards once" "$GODOT" --headless --path . --script verify/maze_coordinate_frame.gd
run "maze World return: do live exit and cold World save/re-entry retain party and independent maze/lab history" "$GODOT" --headless --path . --script verify/maze_world_return.gd
run "maze relic consumers: do real victories unlock owned campaign spells without using or consuming maze keys" "$GODOT" --headless --path . --script verify/maze_relic_consumers.gd
run "maze input ownership: do real map/save/swap keys stay exclusive while Marc's local encounter policy remains independent" "$GODOT" --headless --path . --script verify/maze_input_ownership.gd
run "Marc earned map: can real pre-map swimming reach/open the chest, use L and return without geometry or current shortcuts" "$GODOT" --headless --path . --script verify/marc_earned_map.gd
run "Marc chest ownership: do both chests block real actions but pause/resume safely for every diver" "$GODOT" --headless --path . --script verify/marc_chest_ownership.gd
run "Marc earned-map persistence: do actual save/cold Load/legacy Load preserve map, spent door keys and spell relics independently" "$GODOT" --headless --path . --script verify/marc_earned_map_persistence.gd
run "Marc map region: do generated real L/badge/closure cases respect acquired-map availability for every diver" "$GODOT" --headless --path . --script verify/marc_earned_map_region.gd
run "maze ready-door priority: does real E unlock first on the map, reach the door top and preserve Ctrl/current/key ownership" "$GODOT" --headless --path . --script verify/marc_map_door.gd
run "maze modifier: does Ctrl avoid sinking while Shift sinks in World and Maze" "$GODOT" --headless --path . --script verify/marc_current_modifier.gd
run "maze clockwise selection: do real arrow cycles obey geometry across generated discovery subsets" "$GODOT" --headless --path . --script verify/marc_maze_map_order.gd
run "maze map presentation: do actual overview/help widgets fit desktop and narrow viewports" "$GODOT" --headless --path . --script verify/marc_maze_map_presentation.gd
run "audio manager: does paired music hand off without overlap or stacking" "$GODOT" --headless --path . --script verify/audio_manager.gd
run "audio lifecycle: do title, world, battle, victory, boss, and defeat own one correct cue" "$GODOT" --headless --path . --script verify/audio_lifecycle.gd
run "audio settings UI: can players independently persist music and SFX volume/mute" "$GODOT" --headless --path . --script verify/audio_settings_ui.gd
run "persistence: do inventory and world rewards round-trip through a save" "$GODOT" --headless --path . --script verify/persistence.gd
run "environmental oxygen: can an empty tank still complete the route" "$GODOT" --headless --path . --script verify/environmental_oxygen.gd
run "special encounters: do solo loss/win contracts hold" "$GODOT" --headless --path . --script verify/special_encounters.gd
run "special dispatch: do swap and shockwave launch and restore" "$GODOT" --headless --path . --script verify/special_minigame_dispatch.gd
run "grapple intercept: can aimed shots clear every projectile" "$GODOT" --headless --path . --script verify/grapple_intercept.gd
run "grapple battle: do HP, camera, and actor contracts hold" "$GODOT" --headless --path . --script verify/grapple_battle_integration.gd
run "world grapple aim: is the first-person target unobstructed and safely restored" "$GODOT" --headless --path . --script verify/world_grapple_aim.gd
run "Marc light item grapple: do real layer-5 shots reel once to the shooter without changing anchor traversal" "$GODOT" --headless --path . --script verify/marc_orb_reel.gd
run "Marc exploration controls: do real F/E keys, all zero-Oxygen abilities, modal owners and help agree" "$GODOT" --headless --path . --script verify/marc_exploration_controls.gd
run "imported enemy presentation: are bounds and idle behavior durable" "$GODOT" --headless --path . --script verify/imported_enemy_presentation.gd
run "maze: do both walls rotate 90 degrees and meet their targets" "$GODOT" --headless --path . --script verify/maze.gd
run "maze current route: do normal movement and actual L/E/Ctrl+E traverse the first channel without bypassing collision or currents" "$GODOT" --headless --path . --script verify/maze_current_route.gd
run "Marc swirl spacing: do generated room geometries leave real column gaps rather than count-only improvements" "$GODOT" --headless --path . --script verify/marc_swirl_spacing.gd
run "Marc swirl route: can all three divers actually swim to the eye while orbiting hazards still damage on contact" "$GODOT" --headless --path . --script verify/marc_swirl_route.gd
run "world maze compatibility route: does actual spawn-to-Deep travel enter the maze with both lab guards undefeated" "$GODOT" --headless --path . --script verify/world_maze_route.gd
run "maze puppet approach: does real proximity/confirmation start puppets instead of lab Tethys" "$GODOT" --headless --path . --script verify/maze_puppet_trigger.gd
run "maze puppet waves: do real moves carry resources/effects into wave two with one final outcome and reward" "$GODOT" --headless --path . --script verify/maze_puppet_waves.gd
run "maze puppet reward: does a real carried-party win give one maze key without changing lab progress or restarting music" "$GODOT" --headless --path . --script verify/maze_puppet_reward.gd
run "maze Cordys: does the campaign rematch use normal combat and admit a real legal-kit win" "$GODOT" --headless --path . --script verify/maze_cordys.gd
run "maze Cordys sigil: does real contact start Cordys and preserve independent completion through a snapshot" "$GODOT" --headless --path . --script verify/maze_cordys_trigger.gd -- --real-win
run "maze completion: can a player reach and recover the final relic" "$GODOT" --headless --path . --script verify/maze_completion.gd
run "maze minimap: do walls and live currents match the navigation overlay" "$GODOT" --headless --path . --script verify/maze_minimap.gd
run "maze portrait lanes: does a real two-lane rung carry the portrait without changing direction" "$GODOT" --headless --path . --script verify/maze_latest_switch.gd
run "maze poster priority: does real E open the closer poster rather than the nearby switch" "$GODOT" --headless --path . --script verify/maze_latest_switch.gd -- --poster
run "maze review route: does the direct playtest link enter MazeLevel cleanly" "$GODOT" --headless --path . --script verify/maze_review_route.gd -- --maze-playtest
run "title: is cold launch readable and exclusive"     "$GODOT" --headless --path . --script verify/title_screen.gd
run "title audio: do Hover, Click, and Start Game match their exact menu interactions" "$GODOT" --headless --path . --script verify/title_audio.gd
run "Octopus intake: is the deferred visible candidate structurally characterized" "$GODOT" --headless --path . --script verify/octopus_asset_intake.gd
run "Octopus cutscene intake: is the deferred browser media candidate validated" "$GODOT" --headless --path . --script verify/octopus_cutscene_asset.gd
run "ability popup video: are tutorial clips playing and contained" "$GODOT" --headless --path . --script verify/ability_popup_video.gd
run "tutorial camera handoff: does the post-fight modal release mouse look" "$GODOT" --headless --path . --script verify/tutorial_camera_handoff.gd
run "merge readiness: is defeat exclusive and identity consistent" "$GODOT" --headless --path . --script verify/pr54_merge_readiness.gd
run "fight: play one to the end and come back"        "$GODOT" --headless --path . --script verify/fight.gd
# The only gate here that must NOT be headless. It measures where combatants
# land on screen, and a headless run gets a 64x64 window, which makes every
# screen-space number it produces meaningless. Skipped rather than failed
# where no display is available, so CI does not report a false problem.
if [ -n "${DISPLAY:-}" ] || [ "$(uname)" = "Darwin" ]; then
	run "Marc swirl native visibility: do revealed foreground rocks leave the controlled diver readable at column-aligned camera angles" "$GODOT" --path . --rendering-method gl_compatibility --script verify/marc_swirl_occlusion.gd
	run "maze overview native presentation: do title/help/legend fit actual rendered wide/short/portrait windows without HUD bleed-through" "$GODOT" --path . --rendering-method gl_compatibility --script verify/marc_maze_map_presentation.gd
	run "maze native ready-door input: do eligible door/current/wall priorities survive rendered frame dispatch" "$GODOT" --path . --rendering-method gl_compatibility --script verify/marc_map_door.gd
	for shape in 1280x720 720x480; do
		for phase in 0.35 0.65 0.8; do
			run "full-party attack presentation $shape/$phase: do all delivered attacks stay visible through the real gesture" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$shape" --script verify/spell_attack_delivery.gd -- "--phase=$phase"
		done
		run "spell support presentation $shape: do real cast silhouettes stay below status cards with a usable stage" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$shape" --script verify/spell_support_delivery.gd -- --capture-support
		run "full-party support presentation $shape: do actual three-diver cast and revival remain unobscured" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$shape" --script verify/spell_support_delivery.gd -- --capture-support --three-party
		run "item notice presentation $shape: does actual wrapped reward text fit above usable buttons" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$shape" --script verify/marc_reward_layout.gd
	done
	for shape in 1280x720 720x480 720x900 360x640; do
		run "maze checkpoint presentation $shape: do real P/mouse input expose unclipped save slots without overlapping gameplay captions" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$shape" --script verify/maze_checkpoint_presentation.gd
	done
	for shape in 1280x720 720x480 720x900; do
		run "opening discoverability $shape: do real nearby crystals, training text and both guardians remain visible/usable" "$GODOT" --path . --resolution "$shape" --script verify/opening_discoverability.gd
	done
	for shape in 1280x720 720x480 720x900 360x640; do
		run "recovery UI $shape: do actual saving/retry/Continue clicks and responsive copy remain correct" "$GODOT" --path . --resolution "$shape" --script verify/prologue_recovery_presentation.gd
	done
	run "Cordys narrow framing: do actual skinned vertices remain legible" "$GODOT" --path . --resolution 720x480 --script verify/prologue_stage_framing.gd
	run "stage framing: can you see the fight past the HUD" "$GODOT" --path . --resolution 1280x720 --script verify/stage_framing.gd
	run "stage framing narrow: does responsive combat remain visible at 720x480" "$GODOT" --path . --resolution 720x480 --script verify/stage_framing.gd
	run "tutorial status layout wide: do all status cards remain readable above long captions" "$GODOT" --path . --resolution 1280x720 --script verify/tutorial_status_layout.gd
	run "Marc status layout rendered: do duration labels remain readable at wide/narrow/short sizes" "$GODOT" --path . --rendering-method gl_compatibility --script verify/marc_status_presentation.gd
	run "tutorial status layout narrow: do all status cards remain readable above long captions" "$GODOT" --path . --resolution 803x893 --script verify/tutorial_status_layout.gd
	run "tutorial QTE handoff wide: do success and miss retain stage and Continue" "$GODOT" --path . --resolution 1280x720 --script verify/tutorial_qte_handoff_layout.gd
	run "tutorial QTE handoff narrow: do success and miss retain stage and Continue" "$GODOT" --path . --resolution 803x893 --script verify/tutorial_qte_handoff_layout.gd
	run "Frilled Shark framing wide: do real mesh bounds clear the party" "$GODOT" --path . --resolution 1280x720 --script verify/frilled_shark_framing.gd
	run "Frilled Shark framing narrow: does the long rig remain readable" "$GODOT" --path . --resolution 720x480 --script verify/frilled_shark_framing.gd
	run "lab composition wide: does the Broken Office contain a readable Tethys fight" "$GODOT" --path . --resolution 1280x720 --script verify/lab_battle_composition.gd
	run "lab composition narrow: is the Tethys arena still readable at 720x480" "$GODOT" --path . --resolution 720x480 --script verify/lab_battle_composition.gd
else
	echo
	echo "=== stage framing and lab composition: skipped, need a display ==="
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
	# This gate includes the complete opening, two cold boots and two actual
	# enemy-caused defeats. Keep its process budget separate from the harness's
	# unchanged 120-second opening acceptance limit.
	GATE_TIMEOUT_SECONDS="${OPENING_DEATH_GATE_TIMEOUT_SECONDS:-420}" run "opening browser idle/death: does idle stay free, swimming start once, and real deaths/Restart/cold Load retain completion" env OPENING_TIMING_ONLY=1 OPENING_IDLE_RECHECK=1 OPENING_SAVE_RECHECK=1 OPENING_DEATH_RECHECK=1 node verify/opening_webcheck.mjs "$WEB_DIR" /tmp/gate-opening-prologue
	run "opening browser storage denial: does rejected IndexedDB completion block Continue and recover through Retry" env OPENING_STORAGE_FAILURE=1 OPENING_SAVE_RECHECK=1 node verify/opening_webcheck.mjs "$WEB_DIR" /tmp/gate-opening-storage-denial
	run "webcheck: does the build boot in Chromium" node verify/webcheck.mjs "$WEB_DIR" /tmp/gate-chromium.png
	run "audio webcheck: does a trusted New Game click unlock browser audio" node verify/audio_webcheck.mjs "$WEB_DIR" /tmp/gate-audio.png
	# The retained historical M/H canvas-difference check can pass on ambient
	# animation despite doing nothing. Current L-map proof needs an identified
	# export; don't silently accept a stale generated docs pack.
	if [ -f "$WEB_DIR/build-info.json" ]; then
		run "identified feedback export: do served checksum, ordinary title and real L-map agree" node verify/maze_feedback_webcheck.mjs "$WEB_DIR" /tmp/gate-maze-feedback
	else
		echo "=== identified maze feedback webcheck: skipped, no build-info.json ==="
		skips=$((skips + 1))
	fi
	run "boss webcheck: does ?boss=1 open Glassgoat's fight" node verify/boss_webcheck.mjs "$WEB_DIR" /tmp/gate-tethys.png /tmp/gate-tethys-title.png
	run "guardian webcheck: does ?guardian=trench open the Swordfish Duelist" node verify/guardian_webcheck.mjs "$WEB_DIR" /tmp/gate-guardian.png
	if [ -x /tmp/underwater-screen-ocr ]; then
		GATE_TIMEOUT_SECONDS=300 run "Bomb Bot browser progress: do actual mouse actions reach enemy attacks, victory and restored World controls" node verify/bomb_bot_browser_progress.mjs "$WEB_DIR" /tmp/gate-bomb-progress
		if [ -f "$WEB_DIR/build-info.json" ]; then
			run "delivered spell browser: do real world input and mouse targeting animate/resolve an authored cast" node verify/spell_animation_browser.mjs "$WEB_DIR" /tmp/gate-spell-animation
		else
			echo "=== delivered spell browser: skipped, no identified export ==="
			skips=$((skips + 1))
		fi
	else
		echo "=== Bomb Bot browser progress: skipped, native OCR helper unavailable ==="
		skips=$((skips + 1))
	fi
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
