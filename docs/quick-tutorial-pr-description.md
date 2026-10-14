## Purpose

Respond to the playtester who declined to play because the tutorial was too long. Integrate a short starter with optional full interactive practice and stat explanations accessible in battle and inventory, preserving the latest opening/main changes.

## Current draft

- Starter: one actual Electric Touch choice and one live timing dodge, with three short confirmations. A missed dodge still completes the lesson. No extra real-fight grind or mandatory ability carousel.
- Full Combat Lesson remains an actual five-move interactive lesson, not a prose guide. Quick practice and World Abilities are explicit Inventory > Combat Help choices.
- Battle > Combat Help opens the shared stat/effect/status reference. Escape returns to the same actor/menu without spending a turn or changing resources; prior pause/focus is retained.
- Optional replay borrows temporary combat resources/inventory rather than healing the earned party or saving a practice state.
- Preserve current main's video/Cordys opening, actual combat formulas, maze/lab progression, rewards, audio settings and other Marc changes.

## Evidence so far

`docs/evidence/quick-tutorial-oct14/`: real failures retained for the missing battle reference, long starter caption, clipped reference Close, and replay healing earned resources. Focused fixes pass the corresponding checks. Starter pass and natural-dodge-timeout pass; retained five-move lesson reaches a real victory; reference tested headless and rendered at three viewport sizes and both prior pause states; optional practice entry/Skip preserves party/inventory.

## Before ready for review

- Expanded skip/callback, practice win/loss/item isolation, normal beam handoff, cold-save/reload and embedded-maze tests.
- Reconcile applicable old tests with explicit quick/full profiles without weakening their behavioral oracles.
- Integrate the reviewed PR 101 HUD in this review branch and rerun its regression checks.
- Exact-source Web preview, real browser interaction/storage, readable narrow/wide screenshots and a fresh full scoped visual-audit round with no observed defects.
- Re-fetch relevant Marc changes before final delivery.

No merge, canonical deployment or full campaign acceptance is requested. This is a draft until the remaining gates pass. The saved implementation/defect ledger is `docs/quick-tutorial-overnight-plan.md`; hourly follow-ups end at October 14, 2026 11 a.m. Chicago. Stop work below 3 GB disk space.
