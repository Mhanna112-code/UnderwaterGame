# Temporary next-build progression brief

**Status:** temporary implementation brief, based on the meeting discussion at
approximately 20:03–20:31. It is not final narrative, final level design, or
a replacement for Glassgoat's authored combat tables. Replace this brief with
an approved design document after the next playable build is reviewed.

## Purpose

Build and test the game's core short-form route: the divers descend through
increasingly dangerous water, retrieve the core from a laboratory, and face
the Octopus while escaping. The route should demonstrate the combat system
without requiring a large story campaign.

## Scope boundary

This build owns the combat-and-progression route below. The maze, arena, and
their geometry/minimap work are not dependencies for it; they are separate
work. A maze may be connected as a non-blocking branch only if playtesting
shows that it is fun, passable, and does not interrupt the core route.

Final cutscenes, final narration, and Glassgoat's unfinished asset deliveries
are also outside this brief. Use concise placeholders at their transition
points until their authored replacements arrive.

## Player route

| Phase | Player objective | Guidance | Combat purpose | Transition |
| --- | --- | --- | --- | --- |
| Arrival / tutorial | Learn the minimum movement and combat-reading skills. | Direct light beacon or arrow. | Teach the player that accuracy, evasion, defence, and effects matter. | Player may enter the shallow route. |
| Shallows | Travel deeper and win basic fights. | Direct light beacons/arrows; the stated military context permits explicit guidance. | Anglerfish and Frilled Shark are forgiving: a player can experiment with attacks and see animations without a strict solution. | A save point precedes an authored capstone fight. Winning it opens the deeper route. |
| Deep water | Apply the counter-stat lesson. | Direct light beacons/arrows remain primary. Depth/darkness may communicate increasing danger, but is not the sole navigation system. | Swordfish tests evasion reduction. Sea Urchin tests armour reduction. | A save point precedes an authored capstone fight assembled from enemies already introduced in the zone. |
| Laboratory | Reach the core and discover that the underwater facility created dangerous experiments. | Placeholder story beat until final cutscene/narration arrives. | Mermaid Freak and/or defence robots can establish the facility's danger; their exact encounter order is a content decision for the prototype. | Acquiring the core starts the escape. |
| Escape | Leave with the core. | Clear exit direction and a placeholder transition. | The Octopus is the final boss; it needs manual balance testing rather than extrapolation from ordinary enemies. | Win: temporary ending/cutscene placeholder. |

### Capstone-fight rule

Each zone ends with a **designed, harder but beatable** encounter after a save
point. The meeting used examples such as one Anglerfish/one Frilled Shark in
ordinary fights and a mixed multi-enemy fight at the end of a zone. Those are
examples, not final counts. Progression is gated by the authored capstone, not
an arbitrary number of random encounters. The meeting did **not** decide
whether ordinary encounters inside a zone are fixed, random, or mixed; that is
a prototype choice requiring playtest evidence.

## Combat contract

- Combat is intentionally short and punitive. Stat loss changes the options
  available for the rest of the **current fight**, not permanently across the
  campaign.
- Do not add healing or teammate-buff loops merely because other RPGs use
  them. Any such addition requires a separate design decision.
- Basic enemies must be broadly defeatable by experimentation. Specialized
  enemies should become fair only after the player uses their counterplay.
- **Swordfish = high evasion** and requires evasion reduction / reliable-hit
  strategy. **Sea Urchin = high armour** and requires armour reduction. The
  meeting transcript briefly swaps those labels; retain this mapping unless
  Glassgoat explicitly corrects it.
- Player stats are sourced from `Group_StatsV2`. Enemy stats/moves are sourced
  from Glassgoat's later enemy-stat and move tables. If code differs from
  either, record the discrepancy rather than silently selecting a value.

## Selected next-build decisions

These are deliberate prototype decisions, not questions to reopen during
implementation. Their job is to produce a short route that is enjoyable on a
first play and cheap to evaluate in a real build.

### 1. Teach the quick-read, then let the player play

The opening combat lesson has one primary message: **green means the move
improves the current situation; red means it creates an immediate cost or
risk**. The player makes one safe, highlighted choice and sees the result.
Detailed formulas, status descriptions, and every starting move remain
available from optional Combat Help; they are not a five-move mandatory
lecture before free play.

After that first win, the world resumes at the first shallow-water beacon with
one objective: **“Shallows — follow the beacon.”** It does not open another
full-screen menu, require sonar, or expose several competing destinations.

### 2. Use one visible route guide, not a map of chores

The critical path uses exactly one bright next beacon and a matching directional
arrow when the beacon is off-screen. Reaching an objective replaces it with the
next one. Beacons are the primary navigation language; darkness/depth is mood
and a danger signal, not a navigation puzzle.

Sonar remains useful for optional salvage/guardian discovery and the minimap,
but it is never required to find or progress through the core route. The
existing tutorial copy that says sonar is the *only* way to find objectives
must be changed before this route ships.

### 3. Make every mandatory fight authored in the first vertical slice

The core route has no random encounter rolls. That removes ambiguity about why
a fight started, protects tutorial and boss pacing, and lets a reviewer replay
the same lesson. The existing 8–16 m / 50% random system may remain in future
optional exploration water, but not in the route corridor, checkpoints,
puzzle/guardian spaces, lab, or boss approach.

Ordinary enemies are **not** placed in the open world merely to point at the
route. The meeting's current direction is to stage only bosses visibly; a
beacon/arrow and a clear route-beat label explain ordinary authored fights.
Whether ordinary visible enemies return is a post-playtest decision, not a
requirement for this build.

| Route beat | Encounter | What it teaches |
| --- | --- | --- |
| Opening lesson | Scripted single Angler; no campaign-loss state. | Read a green/red result and make one meaningful move choice. |
| Shallows 1 | One Angler. | Experiment safely with ordinary attacks/effects. |
| Shallows 2 | One Frilled Shark. | A second basic foe and a visible enemy turn. |
| Shallows capstone | One Angler + one Frilled Shark, after a rest beacon. | Target priority and the first two-enemy fight; never a four-enemy surprise. |
| Deep 1 | One Swordfish. | Use Maxilani's Electric Touch to reduce Evasion, then attack. |
| Deep 2 | One Sea Urchin. | Use Musashi's Weaken to reduce Defense, then damage it. |
| Deep capstone | One Swordfish + one Sea Urchin, after a rest beacon. | Combine both counter-stat lessons. |
| Lab | One authored Mermaid Freak boss when its encounter is ready. | The laboratory's danger is a memorable encounter, not another random pack. |
| Escape | Octopus final boss when its delivered rig/attacks are ready. | Final encounter; no ordinary encounters can interrupt it. |

Defence robots remain environmental storytelling or optional content until they
have a distinct, tested combat role. They do not expand the critical route by
default.

### 4. Make checkpoints generous between fights, strict within fights

Every capstone beacon automatically writes a checkpoint when entered and
visibly restores party HP/Oxygen. It must say **“Checkpoint secured — party
restored”** so the player understands both outcomes. A victory also writes the
next checkpoint. There is no player-controlled heal/buff loop inside combat:
the party must live with a poor tactical choice until that fight ends.

This is deliberately forgiving at the campaign layer and demanding at the
combat layer. It prevents a short game from turning a previous, unrelated
fight into an unwinnable capstone while preserving Glassgoat's fight-long
attrition philosophy.

### 5. Tune for strategy recognition, not brute-force punishment

The initial quantitative targets are intentionally broad enough for human
feel-testing, but narrow enough to reject a broken build:

| Scenario | Quick-read player | Skilled player | Required contrast |
| --- | --- | --- | --- |
| Tutorial and either single basic fight | At least 90% win rate; no campaign-ending failure. | At least 95%. | A first player can learn without grinding. |
| Shallows capstone | 80–95%. | At least 95%. | Two enemies create pressure without a wall. |
| Deep single-enemy lessons | At least 80% after the contextual prompt. | At least 95%. | The named counter move materially improves the result. |
| Deep capstone | At least 70%. | At least 90%. | Using both counters beats a damage-only policy by at least 25 percentage points. |

“Quick-read” is a new simulator policy: it selects moves whose *actual*
resolved result weakens the enemy side and avoids a red self-cost, rather than
assuming a player reads formulas. It is the policy that validates the colour
language players already found intuitive. A skilled policy may use the full
move/stat detail. Until those policies exist, current generic `casual` route
numbers must not be presented as proof that this designed route is balanced.

### 6. Use short, skippable transition cards

Until Glassgoat delivers narration/cutscenes, each zone transition gets a
single title, one sentence of context, and an explicit **Continue** button.
It may pause the handoff, but must never cover the active game HUD after the
player continues. No card may be needed to understand controls or combat
counterplay.

## Verification contract for implementation

Implementation must expose a small public route-state contract (for example,
phase, objective id, checkpoint id, encounter policy, and an
`objective_changed` signal). Tests must consume that contract or visible UI
state rather than assert private helper names.

| Contract | Automated proof | Human proof |
| --- | --- | --- |
| Tutorial handoff | Complete the real tutorial win path; assert free world input, one shallow objective, and no battle/overlay left behind. | A first-time player can state the next action within 10 seconds. |
| Route guidance | At every route phase, assert exactly one critical objective is active and its beacon/arrow is available. | A reviewer follows the primary hosted build without query-string shortcuts. |
| Authored encounters | Across many seeded movement/encounter checks, assert the critical path produces only the listed fights in order. | Reviewer can tell why each combat began from its route beat, without ordinary enemies serving as route markers. |
| Counter lessons | Differential combat tests show Electric Touch makes Swordfish hittable and Weaken makes Sea Urchin damageable; the displayed colour/result must equal the resolved combat result. | Player can explain what changed after using each counter. |
| Checkpoint recovery | Save/reload immediately before and after each capstone; assert location, unlocks, full party resources, and no duplicated/replayed encounter. | Lose a capstone once and restart without replaying prior route content. |
| Difficulty | Seeded quick-read, damage-only, and skilled policies meet the bands above. | At least five fresh-player runs record route clarity, win/loss reason, and frustration point. |
| Presentation | Browser/UI regression verifies transition dismissal returns to a usable world without HUD overlap. | Screenshots/GIF plus one complete manual hosted run show each handoff. |

## First playable implementation

1. Make the shallow route playable with direct beacons/arrows, basic enemy
   encounters, a checkpoint, and a fixed capstone fight.
2. Add the deeper route with the Swordfish and Sea Urchin counter-stat tests,
   then a checkpoint and a fixed capstone fight using only already-taught
   enemies.
3. Add temporary laboratory/core/escape transitions; do not block on final
   narrative or cutscenes.
4. Keep maze/arena entry points non-blocking for route completion. A tested,
   non-annoying maze may be offered as an optional branch.
5. Add the Octopus to the final escape only after its delivered asset and
   animations are integrated and its encounter has been manually tested.

## Done conditions for the next build

- A new player can follow the route without relying on sonar or guessing the
  next destination.
- The player can reach and defeat a shallow basic encounter by trying normal
  attacks.
- A player who ignores evasion/armour counterplay receives understandable
  failure feedback against Swordfish/Sea Urchin; using the intended counter
  changes the result.
- Zone progression comes from a visible checkpoint plus authored capstone
  fight, not opaque random-fight counts.
- The route reaches a temporary lab/core/escape sequence without requiring
  maze completion.
- A human reviewer can use a hosted playtest link to enter each route phase
  and verify its guidance, encounter, checkpoint, and transition.
- Tests cover the move effects and zone/capstone sequencing. Manual playtests
  cover clarity, frustration, and actual boss feel.

## Prototype choices that should be shown, not debated first

- Exact beacon placement, route length, ordinary encounter counts, capstone
  lineup, checkpoint presentation, and placeholder transition text.
- Whether a completed, non-annoying maze branches off the route in this build.
  It does not block this build or gate its critical path.
- Exact cutscene wording and art direction, pending Glassgoat's authored work.

## Open intake, not a build blocker

- Final Octopus damaged/hit animation and final presentation.
- Final authored cutscenes/narration.
- Final laboratory/environment pieces.
- Any explicit correction by Glassgoat to player/enemy stat tables or the
  Swordfish/Sea Urchin counter mapping.
- Whether ordinary encounters within a zone are fixed, random, or mixed.
