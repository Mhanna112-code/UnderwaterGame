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

## Run it from source

Godot 4.7.1, no plugins, no build step. Clone and open the folder as a
project, then press F5. `game/world.tscn` is the main scene.

## What is here

- `art/characters/Main_Team_Rigging_2.fbx` as delivered, plus Godot's import
  settings beside it. Godot 4.7 reads FBX natively, so there is no conversion
  step and no committed intermediate.
- `game/diver.gd` handles everything the export has opinions about: the models
  stack on one origin, carry a -90 degree X rotation with a scale of 100, and
  face +Z where Godot's forward is -Z. Fixed once, there.
- `game/world.gd` is the dive site and the camera.
- `game/lineup.tscn` stands the whole cast in a row with their measured sizes,
  for looking at rather than playing.
- `docs/` is the exported browser build.
- `verify/` and `tools/` are the checks. Every number in `docs/art-intake.md`
  comes out of one of them.

## The models are not rigged

The FBX is called `Main_Team_Rigging_2` but it carries no bones, no skin
deformers and no blend shapes. See `docs/art-intake.md` for the evidence and
for what to change on the Blender side.

That is why nobody here has a swim stroke. Every bit of motion is procedural
and applied to the whole model: the body pitches into a glide when it gets
moving, stands up when it stops, bobs, banks, and trails bubbles. It reads as
alive from a distance and it will not survive a close-up. Once a rigged export
lands, that code is where the real animation replaces it.

The lantern is planted in the seabed as a beacon for the same reason. Carried,
it read as a stick floating beside somebody, because no diver in this export
has a hand to hold it with.

## Checks

    godot --headless --path . --script verify/swim.gd     # do they actually move
    node verify/webcheck.mjs docs out.png                 # does the build boot
    node verify/webcheck.mjs <live-url> out.png           # does the live link boot

`verify/swim.gd` drives the real scene for two seconds of play and fails if a
diver did not move, fell through the floor, stayed bolt upright, or lost the
camera. `verify/webcheck.mjs` loads the build in Chromium with software WebGL2
and fails if the canvas is a flat field of one colour.

## GitHub Pages

`docs/` is already a complete web build, so Pages can serve it with no
workflow and no build step. It needs one switch that only a repo admin can
flip: Settings, Pages, Source "Deploy from a branch", branch `main`, folder
`/docs`. The Vercel link above works either way.
