# Marc's post-lab ramp and stationed Cordys requests

October 5, 2026. Direct main follow-up after PR100 integration.

## Decisions implemented

- The physical maze ramp is already beyond the lab, not at the blockade:
  laboratory X=175, maze approach X=215, ramp begins at the world edge X=230.
  No ramp relocation was needed. Normal parsed movement reaches the embedded
  maze while the lab and Tethys remain locked and both guards undefeated.
- Cordys is now visibly stationed in the main boss room across the hallway from
  the secret room. He idles, faces the doorway and has a small name label.
  The purple floor sigil and its automatic fight-start behavior are removed.
- Both rooms use the existing shared Yes/No modal with Marc's requested text:
  "A great danger is detected here. Are you sure you would like to proceed?"
- No (or Esc) leaves the player in place. It does not repeatedly ask while the
  player remains nearby; move away and approach again to receive a new prompt.
  No is the initial safe focused choice. Yes/Y starts the existing campaign
  Cordys rematch, not the opening defeat or a second laboratory Tethys.
- Puppet roster, key spending, rewards, boss balance and lab progression are
  unchanged. Persisted `main_boss`/`secret_boss` completion IDs remain compatible.
  A completed Cordys snapshot removes both his station and further prompts.

## Focused evidence

- `verify/maze_cordys_station.gd`: missing model reproduced before repair;
  real W approaches/declines for every diver, modal ownership, stationarity,
  actual door E, inactive maze, skin/floor/wall bounds and undefeated restore.
- `verify/maze_cordys_trigger.gd -- --real-win`: actual confirmation, legal
  12-action victory and completed snapshot restore, independent lab/puppets.
- `verify/maze_checkpoint.gd`: actual Cordys-caused defeat and checkpoint restart
  still preserve campaign progress without replaying the opening.
- `verify/maze_puppet_trigger.gd`: secret confirmation still starts the approved
  first puppet wave, not Tethys; music and sonar ownership remain correct.
- `verify/world_maze_route.gd`: real input-controlled swimming reaches the
  existing post-lab ramp without requiring lab victories or resetting party.
- Native station/confirmation captures: 1280x720, 720x480 and 360x640.

The boss-room tests disclose a location fixture and supplied key. They do not
prove complete maze traversal/key acquisition, human discoverability, full
campaign balance or browser checkpoint durability. Existing Windows/Linux
downloads remain older builds unless a separate delivery is recorded.

## Web delivery

Verified immutable station candidate:
https://underwatergame-r1mc1wj82-immortaldemongods-projects.vercel.app/

- Runtime source: `afdbd4540d88e6c4ade088d61f1c553c29950426`.
- Actual served pack: 93,317,140 bytes; SHA256
  `7e654b09a2b82eb306c6df0fc21730c1fb9adcb34c0b5d61143225219ce8aba4`.
- Real hosted Title Load, W approach, N decline, S/W reapproach and Y accept all
  passed with no captured script/page errors. Question and both choices remain
  readable at 1280x720, 720x480 and 360x640. Screenshots were visually inspected.
- The browser uses an isolated recovered-campaign room fixture, not a claim of
  full maze/key navigation or durable player-save acceptance.

Promotion of this isolated candidate was deliberately withheld: the concurrently
authorized safety workstream has incorporated the station changes into combined
runtime `138ca535c3a5d8d174225eb109b56b35ea190be0`. The older station-only pack
was not promoted over the newer combined release.

The combined release is now published on the existing public and campaign-review
URLs. Runtime source is `138ca535c3a5d8d174225eb109b56b35ea190be0`; the matching
generated export was committed to main in `279dd5e`. It includes station source
commits `4228b9a` and `afdbd45` alongside the concurrent safety repairs.

- https://underwatergame.vercel.app/
- https://underwatergame-maze-campaign-review.vercel.app/
- Combined pack: 93,321,284 bytes; SHA256
  `e5f790f1a30bc3390a1006784257ac1957c8998ec53fcc672bc8ed723c527de9`.
- Both aliases' metadata and actual streamed `index.pck` bytes match that source
  and hash: `docs/evidence/cordys-station/public-artifacts.json`.
- Combined hosted real-input station/decline/reapproach/accept evidence:
  `docs/evidence/main-safety-oct5/combined-hosted-cordys/receipt.json`, with no
  findings. The station and confirmation screenshots were visually inspected.
- Station-only browser provenance and screenshots are retained separately in
  `docs/evidence/cordys-station/browser/`; they are not mislabeled as the newer
  combined runtime's proof.

These are focused regression and delivery checks, not complete campaign
acceptance. Windows/Linux download packages have not been refreshed by this
follow-up.
