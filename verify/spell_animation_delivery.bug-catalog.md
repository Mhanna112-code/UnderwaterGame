# Spell-animation delivery verification

Scope: `content/cast.gd` maps moves to clips; `Diver.play_clip()` resolves and
plays them on the existing imported mesh. The October 3 Dropbox deliveries
are partial animation updates, not complete replacements for these models.

## Interface and boundaries

- Public behavior: named learned moves play their authored animation; existing
  attack, swim, hurt, down and victory clips still work on the same mesh.
- IO: FBX import, animation-library resources, skeleton/bone track paths.
- Timing: non-looping casts run for their actual duration then return to idle.
- Branches: family-specific mapping, absent clip fallback, supplementary library
  resolution, support moves aimed at allies instead of enemies.
- Contract names come from the actual imported animation list and SpellTree
  display names, not the filenames alone. `Swift Strike` corresponds to the
  delivered `Swift Slash` action.

## Catalog and tests

| ID | Failure | Test and reason |
|---|---|---|
| SPELL-ANIM-01 | Nine delivered spell attacks silently use generic attacks. | Decision table over all nine delivered move/character pairs; require each authored clip to resolve and visibly change bone poses. Generic fallback cannot pass. |
| SPELL-ANIM-02 | Replacing a partial FBX loses existing swim or attack clips. | Preserve all motion and base-move playback on the actual runtime diver; existing `clips.gd` remains a second check. |
| SPELL-ANIM-03 | Valid clip names animate no mesh, or mismatched rig paths distort it. | Generator rejects unresolved nodes/bones; sample actual runtime skeleton and rendered skin. Compare source/target rest poses and inspect native captures rather than treating name resolution as visual proof. |
| SPELL-ANIM-04 | Long support casts obscure allies or leave the diver stuck. | Public battle move/target controls, actual heal/revive outcome, return to idle and next usable turn; rendered battle inspection at narrow/wide sizes. |

Tests assert authored delivery contracts and actual poses/outcomes. Cosmetic
renames require an intentional contract update; code-only refactors do not.

## Skipped / not established

- No bespoke clips were delivered here for Tidal Burst, Current Snare,
  Healing Current or Musashi's empowered Weaken/Slow. Keep working fallbacks;
  do not invent animation coverage.
- Latest Discord pin provenance is not established by the stale export.
- This does not rebalance moves, change learning rules, or prove a fully earned
  campaign playthrough.
- Native captures alone do not establish web export/Chrome behavior.

## Evaluation

- Caught: all nine moves used generic fallbacks before repair. All now resolve
  authored clips and change actual runtime poses; old motion/base-attack checks
  pass. No complete FBX replacement was needed.
- Characterized: source/target rest poses match except explicitly keyed `c_pos`.
  Two unbound Maxilani controls are omitted; source/ported body poses were
  compared and the working carried prop remains.
- Discovered: long support casts ran into the next turn; narrow target-menu
  allocation and status cards hid the gesture. Actual public-menu HP/Oxygen,
  return-to-idle and native skin/card overlap checks catch these. Three-party
  heal/revive also passes; injected kit is labelled, not an earning claim.
- Regression caught: fixed log height reduced 720x480 lab actors below their
  existing readability floor. Content-fitting narrow log restores a 223px
  stage and a 73px smallest actor without cutting the carrier notice.
- Invalid fixture rejected: the added companion case initially selected a
  nonexistent Palm Thrust label and failed with a script error. Corrected to
  the actual Precise Tap button and added an explicit missing-target failure.
- Native runtime evidence alone does not establish exported browser playback,
  all attack extremes, subjective pacing or full-game polish.
