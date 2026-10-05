# Combat SFX playback bug catalog

The asset-intake gate proves that Glassgoat's reviewed derivatives exist and
import. It does not prove that a player can hear them. These are separate
failure modes and this catalog covers the runtime half of the contract.

| ID | Player-visible bug | Cheapest reliable detector |
| --- | --- | --- |
| COMBAT-SFX-001 | An attack animates silently because no swing sound is requested. | Audio-manager contract test calls the public swing event and observes its semantic trace. |
| COMBAT-SFX-002 | A landed attack, miss, or dodge has no distinct audio feedback, or one result overwrites the swing before it can be heard. | Contract test starts swing then result and proves two different pooled SFX players own the two streams. |
| COMBAT-SFX-003 | Battle computes and displays a damage result but never forwards that player-visible result to audio. | Production-path test invokes Battle's real combat-feedback method and observes `combat_hit` through GameAudio. |
| COMBAT-SFX-004 | Bucky's shockwave challenge starts with no cue, leaving the delivered shockwave sound unused. | Audio-manager contract test calls the public shockwave event and observes its semantic trace. |
| COMBAT-SFX-005 | Combat players bypass the SFX bus, so the in-game SFX volume/mute controls do not affect them. | Contract test inspects every combat player bus. |
| COMBAT-SFX-006 | Headless verification leaks compressed streams after disposing the audio owner. | Contract test releases the manager and verifies every pooled player dropped its stream. |

## Scope

This increment intentionally maps the delivered sounds to a restrained set of
semantic moments: attack start, landed impact, miss/dodge, and Shockwave start.
It does not invent bespoke sound design for every move or continuously replay
the ten-second Shockwave source.
