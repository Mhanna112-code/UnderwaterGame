# Opening title handoff bug catalog

Scope: the Mermaid movie's first-run ending only. No tutorial, lab, Cordys,
campaign or media-source redesign.

The current owner frees itself immediately at EOF. World then saves the viewing
milestone and unpauses gameplay. `PrologueCinematic` inherits this owner, whereas
the lab has its own skippable owner. Consequently any transition must be opt-in,
must leave those other owners alone, and must not bank world swimming time.

| ID | Failure | Decisive verification |
| --- | --- | --- |
| TITLE-001 | Movie hard-cuts to gameplay, with no connecting title/question. | Actual decoder EOF enters a visible brief title before completion; rendered wide/narrow frames and browser recording. |
| TITLE-002 | Movement/combat starts beneath the card, or an input skips it. | Held W/Escape during the real handoff cannot unpause World or start a fight; after completion real W still moves and retains four seconds of swimming. |
| TITLE-003 | Repeated EOF starts duplicate cards/completions or the watchdog mistakes the title for a decoder stall. | Repeated EOF while title is live, exactly one handoff/completion, no fallback, owner teardown. |
| TITLE-004 | New credits/title also appear in Cordys/lab, or decoder failure traps the player. | Opt-in default off, unchanged independent lab skip and Cordys segment gates; fallback Continue remains immediate and does not claim successful viewing. |
| TITLE-005 | Credits crop on small screens or dominate the opener; fade ignores Music settings. | Real 1280x720 and 720x480 captures; bus remains Music, only local video amplitude fades, no settings writes. |
| TITLE-006 | Completed opener is replayed on load, or deployed bytes are stale. | Existing isolated World/save gate plus exact hosted commit/PCK identity and normal browser New Game. |
| TITLE-007 | Revealing the paused world exposes an unset camera/HUD, which visibly zooms or pops when control returns. | Camera position/orientation during title must match first idle physics frames after reveal; inspect continuous browser transition. |

Tests use decoder EOF and public signals rather than a fake win or phase
injection. Fast lifecycle tests are not proof of a polished transition: rendered
native/browser playback is an independent acceptance gate. Context-free human
judgment and the final project-wide visual audit remain outstanding.
