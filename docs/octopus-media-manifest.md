# Octopus media intake manifest

This is a verified asset intake, not a claim that the Octopus route or fight is
implemented. The current vertical slice ends at the existing maze transition.

## Visible model

| Field | Value |
| --- | --- |
| Canonical source | `/Users/tomriddle1/Dropbox/Octopus_Boss_V2.fbx` |
| Source/runtime SHA-256 | `e51ac165292525291714505341661067dc56022b20dc52d7aa29ccdf2d491792` |
| Runtime path | `res://art/deep_zone/Octopus_Boss.fbx` |
| Import proof | 7 meshes, 6 materials, 34,585 vertices, 41,928 faces, 203 bone bindings |
| Authored animation proof | 15 clips; Idle, Head Bash, Poison Breath, and Spinning Slay visibly animate in Godot |

`Octopus_Boss_updatedvs.fbx` is byte-identical to V2 and is deliberately not
committed as a duplicate. The old `Octopus_Boss.fbx` delivery had animations
but no renderable geometry and is not used.

The replacement is a composite boss with Octopus, Sword Fish, Angler, Frilled
Shark, Merfolk, and Bomb Bot corpse materials. That may be narrative intent,
but it still requires Glassgoat's confirmation. Some attack poses expose a
bright line primitive as long white rods. The future boss actor must suppress
or repair that surface before gameplay can be approved.

## Revised cutscene

| Field | Value |
| --- | --- |
| Canonical source | `/Users/tomriddle1/Dropbox/Octopus_demonV3.mp4` |
| Source SHA-256 | `138c4d3d4b720febae992e6cd8e8c30260513caaeb8e359a0240a8b69665226b` |
| Runtime path | `res://media/cutscenes/octopus_demon_v3.ogv` |
| Runtime SHA-256 | `8cad2b4924837aedd38eac035ff9733231d550f3754b487f220fd97f2588033c` |
| Runtime encoding | 1280×720, Theora video, Vorbis stereo audio at 48 kHz |
| Duration | 60.714667 seconds |

V3 improves capitalization, pronouns, punctuation, and the final visible reveal
of “Cordys, Mistress of the Puppets.” Its AAC source audio is byte-identical to
V2; the revision is visual/textual. Red text on black remains low-contrast, and
the sentence “I made your furnaces heat it from below to above all.” remains
awkward. The file is admitted for later-route integration but is not yet wired
into progression.

## Evidence and automated contracts

- `docs/evidence/octopus-intake/octopus-godot-idle.png`
- `docs/evidence/octopus-intake/octopus-godot-head-bash.png`
- `docs/evidence/octopus-intake/octopus-godot-poison-breath.png`
- `docs/evidence/octopus-intake/octopus-godot-spinning-slay.png`
- `docs/evidence/octopus-intake/octopus-v3-timed.jpg`
- `verify/octopus_asset_intake.gd`
- `verify/octopus_cutscene_asset.gd`
