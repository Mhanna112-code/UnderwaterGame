# INT-07: initially downed divers return as usable fighters

October 4, 2026. Complete target reads carried forward: Battle, Diver,
CombatantStats, Items, SpellTree, InventoryMenu and MazeLevel. Their changed
revive/actor/queue/target consumers were re-read against 50b3b0a.

## Module contract

1. Surface: actual Attack/Items, paged move and ally-target buttons; Battle
   player_swing_staged and finished signals; same authoritative party resources.
2. Load-bearing comments: all party members receive actors, but initially downed
   actors are hidden. Item healing explicitly rebuilds their stage actor. Spell
   revival instead calls the fade-reversal clip, written for an actor that died
   while already visible. The two paths do not have equivalent initial state.
3. IO: seeded enemy roster/combat, animation and delayed send-home callbacks,
   asynchronous turn queue; no save writes. XP/known kit uses real learning APIs.
4. Branches: initially down versus death after spawning; potion versus Tidal
   Revival; three downed identities; absent/dead Bucky cannot cast his own revival;
   queue rebuilt after the current round, downed cards hidden then restored.
5. Types: normal 10-HP baselines, shared CombatantStats, equipped tidal_revival
   (cost 28 O2), potion inventory count. Actor.visible/scale/home are presentation,
   not substitutes for authoritative HP. No artificial enemy HP or outcome.
6. Existing gate calls play_revive directly after manufacturing HP and a fade. It
   cannot catch a pre-battle hidden actor staying invisible after an actual cast.

## Catalog

| Bug | Impact / plausibility | Oracle / status |
| --- | --- | --- |
| Revival compensates for a nonexistent death fade, enlarging/lifting an initially downed actor | High: restored fighter has incorrect stage scale/position | Valid actual spell red: scale/home fail; targeted repair green |
| Potion and spell restoration diverge or lose source resource identity | High: recovery works through only one menu path | Five generated supported identity/method cases green, actual next-turn attack required |
| Floating HP glyph fades but its black outline remains opaque | Medium: native healing result turns into dark unreadable ghost text | Valid red in both actual revival casts; fill/outline fade together after repair, five cases green |
| Bucky's support cast defaults to Hammer and its arms obscure the revived ally | High presentation: the successful action hides its own result | Reproduced at native 1x; delivered one-shot support gesture keeps both recipients visible after repair |

First case: actual earned Tidal Revival from Bucky onto initially downed Maxilani,
then a visible move by Maxilani on her next usable turn. Assert exact shared HP,
O2 cost, status-card visibility, mesh/actor visibility, stage-normal scale/home,
and actual player_swing_staged from the revived actor. Keep opponent alive using
normal non-damaging moves until the revived diver acts. A final win is not needed
to prove revival; a synthetic result is never emitted.

Self-critique: no private revival helper or animation invocation accepts the test.
Actual menu/turn/actor/resource observations reject wrong-but-stable hidden actors.
Single-enemy/direct Battle construction is an explicitly disclosed consumer fixture,
not a maze navigation or campaign-balance proof. No inflated HP, impossible kit,
perfect QTE or manipulated target stats. Supported cases are generated, not separate
hand-picked expectations derived from implementation branches.

## Skipped

Whole-route balance, battle UI framing at every size, newly downed animations,
downed exploration steering/caster guards and cold saves are separate acceptance.

## Evaluation

The first harness used a captured scalar for its signal observation; GDScript did
not update the outer value. Correcting that to a mutable observation dictionary
produced a valid red: usable turn and visibility passed, but scale and home failed.
Do not count the earlier extra usable-turn finding as a game defect. Spell revival
now uses the potion path's fresh stage actor instead of reversing a fade that never
occurred. Five supported target/method cases pass headless and native OpenGL; all
retain the authoritative resource, restore HP/card/normal scale/home and make an
actual next-turn attack. Spell casts pay 28 O2, potions spend one real item, no HP
max is inflated. All five native captures were inspected. Combat lifetime, relic
consumers and menu/title regressions also pass without engine/script errors.

Historical observation at d0fe9ed, subsequently repaired below: the transient +10 HP text appeared very
dark against water in the spell captures. The normal battle log is readable. This
did not invalidate actor restoration, and was not accepted as polished feedback.

Follow-up contract: Label3D's font modulate and outline_modulate are separate
colors. Fading only modulate.a leaves the outline fully black after the color
vanishes. The real-cast observer samples the actual transient HP label during its
fade and compares fill/outline opacity, rather than invoking the text helper or
pinning a chosen RGB/font size. Native captures still own readability acceptance.
Inspection also found duplicate stage restoration: feedback already rebuilds the
revived actor before the later reaction branch. Remove the redundant late rebuild,
keeping one restoration owner and the same actual-turn/resource oracles.

Production-speed native hold captures confirm a separate presentation defect:
the fallback Proto5 Hammer obscures the recipient with its telescoping arms.
Runtime asset inspection confirms Proto5_(Thumbs_P)(Start), a delivered 1.15s
one-shot gesture, separately from the Mid loop used for victory. Only Bucky's two
support moves use this gesture; attack mappings and the fallback remain unchanged.
Native timing must be 1x for one-second visual feedback: PNG/readback overhead at
8x consumed the text lifetime and caused an invalid missing-label finding. That
accelerated capture failure is excluded, not patched into production timing.

Follow-up evaluation: actual real-cast red reported two fill/outline mismatches.
The repaired lifetime retains a short readable hold, then fades both colors over
the existing total 1.1 seconds. Five headless and five native 1x recovery cases
pass; the two hold frames and all five later frames were inspected. Hold text is
readable and both support recipients remain visible. Only the two support moves
use the delivered one-shot gesture; Hammer attack framing is not accepted by this
check. The redundant late actor rebuild was removed because combat feedback is
already the single restoration owner. Clip inventory, three-rig animation checks,
eight actual relic battles, combat content and 20 effect-pool cases remain clean.
