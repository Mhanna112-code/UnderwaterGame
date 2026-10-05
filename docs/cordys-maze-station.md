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

Pending fresh export, identified artifact and actual browser Title Load/W/No/
reapproach/Yes checks. Existing public and campaign-review URLs will be retained.
