# Underwater Game — preliminary design and proof map

**Status:** working design map for Marc's fuller design documents. It records
what the game currently does, what the team has proposed to test, and what is
still a decision or an undelivered asset. It is not a merge approval, final
narrative, art-direction sign-off, or replacement for Glassgoat's authored
combat tables.

**Source date:** 26 September 2026. This map was assembled from the game
source, the open GitHub issues, the combat/art intake records, and the meeting
that produced `TEMP-next-build-progression-brief.md`.

## How to read this document

Every feature is assigned one of four states:

| State | Meaning |
| --- | --- |
| **Implemented** | Present in current source. It may still need human acceptance. |
| **Prototype / playtest candidate** | Implemented on a branch or proposed for a build so the team can learn from a playtest. It is not a final design decision. |
| **Decision required** | The team has competing or incomplete direction. Code must not silently choose the answer. |
| **Not delivered / deferred** | The feature needs an authored asset, text, balance target, or explicit scope decision first. |

The current `main` branch is the only merged baseline. PR #88's authored-route
work is an **open prototype**, not a claim that its route, temporary art, or
balance is already accepted. Query-string review routes are test access, not
additional player progression.

## Player promise and core loop

### Current working promise

The player commands a three-diver party in an underwater world. They navigate
to meaningful places, use party abilities and combat counterplay, win fights
or optional challenges, gain access to deeper content, and eventually escape
with the laboratory core. The game should be readable first and strategically
deep second: players can use clear immediate outcomes, then inspect full stats
and formulas when they choose.

### Proposed short-form loop to test

1. See one clear next destination.
2. Travel there using ordinary swimming and party-world abilities.
3. Enter a deliberate encounter or puzzle whose purpose is clear.
4. Read the combat result, choose a response, and learn a useful counter.
5. Gain a checkpoint, an item, access, or new route information.
6. Enter a harder area that reuses the learned tool in a new combination.

This loop is a **prototype hypothesis**, not a settled release design. The
team still needs to decide which minigames genuinely serve it and whether
ordinary encounters are visible/avoidable rather than random. See [#49](https://github.com/Mhanna112-code/UnderwaterGame/issues/49) and [#8](https://github.com/Mhanna112-code/UnderwaterGame/issues/8).

## Game structure

| Segment | Player purpose | Current state | Evidence / boundary |
| --- | --- | --- | --- |
| Title and first action | Begin a new run without world HUD noise. | **Implemented** | New Game is primary; Load appears only once a save exists. Final intro prose is not approved. [#58](https://github.com/Mhanna112-code/UnderwaterGame/issues/58) owns narrative. |
| Opening combat lesson | Learn the immediate meaning of benefit, opening, and cost; make one useful choice. | **Prototype / playtest candidate** in PR #88 | Current branch has a short Quick Read lesson, optional detail, QTE outcome copy, skip/loss paths, and browser-layout tests. Its visual on-ramp still needs human review under [#77](https://github.com/Mhanna112-code/UnderwaterGame/issues/77). |
| Free-world exploration | Move, switch divers, use world abilities, discover optional sites. | **Implemented, incomplete teaching** | Swimming, switching, Sonar, Shockwave, Grapple, and Swap exist. A cold player still needs a progressive introduction to what each ability does and why switching matters. [#47](https://github.com/Mhanna112-code/UnderwaterGame/issues/47). |
| Shallows route | Learn basic combat against Angler and Frilled Shark; reach a first capstone. | **Prototype / playtest candidate** in PR #88 | Authored route roster/order and checkpoint contract exist on the branch. The decorative reef passage is rejected placeholder art, not finished environment content. |
| Deep route | Apply Evasion and Defense counterplay against Swordfish and Sea Urchin. | **Prototype / playtest candidate** in PR #88 | Route cards and counter tests exist. Current deep "ruin" primitives are rejected placeholders, not approved scenery. |
| Guardians and optional specials | Discover an artifact site, choose a diver, complete an optional challenge, earn a key item. | **Implemented, needs presentation/playtest work** | Physical artifact guardians, sonar discovery, loss-safe retry, and item persistence are wired. Their discoverability and player-facing purpose remain part of world/UX review. |
| Lab and core | Reveal the laboratory danger and acquire the core. | **Not delivered / deferred** | The branch uses a Mermaid Freak *preview* rather than a mandatory fight. Final lab pieces, encounter sequence, core interaction, and narration are not delivered. |
| Escape / Octopus | Resolve the game with a final encounter and ending. | **Not delivered / deferred** | Octopus asset, attack set, balance, checkpoint/retry flow, and final ending presentation are not ready. Do not represent this as complete. |
| Maze | Optional/parallel spatial puzzle content, not a required dependency for the core route. | **Implemented separately; design placement unresolved** | Maze geometry/minimap work belongs to its own review path. [#78](https://github.com/Mhanna112-code/UnderwaterGame/issues/78) owns discoverability; route design must decide whether/how it connects without blocking the core loop. |

## Navigation and world rules

### Direction and discovery

The meeting approved direct guidance for the critical path: a light beacon or
arrow is appropriate because the divers plausibly know their mission. Sonar is
for optional discovery and should not be the sole means of finding a required
destination.

The current PR #88 prototype uses one active beacon and an off-screen
directional cue for its authored route. That is a testable navigation choice,
not a license to make every place a marker or to use ordinary enemies as route
signposts.

| Rule | State | Proof needed |
| --- | --- | --- |
| One active critical objective at a time. | **Prototype / playtest candidate** | A fresh player can state the next action without coaching; normal-path recording proves no competing HUD/marker. |
| Beacons/arrows guide required progression. | **Prototype / playtest candidate** | Normal play reaches each route beat without Sonar or URL shortcut. |
| Sonar finds optional artifact/guardian content. | **Implemented** | Save/load and guardian integration tests exist; human playtest must show it is understandable rather than invisible. |
| Item sites are not route-marked. | **Implemented design boundary** | Maintain separation between optional discovery and critical route guidance. |
| Normal encounters are visible and avoidable, with a meaningful skip cost. | **Decision required** | [#8](https://github.com/Mhanna112-code/UnderwaterGame/issues/8) records this as a team decision; current authored-route random exclusion does not settle open-world policy. |

### Environment and art contract

Glassgoat's agreed delivery model is reusable pieces, integrated and reviewed
incrementally—not a monolithic Blender environment. Intended pieces include
rocks, pillars, algae/plants, ambient fish/background effects, and eventually
a broken underwater lab. See [#57](https://github.com/Mhanna112-code/UnderwaterGame/issues/57).

The following distinction is important:

| World visual | Status | Design ruling |
| --- | --- | --- |
| Existing seabed, rocks, guardian sites, characters, and enemy models | **Implemented source content** | Retain and evaluate in normal play. |
| PR #88 Shallows reef passage built from procedural primitive meshes | **Rejected placeholder** | It must not be described as finished environment art or used as proof that a real location has been delivered. |
| PR #88 Deep cylinder/ruin silhouettes | **Rejected placeholder** | Same rule: either replace with reviewed art or remove; do not hide them behind a review URL. |
| Beach assets | **Delivered but untested** | [#31](https://github.com/Mhanna112-code/UnderwaterGame/issues/31) must determine their actual use, scale, performance, collision, and visual fit. |
| Ambient fish, algae, pillars, lab pieces | **Not delivered / deferred** | Intake and individually review each group under [#57](https://github.com/Mhanna112-code/UnderwaterGame/issues/57). |

No environment change is complete merely because it renders. A real asset
group is complete only when it appears on the normal route, has intentional
scale/materials/collision, survives a web build, does not obstruct traversal
or spawn clearance, and receives a keep/revise ruling from the artist/team.

## Party, combat, and progression

### Party roles

The current Group Stats V2 baseline is implemented:

| Diver | Combat role | Base stats |
| --- | --- | --- |
| Maxilani | Fast accuracy/evasion specialist | 10 HP, 1 STR, 0 DEF, 3 AGI, 3 EVA, 3 ACC |
| Musashi | Balanced consistent attacker | 10 HP, 2 STR, 2 DEF, 2 AGI, 2 EVA, 2 ACC |
| Bucky | Slow power/tank character | 10 HP, 4 STR, 4 DEF, 1 AGI, 0 EVA, 1 ACC |

Stats, current Evasion, status effects, result-first move choices, and
optional Combat Help are implemented. The source map remains
`docs/glassgoat-combat-v2.md`; it is the authority for what the current slice
does and does not claim.

### Combat reading model

The intended player experience is:

- a move presents immediate resolved information—damage, effect, and risk;
- green means a **Benefit** to the player side, red on an enemy is an
  **Opening**, and red on the player side is a **Cost** or risk;
- full formula/stat detail is available on demand, not required before the
  first useful decision.

This is a promising playtest finding, not evidence that colour alone is
sufficient. Result words and keyboard-accessible detail must remain present.
The opening/tutorial work is governed by [#77](https://github.com/Mhanna112-code/UnderwaterGame/issues/77), while the broader response/feedback epic is [#17](https://github.com/Mhanna112-code/UnderwaterGame/issues/17).

### Enemy roles and content state

| Enemy | Intended tactical role | Status |
| --- | --- | --- |
| Angler | Basic foe; Bite/Bleed, Headbutt/Stun, Shine/Evasion pressure. | **Implemented with balance exception under review.** Headbutt's two-turn stun is isolated in PR #86; Glassgoat's authored table remains documented. |
| Frilled Shark | Basic enemy; Bite and armor-reduction Tail Spin. | **Implemented**; framing/visual scale has dedicated verification. |
| Swordfish | High-Evasion enemy; rewards Evasion reduction/reliable hits. | **Implemented**; its authored move table is present and requires normal-route human review. |
| Sea Urchin | Armored enemy; rewards Defense reduction. | **Implemented actor, provisional combat presentation.** Final authored attack sheet is incomplete. |
| Mermaid Freak / Tethys | Boss/late-game danger. | **Animation/combat review exists; campaign role is deferred.** Corrected textured FBX intake is open in [#59](https://github.com/Mhanna112-code/UnderwaterGame/issues/59). |
| Octopus | Escape boss. | **Not delivered / deferred.** |

### QTE and minigames

The QTE is not settled design. It has visible prompt/outcome work, but the
team still needs to decide whether success negates or reduces an attack, which
strategic purpose it serves, and its kill condition after fresh playtests.

| Question | Owner / issue | Required evidence |
| --- | --- | --- |
| Does a successful QTE negate or reduce damage? | [#11](https://github.com/Mhanna112-code/UnderwaterGame/issues/11) | Explicit team ruling plus a test of that exact rule. |
| Does the QTE improve combat enough to keep? | [#9](https://github.com/Mhanna112-code/UnderwaterGame/issues/9) and [#49](https://github.com/Mhanna112-code/UnderwaterGame/issues/49) | Named playtest count, measured result, keep/cut ruling. |
| Are special environmental minigames understandable and necessary? | [#47](https://github.com/Mhanna112-code/UnderwaterGame/issues/47) | First-time player completes the teaching sequence without coaching. |

## Player access versus review access

Normal players must be able to reach all claimed core content through New
Game. Review shortcuts exist so a contributor can inspect a feature quickly;
they must never be treated as the only implementation of player content.

| Review route | Purpose | Design status |
| --- | --- | --- |
| `?boss=1` | Tethys animation/combat inspection. | Existing review tool; not normal campaign completion. |
| `?guardian=shallows` / `?guardian=trench` | Inspect each physical artifact guardian. | Existing review tool. |
| `?special=1` | Inspect special-encounter chooser/minigame dispatch. | Existing review tool. |
| `?onboarding=1` | Inspect world-controls onboarding. | Existing review tool. |
| `?spells=1` | Inspect spell UI with review resources. | Existing review tool. |
| `?maze=1` | Inspect maze route. | Existing review tool. |
| `?open-water=1` | Reproduce the former invisible-barrier regression. | PR #88 QA tool only, not content. |
| `?reef-passage=1` | Inspect the same Shallows capstone state the normal route would create. | PR #88 QA tool only. Its current primitive landmark is rejected pending real art direction. |

## Planned work map

The open issue list should guide work, but it is not a feature list by itself.
This grouping states why each set matters to the player.

| Player outcome | Primary issues | What must be decided or proven |
| --- | --- | --- |
| A new player knows what to do and how to use the party. | [#47](https://github.com/Mhanna112-code/UnderwaterGame/issues/47), [#77](https://github.com/Mhanna112-code/UnderwaterGame/issues/77), [#16](https://github.com/Mhanna112-code/UnderwaterGame/issues/16), [#36](https://github.com/Mhanna112-code/UnderwaterGame/issues/36) | Short visual teaching, clear ability purpose, accessible QTE instruction, discoverable optional detail. |
| Combat produces choices rather than one optimal click. | [#17](https://github.com/Mhanna112-code/UnderwaterGame/issues/17), [#15](https://github.com/Mhanna112-code/UnderwaterGame/issues/15), [#21](https://github.com/Mhanna112-code/UnderwaterGame/issues/21), [#22](https://github.com/Mhanna112-code/UnderwaterGame/issues/22), [#29](https://github.com/Mhanna112-code/UnderwaterGame/issues/29), [#35](https://github.com/Mhanna112-code/UnderwaterGame/issues/35) | Counterplay, status definitions, readable turn/character focus, and human balance validation. |
| The world offers intention, place, and discoverable optional content. | [#8](https://github.com/Mhanna112-code/UnderwaterGame/issues/8), [#27](https://github.com/Mhanna112-code/UnderwaterGame/issues/27), [#31](https://github.com/Mhanna112-code/UnderwaterGame/issues/31), [#57](https://github.com/Mhanna112-code/UnderwaterGame/issues/57), [#78](https://github.com/Mhanna112-code/UnderwaterGame/issues/78) | Encounter policy, real environment pieces, maze orientation, and normal-path visual review. |
| The game has authored tone and an endgame. | [#58](https://github.com/Mhanna112-code/UnderwaterGame/issues/58), [#59](https://github.com/Mhanna112-code/UnderwaterGame/issues/59) | Glassgoat narration, textures, lab/core/escape content, and boss acceptance. |
| A shared web build is trustworthy to test. | [#12](https://github.com/Mhanna112-code/UnderwaterGame/issues/12), [#38](https://github.com/Mhanna112-code/UnderwaterGame/issues/38), [#40](https://github.com/Mhanna112-code/UnderwaterGame/issues/40), [#41](https://github.com/Mhanna112-code/UnderwaterGame/issues/41) | Fresh-player testing, review discipline, loading experience, and explicit decision ownership. |

## Proof standard

Every future slice should name both its automated contract and its human
evidence before implementation. Neither is a substitute for the other.

| Claim | Minimum automated proof | Minimum human proof |
| --- | --- | --- |
| A route is reachable. | Real movement/trigger test from normal entry; no synthetic signal-only pass. | Complete it in a hosted build without a query shortcut. |
| A combat lesson works. | Exercise the real turn, result, QTE/skip/loss path, and viewport layout. | Fresh player explains the useful choice and next action. |
| An asset belongs in the game. | Import/material/scale/collision/spawn-clearance and web-build checks. | Screenshot/GIF from the normal location plus explicit keep/revise ruling. |
| A balance change is better. | Reproducible policy/simulation comparison against current rules. | Several human runs, including loss reasons and frustration notes. |
| A UI is accessible. | Responsive viewport and keyboard path checks. | Normal browser review at ordinary zoom, no coaching. |

## Immediate design decisions to record before broad implementation

1. State the repeatable core loop and assign each retained minigame a job.
2. Decide visible/avoidable versus random ordinary encounters and the precise
   consequence of skipping them.
3. Decide the QTE's attack outcome and its keep/cut condition.
4. Define the first-time ability-teaching order before asking for a combined
   puzzle.
5. Accept, revise, or reject each environment asset group only after it is
   placed on a normal path and reviewed visually.
6. Keep Glassgoat's final narration, final environment pieces, corrected
   Tethys textures, lab/core, and Octopus escape explicitly deferred until
   their delivery and acceptance criteria are met.

## Maintenance rules

- Update a row's state when source, issue decision, or playtest evidence
  changes; do not rewrite history to make a prototype look accepted.
- Link implementation PRs and their exact hosted build SHA in the relevant
  issue, not only in chat.
- Keep review routes documented, but never require them to see a claimed
  player-facing feature.
- Add final narrative, art direction, or stat changes only with the named
  owner's source and acceptance evidence.
