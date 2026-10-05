# Stationed maze finale: bug catalog

2026-10-05. Scope: maze boss-room construction, approach prompts, battle dispatch,
modal/input ownership and boss-trigger snapshot consumers; Cordys presentation
adapter and shared ConfirmPromptModal read alongside them.

## Contract and boundaries

Physical approach in the main room opposite the secret room must show an idle,
stationary Cordys. The shared Yes/No modal asks: "A great danger is detected here.
Are you sure you would like to proceed?" No/escape must not begin combat; Yes
starts the existing campaign Cordys battle, not the forced-loss opening or Tethys.
Secret-room puppets, key rules, campaign rewards and independent lab progress
remain intact. The ramp is already beyond the lab and is not a victory gate.

IO: physics/input/frame timing, skin animation/rendering, music, campaign snapshot
serialization. Branches: active/inactive maze, active/inactive diver, other modal,
approach/decline/accept, battling, undefeated/defeated restoration. Trigger IDs
`main_boss` and `secret_boss` are persisted completion identities, not actor names.
Existing finale gate tested automatic sigil contact; checkpoint gate hardcoded
that sigil node. Both must follow deliberate confirmation instead.

## Catalog and tests

| ID | Failure and impact | Plausibility / cheapest evidence | Status |
| --- | --- | --- | --- |
| CS-1 | Invisible automatic sigil starts finale before player consents | Present main implementation; real rendered actor + W approach + modal/no Battle | Reproduced, fixed |
| CS-2 | Decline traps player or immediately reopens; held input swims through prompt | Proximity poll and modal lifetime; actual N/Esc/W/Tab/P, reapproach | Characterized |
| CS-3 | Companions or another modal initiate fight; inactive maze polls | Shared actors and embedded subtree; actor/owner decision cases | Characterized |
| CS-4 | Yes starts wrong boss, or restored defeated boss respawns | Shared generic dispatch and saved trigger list; real Yes, legal combat win, snapshot round trip | Characterized |
| CS-5 | Mesh faces away, intersects room, or modal clips narrow screens | Cordys skinned bounds and fixed room geometry; native captures plus live pose bounds and control rectangles | Characterized |

Self-critique: location fixtures isolate room behavior, not complete maze/key
navigation. Real W/proximity/Yes/No own battle start; no direct start call or
injected won result. Wrong-but-stable automatic combat or hidden model fails.
Assertions use observable actor, modal, battle/result and completion surfaces;
old node-name assertion is removed. Generated active-diver cases and idle-frame
samples cover the bounded ownership/stationarity domains. Screenshots supplement
semantic checks, never replace them.

## Skipped

- Full campaign balance, human navigation and browser storage durability: outside
  this staging request; existing gates do not substitute for a full playthrough.
- Repositioning the ramp: current physical layout already places it beyond lab.
- Changing puppet roster, rewards or lab prerequisites: explicitly out of scope.

## Evaluation

- Red: current main reported `CS-1 main room has no single visible stationed
  Cordys`. Replaced the executed automatic sigil with a visible idle actor and
  an active-diver, room-contained, deliberate confirmation flow.
- Green: all three real W approaches, N/Esc declines, safe default No, held
  W/Tab/P ownership, inactive companion, inventory owner and inactive/resumed
  maze. Native 1280x720, 720x480 and 360x640 layouts rendered/readable.
- Actual confirmed campaign fight won in 12 legal actions; completion/snapshot
  restore removes the model, leaves the secret encounter and lab independent.
  Real checkpoint defeat/restart and puppet dispatch regressions passed.
- Observer defect: headless defaults to a 64px viewport; its clipping findings
  were not a game defect. Explicit virtual 1280x720 fixes that observer, and
  actual native narrow rendering verifies the real UI.
- Construction risk found during writing: imported actor normalization assumes
  construction at the origin. Construct there before room translation, then
  verify live skinned foot and wall bounds. No change to battle art adapter.
- Initial room-location fixture bypassed a closed entrance, squeezing the
  camera against it. The corrected fixture supplies one key and spends it with
  real E; this is disclosed and is not proof of earning the key.
- Browser verification and served-artifact receipts are recorded separately in
  `docs/cordys-maze-station.md`; native checks do not prove a hosted export.
