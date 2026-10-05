# Maze audio ownership

Read: full audio_manager.gd, Maze ready/battle/result/secret/checkpoint owners,
Battle wave/finisher consumers and current cue map. Public audio cue state and
transition signals own observable sequencing. Phoenix requires INTRO→LOOP with
no crossfade, one player; identical cue calls are idempotent. User bus settings
are separate from cue trims. World stops its music before handing off to Maze;
Maze currently never starts exploration or battle music (except Game Over).
Wave transition has no result and must not restart music. Return/restore must
restore the exploration owner, never prologue/title. Tests: existing manager
pins stream contracts but cannot accept live maze dispatch or audible seams.

Ranked bugs: silent maze after World stops music (real Maze entry cue assertion);
silent/wrong puppet or final encounter (actual proximity/sigil cue assertion);
wave one restarts Battle INTRO (real wave boundary transition-count invariant);
resolved fight leaves boss track in exploration (actual Maze victory callback);
loss overwrites Game Over with exploration (existing real death/checkpoint gate).

First test: actual Maze ready must emit exploration loop state. No direct
audio-helper call accepts it; native sound listening is separate. Headless tests
observe semantic cue ownership, not hardware, audible volume or seamless joins.
Skip new music/assets/global mix redesign. Listening/export/browser checks remain
mandatory follow-up, not claims established by trace assertions.

Evaluation: actual Maze entry reproduced silence. Ready now owns exploration;
actual puppet confirmation selects Battle INTRO, actual final sigil selects
Cordys INTRO, and actual maze wins return exploration. The live puppet boundary
retains the same music transition trace across both waves. No crossfade or cue
replacement was added to the shared audio manager.

Carried-party testing discovered a separate state-owner bug: Maxilani's Sonar
continued billing shared O2 while combat was active. Actual Q/guard contact plus
a timed no-player-action interval reproduced it independently. World/Maze now
suspend exploration clocks for their fights and resume on results, retaining
Sonar's setting/tick rather than toggling/resetting it. The actual two-wave Maze
win retains Sonar preference and returns its clock; ordinary/prologue World
timed ownership and all departure/error paths remain follow-up checks.

The carried-party policy initially lost after spending first-wave turns healing,
letting Angler stack persistent Bleed. Clearing threats before second-wave healing
wins without stat edits. Its first input probe also observed only one queued
process frame; using the existing two-frame delivery contract fixed that fixture.
Neither is presented as a production fix or a global balance conclusion.
