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

## PR #88 hosted-playtest repair plan

This section converts the first complete hosted playtest into implementation
work. It is deliberately more specific than the prototype brief above: each
item says what was observed, the decision for the next build, the repair
approach, and the evidence required before calling it fixed. Do not use a
passing headless unit test as a substitute for the required browser evidence.

### Preserve the evidence that worked

The reviewer understood and enjoyed the short combat reading: green on the
party side is a benefit, red on the enemy is an opening, and red on the party
side is a cost or risk. The concise opening, contextual move hover text, and
the live QTE explanation made the first fight understandable. Preserve this
as the default on-ramp. Do **not** replace it with the full detailed tutorial
or make formula-reading compulsory.

Hover help is a useful enhancement, not a reason to put duplicate prose on
every screen. Add it only where a player has a real question in the moment:
move results/statuses, optional-special-encounter controls, and Combat Help
entries. Every hover-only explanation must also be reachable by keyboard or
plain visible text; a mouse tooltip may never be the sole instruction.

The quick-read must also not rely on colour alone. Keep the successful green /
red treatment, but pair every move-result colour with a short text/icon cue
such as `Benefit`, `Opening`, or `Cost`. This preserves the fast scan for all
players, including players on a weak display or those who do not distinguish
the two colours easily. Verify the result remains understandable in a
desaturated screenshot and through keyboard-only move selection.

**Implemented in this repair:** every live target preview now displays a
neutral-text `Quick Read` line under the selected move. It identifies damage
as a `Benefit`, an enemy stat decrease as an `Opening`, and a player-side
decrease as a `Cost`; it resolves formula amounts from the acting diver's
current stats. `verify/combat_quick_read.gd` and the windowed
`verify/semantic_quick_read_layout.gd` verify that this line is present and
in-bounds at 1280×720 and 1920×1080. A desaturated hosted capture remains a
final visual-evidence requirement.

The hosted build is a product surface, not merely an export artifact. Before
each review link is posted, cold-launch it in at least Chrome and Firefox,
verify title → New Game receives input without an extra focus click, and
record its build SHA in the PR. Slow first-load reporting alone is not a
gameplay bug, but a failure to reach an interactive title screen is.

### Required repair matrix

| Playtest observation | Next-build decision and repair | Required automated evidence | Required human evidence |
| --- | --- | --- | --- |
| After Electric Touch, the tutorial stat rows were cut off below the browser viewport. | Make the battle's lesson/UI responsive: reserve a minimum visible stage band, constrain the lower panel to the usable viewport, and place optional/detail content in a scrollable or collapsible region instead of pushing mandatory content off screen. The active instruction, Continue button, move choice, and current fighter must remain visible together. | Render/inspect 1280x720 and 1920x1080 battle layouts after each tutorial caption; assert positive stage height and that the Continue button, mandatory text, and active controls are within viewport bounds. | At normal browser zoom, a fresh tester can complete the lesson without any clipped required text or hidden control. |
| The QTE succeeded once and missed once, but both paths appeared to freeze on a blank battle screen. Pressing Enter eventually advanced without visible instruction. The dodge animation also read as a pole-spin rather than a dodge. | Treat this as a tutorial-handoff blocker. Trace the live success and miss paths at browser resolution, including the stage camera, bottom-panel height, animation selected, and input state. Keep a visibly labelled `Continue · Enter` button on any acknowledgement step; no progression may require an unseen keypress. Use a stable dodge/fallback reaction if the imported animation does not read as a dodge. | Drive the real moving QTE at production speed without injecting Enter. On both success and miss, assert the result card/button is visible, battle stage height remains positive, exactly one acknowledgement is required, and World regains movement afterward. Capture screenshots/GIF for both paths. | A first-time player can state what happened after the QTE, sees how to continue, and never interprets the screen as frozen. |
| Combat contact felt like it froze briefly. | Instrument the transition and distinguish expected attack timing from a stalled frame. Show a visible combat-result/turn state while any deliberate delay runs; eliminate avoidable blocking work. | Record frame/transition timing around first contact and QTE resolution; fail/report any unexplained long frame or a hidden busy state. | The fight feels like a deliberate animation/turn transition, not a hang. |
| The Frilled Shark filled half the stage and obscured Musashi. | Normalize each enemy using its visual bounding box, not only height. For elongated rigs, cap rendered horizontal extent as well as combat radius. Frame the camera from actual rendered bounds plus overhead bars, rather than the actor's capped engagement radius. **Implemented:** Frilled Shark now has a 3.4 m visual nose-to-tail cap while retaining its authored combat stats/reach; the battle camera reads actual mesh bounds. | `verify/frilled_shark_framing.gd` starts a normal World-to-Battle Frilled Shark fight and projects all imported mesh corners. At 1280×720 and 1920×1080 it requires the mesh inside the stage safe area, no more than 45% of stage width, and no party body point inside its screen bounds. Existing eight-fight `verify/stage_framing.gd` remains green. | Screenshot the Frilled Shark fight: it reads as larger than a normal fish, but every party member, enemy name/HP, and target cursor remains readable. |
| The first beacon was too close, and a visible beacon could coexist with an on-screen `Beacon • LEFT` label/glyph. | **Implemented:** every beat is now 8–12 seconds of ordinary swim from its predecessor. The tutorial's hovering arrow is retired on free-route handoff. The HUD label projects rendered beacon bounds, and appears only when those bounds are off screen. | `verify/progression_route_traversal_matrix.gd` checks distance budgets; `verify/route_guidance_visibility.gd` checks visible, partial, and off-screen camera cases against actual post/lamp bounds. | Hosted visual comparison remains required. |
| The player could be blocked approaching a beacon from one direction and had to backtrack around an unseen object. Existing traversal proof covered only the first direct leg. | **Implemented:** the deliberately lateral route avoids guardian sites and the corridor blockade rather than assuming them passable. | The matrix starts every beat from its prior location at left/center/right 5 m offsets, drives real `move_and_slide()` input, and waits for the live `Area3D` battle trigger—no target teleport or emitted signal. | Complete the hosted route without an invisible-wall moment, backing away to find a hidden route, or guessing which obstacle is solid. |
| Ignoring the route exposed an optional special encounter whose panels/controls were unintelligible because its ability had not been taught. | Keep it optional rather than treating it as an accidental punishment. Before entry, state that it is off-route, name the required diver/ability, show the exact input/objective, and offer `Practice controls`, `Enter challenge`, and `Leave`. Do not make its reward or failure necessary for the critical route. | Assert the prompt identifies optional status and has reachable practice/leave actions; execute the practice overlay and verify its controls are visible before the challenge starts. | A player who deliberately leaves the beacon understands why the challenge appeared and how to decline or learn it. |
| The deeper-stat tutorial exists in Combat Help but was not discoverable during the route. | Keep detailed instruction optional, but make it discoverable at the moment it matters: a compact `Need a refresher? Combat Help` affordance on route transitions and a just-in-time Swordfish/Urchin counter card. The counter card must teach only Electric Touch→Evasion and Weaken→Defense, then return control. | Assert the Help affordance exists on shallow/deep transitions, opens the detailed lessons, and returning restores the exact route state. Assert Deep 1 identifies Swordfish/Evasion and Deep 2 identifies Urchin/Defense. | A player can find the detailed lesson without knowing it exists beforehand and can explain each counter after the contextual prompt. |
| Shallows and Deep water looked equally bright; the route was a visually empty straight line of beacons. | Keep explicit beacons, but give the deep boundary a readable environmental change: denser fog/lower ambient range, a distinct colour/terrain silhouette, and landmarks that form one purposeful lateral dogleg per zone. The start area should not remain clearly visible from deep water, while the active beacon remains readable. This does not make maze work a dependency. | Capture fixed camera comparisons at the shallow/deep boundary; assert phase-specific environment values and route positions are not a single collinear chain. | A reviewer can tell they entered Deep water before reading the label and feels guided through a place, not sent down an empty straight ruler line. |
| A reported deep-water Angler conflicted with the intended Swordfish-first route. | The critical route must expose its beat and battle source in player-visible copy/logging: for example, `Route encounter — Deep 1: Swordfish`. Keep guardian/special encounters explicitly labelled as optional. Do not silently assume the report was wrong; reproduce it with route state capture before closing the finding. | Every route trigger logs objective id, roster, and source; run the full physical route and assert the declared roster sequence. A random distance roll must remain suppressed while a route objective is active. | A tester can say why a fight began and whether it was the main route or optional content. |
| The reviewer reached the lab with no usable items and then lost to 180-HP Tethys after reducing her only to 128 HP. It was unclear which checkpoint restored them. | Do not make an unvalidated Tethys fight the required completion gate. Until Glassgoat's final boss stats/encounter direction and a normal-party balance pass exist, the lab ends with a clearly labelled Mermaid Freak preview/reveal plus the temporary escape/core handoff. Keep `?boss=1` as a separate boss playtest. Reintroduce a mandatory boss only with an agreed balance target and no reliance on undisclosed items/healing loops. On any route loss, name the restored checkpoint and restore the documented state. | Add a normal-party boss simulator and a real hosted victory/defeat path before making Tethys mandatory. It must state whether items are intentionally unavailable. Loss/reload tests must assert the named checkpoint, position, route beat, party resources, and no duplicated encounter. | A tester understands whether Tethys is a preview or a winnable boss, never assumes hidden items are required, and knows exactly where/why they restarted after a loss. |
| Character naming was not immediately legible (`Maxilani`/`Maximilian` in the recording). | Audit display names across world HUD, turn cards, tutorial copy, Combat Help, and dialogue. Do not choose a new canon name without the content owner; make the approved name consistent once confirmed. | A string-consistency test covers approved display names in the relevant UI/data sources. | A player can identify the active diver without having to infer who `Max` is. |

### Verification sequence and merge gate

1. Repair the tutorial layout and QTE handoff first. Do not continue a full
   route playtest while a first-time player can reasonably believe the game
   froze.
2. Repair Frilled Shark sizing and camera framing, then capture a normal
   single-enemy battle at the review resolutions.
3. Repair/test physical traversal and guidance for **every** route beat before
   tuning presentation; synthetic trigger signals are insufficient evidence.
4. Add optional-content onboarding, route encounter-source labels, and
   discoverable detailed Combat Help without replacing the successful
   quick-read.
5. Add the Deep-water visual/route-shape pass and run another full hosted
   human playthrough.
6. Keep Tethys out of the mandatory completion claim until normal-party
   balance, loss/checkpoint behavior, and a manual hosted victory are all
   demonstrated.

The next build is merge-ready only when the first five steps have both green
automated evidence and fresh hosted screenshots/GIF/manual evidence. Tethys
may remain in the repository and query-string boss test, but it must be
labelled a preview rather than represented as a completed core-route boss
until step six is complete.

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
