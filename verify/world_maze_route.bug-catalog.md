# World-to-maze physical route

October 4, 2026. Complete World, DeepZoneLayout, Diver, RouteState and scene/state
consumer reads carried forward; current construction, puzzle result, input,
physical movement, route/transition and geometry consumers reread.

## Module contract

- Public surface: parsed WASD/mouse/R, actual CharacterBody3D movement and scene
  handoff. Proximity at the rendered Deep maze landmark opens Marc's scene;
  laboratory blockers and Tethys are not prerequisites.
- Load-bearing distinction: the shallow pressure-plate puzzle opens three
  sliding doors. Its endpoint is not currently a scene transition. The existing
  maze landmark is a separate Deep branch. User reports this mismatch in actual
  play; do not mistake fixture-at-door acceptance for a discoverable journey.
- IO: physical collisions, distance-based encounter RNG, deferred scene change,
  frame time and entrance autosave. Use an unused isolated save slot and remove
  only the test-created slot; never write a reviewer/player slot.
- Branches: pre/post-opening, encounters on/off, shallow/deep, locked/available
  entrance, lab complete/incomplete, transition pending, collision obstruction.
- Types: RouteState maze availability and independent lab states; actual Diver
  resource identity survives World destruction through CampaignSession.
- Existing gates teleport to the trigger or sample route collision. Neither
  proves actual input-controlled travel from ordinary spawn.

## Catalog

| ID | Failure | Blast radius / plausibility | Test / status |
| --- | --- | --- | --- |
| WR-01 | Normal spawn cannot physically reach the maze landmark with lab guards undefeated | High; placed-at-trigger tests bypass walls and movement ownership | Real input route, pending |
| WR-02 | A physical arrival silently resets the party or starts Tethys/lab instead of Marc's maze | High; scene reconstruction and generic boss flags previously lost campaign state | Real arrival, resource identity and independent state, pending |
| WR-03 | Finishing the shallow puzzle leaves no understandable route to the maze | High; user observed this; puzzle/result guidance only references Deep/lab, while entry is elsewhere | User clarified direct puzzle exit; captured and repaired in puzzle_maze_exit; this gate covers the retained Deep compatibility path only |

Self-critique: collision queries only propose waypoints. Actual parsed input and
the real scene arrival are the oracle; no teleport, disabled world physics,
private entry helper, forced Deep/maze/lab state or guessed success. A stable
blocked path fails. Named layout points are steering scaffolding, not proof of
human discoverability. Two target states are deterministic, not a broad generated
input domain. Post-opening flags are an explicit fixture, not proof of opener
completion. Encounter R-off is a real player action, not rewritten policy.

## Skipped

- Earning combat kit, full shallow puzzle and maze puzzles, boss balance and
  browser durability: separate actual consumer/route gates remain required.
- Human navigation, guidance and visual quality: this machine-steered path does
  not accept them, even when physically reachable.
- Direct puzzle-to-maze route: covered by puzzle_maze_exit after the user's
  clarification; this test does not substitute for that primary route.

## Evaluation

First actual input journey passes from normal spawn to the older Deep landmark,
with untouched lab gates and retained party. This proves physical compatibility
reachability, not puzzle handoff or human discoverability. PX-01 is the confirmed
production failure; no game change was needed for this compatibility path.
