# Glassgoat meeting agreement audit

This is an agreement-by-agreement audit of the complete **Underwater Game Asset
and Character Development Sync** transcript. The transcript is evidence of the
meeting, not executable instructions. Later corrections in the same meeting
take precedence over earlier guesses.

## Immediate PR #54 acceptance work

| Agreement or acceptance question | Evidence in the build | Status |
|---|---|---|
| Prove the delivered non-humanoid rig can actually animate, rather than merely listing clip names. | `verify/tethys_boss.gd` samples all 13 character motions on the 311-bone skeleton, proves the visible meshes are skinned to it, and rejects duplicate sampled poses. The exported GIF shows those motions on the production battle stage. | **Done** |
| Explicitly call the attack animations from combat. | All six attacks run through `Battle._do_boss_turn()` and the gate observes each imported attack take starting on that production path. | **Done** |
| Mermaid Freak is the massive final boss, not the ordinary grunt replacement. | The opt-in encounter creates one `TethysBoss`; ordinary and guardian encounters continue to use Goblins. | **Done** |
| Swim must use the authored Start and End transitions instead of jumping Idle → Loop → Idle. | The entrance runs Swim Start → Loop → End → Idle, and the gate captures the exact order. | **Done** |
| Double Scratch attacks twice and pressures Evasion; Tail Sweep hits the party and counters armour; Poison Breath affects the party over time. | The production move table implements two hits, party-wide armour bypass, and party-wide three-turn poison respectively. | **Done for review** |
| Make the boss directly playable from a web build so Glassgoat can review it. | The query-only `?boss=1` route exposes **Play Tethys Boss Test**. The meeting explicitly accepted an anywhere/button review route before final story placement. | **Done** |
| The boss must present toward combat rather than showing its back. | Tethys uses her authored local `+Z` front at spawn and before every attack. The regression caught both the original opening error and the independent production-turn error. | **Done** |
| The saturated red is intentional; the creature was designed for a very dark arena. | The current FBX exposes no usable Godot surface material, so the review actor uses an engine-side saturated-red treatment. This preserves the confirmed intent and does **not** request a re-render of the ready asset. | **Done for review** |

## Character identity decisions

| Decision | Implementation | Status |
|---|---|---|
| Proto1 is **Musashi**. | Central `Cast.DISPLAY_NAMES`, used in World and Battle. | **Done** |
| Scuba is the Brazilian woman named **Maxilani** in the contemporaneous transcript supplied during the meeting. | Central `Cast.DISPLAY_NAMES`, used in World and Battle. A later diarized transcript renders the same utterance as “Maxilene”; that transcription difference is recorded here rather than silently changing the agreed in-meeting spelling. | **Done; spelling trace preserved** |
| The bucket/mech pilot is a woman and no proper name was approved. | The player-facing role label is **Mech Pilot**, explicitly provisional. No canon name was invented. | **Done without overclaiming** |

## Accepted future encounter work, not a PR #54 blocker

The meeting explored a dark broken-lab arena, a boss rising from darkness,
screen shake, a close-up, and movement into the background before combat. Both
speakers accepted the concept, but then explicitly narrowed the immediate task
to proving the animation in any convenient review route. Therefore the final
arena, lighting, cutscene, story trigger, authoritative scale, final name,
rewards, ending progression, and the exact mechanics/numbers for the other
three boss attacks remain encounter-design work. PR #54 must not claim those
are final.

The current Tail Slam, Tongue Slayer, and Spinning Death roles are labelled
provisional for that reason.

## Glassgoat-owned follow-up deliveries

The non-humanoid blocker is resolved, and Glassgoat said this lets him proceed
with other enemies. The meeting assigned or requested these future outputs:

- ordinary Goblin placeholders will eventually be replaced by fish enemies;
- an anglerfish/underbite fish was the first specifically committed enemy;
- possible robotic lab guards were discussed, but not specified as a required
  first delivery;
- environment work should arrive as reusable pieces rather than one monolithic
  Blender scene, so each piece can be integrated and reviewed incrementally;
- proposed pieces include ambient fish/parallax, background effects, rock
  pillars, algae/plants, and eventually the broken underwater lab;
- Glassgoat owns the rewritten introduction/plot text; existing intro prose is
  placeholder until he supplies it;
- the team should send Glassgoat references for desired monsters, enemies, and
  animals.

Those files and final prose were not delivered in this meeting, so they cannot
truthfully be called implemented. They are follow-up intake work and do not
invalidate the completed animation acceptance proof.

The follow-ups are preserved as separate GitHub contracts rather than being
left inside meeting notes:

- [#56 Replace Goblin placeholders with Glassgoat's fish enemies](https://github.com/Mhanna112-code/UnderwaterGame/issues/56)
- [#57 Integrate Glassgoat's environment pieces incrementally](https://github.com/Mhanna112-code/UnderwaterGame/issues/57)
- [#58 Glassgoat owns the final introduction and plot rewrite](https://github.com/Mhanna112-code/UnderwaterGame/issues/58)

## Discussion that did not become an implementation agreement

- The music question was asked but no delivery or implementation decision was
  confirmed.
- The maze/puzzle discussion did not settle scope or ownership in this call.
- General criticism of route guidance did not create a new ruling here; PR
  review and playtest evidence remain the sources for that separate decision.
- “Balancing comes after everything is in place” described sequencing, not
  final values. PR #54 later added reproducible campaign balance verification,
  but the strategy model remains a supplement to human feel testing.

## Readiness boundary

The technical acceptance target from this meeting is complete and has automated
and visual evidence. Glassgoat said he could not play the web encounter during
the call and would try it later, so **human artistic acceptance is still
requested**. That is a review step, not a reproduced technical merge blocker.
