# PR100 authored combat turn regressions

## Contract and scope

Battle builds authoritative party/enemy stat resources, sorts an initiative queue,
then dispatches either usable player menus or an animated enemy action. Stun must
consume a whole scheduled turn without entering either action path. Goblin is the
shared enemy actor interface; only its Angler identity owns retaliation and Bite
history. Battle must feed real single/all-target player damage and resolved Bite
outcomes into that per-fight state. Forced tutorial/prologue targets, other enemy
species and special/boss handlers must keep their existing behavior.

## Ranked catalog

| ID | Failure | Severity | Cheapest effective test |
|---|---|---|---|
| TURN-01 | Helpers count stun but real dispatcher still opens menus/executes AI | High | Actual Battle initiative dispatch, both sides, durations 1–3 |
| TURN-02 | Skip counts twice, spends Oxygen, refills EVA or loses next healthy turn | High | Generated dispatcher cases; resource/UI witnesses |
| AI-01 | Angler forgets player damage, so low-HP Headbutt attacks wrong living diver | High | Real Battle attack buttons + joint selector across seeds |
| AI-02 | Resolved Bite misses never schedule Flash Blast, or reset leaks between fights | Medium | Real enemy turn + next decision, fresh-actor and streak witnesses |
| AI-03 | Angler restoration overrides tutorial target or other species | High | Forced-decision and subtype characterization; existing QTE/prologue gates |

## Self-critique / skipped

Queue fixtures isolate dispatch rather than replaying an entire campaign. AI selector
properties alone cannot prove Battle supplies history: supplement them with actual
attack-button damage and a resolved enemy Bite. No tests copy the production AI.
Keep RNG assertions about invariants, not a brittle exact sequence. Campaign balance,
retry/menu/maze regressions and visual polish are outside this focused patch; existing
route and presentation gates remain separate evidence, not claimed fixed here.

## Evaluation

TURN-01/02 failed against the original dispatcher (wrong active actor, no
countdown, unwanted EVA refill), then passed on both sides at durations 1–3
and for forced tutorial initiative. The missing AI interface failed separately.
GREEN exercises 128 decision seeds (50 probabilistic Headbutt witnesses), cumulative
damage, absent top dealer, half-HP boundary, Bite streak consumption, fresh fights,
forced targets and all four non-Angler species.

The live scene uses actual Multiple Knee Combo / Precise Tap buttons, both enemy
damage histories, a real missed Bite, party-wide Flash, actual Headbutt landing on
Musashi and a skipped victim turn. Temporarily disconnecting BOTH live damage
recording calls made this regression fail even though the actor-level properties
still passed; those mutation edits were removed. This catches the helper-only
false-positive that motivated the patch.

The screenshot is a controlled runtime witness (100-HP enemies kept alive for
history observations), not a claim about ordinary enemy stats or campaign balance.
The route simulator now calls production's joint AI and records production history
instead of silently retaining the retired weighted-only policy. Existing bands
pass: 90.4% casual / 100% skilled across 240 routes each; these are policy models,
not measured human success rates. No balance thresholds or gameplay numbers changed.

Fourteen surrounding combat/status/QTE/opening/revival/menu gates passed with no
Godot errors. Full integration gates, web refresh and unrelated tutorial retry/maze
work are not asserted complete by this focused patch.
