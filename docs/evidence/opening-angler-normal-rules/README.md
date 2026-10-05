# Opening combat correction

User report: opening guaranteed damage/hits and taught combat unlike the game.

## Root cause and change

The opening Angler overrode HP/STR/DEF/AGI/ACC/EVA, hid non-damaging moves and
rewrote move accuracy. Existing tests incorrectly enforced that design.
The correction retains the actual normal species-stat factory (including its
5–25% independent boosts), all three full move kits and ordinary combat turns.
Only HP is reduced to 3 versus the ordinary base of 5 (boost may round to 6).
Actual enemy defeat alone triggers Cordys, with no normal victory rewards.

`red.log` uses the new contract against the old source; eight genuine failures.
`buttons.log` uses real Attack/move/target buttons: all 11 base choices, twelve
accuracy/evasion/defense boundary fixtures, followed by real next-turn completion
after a nonlethal hit, utility and miss. Initiative-only solo fixtures put the
selected diver first; they are not claims about production turn order. Ordinary
three-diver turn order and complete handoff are covered by `journey.log` and
`real-loss.log`, with an isolated test save directory. No player's save changed.
`cordys.log` reruns the actual 15-choice stat/damage/status matrix and high-HP
survivors; ordinary rules, Quick Read and enemy-move gates are separately logged.

## Campaign balance remains unresolved

No damage multiplier was found in the opener. Its real cheats were zero enemy
stats, missing utility and inflated accuracy. Bucky's large powers are inherited:
Guard Bash 6 (+3 ACC), Heavy Kick 10 (+0 ACC), Haymaker 15 (-3 ACC), with STR 4
and ACC 1. Guard Bash can deal roughly 7–10 damage against a 5-HP, DEF-2 Frilled
Shark. The other two initially miss its EVA 2; after EVA is depleted Heavy Kick
can deal roughly 10–14. Thus preserving real combat does not equal balanced
combat. These scales/accuracy penalties need a separate evidence-driven tune;
this fix does not silently change the campaign, spell tree or encounter roster.

## Exact hosted proof

- Runtime source: `7ffc53141ef4d35375912d3e1763a54c40d5ffb3`.
- Browser harness follow-up: `d687efa` replaces old move-menu coordinates with
  visible-label selection. The initial browser run stalled at Musashi's menu
  because it clicked empty space at the old Y coordinate; it was a harness
  defect, not a combat-resolution defect (`browser/` preserves that failure).
- Deployment: `dpl_5n3DJkRfavmhBjRMwDbcQfPrTMeS`.
- Same review URL: https://underwatergame-opening-prologue-review.vercel.app/.
- PCK: 96,740,568 bytes; SHA-256
  `e87b5943b296b4b751b13989db67a109d3a6c0a2d4b85344a6fb3156b5b6b5f6`.
- `browser-corrected/`: ordinary title/New Game, complete movies, real swimming,
  visible Electric Touch 1 damage and 2/3 remaining HP, normal Musashi next turn
  and Precise Tap kill, Cordys actual 1 damage/80–78–76 retaliation, recovery
  and normal world. 111.656 seconds from New Game to control, no browser errors.
- Actual persisted completion/defaults and cold title Load return to the world
  without replay; native actual later-combat death/Restart/Load also passes.
- Inspected screenshots show readable full move menus, nonlethal feedback and
  retained normal turn control. No claim of campaign balance or all-game polish.
- Public main and secondary main aliases remain on
  `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`; only review alias changed.

An unlinked-directory CLI inspection unexpectedly auto-created the empty
`underwatergame-opening-prologue` project. It had no deployments; the exact new
project was deleted, confirmed 404, and the intended existing UnderwaterGame
link restored before deployment. No pre-existing project/save was removed.

Human balance/fun acceptance is not claimed by green arithmetic tests.
