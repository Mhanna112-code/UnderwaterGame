# Shallows orientation and purpose (2026-10-04)

Scope: World's existing location-aware objective panel. No encounter rate,
balance, compulsory grinding, progression state, maze or tutorial changes.

## Contract and code context

- Public surface: visible `route_objective_hud` label/panel during normal
  post-opening play, actual movement, diver selection and title Load.
- The existing physical `DeepZoneLayout` contract defines Shallows below x=60;
  saved RouteState zone/objective can legitimately lag the active diver.
- `_refresh_world_guidance` has a completion guard, then Deep, then intact
  puzzle-contact branches. The missing Shallows fallback leaves a blank panel.
- Load-bearing invariants: do not persist display copy or erase the pending
  lab objective; only the active diver determines proximity; unfinished
  prologue is deliberately quiet. The Bucky hint is retired by real wall
  consumption, not by a synthetic win.
- IO: save JSON and world physics/input/layout; no new persistence. Existing
  native/browser local-guidance tests already cover boundary crossings,
  active diver, spatial cases, real Shockwave and consumed-wall Save/Load.

## Bugs and test design

| ID | Failure / impact | Plausibility | Test |
| --- | --- | --- | --- |
| SHALLOW-001 | Normal post-opening Shallows have no zone/purpose indication. Players do not know why to fight. | Missing final fallback in existing guidance selection. | Completed checkpoint through actual title Load: visible label names Shallows and becoming stronger, not the lab/wall. Red before code change. |
| SHALLOW-002 | Shallows copy persists in Deep, erases the lab goal, or disappears after returning/reloading. | Mixing saved objective/zone with physical location. | Real W/S boundary crossing plus retained objective and reload; bounded clear-water location sweep. |
| SHALLOW-003 | Generic copy hides the local Bucky instruction or replaces the opening/training flow. | Prompt precedence and milestone guards. | Existing real Shockwave/proximity/active-diver/unfinished save cases; broken/departed wall returns to Shallows copy. |
| SHALLOW-004 | New text is clipped/hidden by controls or minimap on a small window. | Existing responsive HUD width and shared panel. | Real wide/narrow rendering and hosted OCR/screenshots. |

Self-critique: assert the visible instruction's meaning and world progression,
not helper call counts, exact spacing or pixel equality. Wrong stable blank/
lab/wall output fails. Save/position fixtures isolate geography; crossing and
Shockwave still use production input. Property generator covers 24 arbitrary
clear-water positions independently of the room bounds helper.

## Skipped

- Mandatory fight count, grinding rewards/rates, guidance after the lab or
  broader exploration redesign: not requested.
- Existing world art occlusions OPEN-032/046: retained in the larger audit.
- Full opening replay for every spatial case: completion fixture is explicit;
  focused full-recovery browser verification may supplement the HUD checks.

## Evaluation

Pending red/green, rendered and exact-hosted evidence.
