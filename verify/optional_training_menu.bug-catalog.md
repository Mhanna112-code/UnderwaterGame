# Optional training menu — bug catalog

**Generated 2026-09-26**
**Scope:** Combat Help's new optional learning entries, `World`'s modal handoff, and the reusable tutorial surfaces.

## What this change does

It makes the material intentionally removed from the mandatory opening discoverable from Combat Help. It must preserve the short route-ready opening, keep campaign state unchanged, and exchange one full-screen surface for another without leaving a player under an invisible modal.

## Public interface

| Surface | Contract |
|---|---|
| Combat Help buttons | A player can select `World Ability Training` or `Advanced Combat Guide`. |
| World training handoff | Opening either entry replaces Combat Help and leaves normal world controls usable when its overlay closes. |
| Ability walkthrough | Starts with movement/look/switch controls, then presents Swap/Sonar, Grapple, and Shockwave. |
| Advanced guide | Starts with an overview, then covers the deferred combat concepts using current rules. |

## IO boundaries and branches

- No persistence, network, randomness, or filesystem I/O is introduced.
- Both actions branch on `world != null`; `World` must additionally cope with its help modal already being visible.
- The important lifecycle boundary is `InventoryMenu.close()` → tutorial overlay `open()` → overlay `dismiss()`.

## Bug catalog

| ID | Failure mode | Blast radius | Why plausible | Test type | Status |
|---|---|---|---|---|---|
| TRAINING-MENU-1 | A button is absent, opens behind Combat Help, or leaves the HUD/modal state unusable after closing. | High: optional learning is inaccessible or the player appears soft-locked. | Both surfaces are runtime-built full-screen Controls with separate visibility and HUD handling. | Public UI lifecycle contract | Green |
| TRAINING-MENU-2 | The advanced entry opens generic or stale content rather than the deferred combat material. | Medium: a player seeking deeper combat learning receives unrelated help and cannot recover the dropped concepts. | The generic F1 tutorial book already exists and is easy to wire accidentally. | Public UI sequence contract | Green |

## Test plan

### TRAINING-MENU-1 — reachable world walkthrough

- **Test type:** Public UI lifecycle contract.
- **Description:** `optional training menu: World Ability Training replaces Combat Help and returns to usable world controls — guards against nested-modal trap.`
- **What it catches:** missing button, a button that leaves Help visible behind the walkthrough, a wrong first page, and a dismiss that leaves the world paused/HUD hidden.
- **Self-critique:** It observes rendered button labels and public overlay state, not private implementation calls. A behavior-preserving refactor passes.

### TRAINING-MENU-2 — correctly scoped advanced guide

- **Test type:** Public UI sequence contract.
- **Description:** `optional training menu: Advanced Combat Guide opens its overview then Combat Basics — guards against generic/stale help routing.`
- **What it catches:** a button wired to F1's broad book, missing combat overview, or a nested menu that leaves Help visible.
- **Self-critique:** It asserts player-visible page titles via a new public page-data accessor. A redesigned renderer with the same visible sequence passes.

## Skipped

- Interactive five-move combat practice: deferred. The old scripted sequence is stale and disconnected; reactivating it without current enemy/party and balance design would be a larger feature, not safe menu wiring.
- Pixel-level typography and button color: visual polish, not a durable behavioral contract. It should be checked in the hosted build once the focused behavior is green.
- Save-state differential: these entries only open reading overlays and do not call save or battle APIs; the existing replay test already owns practice-state restoration.

## Post-write evaluation

- **Bugs caught:** The initial red run confirmed neither optional entry was reachable from Combat Help. The implementation adds both buttons and closes the prior modal before opening their respective learning surfaces.
- **Bugs characterized:** `optional_training_menu.gd` is green: World Ability Training opens at `world-controls`, dismisses back to an active HUD/world, and Advanced Combat Guide opens its overview followed by Combat Basics.
- **Bugs discovered during writing:** The old expanded five-move functions are present in `Battle` but have no callers after the short-opening change. They are not exposed by this addition; treating them as a ready-made practice mode would be misleading.
- **Tests removed:** None.
