# PR #72 extraction ledger

## Purpose and rules

This ledger is the implementation contract for extracting the intended
player-facing work from raw PR #72 (`combat-ui-and-tutorial-updates`,
`87b1842`) into the release integration branch (`release/today-build` / PR
#74).  It compares that raw source with the #74 baseline `5069ed5`.

Raw #72 will remain unchanged as a review record.  Each focused extraction PR
targets `release/today-build`, is tested on its own, and is merged there before
the next slice begins.  Generated Godot sidecars (`*.import`, `*.uid`) and web
output are regenerated only from final source; they are not hand-ported.

**Disposition meanings**

- **Planned** — a real intended behavior which has not yet been ported.
- **Integrated** — the raw behavior is ported and verified in the target slice.
- **Ported equivalent** — a newer implementation provides the same player
  contract, with evidence linked in this table.
- **Explicit design decision** — two player-visible behaviors genuinely cannot
  coexist.  The decision, owner, and test evidence must be written here before
  a slice may merge.

There is deliberately no `Dropped` disposition for a real feature.  A
`Ported equivalent` must name the implementation and prove the contract; it is
not shorthand for "the old code was inconvenient."

## Baseline already in #74

The baseline includes only a narrow set of #72-equivalent tutorial safety
outcomes: tutorial Run lock, explicit Skip Tutorial, tutorial win/loss/retry
return paths, cleared camera override, and a forced-QTE contract.  It does not
yet contain #72's ability popups, visual tutorial treatment, Quick Read/
tooltip system, menu/spell/title work, or maze minimap UX.  Those remain
planned work below.

## Source-feature ledger

| #72 source change | Intended player-facing behavior | Destination slice / PR | #74 baseline equivalent | #70 / #73 interaction | Regression contract | Required evidence before merge | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `character_ability_popup.gd`, `character_ability_popup.tscn`, `game/world.gd` ability-popup hunks | A player is shown each diver ability in context, with the actual control and purpose, instead of having to infer it from a long text page. | 1 — `followup/tutorial-visual-onramp` | None. | Must coexist with #70's maze controls and #73's guardian encounters; it must not consume normal swim input or leave a modal behind. | Closing a popup restores steerable world input; every displayed control invokes a currently legal ability. | `verify/tutorial_ability_onboarding.gd`, `?onboarding=1` visual route, exact deployment. | **Ported equivalent** — `AbilityOnboarding` is World-owned/paged instead of raw #72's global popup, and its copy is derived from current ability behavior. |
| `game/pulse_text_effect.gd`, `game/battle.gd` Enter/Continue presentation hunks | The next tutorial action is visually legible and discoverable rather than static dense text. | 1 — `followup/tutorial-visual-onramp` | Raw text-based Continue exists; no pulse treatment. | Must not conflict with current forced-QTE timing or Skip Tutorial. | Continue is clickable and keyboard reachable; animation cannot block, duplicate, or auto-advance a step. | `verify/tutorial_continue_button.gd`; manual live-canvas review. | **Ported equivalent** — the visible `TutorialContinue` button pulses while the real narration wait is active and shares Enter's handler. |
| `content/tutorial_content.gd` tutorial copy/hint hunks, `game/battle.gd` tutorial captions | Tutorial text teaches the current action at the time it is needed and leaves deeper formula detail available on demand. | 1 — `followup/tutorial-visual-onramp`, with shared terminology consumed by slice 2 | Partial safety flow only; content is not equivalent. | GlassGoat owns final narration/intro text; temporary instructional copy must not overwrite that future work. | Instructions match real keys, oxygen/ability constraints, and the actual QTE outcome. | `verify/tutorial_ability_onboarding.gd`; manual page-by-page review. | **Ported equivalent** — four post-combat pages teach current swim, swap/sonar, grapple, and shockwave behavior; final narration/intro remains untouched. |
| `game/tutorial_result_popup.gd`, `game/battle.gd` tutorial resolution hunks | After a lesson, the player receives a clear result and next action rather than an ambiguous disappearance of the tutorial. | 1 — `followup/tutorial-visual-onramp` | A different result popup may exist, but no raw-#72 equivalence has been proven. | Must preserve #74's win, loss, retry, explicit skip, and world-return contracts. | Result UI never traps focus; success, retry, and exit each lead to the promised state. | `verify/tutorial_loss_choice.gd`, `verify/tutorial_skip.gd`, `verify/tutorial_ability_onboarding.gd`. | **Ported equivalent** — clearer retry/return labels, keyboard focus/Enter/Escape paths, and a one-time world-control handoff after win/skip/exit. |
| `verify/tutorial_exit.gd`, `verify/skip_tutorial_button_probe.gd`, `verify/tutorial_loss_choice.gd` | Automated proof for tutorial exit controls, skip discoverability, and loss recovery. | 1 — `followup/tutorial-visual-onramp` | Related #74 tests exist but need direct comparison before claiming equivalence. | Must test against the integrated UI, not a raw #72 fixture. | Every visible exit path is reachable and returns control to the world/title as labelled. | Existing exit/QTE/skip/loss tests plus `tutorial_continue_button`, `tutorial_ability_onboarding`, and `tutorial_onboarding_review_route`. | **Integrated** — retained #74 flows are exercised against the new overlay, including Retry-not-onboarding and one-time loss Exit handoff. |
| `game/tooltip_button.gd`, `game/battle.gd` tooltip/menu-button hunks | Move and status details are available on demand, so the normal combat screen stays readable without hiding important information. | 2 — `followup/combat-quick-read` | None. | Must work with #73 authored move descriptions and with mouse and keyboard; no hover-only critical facts. | Every move exposes damage, target, effect, duration, and self-risk by an accessible interaction. | `verify/combat_quick_read.gd`, narrow web viewport review, combat manual evidence. | **Integrated** — wrapped `TooltipButton` context is attached to every move; the visible result remains sufficient to choose without hover. |
| `game/battle.gd` target and all-target preview hunks | Before committing a move, the player can see relevant target stats/results, including all-target attacks. | 2 — `followup/combat-quick-read` | Current selection feedback exists, but raw-#72 parity has not been established. | Must reflect #73's Angler, Swordfish, Frilled Shark, and Tethys data, not obsolete Goblin assumptions. | Preview corresponds to the same target set and stats used by `CombatRules` when the move resolves. | `verify/combat_quick_read.gd` target-set differential; manual guardian fight. | **Integrated** — all-target hover now creates one current-stat panel for every affected enemy and clears them on every menu exit. |
| `game/battle.gd` formula-toggle removal/result-first hunks, `content/tutorial_content.gd` combat-copy hunks | A player can use quick outcome cues first, then inspect deeper calculation detail instead of reading formulas before every choice. | 2 — `followup/combat-quick-read` | Existing colors are promising but their semantics have not been formally verified. | Must retain GlassGoat's authored formulas and prevent a favorable cue for a zero, floored, or failed effect. | Quick Read colors and text agree with actual hit, damage, effect, duration, and self-cost. | `verify/combat_quick_read.gd`, `verify/glassgoat_discord_followup.gd`, manual 1280×720 guardian route. | **Ported equivalent** — the obsolete result/formula menu mode is removed; resolved outcomes stay visible and the same move exposes target, formula, effect, and current duration in contextual detail. No calculation changes were made. |
| `content/combat_moves.gd` UI metadata and tutorial-facing move hunks | Player move labels, help text, and displayed effects accurately explain the moves available in combat. | 2 — `followup/combat-quick-read` for display-only data; 5 for any formula change | No direct equivalence established. | Formula changes intersect GlassGoat's current stat/move table and #73 move roster. | UI-facing data may not silently change a move's actual calculation. | Per-move source mapping; UI-to-rule differential test. | Planned |
| `game/inventory_menu.gd`, `game/items.gd` inventory hunks | Inventory and item effects are understandable and usable from the game menus. | 3 — `followup/menus-spell-title` | None proven. | Must retain save/load and oxygen/item behavior in #74. | Opening/closing inventory preserves game control; applying an item changes the documented state exactly once. | Menu interaction test and title → game → pause → inventory browser route. | Planned |
| `game/spell_tree.gd`, `slot.gd`, `slot.tscn`, `verify/spell_playtest.gd` | Spells/slots are presented as a usable progression interface with a direct playtest of legality and effects. | 3 — `followup/menus-spell-title` | None proven. | Must not alter #73 formulas or #74 oxygen costs accidentally. | A displayed spell is selectable only when legal; selection preserves the calculation advertised by its UI. | Spell contract test, focused playtest, immutable deployment. | Planned |
| `game/title_screen.gd`, `project.godot` title/input hunks | A clear first-run and returning-player title/load flow, including appropriately readable slot presentation. | 3 — `followup/menus-spell-title` | #74 fixes title/HUD overlap but does not prove raw #72 title/slot behavior. | Must preserve existing saves and cold-start UI behavior. | Title has one clear first action; Load only presents valid state; entering and returning from game never overlaps world HUD. | Cold-start and returning-save browser routes at normal and narrow widths. | Planned |
| `game/maze_mini_map.gd`, `game/world.gd` minimap hunks | The maze map/navigation UI represents dynamic currents and changing corridors so players can orient without being guided into walls. | 4 — `followup/maze-minimap-ux` | None. | #70 owns geometry, H-operated opening, collision traversal, and reusable wall endpoints. | Map state before/after a wall/current shift matches actual reachable geometry. | Maze-state differential test, direct `?maze=1` traversal video/GIF and manual completion. | Planned |
| `game/combat_rules.gd` timing/formula hunks | Status/self-effects resolve in the intended order and moves obey the authored stat formulas. | 5 — `followup/combat-content-reconciliation` | Current #74 rules contain later changes; no raw equivalence presumed. | Directly conflicts with #73 authored formulas and enemy roster balance. | A move's displayed rule, resolved damage, status, duration, and self-risk all agree. | Per-move decision table and GlassGoat-table mapping. | Planned |
| `game/diver.gd` downed/revive/actor-lifetime hunks | Downed divers and revives remain visually coherent without freeing an actor that battle UI later references. | 5 — `followup/combat-content-reconciliation` | #74 has a freed-actor guard, not a proven equivalent revive presentation. | Must preserve #74 dead-actor regression protection and current party targeting. | Defeat, revive, retarget, and battle exit produce no freed-instance errors or orphan UI. | Death/revive lifecycle regression and console-clean battle run. | Planned |
| `content/enemy_moves.gd`, `docs/enemy-move-intake.md`, `verify/glassgoat_combat.gd`, `verify/glassgoat_discord_followup.gd`, `verify/pr54_merge_readiness.gd` | Enemy move definitions, source documentation, and tests match GlassGoat's approved enemy/stat design. | 5 — `followup/combat-content-reconciliation` | #74 carries #73 authored actors/moves but not yet a line-by-line raw-#72 reconciliation. | Must preserve Angler, Swordfish, Frilled Shark and boss identities; stale Goblin values cannot replace them. | Every changed move is mapped to its approved source rule or an explicit design decision. | Versioned move-table audit and focused authored-enemy fights. | Planned |
| `game/special_encounter_prompt.gd`, `verify/special_encounters.gd` | Special encounters are understandable, trigger reliably, and retain their intended prompt/flow. | 5 — `followup/combat-content-reconciliation` | #74 includes special-encounter work, but raw-#72 comparison is still required. | Must preserve #74's reviewable special-encounter build and avoid tutorial/maze control interference. | Prompt launches the intended minigame and exits cleanly to normal play. | Focused special-encounter gate plus browser route. | Planned |
| `game/tethys_boss.gd`, `verify/tethys_boss.gd` | Boss mechanics and status effects behave according to their approved encounter rules. | 5 — `followup/combat-content-reconciliation` | Tethys exists in #74; raw #72 behavior has not been reconciled. | Cannot regress boss facing/animation, target selection, or the existing boss direct-launch route. | Boss effects have correct targets, durations, and damage/poison semantics. | Boss decision-table test and `?boss=1` manual playtest. | Planned |
| `game/item_guardian.gd`, `game/items.gd` guardian-related hunks, `verify/encounters.gd` | Artifact collection has a deliberate guardian encounter and reward flow. | 6 — `followup/guardian-item-integration` | #74 has physical guardians, but raw #72's `ItemGuardian` behavior is a known conflict. | Required current contract: Angler guards shallows; Swordfish guards trench; neither site is preempted by random encounter. | Both sites physically exist, launch their correct one-enemy battle, grant their reward once, and remain protected from random preemption. | Guardian-site integration test, both manual site routes, explicit design record. | Planned — compatibility decision required |
| `project.godot` non-generated input/autoload/scene configuration not covered above | Supporting configuration loads each accepted UI component and preserves established controls. | The slice that owns the referenced component | No blanket equivalence. | A configuration port can silently alter actions or startup scene. | All referenced scripts/scenes/actions load, and existing world/combat controls remain bound. | Project-load gate plus action-binding smoke test. | Planned |

## Generated-artifact inventory

The following raw-#72 changes are intentionally not copied by hand because
they are generated output rather than product behavior:

- Every `*.import` entry in the raw comparison, including art textures,
  models, screenshots, icons, portraits, and evidence images.
- Script/scene sidecars such as `character_ability_popup.gd.uid`,
  `game/pulse_text_effect.gd.uid`, `game/tooltip_button.gd.uid`,
  `game/tutorial_result_popup.gd.uid`, `slot.gd.uid`,
  `verify/*.gd.uid`, and `tools/shoot_maze_traversal.gd.uid`.
- The final exported web output, including `docs/index.pck` and its associated
  generated files, which will be created once source slices 1–6 are merged.

Regeneration is still verifiable work: the final Vercel artifact's `index.pck`
SHA-256 must equal the committed export produced from the final #74 source.

## Required compatibility decisions

1. **Physical guardians versus raw `ItemGuardian` behavior.** The integrated
   build must retain both artifact-site encounters.  If any raw behavior would
   remove, replace, or bypass Angler at shallows or Swordfish at trench, the
   guardian integration slice must provide a tested coexistence design or an
   explicit team decision.
2. **Raw #72 formula changes versus #73 authored enemy content.** The
   reconciliation slice must make a per-move mapping to GlassGoat's approved
   table; neither older values nor UI-only text may silently become the source
   of truth.
3. **Tutorial completion semantics.** If raw #72 requires defeating an enemy
   before the tutorial ends while #74 permits a scripted completion path, the
   tutorial slice must select and test one player-visible contract rather than
   mixing both paths accidentally.
4. **Quick Read versus the former formula-menu mode.** Slice 2 keeps raw
   #72's result-first direction and removes the separate `Show formulas` /
   `Show results` state. Glassgoat's on-demand-detail requirement is retained
   through each move's wrapped contextual detail, which gives the exact target,
   calculation, effect, duration, and self-risk without a mode switch that can
   look frozen. `verify/combat_quick_read.gd` and
   `verify/glassgoat_discord_followup.gd` prove this is display-only and
   current-stat-driven; formula/rule decisions remain Slice 5 work.

## Evidence update log

| Slice | PR | Baseline SHA | Focused tests | Full gates | Browser/manual evidence | Immutable Vercel URL | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 — Tutorial presentation | [PR #79](https://github.com/Mhanna112-code/UnderwaterGame/pull/79) | `5069ed5` | `tutorial_continue_button`, `tutorial_ability_onboarding`, `tutorial_onboarding_review_route`, `tutorial_loss_choice`, `tutorial_skip` — green | Gameplay suite completed clean; stock browser sub-suite skipped because Playwright is absent | Manual canvas: `?onboarding=1` entry → four pages → dismiss → visible swim movement; stale beacon banner regression fixed | [exact SHA `5602585` preview](https://underwatergame-release-5069-review-ql7np2lm1.vercel.app/?onboarding=1), PCK SHA-256 `4fdf701bb6e62755512cd5b319789f0af3d2946dc3d9d947963d2b96e581ffce` verified deployed | Ready for slice review |
| 2 — Combat Quick Read | [PR #80](https://github.com/Mhanna112-code/UnderwaterGame/pull/80) | `27204ad` | `combat_quick_read`, `glassgoat_discord_followup`, `combat_feedback` — green | `verify/gates.sh` gameplay clean; stock browser sub-suite skipped because Playwright is absent | Manual guardian review at 1280×720: `?guardian=trench` → guardian → Attack → resolved choices → target → Back; no browser console errors. Move-local tooltip structure is also asserted by `combat_quick_read`. | Initial exact source `089d4e5` preview [deployed](https://underwatergame-release-5069-review-fmw5r1t4q.vercel.app/?guardian=trench) with matching PCK SHA-256 `a705a756bbd9d4715171350a553b153dea6517ba97ca81b9cada7790db11bc46`; final evidence-record commit rebuild pending. | Ready for focused PR review |
| 3 — Menus/spells/title | pending | pending | pending | pending | pending | pending | Planned |
| 4 — Maze minimap | pending | pending | pending | pending | pending | pending | Planned |
| 5 — Combat/content reconciliation | pending | pending | pending | pending | pending | pending | Planned |
| 6 — Guardian/item integration | pending | pending | pending | pending | pending | pending | Planned |
| 7 — Final generated export | PR #74 | pending | pending | pending | pending | pending | Planned |
