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
| TITLE-008 | Intro credits omit the developers, or adding them displaces the art/music credits. | At actual decoder handoff, visible labels name ImmortalDemonGod, Mhanna, Glass_Goat and Phoenix Down Music; native wide/narrow/portrait captures check clipping. |

## October 5 credit correction

OpeningVideo publicly exports its media path/title opt-in/local volume and emits
handoff/completion signals. It loads Theora media, observes decoder progress and
uses pause-safe timed transitions. EOF enters the title only when opted in;
failure exposes Continue; inherited Cordys playback keeps opt-in disabled.
No new type/string dispatch contracts or save writes are added by the credit fix.

TITLE-008 is a captured omission test through real decoder EOF and visible label
content, not a source-text snapshot. It fails for missing names but permits label
reorganization and punctuation changes. Existing TITLE-005 bounds checks and real
captures independently cover the added line's layout. The actual submitted
handles are the credit contract; tests do not invent individual job titles.

Skipped: changing the movie's embedded credits, retiming the opening, and adding
a global credits menu are outside this narrow request. Existing movie fade,
pause, failure handling and inherited cinematic policy remain unchanged.

Evaluation: TITLE-008 failed first for both absent developers and passed after
adding them without removing the art/music credits. Native 1280x720 and 720x480
showed all credits readable. The 360x640 capture caught an inherited title
mid-word wrap despite passing viewport bounds. TITLE-005 now also checks the
single-word headline stays on one line; responsive font size repairs that
observed presentation defect rather than treating bounds alone as acceptance.

Tests use decoder EOF and public signals rather than a fake win or phase
injection. Fast lifecycle tests are not proof of a polished transition: rendered
native/browser playback is an independent acceptance gate. Context-free human
judgment and the final project-wide visual audit remain outstanding.
