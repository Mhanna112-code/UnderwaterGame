# Maze coordinate-frame migration — October 5, 2026

## Scope and code reading

The fully read `CampaignCheckpoint` codec (222 lines) is the durable JSON
boundary; `CampaignSession` carries live resources. The snapshot capture,
runtime-reference validation and restore section of MazeLevel was read in full,
along with the existing checkpoint IO and party-continuity verifiers. This is a
scoped coordinate-boundary batch, not a claim to have finished reading or
integrating the entire World/Maze implementation.

Public contracts: CampaignCheckpoint.encode/decode/valid_maze, and MazeLevel's
campaign_snapshot/restore_campaign_snapshot/snapshot_matches_runtime. A new
MazeCoordinateFrame.rebase will make translation explicit. Legacy snapshots
omit the origin and therefore mean the standalone origin (0,0,0). The new
metadata does not change the version-one puzzle/party schema.

Load-bearing invariants: Marc's embedding shifts authored children while the
maze root stays at zero; rotations, sizes, current directions and discovered
node identities are NOT positions. A shallow duplicate would mutate the prior
checkpoint. Wall rotation homes must move with their walls, otherwise closing
a saved open hallway snaps it back to its former location.

IO: production snapshot data crosses JSON/disk in the existing codec. This
verifier has no save-file writes. Real MazeLevel construction uses randomness
for poster choices; the same captured valid baseline is retained as the oracle.

Branches: absent/present/malformed origin; same/different destination origin;
legacy/translated snapshot; empty/populated rewards and rotation homes;
valid/invalid puzzle data. Existing codec tests have 24 party-state combinations
but no frame migration. Existing scene handoff checks assume separate scenes.

## Catalog and self-critique

| ID | Failure mode | Risk / plausible cause | Test and accepting oracle |
|---|---|---|---|
| FRAME-1 | A snapshot from another frame restores party/walls/rewards at the old coordinates | High: current restore ignores origin metadata; required embedding would strand or corrupt a saved run | Public real-scene restore of a framed valid snapshot must reproduce the original physical state, not the framed numbers |
| FRAME-2 | Translation drops state, changes orientation/size, mutates input, or shifts twice | High: many coordinate-bearing containers and mutable nested dictionaries | Generated translation and JSON round trips; original baseline and geometry-relative distances are independent oracles |
| FRAME-3 | Malformed origin is accepted then partly mutates the live scene | High: optional metadata previously unchecked | Negative cases at public codec/runtime boundary; invalid frame must be rejected before restore |
| FRAME-4 | Reapplying a checkpoint duplicates pending item/key rewards | High: embedded ownership will retain live scene nodes; existing restore appends saved rewards without replacing current ones | Two public restores must leave exactly one reward/key; an empty saved reward list must remove unsaved rewards |
| FRAME-5 | Runtime validation approves a source frame which cannot translate into the playable coordinate range | Medium: source validation alone misses destination overflow; Load could proceed into an unchanged maze after restore rejects it | A shape-valid source with a legal origin and extreme wall must fail snapshot_matches_runtime before mutation |

FRAME-1 is a required migration-contract red, not a claim that the current
standalone deployment already saves embedded coordinates. The normal scene's
same-frame behavior must remain unchanged.

Wrong-but-stable output fails: actual restored physical coordinates, rewards,
rotation homes and non-spatial state are compared against the captured original
scene. A behavior-preserving refactor may change the migration implementation
without changing these assertions. The generated fixture uses a recursive
semantic position-name oracle, not the production per-container implementation.
Every active diver and all eight downed patterns are covered with multiple
origins, including nonzero vertical offsets; no large-resource combat fixture.

FRAME-4 uses actual ItemOrb and key pickup nodes and public snapshot output,
not callback counts or private helper assertions. A refactor may replace the
implementation, but repeated restore must not duplicate collectible rewards.

## Skipped / deferred

- Physical connected entrance, shared live actors, camera/HUD ownership,
  inactive-area processing: next embedding batch; migration alone proves none.
- Legacy World save positions and laboratory placement are outside this maze
  snapshot translation. They must not be shifted here.
- Current radius-site state is not yet in this snapshot schema; its eventual
  coordinate metadata must be added with its production persistence port.
- Browser durability and new exports remain full-goal acceptance work.

## Evaluation

FRAME-1 first run failed six real restore oracles (party, walls, rotation
homes, broken-rock records, pending orb and pending key). No script error.
The metadata/rebase boundary repairs those required migration failures.

FRAME-4 was probed after FRAME-1 passed: repeated live restore duplicated
pending rewards, and an empty checkpoint left unsaved drops behind. Both
assertions failed before the replacement fix. This is a concrete existing
public-restore defect, not only a future embedding requirement.

Final focused run passes the real restores, 144 generated active-diver/downed
pattern/frame cases, ten malformed origins, three invalid destinations and
one translated-coordinate overflow. Generated cases include depleted Oxygen,
statuses, earned kit, independent lab/tutorial progress and six spatial frames.
JSON and reverse-frame round trips preserve resources and puzzle state;
source mutation, same-frame double shifts and direction/size changes fail
the independent oracle. Repeated reward restore and removal now pass.

FRAME-5 adversarial red: runtime preflight accepted a legal saved origin/wall
whose destination coordinate overflowed the codec range. Preflight now checks
the translated frame before releasing Load. Final negative cases also pass
through public CampaignCheckpoint.decode, not just its shape validator.

Adversarial investigation: a shape-valid extreme coordinate can overflow
the accepted range after translation; the post-translation validator rejects
it without live mutation. Legacy absence is intentionally not rejected.
Future live restore of previously broken rocks/closed doors still requires
rebuilding/restoring structural state; reward idempotence is NOT proof of
that broader rollback contract.

Receipts: /tmp/pr100-oct5-frame-red.log,
/tmp/pr100-oct5-frame-repeat-red.log,
/tmp/pr100-oct5-frame-repeat-green.log. Durable receipt copies accompany this
batch. No completed embedding, browser, normal-route or release claim.

Preservation runs pass: 24 valid/40 invalid checkpoint IO and actual corrupt
Load rejection; earned-map save/cold/legacy Load; real secret E/Esc continuity;
12 World-return cases; 59 orb checks; actual full-party loss/restart and failed
save preservation; 86 exploration control cases. No script errors were found
in the captured logs. See the durable receipt README for each test's limits.
