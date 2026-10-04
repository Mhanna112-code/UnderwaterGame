# Cordys opening prologue — implementation plan

**Status:** execution in progress; Phases 0 and A complete.

**Prepared:** 2026-10-03

**Parent:** PR #96, `feature/deep-zone-vertical-slice`, confirmed remote source
head `27a5b5253256a26733f8a320c3c6b4f97c64dece` on 2026-10-03.

**Current child candidate:** clean worktree
`/Users/tomriddle1/underwatergame-opening-prologue` on
`feature/opening-octopus-prologue`, based exactly on the confirmed parent SHA.

**Current deployment:** Shallows guidance candidate from runtime source
`4836d0198aa4a3468f570df31782a0cedb36eb92`:
`https://underwatergame-opk53hlsh-immortaldemongods-projects.vercel.app/`.
PCK SHA-256 `ea5ef3c1d7e879c41392d7ed85ad62b5f63b9536189e74d3e5ab3fe08d714e8e`.
Stable review alias: `https://underwatergame-opening-prologue-review.vercel.app/`.
The stable alias serves that candidate after actual hosted full movies,
title/reveal, swimming, combat, recovery and cold Load (94.215s to control).
Shallows visibly says `Shallows: fight to grow stronger.`; Deep and local
puzzle hints retain their location/priority. No injected completion or review
flag in the full opening run; geography fixtures are explicit in the separate
eight-observation boundary/puzzle run. Evidence: `docs/evidence/shallows-guidance/`.
The movie now closes with a brief question/credits/title and fades into control;
native held-input isolation and save/load gates pass. Its hover remains quieter,
filtered/faded, 180ms and rate-limited (prior source-labeled WebAudio proof).
Native wide/narrow Shallows frames and existing Deep/defaults gates also pass.
Earlier opening/free-swim/restart/storage evidence remains in its original
packets; this is not a new actual later-death/Restart or storage-fault run.
Prior title/held-input/idle proof: `docs/evidence/opening-title-handoff/`.
There is no idle fallback. Sonar and encounters enable at opening recovery.
This is a review candidate, not final acceptance. The inherited PR #96 alias
remains baseline only; `underwatergame.vercel.app` remains the Oct 1 deployment.

**Child branch:** create a clean worktree from the confirmed PR #96 head and
use `feature/opening-octopus-prologue`. Open its PR against PR #96 so the first
review shows only the opening delta. After PR #96 merges, retarget/rebase onto
`main` and re-run every acceptance gate.

**Companion contracts (repository copies are binding):**

- `docs/opening-prologue-asset-manifest.md`
- `verify/opening_prologue.bug-catalog.md`
- `docs/opening-prologue-visual-audit-log.md`
- PR #96's `IMPLEMENTATION_PLAN.md`, `INVENTORY.md`, audio manifest, Octopus
  manifest, and existing verification catalogs remain inherited evidence.

## Execution progress

| Phase | Status | Exit evidence |
| --- | --- | --- |
| 0: clean child branch | complete | Remote PR #96 head `27a5b525…`; clean child worktree; initial diff contains only these four planning contracts. |
| A: contracts and asset intake | complete | Durable state/migration gates; canonical manifests; 4 m prologue Cordys adapter and four-pose gallery; pinned Final Boss Ogg derivatives and authored gain gate. |
| B: opening video lifecycle | in progress | Native lifecycle/policy/save gates green. Latest title/reveal now joins the movie to control with credits/question and settled camera/HUD; real EOF/held input, 1280x720/720x480 title frames and normal hosted movie/title/idle/swim pass (`opening-title-handoff/`). Earlier full Cordys/recovery journey remains source-labeled. Tall/final whole-candidate listening/human acceptance remain. |
| C: quiet spawn and Angler | in progress | OPEN-035 removed the old seven-second idle fallback. Four seconds of requested, actual horizontal swimming are required; idle, camera-only, blocked input and passive motion cannot consume that window. Native idle/look/swim and 384-case direction/frame-time/prior-idle matrix pass. Exact hosted full-movie idle/look/late-swim passes: 15.007 seconds stationary, then 4.001 seconds of real W before Angler. Continuous video shows actual displacement; remaining broader visual/human acceptance is not claimed. |
| D: Cordys interruption | in progress | OPEN-036/037 replace the forced HP-zero finisher and Angler-derived accuracy rewrite with normal player moves/effects and actual STR/DEF/ACC/EVA retaliation. Native 15-case button/differential matrix and three high-HP survivors pass. OPEN-038 duplicate impact cue was caught and repaired. Exact hosted normal-entry Axe Kick shows 4 damage, 996/1,000 boss HP, then 80/78/76 retaliation. Browser later-death/Restart/Load and denied-storage/Retry/cold-Load pass. Framing remains green; complete final listening/human audit remains. |
| E: recovery and optional training | in progress | Prior checkpoint proofs remain; current `296b1a5` reruns native actual death/Restart/Load, training Skip/death, denied recovery save, optional training and migration. Hosted full opening with 16.753 s deliberate idle/look takes 105.643 s total (88.890 s engaged), then cold Load/two actual deaths/Restart/title Load pass without replay/errors. Separate hosted rejected IndexedDB commit/Retry/cold Load passes. Attrition fixtures are documented, not campaign balance evidence. |
| F: exact artifact and polish | in progress | Stable alias serves runtime `4836d01`; unauthenticated metadata/PCK match the 93,827,780-byte archive export. Latest `shallows-guidance/` packet: full normal opening/recovery/cold Load, eight rendered geographic observations, wide/narrow native guidance and unchanged Deep/defaults gates. Prior title packet retains initial camera/HUD defect and corrected replay/GIF; prior menu-audio/combat/death/storage proofs remain source-labeled. Blind test, user listening acceptance, remaining viewport checks, OPEN-032 training-label occlusion, OPEN-046 close save-crystal occlusion and final zero-defect audit round remain. |

Update this table whenever a phase changes state. A phase may be `in progress`
or `complete` only when its stated stop gate and evidence exist; code presence
alone is not completion.

## Goal

Replace the mandatory intro-crawl/tutorial funnel with a short authored hook
that gives the player a reason to care before instruction:

1. preserve the existing cover art;
2. play Glassgoat's Mermaid Freak video as a temporary first-run opening;
3. return control in a quiet free-swimming spawn;
4. fight a modestly weaker Angler with ordinary stats, full moves and real turns;
5. have Cordys interrupt the victory, receive one normal combat action, and
   decisively defeat the party;
6. recover the party, establish the long-term goal, and save safely;
7. restore the existing combat tutorial as an optional nearby beacon;
8. continue into the existing PR #96 game without redesigning its later route.

The opening succeeds when a context-free player understands who defeated the
party, that the defeat was intentional, what they hope to accomplish later,
and that Combat Training is optional.

## Binding scope

### Included

- New Game title-to-opening handoff.
- Temporary opening playback of the existing Mermaid Freak media.
- A public prologue state contract and backward-compatible save migration.
- A direction-independent quiet-spawn encounter trigger.
- A dedicated prologue Angler configuration that cannot alter ordinary
  Angler balance.
- A visible, production-framed `PrologueOctopus` presentation using the
  delivered Octopus FBX and selected authored clips.
- A scripted defeat result distinct from normal Game Over.
- The recovery message: `Grow stronger. Find a way to defeat Cordys.`
- Independent `opening_video_seen`, `prologue_complete`, and
  `tutorial_complete` state.
- The existing tutorial as optional training, with its current content,
  Retry, Return to World, Skip, Combat Help, and replay paths preserved.
- A prologue-specific audio mix that preserves PR #96's exploration and
  battle music and introduces Phoenix's Final Boss motif for Cordys.
- Automated, real-window, exact-export, hosted-browser, listening, and blind
  playtest evidence.

### Explicitly not included

- Redesigning PR #96 after the recovery handoff.
- Rewriting the existing tutorial curriculum, storyboards, ability onboarding,
  Combat Help, Shallows, Deep route, Tethys lab, maze, or random encounters.
- Implementing or balancing the eventual campaign Cordys fight.
- Marking campaign Octopus route state available, in progress, or defeated.
- Adding rewards, XP, Spell Points, key items, or level progression to either
  prologue encounter.
- Replacing the eventual maze-door Octopus route.
- Camera shake, forced zoom punches, or screen-wide flashes. These are blocked
  on reduced-motion support and are unnecessary for this slice.
- Claiming the temporary Mermaid video is Glassgoat's final opening.

## Reconciliation with PR #96

This plan changes the three original PR #96 dispositions below. Later
explicit user corrections also enable Sonar/encounters at recovery and scope
world guidance by location: lab prompts only in Deep, short Bucky Shockwave
prompt near the intact puzzle entrance, retired on destruction/consumed Load.
After opening completion, clear Shallows show `Shallows: fight to grow stronger.`
in the same single HUD panel. The intact-wall hint takes priority there;
physical entry into Deep replaces it with the lab instruction, and returning
restores the Shallows prompt without erasing `find_lab` progression. This is
orientation and purpose, not a compulsory grinding quota or balance change.
They do not redesign later progression, encounters, puzzle/maze or abilities.

| PR #96 decision | Opening-prologue decision |
| --- | --- |
| Octopus has verified media but no runtime gameplay owner. | The asset gains a **prologue-only presentation owner**. Campaign Octopus progression and balance remain deferred. |
| Phoenix's Final Boss INTRO/LOOP pair is reserved for a later route. | The prologue uses the beginning as Cordys's leitmotif. The later campaign fight retains ownership of the complete presentation. |
| Mermaid Freak video is the skippable Tethys/lab cutscene. | The same runtime OGV is temporarily reused as the first-run opening without duplicating bytes. The lab copy stays skippable and unchanged. |

The temporary repeated Mermaid video is an explicit product decision, not an
unnoticed defect. Glassgoat's final opening replaces only the opening asset
reference and removes the repetition. It must not alter the lab cutscene.

## Exact player-facing sequence

### Approved cinematic pacing revision, 2026-10-03

The original 0.65-second false-relief beat was judged potentially too abrupt.
Use the approved edit `octopus_prologue.ogv` as a **single continuous decoder**: play its first
25 seconds after the Angler falls, pause/hide it during Cordys combat, then
resume its boss-name ending after defeat and before recovery motivation. Do not seek,
duplicate the video bytes, play exploration/boss music under its embedded
audio, or return to the world between these beats. Video failure retains the
concise Continue recovery path. The lab Mermaid owner is unchanged.

Expose `octopus_introduction` and `octopus_aftermath` as transient public
phases. Interrupted sessions still normalize to quiet spawn, with no new
durable cinematic completion field. The prologue completion write remains
after the aftermath, full restoration, safe placement and motivation.

Miguel explicitly approved removing the long “You arrived…” monologue while
keeping the boss-name ending. Retain source [0,25) and [54⅓,EOF): frames
0–749 and 1630–1820 at 30 fps, with matching audio intervals. The first
“C” of Cordys and the complete “Mistress of the Puppets” ending survive.
The edited footage is about 31.38 seconds. The original Dropbox MP4 and
PR #96 archival OGV stay unchanged; exclude that unused full OGV from this
child's web package. Only the edited derivative is live. Earlier 109–119 s
journey measurements used the full V3 and are historical, not current-edit
timing acceptance. Re-run exact native/browser journeys and listening review.

```text
cover art (silent)
  -> New Game and slot selection
  -> temporary Mermaid Freak video (first completed viewing cannot skip)
  -> movie/audio fade to black (final 550 ms, no media edit)
  -> brief title: UNDERWATER / Can you survive the deep? / art and music credits
  -> fade into the visible world/controls (3.55 s total title/reveal)
  -> quiet free-swimming spawn with restrained exploration ambience
  -> at least four seconds of actual swimming, never an idle countdown
  -> one-Angler prologue battle
  -> ordinary combat actions defeat the 3-HP Angler (normal species HP is 5)
  -> no victory fanfare; brief false-relief pause
  -> first 25 seconds of the Octopus V3 cinematic, with its own audio only
  -> environment darkens and Cordys interrupts the same battle presentation
  -> Phoenix Final Boss intro begins on the reveal
  -> one real player action resolves normal damage/status/cost rules
  -> one authored Cordys finishing move defeats the party
  -> music ends; approximately one second of silence
  -> resume at the Cordys title ending from the edited movie's paused 25-second position
  -> recovery card: “Grow stronger. Find a way to defeat Cordys.”
  -> fully restored, saved, controllable normal PR #96 world
  -> optional Combat Training beacon nearby
```

No user-facing copy introduced by this slice may contain an em dash.

## Public state contract

### Durable saved fields

| Field | New save | Old save with field absent | Meaning |
| --- | --- | --- | --- |
| `opening_video_seen` | `false` | `true` | The temporary/final first-run opening completed successfully. |
| `prologue_complete` | `false` | `true` | The scripted Cordys defeat and recovery completed. |
| `tutorial_complete` | `false` | infer from existing completed/skipped tutorial state, otherwise `true` for an old save | Optional Combat Training is retired. |

The initial New Game save must explicitly contain `false`; field absence is
reserved for migration of existing PR #96 saves. This prevents old saves from
being indistinguishable from a newly-created pre-opening save.

### Observable runtime phase

Expose one public phase and a `phase_changed` signal:

- `title`
- `opening_video`
- `spawn_exploration`
- `angler`
- `octopus_introduction`
- `octopus_reveal`
- `octopus_response`
- `scripted_defeat`
- `octopus_aftermath`
- `recovery`
- `complete`

The HUD, audio owner, verifier, and transition controller consume this public
contract. Tests must not depend on private helper order.

### Encounter source

Add two semantic sources:

- `prologue_angler`
- `prologue_octopus`

They must never be treated as `random`, `lab_blocker`, `lab_boss`,
`maze_door`, guardian, tutorial, or campaign Octopus encounters.

### Campaign Octopus state

The prologue never changes `RouteState.octopus_state`. That state remains
`unavailable` until the future maze-door route explicitly owns it.

## Save and interruption normalization

Transient video, Battle, tween, timer, audio-player, modal, and actor nodes are
never serialized.

| Interrupted state | Next load |
| --- | --- |
| Before or during the opening video | Replay the opening video. |
| Video completed, before movement | Start at quiet spawn; do not replay the video. |
| During the Angler | Normalize to quiet spawn and restart the trigger. |
| During either Octopus cinematic portion | Normalize to quiet spawn and restart the playable prologue; no decoder position is serialized. |
| During Cordys reveal/response/defeat | Normalize to quiet spawn and restart the playable prologue; do not replay the video. |
| During recovery after state write | Restore a healthy party in normal play; do not repeat Cordys. |
| Old PR #96 save | Enter normal PR #96 play with the prologue treated as complete. |
| Missing/failed video decoder | Show a concise `Continue` recovery action; never leave a black soft-lock. Record the failure. |

Write `opening_video_seen = true` immediately after successful playback.
Write `prologue_complete = true` only after party recovery and the long-term
motivation have been committed. Save again before control returns.

## Opening and tutorial independence

Completing the prologue unlocks normal play. It does not complete or start the
tutorial.

After recovery, spawn the existing tutorial beacon outside its activation
radius with a clear path and the label `Optional Combat Training`.

The beacon:

- is not the active route objective;
- does not capture the camera;
- has no compulsory off-screen arrow;
- remains available after a tutorial loss followed by Return to World;
- retires after completion or an explicit in-battle Skip;
- launches the current PR #96 tutorial unchanged;
- triggers the current post-tutorial ability onboarding only when the player
  chooses the training path under its existing rules;
- remains replayable from Combat Help under the current menu contract.

Normal TAB switching, random encounters, save points, abilities, and route
progression gate on `prologue_complete`, not `tutorial_complete`.

At opening recovery, enable Sonar on Maxilani and random encounters before
writing the healthy completed checkpoint. Both must show On when Continue
returns control, without requiring the optional tutorial. Keep the existing
Sonar oxygen drain and Q/R toggles; later saved Off choices survive Load.
Older completed saves without these fields adopt the On defaults. An
unfinished opening must not gain Sonar prematurely, and empty oxygen cannot
restore an inert On flag. Verification: `opening_exploration_defaults.gd`,
the actual opening journey, and rendered/hosted HUD checks.

## Starting tuning hypotheses

These values are implementation starting points. They change only through a
recorded playtest finding, not ad hoc code edits.

| Variable | Initial value | Required observation |
| --- | ---: | --- |
| Temporary video | full 33.877 s asset | Player remains engaged and understands playback is intentional. |
| Video local trim | `-6 dB` | Dialogue/music is clear with safe headroom and no competing cue. |
| Post-video title/reveal | 3.55 s including fades | Brief connecting question and credits, no crawl; world stays paused until visible controls return. |
| Prologue exploration trim | approximately `-7 dB` versus normal | Existing ambience remains present but feels quiet. |
| Movement trigger | 2–4 m from recovery-safe spawn | Forward, backward, left, right, and diagonal movement all work. |
| Minimum free-swim window | 4 s of requested, actual horizontal swimming | Idle/camera-only time, passive drift and blocked input do not count. Crossing the distance threshold alone cannot interrupt sooner, including after a long wait. |
| Idle behavior | wait indefinitely | A stationary player keeps control; no timed Angler fallback. This user correction supersedes the old seven-second fallback. |
| Angler party/enemies | current party versus one Angler | Stage remains legible and resembles real combat. |
| Angler actions | full ordinary move kit | HP alone is reduced to 3. Accuracy/evasion, utility, damage, costs, effects and enemy turns remain normal; weak/missed actions do not guarantee victory. |
| Angler rewards | none | No progression data changes. |
| Battle intro | existing 15.000 s intro at `0 dB` local trim | Good existing music remains; it does not dominate. |
| Battle loop fallback | approximately `-7 dB` if reached | Waiting in the menu cannot cause a loud jump. |
| Cordys response | one player action | Attack visibly connects but changes the outcome negligibly. |
| Cordys attack | one selected authored finishing move | Full party defeat is decisive and obviously scripted. |
| Final Boss intro | approximately `0` to `-1 dB` | Cordys has a distinct musical identity without clipping. |
| Final Boss loop | approximately `-4.5 dB` if reached | Intro-to-loop loudness remains perceptually stable. |
| Post-impact silence | approximately 1 s | Defeat lands emotionally without reading as a hang. |
| Total New Game to recovery | under 2 minutes for an engaged run | The hook does not become another opening barrier. Deliberate player inactivity is not forcibly converted into combat. |

## Binding audio contract

The tracks are good. The prologue changes cue timing and authored gain, not
the player's saved volume or the ordinary post-prologue mix.

### Measured source boundary

| Cue | Integrated loudness | Peak | Prologue disposition |
| --- | ---: | ---: | --- |
| Mermaid video audio | -13.3 LUFS | +1.5 dBFS | Sole video cue, Music bus, start at `-6 dB`. |
| Exploration loop | -13.9 LUFS | +0.1 dBFS | Preserve; prologue-only trim near `-7 dB`. |
| Battle intro | -26.9 LUFS | -9.6 dBFS | Preserve at `0 dB`; normally ends after the Angler does. |
| Battle loop | -13.7 LUFS | -0.3 dBFS | Prologue fallback trim near `-7 dB`; no 21.65 dB edge jump. |
| Final Boss intro | -19.0 LUFS | -3.6 dBFS | Cordys reveal cue, approximately `0` to `-1 dB`. |
| Final Boss loop | -14.6 LUFS | -1.0 dBFS | Trim near `-4.5 dB` if the prologue reaches it. |
| Heavy hit | -26.3 LUFS | -10.0 dBFS | Candidate finishing impact; audition against the boss cue. |

### Cue sequence

1. Cover remains silent; existing restrained UI SFX may play.
2. New Game supplies the trusted browser gesture.
3. Stop `GameAudio` music before the Mermaid video starts.
4. Route video audio to the Music bus. Never layer exploration beneath it.
5. After playback, leave transition space and fade in trimmed exploration.
6. Angler replaces exploration with the existing Battle intro.
7. Suppress the normal victory fanfare.
8. Duck/stop Battle music for the false-relief beat.
   Play the first 25 seconds of Octopus V3 with its embedded audio alone,
   then pause both playback and embedded audio for combat.
9. Start Phoenix's Final Boss intro exactly on Cordys's visible reveal.
10. Briefly duck music for the registered player hit and finishing impact.
11. Stop/fade Final Boss music immediately after the decisive hit.
12. Hold deliberate silence through the recovery motivation.
    Before that motivation, resume the approved Cordys title ending with its
    embedded audio alone. Music/SFX preferences apply to both video portions.
13. Fade ordinary PR #96 exploration back in exactly once.

### Audio-manager boundary

Keep one semantic audio owner. Extend it to support:

- intro gain and loop gain;
- short fade-out before replacing a cue;
- temporary ducking for a major impact;
- idempotent restoration after the prologue.

Authored gain is additive to the player's existing Music setting. Never write
a different Music/SFX slider value to make the prologue quieter. The Mermaid
video uses the Music bus so saved volume and mute apply to video, exploration,
Battle, and Cordys. Music mute and SFX mute remain independent.

Phoenix's INTRO-to-LOOP pairs still transition immediately without a
crossfade. Cue-to-cue fades are allowed because they are separate states.

## Visual and motion contract

Recorded framing repair: Spinning Slay's wide/deep travel could not be both
contained and readable in the short laptop stage. Poison Breath is the selected
authored prologue finisher, with the existing impact/death timing and no campaign
move-table change. A fixed orthographic stage contains the actual skin envelope
without perspective shrinkage or camera pumping. The 19-pose-per-clip derivative
is generated by `tools/derive_cordys_framing.gd`; the live projection verifier
independently samples 21 poses for idle/reveal/hurt/finish at every viewport.
Do not accept the prepared hull as a substitute for those moving-skin checks.

- The video uses responsive 16:9 FIT sizing with letterboxing as necessary;
  never stretch, crop, or double-render it.
- Cordys is framed from measured visible bounds, presents the authored front
  toward the party, remains floor/stage-aligned, and cannot obscure the HUD or
  party.
- Character and boss silhouettes remain readable at 1280×720, 720×480, and
  the existing tall review viewport.
- Inspect every selected Octopus pose for the known bright-line primitive;
  suppress or repair the artifact without hiding legitimate meshes.
- The composite/corpse presentation is accepted for this delivered model, but
  it must read intentionally in production framing.
- Use animation, lighting, restrained fades, cue timing, and model entrance.
  Do not add camera shake, forced zoom, or screen-wide flashes.
- The recovery card and optional-beacon label must remain readable without
  covering character names, party status, or controls.

## IO boundaries and risky branches

| Boundary | Risk | Required proof |
| --- | --- | --- |
| Save files | Old save replay, new save ambiguity, transient state restore | Missing-field migration plus new-save and interrupted-state round trips. |
| Time | Idle starts a fight, delayed swimming loses its window, trigger fires twice, music reaches loud loop | Multi-direction/frame-time/prior-idle matrix, actual idle/look/swim test and bounded engaged waits. |
| Input | Video leaks movement, combat buttons stall after a nonlethal action, beacon triggers accidentally | Real input at normal entry; spawn outside trigger volume; exercise multiple real turns. |
| Scene ownership | Duplicate video/Battle/audio/UI or leaked objects | Owner counts through every transition and repeated teardown. |
| Browser audio | Autoplay rejection, mute mismatch, stacked sources | Exact exported browser after New Game gesture at multiple settings. |
| Video decoder | Black screen, duplicate playback, bad aspect | Wide/narrow/tall captures, finish/failure lifecycle. |
| FBX import | Invisible, static, tiny, backward, bright-line actor | Structural mesh/skin/clip gate plus production-camera review. |
| Combat dispatch | Prologue rules contaminate normal Angler or campaign boss | Differential normal-versus-prologue encounter tests. |
| Web package | Duplicate media, stale deployment, first-reveal hitch | Manifest/digest/size comparison, exact PCK hash, runtime load observation. |
| Existing PR #96 | New opening breaks Tethys, maze, tutorial, audio, or save flow | Existing aggregate suite plus both post-recovery journeys. |

## Implementation phases and stop gates

### Phase 0 — clean child branch

1. Reconfirm PR #96 remote head and compare it with `27a5b52`.
2. Create a clean worktree/branch from that exact head. Do not carry generated
   `.import`/`.uid` churn from the existing checkout.
3. Copy these planning artifacts into the child branch under `docs/` and
   `verify/` before functional changes.
4. Record the actual base SHA in this plan.

**Stop gate:** branch diff contains planning artifacts only and no unrelated
PR #96 changes.

### Phase A — contracts and asset intake

1. Add public prologue phase, signals, encounter sources, durable fields, and
   migration rules before changing New Game.
2. Update the asset/audio/Octopus manifests with canonical digests, runtime
   ownership, web derivative, package-size delta, and replacement seam.
3. Derive web OGG files for Phoenix's canonical Final Boss INTRO/LOOP pair;
   never import the old DEMO MP3 or Dropbox duplicates.
4. Build a temporary Octopus gallery using the production importer and record
   measured bounds, visible meshes/materials, skeleton, clips, facing, selected
   poses, and bright-line disposition.
5. Create the bug catalog tests in highest-blast-radius order. Each test must
   first prove red or characterize current behavior before implementation.

**Stop gate:** state round-trip/migration gates are meaningful; every admitted
asset has one source, runtime owner, digest, and evidence; the Octopus is
visually usable before a battle depends on it.

### Phase B — opening video lifecycle

1. Replace the normal intro crawl with a generic opening-video owner selected
   from one configurable asset reference.
2. Preserve the existing lab owner and its skippable policy.
3. Route opening video audio through Music at the authored trim.
4. Save `opening_video_seen` on successful completion.
5. Provide a visible failure fallback, debug fast-forward, and clean control
   restoration.

**Stop gate:** normal New Game shows one correctly-sized video, blocks world
input, respects volume/mute, survives decoder failure, persists completion,
and does not change the lab video contract.

### Phase C — quiet spawn and Angler

1. Enter `spawn_exploration` with trimmed existing ambience and no mandatory
   tutorial arrow/camera capture.
2. Suppress random encounters and progression triggers until the prologue is
   complete.
3. Require at least four seconds of actual requested horizontal swimming and
   meaningful displacement before the one-shot trigger. Never start from idle
   time. Looking around, blocked input and passive drift cannot bank that
   window. Measure actual key-driven displacement as well as phase timing.
4. Reduce only this Angler's HP to 3 versus normal 5, retaining normal stats,
   full moves, enemy turns and accuracy/evasion. No forced hit/kill or rewards.
5. Use Battle intro with a safe loop fallback. Suppress normal victory audio.

**Stop gate:** real keys move the diver before combat, movement cannot trigger
before four seconds of swimming, all horizontal directions work, and prolonged
idle/camera-only input stays out of combat; weak, utility and missed actions
behave normally and subsequent real actions can finish; ordinary Anglers are unchanged; no
reward/state leak or duplicate battle exists.

### Phase D — Cordys interruption

1. Transition inside the combat presentation without an overworld flicker.
   Insert the approved first 25 seconds of Octopus V3, retaining one paused
   decoder for the aftermath. Verify actual pause position and silent combat.
2. Instantiate the prologue-only Octopus actor with selected reveal/idle/hit/
   finishing clips, correct facing, material, scale, and framing.
3. Start the Final Boss motif on reveal.
4. Offer the normal move kit with unchanged accuracy, damage, status, self-cost
   and Oxygen rules. Damage is small relative to 1,000 HP, never clamped to 1.
   Base Maxilani witnesses: Electric Touch 1, Axe Kick 4, Stabbing 1 plus Bleed
   2; Flash Blast applies Blindness even though it deals no damage.
5. Resolve Poison Breath through shared combat rules using opening-only STR
   80 and ACC 30 against each diver's real DEF/EVA. No direct HP reset. These
   stats defeat the fresh party; high-stat diagnostic survivors remain alive
   and can act again rather than being declared defeated. Preserve the special
   defeat/recovery presentation and campaign-boss isolation.

**Stop gate:** no normal victory, Game Over, campaign Octopus state, reward,
or balance mutation occurs; Cordys is readable and animated at every target
viewport; audio has one owner and no loop jump.

### Phase E — recovery and optional training

1. Stop boss audio, hold silence, restore all HP/Oxygen, place the party at a
   safe spawn, show the motivation, mark completion, and save.
   Resume the edited boss-title ending after silence and before the atomic recovery
   write. Never expose motivation or save completion while it is still playing.
2. Restore ordinary exploration exactly once.
3. Spawn Optional Combat Training outside the party's activation radius.
4. Decouple world progression from tutorial completion.
5. Verify completion, Skip, Retry, Return to World, ignore, save/load, and
   Combat Help replay behavior.

**Stop gate:** both public journeys succeed from normal entry:

- recovery → ignore training → continue normal PR #96;
- recovery → enter training → complete/skip/retry/return → continue PR #96.

### Phase F — exact artifact, blind test, and zero-defect audit

1. Run focused gates after every repair and the inherited aggregate suite.
2. Export from an exact clean commit; compare local and served PCK byte count
   and SHA-256.
3. Deploy one immutable URL and the stable child-PR alias with no auth.
4. Play the normal entry at 1280×720, 720×480, and the tall review viewport.
5. Conduct the audio matrix and a context-free comprehension playtest.
6. Repeat the audit loop until an entire round reports no observed defect.

**Stop gate:** every done condition below is met and the final audit log records
a zero-observed-defect round on the exact public artifact.

## Evidence matrix

| Surface | Automated proof | Human proof that can reject green tests |
| --- | --- | --- |
| State/save | Round-trip and old/new/interrupted decision table | Reload at video, spawn, battle, defeat, recovery and completed boundaries. |
| Video | Stream/digest/policy/owner/aspect lifecycle | Normal New Game playback at all target viewports with audio sync. |
| Trigger | Direction/frame-time/prior-idle invariant and real idle/look/late-swim negative path | Wait without moving, look around, then swim in visibly different directions without debug teleport. |
| Angler | Differential prologue/ordinary behavior, no-reward invariant | Choose each visible offensive option and inspect staging/audio. |
| Cordys | Mesh/skin/clip/facing/bounds and encounter-source gates | Inspect reveal, hit, finishing move, composite and bright-line behavior. |
| Defeat/recovery | Special-result state and party restoration | Confirm the loss reads as authored, not broken or punitive. |
| Optional training | Ignore/complete/skip/retry/return decision table | Play both post-recovery branches through controllable normal world. |
| Audio | One-owner state trace, gain/loop/mute/persistence gates | Listen at 100%, 50%, Music mute, SFX mute, laptop speakers and headphones. |
| Regression | Existing PR #96 gates | Reach ordinary post-opening world, optional tutorial, Deep, lab/Tethys and maze as affected. |
| Artifact | Fresh export plus local/served digest and console gate | Use ordinary public URL; query routes are supplementary only. |

Screenshots and GIFs are evidence only when paired with semantic proof. A
stable screenshot cannot prove input, state, audio, or recovery behavior.

## Context-free acceptance questions

After the opening, without prior explanation, ask the tester:

1. Who defeated the party?
2. Did the defeat look intentional or like a balance/technical failure?
3. What do you expect to accomplish eventually?
4. What can you do immediately?
5. Is Combat Training required or optional?

The opening fails comprehension acceptance if the tester cannot identify
Cordys/Octopus as the long-term threat, thinks the game ended, believes the
tutorial is mandatory, or describes the opening as audiovisually overwhelming.

## Commit plan

1. Add binding plan, asset manifest, bug catalog, and audit log.
2. Add public prologue/save/migration contract and red state tests.
3. Import/characterize Final Boss audio and production Octopus actor adapter.
4. Add opening video lifecycle and exact audio routing.
5. Add quiet spawn and health-only weakened Angler using ordinary combat.
6. Add Cordys interruption and scripted defeat.
7. Add recovery and optional tutorial handoff.
8. Add/repair focused verification one defect at a time.
9. Complete visual/audio polish and evidence.
10. Export, deploy, and record exact artifact proof.

Do not bundle generated web output into an earlier behavioral commit. Never
hand-merge `docs/index.pck`; regenerate from the accepted source commit.

## Final visual/audio polish loop

Repeat until one complete round reports no observed defect:

1. Export the exact candidate commit and verify its PCK digest.
2. Start from the ordinary title; never substitute query-only routes for the
   complete journey.
3. Review every opening phase and both post-recovery branches at every target
   viewport.
4. Check missing/tiny/floating/clipped assets, collision, camera, facing,
   duplicated/cropped video, unreadable UI, wrong animation, stale state,
   blocked controls, audio overlap/jumps/silence, load hitch, leaks, and all
   browser/Godot errors.
5. Record each defect with exact commit/deployment, reproduction, expected,
   observed, evidence, and affected journey.
6. Fix it, run its focused gate, rebuild/redeploy, and replay the whole affected
   journey rather than only the exposing screenshot.
7. Record PASS only when no scoped defect or unexplained deferral remains.

The temporary Mermaid repetition and pending final opening replacement are
explicit product decisions and therefore do not masquerade as undiscovered
defects. Technical playback, layout, audio, and handoff defects still block.

## Done conditions

- Child PR is based on the confirmed PR #96 head with no unrelated changes.
- Every admitted asset has provenance, digest, owner, runtime path, and web
  proof; no duplicate Mermaid or Final Boss source is packaged.
- An engaged New Game to recovered control takes under two minutes; idle time
  does not force an encounter.
- The old intro crawl and mandatory tutorial funnel are absent.
- The temporary Mermaid opening is single-rendered, responsive, audible,
  volume-controlled, and correctly persisted.
- Four seconds of actual swimming in any horizontal direction reaches exactly
  one Angler; standing still or looking around never starts it.
- The prologue Angler changes HP only (3 versus normal 5). All moves, stats,
  hit/miss rules, costs, effects and turns match normal combat. Actual defeat
  interrupts once with no rewards. Campaign-wide balance is not claimed.
- Cordys visibly interrupts the victory, receives one normal stat-based action
  (not a fixed damage result), and defeats the fresh party with one readable
  stat-based authored move. Status and cost choices remain real.
- No normal victory fanfare, Game Over screen/music, campaign Octopus state,
  or route progression is used for the scripted loss.
- The party is restored, safely positioned, saved, and given the exact
  long-term motivation before normal control.
- Optional Combat Training is clearly optional, cannot trigger accidentally,
  and all existing completion/Skip/Retry/Return/replay paths work.
- Ignoring training permits normal PR #96 progression.
- Old saves do not replay the prologue; interrupted new saves normalize safely.
- Music/SFX settings remain independent and persistent; per-cue trims never
  rewrite the player's sliders.
- Video, exploration, Angler, Cordys, silence, and restored exploration each
  have exactly one correct audio owner and transition.
- No load hitch, object/RID leak, stale modal, dangling timer/tween, or browser/
  Godot error remains.
- Existing relevant PR #96 gates pass.
- Local export, immutable deployment, and stable alias serve the same PCK.
- Context-free testers answer the five comprehension questions correctly.
- The final audit log contains one complete zero-observed-defect round.

## Final-video replacement contract

When Glassgoat supplies the final opening:

1. intake and visually audit the source;
2. record provenance, digest, dimensions, duration, audio measurements and
   approval status;
3. transcode once to the supported web format;
4. replace the single configurable opening reference;
5. keep the Mermaid lab reference unchanged;
6. repeat video/audio/state/browser and full affected-journey verification;
7. update the manifest and remove the temporary-opening disposition.

No prologue state, combat, save, tutorial, or campaign-route code should need
to change for that replacement.

## Blocking decisions

None. Timing, gains, trigger distance, camera composition, and animation choice
are bounded implementation hypotheses to be tuned through the recorded audit
loop. The temporary repeated Mermaid media, Cordys naming, optional tutorial,
scripted defeat, and restricted campaign scope are binding decisions.
