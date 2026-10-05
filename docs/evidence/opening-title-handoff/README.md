# Mermaid opening title and world handoff

Final runtime source: `44ae14bab08f744ec6ac9019509c19b94cce72ac`.
Initial title component source: `4c04e2a`; its native title pictures/policy logs
remain valid for the unchanged title layout. Final World/reveal evidence is
separately labeled below.

User observed an abrupt movie-to-gameplay cut. The original EOF immediately
freed OpeningVideo; the new first-run opt-in fades the final 550ms of video and
its local audio to black, shows a restrained title/question/author credit, then
reveals the world and controls. No source movie is edited or duplicated. The
title/reveal lasts 3.55s. It adds no mandatory reading, button, music layer,
tutorial changes or later campaign redesign. Cordys inheritance defaults off;
lab skip behavior remains independent. Existing settings and four seconds of
actual swimming before Angler remain unchanged.

## Native checks

- Red before implementation: `TITLE-001 first-run owner has no authored title
  handoff`, exit 1, from `verify/opening_title_handoff.gd`.
- Actual decoder EOF, visible title before completion, repeated EOF, Escape,
  paused owner, bounded label rectangles, one completion and teardown: green.
- Real rendered 1280x720 and 720x480 frames inspected: readable centered title,
  question, credits, no clipping. `title-wide.png` and `title-narrow.png`.
- Initial World New Game, full movie, W held during title: no displacement or
  combat. After reveal, real W swims 19.333m and starts the prologue Angler after
  4.130s, not a banked/premature encounter. Test user directory was isolated.
- Visual review of the initial continuous browser excerpt caught a camera zoom
  and late HP/O2 HUD population after revealing the paused world. TITLE-007's
  new camera-pose regression fails against `4c04e2a`. Final `44ae14b` prepares
  existing chase framing and HUD behind the title: camera position/orientation
  remain stable across the first idle physics frames, held W still cannot move
  or bank time, then real W swims 19.333m and starts Angler after 4.117s. See
  `camera-world-green.log` and retained `initial-camera-settle/camera-red.log`.
- Existing `opening_video.gd`, `prologue_cinematic.gd`,
  `opening_prologue_state.gd`, `opening_video_world.gd`, and
  `prologue_audio_envelope.gd`: green. Save tests used an isolated user directory;
  production user saves and the user's running Godot app were untouched.

### Verification defects, not gameplay fixes

An initial headless layout assertion used the dummy display's implicit size;
the fixture now supplies 1280x720 explicitly. Concurrent macOS native captures
also returned a gray texture or waited on an occluded window's draw event. Those
captures were rejected. The verifier now foregrounds its own window and forces
a real render. The final small capture was rerun alone and visually inspected.
These are not counted as gameplay defects or hidden by a green lifecycle log.

## Hosted acceptance

Initial ordinary-entry Chromium run (retained under `initial-camera-settle/`):
3.479s title, 15.345s idle, 4.156s swimming to Angler, zero errors. Its technically
green run was rejected as final visual proof because of the camera/HUD pop.

Final deployment `dpl_9Gnhwqvzz69tVMRHPfaQJGyZWBNb`:
`https://underwatergame-pow6qnuoo-immortaldemongods-projects.vercel.app/`.
Unauthenticated PCK retrieval matches the clean archive export: 93,348,868 bytes,
SHA-256 `9aae479107c184063dba78c0ea09ed25f0db12813cdfd39f61876aa94b54375e`.
Final ordinary-entry Chromium/full-movie replay passes: 3.495s title/reveal,
16.123s idle, camera-only checks, then 4.016s real W to one Angler, zero errors.
`revealed-world.png` and `idle-world.png` plus continuous video were inspected:
camera composition and populated HP/O2 remain stable, with no post-fade zoom.
`transition.gif` is an 8.5s excerpt from the final recording at offset 58.7s,
not a recreated animation. Existing review alias now serves the final candidate.
Main and secondary aliases remain `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`.

No full-project/final zero-defect polish acceptance is claimed by this packet.
The existing OPEN-032/046 world presentation defects remain outside this fix.
