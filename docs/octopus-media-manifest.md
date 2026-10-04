# Octopus media intake manifest

This is a verified asset intake plus a prologue-only presentation owner. It is
not a claim that the later Octopus route or campaign fight is implemented.

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
Shark, Merfolk, and Bomb Bot corpse materials. Glassgoat supplied the complete
asset for project use. Some raw attack poses exposed the pale Swordfish bill as
long white rods. `PrologueOctopus` preserves that mesh while applying a dark
underwater material tint, and the opening gallery verifies the resulting
reveal, idle, hurt, and finishing poses. Campaign ownership remains deferred.

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
- `docs/evidence/opening-prologue-cordys/cordys-reveal.png`
- `docs/evidence/opening-prologue-cordys/cordys-idle.png`
- `docs/evidence/opening-prologue-cordys/cordys-hurt.png`
- `docs/evidence/opening-prologue-cordys/cordys-finish.png`
- `verify/octopus_asset_intake.gd`
- `verify/prologue_octopus.gd`
- `verify/octopus_cutscene_asset.gd`
