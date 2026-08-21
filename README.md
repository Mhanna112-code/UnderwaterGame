# UnderwaterGame

Glass_Goat's diver models, in Godot, swimming.

## Play it now

**https://underwatergame-ratateam.vercel.app**

No install, no Godot, no account. Click the page once so it takes the mouse,
then:

| key | does |
|---|---|
| WASD | swim |
| SPACE | rise |
| SHIFT | sink |
| mouse or arrow keys | look |
| TAB | switch which diver you steer |
| ESC | give the mouse back |

The two divers you are not steering swim a slow circuit of their own.

First load takes 35 to 50 seconds and the progress bar sits full for most of
it. That is the engine starting, not a hang. See "Why the first load is slow"
below. Once it is up it runs fine.

## Open it in Godot

Godot 4.7.1, no plugins, no build step.

1. Clone the repo, or use the copy you already have.
2. Open Godot. In the Projects list press **Import**, not Create.
3. Point it at the **`project.godot` file** inside the repo folder. Selecting
   the folder alone is not enough on some builds; pick the file.
4. Press Import & Edit.
5. Press **F5** to play. `game/world.tscn` is the main scene.

Any "Missing Project" rows already in your list are old paths from other work
and have nothing to do with this repo. "Remove Missing" clears them.

## What is here

- `art/source/Main_Team_Rigging_2.fbx` is the delivery, kept behind a
  `.gdignore` so no editor has to import FBX to open this repo.
- `art/characters/divers.glb` is what the game loads, converted from it by
  `tools/fbx_to_glb.gd`. Same four meshes, same vertex counts, same nine
  materials.
- `game/diver.gd` handles everything the export has opinions about: the models
  stack on one origin, carry a -90 degree X rotation with a scale of 100, and
  face +Z where Godot's forward is -Z. Fixed once, there.
- `game/diver.gd` also tracks how far each diver has swum and rolls a random
  encounter (tall-grass style) every 20-40 meters, at a 25% chance per roll.
- `game/world.gd` is the dive site and the camera. It listens for the diver
  you're steering to roll an encounter, then freezes the dive and drops into
  a turn-based fight, Pokemon-style.
- `game/battle.gd` is that fight: a small isolated 3D stage (your diver's
  back, the grunt facing you) with a menu underneath - Attack opens a move
  list (Jab / Kick / Haymaker), Run ends the fight on the spot. Win, flee, or
  get beaten off and control returns to the dive site.
- `game/goblin.gd` handles `characters/GoblinGrunt.fbx`, the grunt's model.
  Unlike the divers this FBX arrives rigged (an Idle and a Walking take), so
  it gets a real animation instead of procedural posture. Its scale was never
  hand-measured, so it's rescaled to a target height at runtime rather than
  trusting the export's units.
- `game/lineup.tscn` stands the whole cast in a row with their measured sizes,
  for looking at rather than playing.
- `docs/` is the exported browser build.
- `verify/` and `tools/` are the checks. Every number in `docs/art-intake.md`
  comes out of one of them.

## The models are rigged now

The first delivery, `Main_Team_Rigging_2`, carried no bones, no skin deformers
and no blend shapes, so every bit of motion in this game used to be procedural
and applied to the whole model: pitch into a glide, bob, bank, trail bubbles.
`docs/art-intake.md` still has the evidence for that, and it is the reason the
lantern was planted in the seabed rather than carried. No diver in that export
had a hand to hold it with.

Glass_Goat's rigged deliveries replaced it. There are three of them,
`Scuba_Rigged.fbx`, `Prototype1_Rigged.fbx` and `PrototypeV_Rigged.fbx`, and
they work differently to how you might expect: all three characters share a
single 132 bone rig, so **every file contains every character's animations and
only one character's mesh**. That has two consequences the code has to respect.

1. A clip has to be matched by character family, not by motion. Match on
   "idle" alone and the scuba diver gets handed the brass suit's stance.
2. The imported tree cannot be taken apart. The AnimationPlayer's track paths
   are relative to that file's own root, so lifting one mesh out of it, which
   is what the unrigged code did, leaves clips that resolve by name and then
   animate nothing. `game/diver.gd` instantiates the whole file and hides the
   two characters it is not.

`content/cast.gd` is the table of which file, which mesh and which clip belongs
to whom. Every clip name in it was read out of the imported files rather than
guessed, and `verify/clips.gd` fails the build if any of them stops resolving.
Three of them were wrong on the first pass and only that gate found them:
Proto5 has no win clip at all and celebrates with a thumbs up, its heavy hit
reaction is called `Strong_Hit` where the other two say `Heavy_Hit`, and the
scuba diver's win loop is `(Mid2)(Loop)` rather than `(Mid)(Loop)`.

Held motions ship as Start / Mid (Loop) / End. The loop is the one to play. A
Start on its own plays once and drops back to a rest pose, which is what "the
animation is broken" looked like the first time.

The staff is skinned to the same rig as the diver holding it and swims with
her, so it is part of the character rather than a prop parked nearby. Hiding it
along with the other characters' meshes is what left it floating on its own
beside her.

What survived from the procedural code is the yaw turn and the pitch into a
glide, because those follow the camera and the velocity rather than the
animation, and the bubble trail.

## Why the first load is slow

Measured on a 2026 M1, not guessed, both builds served the same way in the
same session by `verify/ffcheck.mjs`:

| build | pck | first drawn frame, Firefox |
|---|---|---|
| before the rigged models | 0.9 MB | 36.7s |
| with the rigged models | 9.3 MB | 57.5s |

The download is not the problem. The wasm is 37.7 MB and arrives in under a
second on this connection; the pck arrives in a tenth of one. The wait is
almost entirely the scene compiling its shaders in the browser's
compatibility renderer, and rigged characters cost more of them than one
untextured mesh did. An empty scene in the same build draws at 15s, so about
15s of any of these numbers is Godot's own web boot. There is no second-visit
discount: the shader cache does not survive a reload here.

So the animations cost about 21 seconds of first load. That is a real price
and it is written down rather than buried: three textured, rigged, animated
characters instead of three untextured ones standing in bind pose is worth it,
but 57 seconds of staring at a blank page is not something to be relaxed
about. See #40.

The lever that would actually move it is material count, and it is an art
call rather than a code one. Each material costs a shader compile in the
browser, and fewer materials or merged surfaces would cut the wait roughly in
proportion. Chromium is several times faster than Firefox on the same build,
which is worth knowing before anyone concludes the game is broken.

## Checks

    ./verify/gates.sh                                     # all of the below, in order

    godot --headless --path . --script verify/clips.gd    # does every clip the game asks for exist
    godot --headless --path . --script verify/animations.gd # do all three rigs change state correctly
    godot --headless --path . --script verify/swim.gd     # do they actually move, and animate while moving
    godot --headless --path . --script verify/balance.gd  # seeded casual/greedy difficulty policies
    godot --headless --path . --script verify/encounters.gd # does a fight start correctly from every area
    godot --headless --path . --script verify/fight.gd    # play a whole fight and come back to the world
    godot --headless --path . --script tools/test_goblin.gd  # does the grunt's model load and size correctly
    godot --headless --path . --script tools/test_battle.gd  # does the fight screen build without erroring
    node verify/webcheck.mjs docs out.png                 # does the build boot
    node verify/webcheck.mjs <live-url> out.png           # does the live link boot

Each of these exits non-zero on a finding and prints what it found, so
`./verify/gates.sh` is the one command to run before pushing. The browser
check is explicitly reported as skipped when Playwright is unavailable;
gameplay checks can still pass in that environment, but the aggregate result
will not claim that every gate ran.

`verify/clips.gd` asks each delivered file what animations it contains and
fails on the first name `content/cast.gd` gets wrong. Roughly thirty clip
names are hand-written in that table and a re-rig or a renamed export turns
any one of them into a diver standing still in the middle of a fight.

`verify/animations.gd` instantiates every delivered rig and drives it through
idle → swim start → loop → end → idle plus both damage reactions. Mermaid's
carried staff must be present, visible and skinned to the same skeleton.

`verify/swim.gd` drives the real scene through swimming and coming to rest. It
fails if a diver does not move, falls through the floor, loses the camera, or
plays the wrong character's clip off the shared rig. It also requires the full
idle → swim start → swim loop → swim end → idle sequence and feeds a real mouse
motion event through Godot's input pipeline, so hard-coding the exploration
camera instead of preserving mouse-look fails the gate.

`verify/balance.gd` runs 120 deterministic seeds through a careless policy
and a greedy policy using the production roster, moves, enemy scaling and
damage/mitigation function. It fails when careless play almost always wins or
loses, when better choices do not improve the result, or when even winning
fights cost too little time or HP to exert pressure.

`verify/fight.gd` starts a real encounter from the overworld and plays it to
the end by pressing the actual buttons, then checks the world came back. It
fails if the fight never resolves, if the battle screen ever has nothing left
to press, if any of the three never swings, or if somebody swings with another
character's animation. A full fight is about 50 party turns' worth of button
presses and takes a bit over a minute.

`tools/test_goblin.gd` and `tools/test_battle.gd` instantiate those two systems
in isolation - useful for telling a bug in the game itself apart from an
editor/Play problem, since they run the exact same scripts outside the editor.

`verify/webcheck.mjs` loads the build in Chromium with software WebGL2 and
fails if the canvas is a flat field of one colour. `verify/ffcheck.mjs` does
the same in Firefox, which is worth running separately: it is several times
slower to first frame than Chromium here, and a build that looks fine in one
can stall in the other.

## GitHub Pages

`docs/` is already a complete web build, so Pages can serve it with no
workflow and no build step. It needs one switch that only a repo admin can
flip: Settings, Pages, Source "Deploy from a branch", branch `main`, folder
`/docs`. The Vercel link above works either way.
