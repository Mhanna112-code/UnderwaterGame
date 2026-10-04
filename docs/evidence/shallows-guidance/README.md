# Shallows orientation and purpose

Runtime source: `4836d0198aa4a3468f570df31782a0cedb36eb92`.
Candidate: `https://underwatergame-opk53hlsh-immortaldemongods-projects.vercel.app/`.
Deployment: `dpl_8JEmVs9xXETD4z9PHwFujAkxhSkq`.
PCK: 93,827,780 bytes; SHA-256
`ea5ef3c1d7e879c41392d7ed85ad62b5f63b9536189e74d3e5ab3fe08d714e8e`.
Unauthenticated retrieval matches the clean committed-source archive export.

## Change

The existing single location-aware panel now says
`Shallows: fight to grow stronger.` after opening completion. It was blank
there. Physical entry into Deep still shows the lab goal; returning restores
the Shallows prompt. The intact puzzle wall's Bucky hint takes priority and
returns to Shallows purpose when departed or actually broken. No new objective,
mandatory grind quota, balance change, tutorial or encounter redesign.

## Native proof

- SHALLOW-001 is red against the prior World: completed Shallows Load renders
  empty guidance, not a zone/purpose. The two-line fallback makes it green.
- `local_world_guidance.gd`: actual W/S crossing, puzzle contact/departure,
  Tab/Tab/E Shockwave, consumed-wall save/load, six spatial/altitude cases,
  24 clear-water positions, inactive-diver and unfinished-opening guards.
- Existing Deep guidance and eight Sonar/encounter preference round trips pass.
  Invalid checkpoint messages in the latter are deliberately tested failures.
- Real 1280x720 and 720x480 captures inspected: one readable centered line,
  inside the viewport and clear of controls/minimap. Fixtures isolate geography
  in a separate verifier user directory; they do not prove normal recovery.

## Hosted proof

- Eight rendered spatial observations pass: Deep Load, real W crossing to
  Shallows, S return, puzzle approach/contact/departure/return, actual Bucky
  Shockwave consumption. OCR and screenshots agree; zero runtime errors.
  `browser-boundary/` explicitly seeds positions/protected settings from an
  actual completed checkpoint in a disposable profile, not an earned journey.
- `browser-normal/`: normal New Game, full movies, title handoff, actual W
  swimming (4.496s), real mouse combat, Cordys aftermath, recovery and Continue.
  Control returns in 94.215s. The new prompt is visibly readable; Sonar and
  encounters are On. Actual persisted completion is inspected, then a cold
  reload and normal title Load restore the same prompt without replaying the
  opening. No completion flags/position fixtures or synthetic battle wins.
- Both browser results have null failure and empty error arrays. Recovered
  and loaded frames were visually inspected; the already-cataloged training
  label world occlusion remains outside this focused prompt fix.
- Same stable review alias updated to this exact artifact. Main and secondary
  public aliases remain `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`.

## Verification boundaries

The full opening browser helper still expected the phase list from before the
title handoff. It now includes the already-implemented `opening_handoff` phase;
this is a harness correction, not another gameplay change. New OCR assertions
check the visible Shallows instruction after normal recovery and cold Load.
No exact pixel, whitespace or call-count assertions substitute for visibility.

User saves and the running Godot app were untouched. This packet does not claim
whole-project zero-defect acceptance: OPEN-032/046 remain in the broader audit.
