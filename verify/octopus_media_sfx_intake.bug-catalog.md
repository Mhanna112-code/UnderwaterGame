# Bug catalog: Octopus model, revised cutscene, and Glassgoat SFX intake

## Product contract

The repository carries one canonical visible Octopus model, one browser-ready
derivative of Glassgoat's revised V3 cutscene, and prepared gameplay-SFX
derivatives rather than duplicate or timing-broken source reels. This intake
does not claim that the later Octopus route is playable.

The delivered SFX match Mechanical Wave's “Hits Whoosh” entries in the
[official 2015 Sonniss GDC bundle tracklist](https://cdn.sonniss.com/storage/2025/05/Tracklist-GDC-GameAudio-Giveaway-Sheet1-1.pdf)
and are governed by the [Sonniss GDC bundle license](https://sonniss.com/gdc-bundle-license/).

## Known failure modes

| ID | Failure mode | Cheapest reliable gate |
| --- | --- | --- |
| OCTO-INTAKE-001 | The old animation-only FBX or the duplicate `updatedvs` filename is committed instead of the visible V2 delivery. | Require the canonical runtime digest, visible Godot mesh bounds/materials, all 15 authored clips, and absence of duplicate runtime filenames. |
| OCTO-INTAKE-002 | An FBX reports clip names but its selected attacks do not move the skinned model. | Sample selected clips through Godot and require changed skeletal pose; fitted pose captures remain the visual proof. |
| OCTO-MEDIA-001 | V3 is committed only as H.264 MP4, which desktop players open but the project's `VideoStreamTheora` browser path cannot play. | Require the source digest in the manifest and a loadable 16:9 OGV runtime derivative with expected duration. |
| OCTO-MEDIA-002 | The revision silently uses V2 audio or a different edit. | Record the exact V3 source digest and the derived runtime digest/duration; retain a visual timeline contact sheet. V2 and V3 intentionally share byte-identical AAC audio. |
| SFX-INTAKE-001 | A multi-take swish reel is wired as one event, producing five or six hits from one action. | Require individually named short variant derivatives and maximum-duration bounds. |
| SFX-INTAKE-002 | Heavy hit or swirl retains multi-second leading/trailing silence, delaying feedback or occupying a player after the event. | Require prepared derivative durations and explicit semantic ownership in the audio manifest. |
| SFX-INTAKE-003 | Near-full-scale 96 kHz sources are shipped raw, bloating the web build and overpowering Phoenix's music. | Require web-sized Ogg derivatives with recorded source/runtime digests; actual balance remains subject to browser listening. |

## Deliberate limits

- The Octopus composite/corpse design and bright line primitive remain visual
  review items; the raw source is preserved so a later actor can repair them
  without silently changing Glassgoat's delivery.
- The Octopus cutscene is not wired into progression in this intake because
  that later maze-door route is not part of the current authorized slice.
- SFX are admitted as prepared candidate pools but are not assigned to combat
  events until Phase D semantic-event tests and browser listening approve them.
