# UnderwaterGame

An in-development Godot RPG about three divers exploring a hostile underwater
world. The current build combines free-swimming exploration, turn-based party
combat, character-specific abilities, guarded artifacts, progression and
environmental puzzles using Glass_Goat's rigged characters and enemy models.

## Play the current main build

**https://underwatergame.vercel.app/**

The first load can take a while, particularly in Firefox. Click the game once
after it appears to let the browser capture the mouse.

The stable URL above is intended to serve `main`. The repository contains the
complete browser export in `docs/`, but the Vercel project is not yet connected
to this GitHub repository for automatic deployments. Until that connection is
enabled, verify the deployed build after a merge instead of assuming that the
alias advanced with the branch.

## Controls

### Exploration

| Input | Action |
|---|---|
| `W` `A` `S` `D` | Swim relative to the camera |
| `Space` | Rise |
| `Shift` or `Ctrl` | Sink |
| Mouse or arrow keys | Look around |
| `Tab` | Switch the active diver |
| `E` | Use the active diver's ability or confirm a selected target |
| Left click | Fire Musashi's grapple while aiming |
| Right click or `Esc` | Cancel grapple aiming |
| `Q` | Toggle Maxilani's sonar |
| `P` | Open the save/spell menu while standing on a save point |
| `F1` | Open the general tutorial book |
| `Esc` | Open or close Inventory, Party Spells and Combat Help |

### Combat and tutorials

Combat is driven primarily by the on-screen buttons. `Enter` advances the
scripted combat tutorial, and `X` answers an enemy quick-time dodge prompt.
Individual special encounters display their controls before the challenge
starts.

## Current game flow

At a cold launch, a first-time player sees one primary **New Game** action. If
a valid save exists, **Load Game** appears as a secondary action and opens the
three-slot picker. A new run shows the temporary scrolling introduction; press
`E` or click to skip it.

The opening world sequence points the player toward a light beam and starts a
choreographed combat tutorial. It teaches turn order, Accuracy versus Evasion,
damage and Defense, status effects, move trade-offs, quick-time dodging, XP and
level growth before releasing the party into the wider map. Switching divers,
using abilities and saving remain gated until that first encounter ends.

After the tutorial:

- Maxilani, Musashi and Bucky can be switched at any time with `Tab`.
- Their exploration abilities are swap, grapple and shockwave respectively.
- Sonar reveals hidden guarded locations and drains oxygen while active.
- Lit beacon routes connect the anchor, shallows and trench combat sites.
- The shallows artifact is guarded by an Angler; the trench artifact is
  guarded by the Swordfish Duelist.
- Ordinary encounters independently choose Anglers and Swordfish, so mixed
  groups are possible.
- The active diver checks for a random encounter after travelling 8–16 metres,
  with a 50% trigger chance at each check—about one encounter per 24 metres on
  average.
- Save points restore the party, persist world/combat progression and provide
  access to learning and equipping spells.
- The corridor gate combines a breakable blockade, grapple crossing,
  whirlpool hazard and a three-diver pressure-plate lock.

The Tethys boss and direct guardian/special-encounter routes remain explicit
review surfaces rather than shortcuts in an ordinary new game. They can be
opened from the web build with `?boss=1`, `?guardian=shallows`,
`?guardian=trench` or `?special=1`.

## Combat

Combat is a turn-based three-diver party system. Effective Agility determines
round order; an attack lands only when its effective Accuracy exceeds the
target's currently available Evasion. Defense mitigates successful hits.
Evasion is spent by dodging and refills on that combatant's next turn.

The battle UI includes:

- an upcoming-turn queue;
- names, HP, oxygen and level for every diver;
- enemy names and overhead health bars;
- target stat comparison;
- result-first move summaries, with optional formula details;
- items, running, equipped spells and status-effect feedback;
- XP, level growth, spell points and post-fight recovery.

Maxilani currently has Glass_Goat's five-move V2 kit: Electric Touch, Scuba
Stabbing, Flash Blast, Multiple Knee Combo and Axe Kick. The formulas live in
`content/combat_moves.gd` and are resolved from the acting character's stats.
Musashi and Bucky have their own base moves and expandable spell trees.

Ordinary enemies use reusable, data-driven move definitions from
`content/enemy_moves.gd`. The Angler and Swordfish actors share a stable enemy
contract while retaining their own models, animation mappings and attacks.
Tethys is a separate boss actor with six authored attack animations.

## Special encounters

Artifact guardians ask the player to choose one diver for a short solo
challenge based on that diver's exploration ability:

- **Maxilani / Swap:** match incoming portraits to the correct slots.
- **Musashi / Grapple:** aim at weak points and intercept incoming threats.
- **Bucky / Shockwave:** choose the rock lane while avoiding solid walls.

A flawless defense prevents the guardian's follow-up strike. Losing a special
encounter does not permanently reduce the selected diver's pre-encounter HP;
winning grants the guarded key item or another defined reward.

## Open the project in Godot

The project currently uses **Godot 4.7.1** with no plugins or external build
step.

1. Clone the repository.
2. In Godot's Project Manager, choose **Import**.
3. Select this repository's `project.godot` file.
4. Choose **Import & Edit**.
5. Press **F5**. `game/world.tscn` is the main scene.

The committed browser build is produced with the `Web` preset:

```sh
godot --headless --path . --export-release Web docs/index.html
```

## Project map

| Path | Responsibility |
|---|---|
| `game/world.gd` | Title/new/load flow, exploration, camera, saving, sites, abilities and battle transitions |
| `game/battle.gd` | Combat stage, menus, tutorial, enemy turns, QTEs, rewards and progression |
| `game/diver.gd` | Diver actor, rig playback, movement, oxygen, sonar and encounter checks |
| `game/combatant_stats.gd` | Persistent HP, oxygen, attributes, XP, levels and status state |
| `game/combat_rules.gd` | Shared hit, formula and effect calculations |
| `content/cast.gd` | Diver files, display names and animation mappings |
| `content/combat_moves.gd` | Glass_Goat's formula-driven Maxilani moves |
| `content/enemy_moves.gd` | Reusable Angler and Swordfish attacks |
| `content/enemy_roster.gd` | Ordinary encounter actor selection |
| `content/sites.gd` | World sites, artifacts, fixed guardians and beacon graph |
| `content/tutorial_content.gd` | General help, status explanations and tutorial move text |
| `game/maze_level.tscn` | Standalone maze/current puzzle development scene |
| `docs/` | Committed HTML5/WebAssembly export |
| `verify/` | Gameplay, balance, regression and browser checks |

## Models and animation contract

The three player deliveries—`Scuba_Rigged.fbx`, `Prototype1_Rigged.fbx` and
`PrototypeV_Rigged.fbx`—share one 132-bone rig. Each file contains one visible
character mesh but animation families for the complete cast. Consequently,
clips must be selected by character family, and the imported scene tree must
remain intact so its AnimationPlayer track paths still resolve.

`content/cast.gd` is the source of truth for those mappings. Held swimming
motions use the authored Start → Mid (Loop) → End sequence. Maxilani's staff is
skinned to her rig and stays with the character instead of being instantiated
as a separate world prop. Procedural yaw, pitch and bubbles remain layered on
top because they follow camera direction and velocity rather than an authored
clip.

The original FBX delivery is retained under `art/source/` behind `.gdignore`.
Runtime-ready character assets live under `art/characters/`; enemy deliveries
and their textures live under `game/` and `characters/` according to their
existing import paths. `docs/art-intake.md` records the asset investigation.

## Verification

On a fresh clone, let Godot import the project once so its global-class cache
and imported model scenes exist:

```sh
godot --headless --editor --path . --import --quit
```

Then run the complete gate suite from the repository root:

```sh
./verify/gates.sh
```

It exercises, among other things:

- rig clip resolution and full swim transitions;
- camera-relative movement and preserved mouse look;
- the water-current barrier;
- Glass_Goat's combat formulas, roster and result-first UI;
- Tethys and both ordinary enemy actors;
- defeated-actor cleanup and battle-stage framing;
- casual and skilled artifact-route balance simulations;
- encounter spacing, site reachability and guardian persistence;
- the opening light beam and combat tutorial;
- all three special encounters and their battle hand-offs;
- the maze rotation contract, title screen and full fight return path;
- Chromium boot plus boss, guardian and special review routes.

The aggregate suite exits non-zero when a functional check finds a regression
or Godot reports a script error. Visual stage framing is skipped when no
display exists. Browser gates are reported as skipped when Playwright or the
committed web export is unavailable; the script does not describe skipped
browser coverage as fully clean.

Useful focused commands include:

```sh
godot --headless --path . --script verify/glassgoat_combat.gd
godot --headless --path . --script verify/balance.gd
godot --headless --path . --script verify/encounters.gd
godot --headless --path . --script verify/intro_sequence.gd
godot --headless --path . --script verify/special_encounters.gd
godot --headless --path . --script verify/fight.gd
node verify/webcheck.mjs docs /tmp/underwatergame-webcheck.png
```

The `*.bug-catalog.md` files beside several gates document the concrete bugs
each regression is designed to catch.

## GitHub Pages fallback

Because `docs/` is a complete browser export, repository administrators can
also serve it through GitHub Pages using branch `main` and folder `/docs`.
That is independent of the Vercel deployment above.
