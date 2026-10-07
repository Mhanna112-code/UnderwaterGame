# Dev Log - Oct 6

All changes since `9a3c28b`. Headless verify suites were re-run after each batch;
remaining failures are listed at the end.

## Battle

- **Pause screen removed.** The in-battle pause overlay (`combat_pause_overlay.gd`) and
  `audio_manager.set_paused` are gone.
- **Move buttons show the name only.** The second line under each party move
  ("Strength Damage 2 Bleed", "Restores 10 HP", ...) is gone. The power badge (top right)
  and O2 cost badge (bottom right) remain.
- **Move tooltips carry the details.** Target, Damage, status with its resolved amount
  ("Bleed 2"), Heal / Revive amounts, Debuff, Self Cost and Accuracy sections. Legacy
  power moves (Swift Strike, Heavy Kick, ...) now explain their damage. No summary line
  and no O2 line.
- **Red stat-loss line alignment.** Axe Kick / Multiple Knee Combo's red "EVA -3" line
  used its own font, size and position. It now matches the button's second line exactly.
  (Superseded by the name-only buttons for party moves, still used by other menus.)
- **Miss wording.** Stat-lowering and status moves (Weaken, Slow, Blinding Silt, Guard
  Break, Current Snare, Electric Touch, Scuba Stabbing, Flash Blast) now log
  "You use Slow, but Angler evades!" instead of claiming the stat dropped.
- **No running from bosses.** Run is shown but disabled ("No escape from a boss") in the
  Tethys and maze Cordys fights. Previously Tethys hid it and Cordys allowed it.
- **Evasion debuffs apply immediately.** Lowering Evasion now also cuts the target's
  current Evasion pool, not only after their next turn.
- **Bleed rule.** Only another Bleed move adds stacks (max 3 per fight); ordinary hits no
  longer add a stack.
- **Damage preview** handles the full-block case in the tutorial math text.

## Moves and enemies

- **Cordys (maze rematch):** +3 to every stat (HP 78, STR 5, DEF 4, AGI 5, EVA 5, ACC 6).
  Octo Stab and Electric Shooting each deal +2 flat damage.
- **Current Snare** lowers Evasion by 1 (was Agility by 3).
- **Move hint text:**
  - Guard Break: "Lowers target's defense by 3"
  - Exploit Opening: "A precise strike"
  - Weaken / Slow: "Lowers defense" / "Lowers agility"
  - Weaken Empowered / Slow Empowered: "Greatly lowers defense" / "Greatly lowers agility"
- **Spell text:**
  - Healing Current: "A strong current restores 10 HP." (hint "Restores 10 HP")
  - Mending Current: "...restoring 8 HP."
  - Tidal Revival: removed "Requires a Reef Plate."

## Tutorial and help

- **Bucky's tutorial turn** adds "This move has an Oxygen cost of 16 as shown in the
  bottom right corner."
- **Bleed help text** rewritten to the new stacking rule. Combat Help sections have
  spacing between them.
- **Combat Help** and every other overworld menu option are available in the maze.
  Dev mode marks Saving as seen.
- **New tutorial clips** installed (grapple and shockwave demos).
- **Tutorial clip recorder:** `tools/record_tutorial_clip.gd`.

## Saving

- **Autosave before return to title**, with an "Autosaving..." indicator and
  "Game will autosave first." on the confirm.
- **Autosave before each boss:** Tethys on entering the lab; the puppets and Cordys on
  their Yes prompt.
- **"Save your progress." banner** on every save point. The white "Maze Save Point"
  captions are removed.

## Maze and world

- **Random fights throughout the maze**, like the overworld (R toggles). The strong room
  is still a forced fight. Encounter rate 0.7.
- **Maze objective line** in the bottom left removed.
- **Ability key items** removed from the inventory list.
- **Sonar pulse ring** while sonar is on, centred on Maxilani's body.
- **Whirlpool particle column** (`game/whirlpool_column.gd`, `Whirlpool.column_visual`).
  A bottom particle bounces around the suction area; upper layers trail it, scaled
  1 + (1 - height ratio). `_delay_for()` is still a stub (returns 0), so the column
  currently moves as one stack.
- **Draft passages WIP** (`maze_draft_passages.gd`): `_current_whirlpool()` is in progress
  and not called yet. Its unfinished lines are commented out so the project compiles.

## Dev mode

- **Teleport** (`game/dev_teleport.gd`, dev mode only):
  - G opens a list of named places plus a clickable top-down map (wheel zooms,
    right-drag pans).
  - T jumps to where the camera is aiming.
  - Includes a Tethys unlock entry.
- **Return To Title** fixed in dev mode.

## Code

- Comments shortened across the codebase.
- Tests updated for the new rules and text: `encounters`, `campaign_goals`,
  `maze_review_route`, `maze_checkpoint_presentation`, `embedded_maze`,
  `glassgoat_combat`, `marc_status_contract`, `item_site_clearing`,
  `sonar_encounter_friction`, `tutorial_win_handoff`, `maze_special_sites`,
  `combat_quick_read`, `glassgoat_discord_followup`, `prologue_combat`.

## Known test failures

- `maze_cordys`: the scripted level-5 party now loses to the buffed Cordys. This is a
  balance signal, left failing on purpose.
- Already failing before these changes (also fail on a clean checkout):
  - `maze_review_route`
  - `maze_checkpoint_presentation` ("real entrance did not reach maze")
  - `sonar_encounter_friction` FR-2
  - `optional_training`
  - `maze_relic_consumers`
  - `tutorial_loss_choice`

## Open questions

- Remove the "a hit always deals at least 1" rule? If so, the 5-point full-absorb rule
  becomes redundant and the tutorial's Electric Touch (1 - 1) would deal 0.
- Should Weaken/Slow Empowered actually lower more than the base moves (both are 2 today)?
