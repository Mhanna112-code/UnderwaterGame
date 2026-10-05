# Opening free-swim regression — 2026-10-05

## Responsibility and public interface

The opening trigger accepts actual requested horizontal swimming after New
Game. World owns video completion, the phase enum in RouteState, and Battle
creation. The test starts an isolated saved run through New Game, observes real
physics and actors, and supplies keyboard movement; it never assigns a phase,
enemy roster or battle result. Only the introductory video's playback is
bypassed in the native test; the exported browser test plays the real video.

The trigger's load-bearing contract excludes idle time, camera-only input,
passive displacement and blocked input. It requires four seconds of actual
swimming and at least three metres of horizontal displacement, then fires once.
World's branches are completed opening, spawn delay, active battle, transition,
and requested movement. RouteState normalizes loaded completion rather than
persisting transient movie/battle ownership. IO boundaries are real physics
timing, the isolated test save, the video decoder, and rendered battle actors.

## Bugs and tests

| Bug | Impact / plausibility | Test | Status |
| --- | --- | --- | --- |
| OPEN-042: the film reveals exploration but a timer starts Cordys without input | High: dc9f8f7 replaced the movement predicate with an unconditional boss handoff | Existing 15-second idle plus camera-only World integration negative path; exported full-movie journey | Caught; native repaired |
| OPEN-043: a misleading `prologue_angler` label masks an actual Cordys roster | High: the direct-Cordys implementation retained the old dispatch label | Require one living, visible Angler actor with its actual display name after swimming | Native repaired |
| OPEN-035: earlier idle/look time consumes the swimming interval | High: a nominal movement gate can still fire on the first input | Existing real W duration assertion and heading/frame-rate/idle property matrix | Native characterized |
| OPEN-044: restoring Angler leaves victory/recovery or completed Load stranded | High: removing one handoff can disconnect later lifecycle ownership | Focused real-button journey through Angler kill, later Cordys response, recovery Continue and fresh title Load | Native characterized |

Wrong-but-stable automatic handoff fails before swimming. An Angler-labelled
Cordys fails the actor/roster assertion. Equivalent lifecycle/owner refactoring
does not change these player-observable results. The existing generated trigger
matrix covers 24 headings × four frame durations × four prior-idle durations,
plus blocked, passive, vertical and displacement boundaries.

`opening_rollback_journey.gd` reuses the established journey's button helpers,
not manufactured battle results. It accelerates movies only and stops before
the unrelated mandatory combat curriculum. It requires full recovery and a
real saved completion before rebuilding World through Load. A permanently
stranded or repeating opener fails; equivalent state ownership changes pass.

## Skipped

- Tethys redesign and relocating Cordys's later introduction: explicitly out of
  scope. This restores the earlier Angler-first opener; it does not replace the
  later scripted Cordys encounter following an actual Angler defeat.
- Full campaign balance, unrelated tutorial redesign and target-platform native
  certification: separate unfinished work, not implied by this repair.
- Existing player save mutation: isolated tests only; durable completed saves
  must remain completed and interrupted saves must resume safely.

## Evaluation

Current main before repair: six findings, including an unsolicited Cordys
introduction during idle and zero actual swimming. Repaired World: 15 seconds
idle plus camera input stays in exploration, 4.254 seconds of actual W input
starts one visible Angler. Trigger property matrix, state migration, World
single-Battle ownership, video viewing/save fallback, ordinary Angler contract
and actual-button recovery/Load journey pass without script or engine errors.
Recovery journey used two Angler actions and three genuine Cordys responses;
all party members recovered, no progression was granted, fresh title Load did
not replay the movies or combat. Exported browser and canonical identity
acceptance remain required before delivery; native video fast-forward is not
proof of real decoder playback.
