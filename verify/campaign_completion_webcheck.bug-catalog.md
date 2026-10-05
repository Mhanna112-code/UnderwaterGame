# Browser campaign-ending bug catalog — October 5

Uses END-1–4 from `campaign_completion.bug-catalog.md`. Read contracts:
World completion/result/load slice, CampaignCompletion, SaveManager atomic
write/rollback, BrowserCheckpoint force-sync and durable readback; existing
manual-save and stationed-Cordys browser probes. The static server has no API
or credentials: canvas input → actual Godot battle/result → RAM filesystem →
IndexedDB → acknowledgment → fresh-page Title Load is the full data flow.

Public interface: actual W/Y, move/target mouse controls, Retry Save/Return to
Title/Load controls and the selected durable JSON. IO: imported game export,
animations/random combat timing, browser storage, screenshots and native OCR.
Branches: party turn/animation/victory; storage denial/confirmed retry; title
exit/fresh page; wide/narrow. A declared supplied level-five legal kit and room
checkpoint isolates the ending, not earning or balancing the campaign.

| Bug | Risk / why plausible | Test and status |
|---|---|---|
| END-1 actual win leaves an unfinished checkpoint/live station | High; battle reward and World save are separate consumers | Real 12-action fight and durable defeated/removed station; characterized |
| END-2 rejected browser persistence falsely promises saved exit | High; FileAccess success is not durable web success | Abort only completed slot0 IDB writes, compare exact previous bytes, click disabled exit, release denial and click Retry; characterized |
| END-3 cold Load repeats the boss or rewrites its reward | High; fresh runtime rehydrates an independent checkpoint | Actual Return to Title, destroy page, new page in same disposable context, actual chosen-slot Load and exact completed byte equality; characterized |
| END-4 ending leaks world HUD/controls or clips choices | Medium; different UI ownership/viewport sizes | Held W/Tab/P plus rendered 1280/720/360 controls; characterized, images inspected |

Self-critique: wrong-but-stable notices cannot pass because the observer requires
a real victory, exact durable bytes and actual UI transitions. No private
game helper, victory event, zero HP or async callback is injected. Native
companion verifies frozen positions/party XP/HP/O2 restoration, which canvas
OCR cannot inspect beneath the exclusive ending. OCR matches semantic labels,
not pixel snapshots or exact wording of the entire page. Storage failure is a
real transaction abort at the external durability boundary, not a mocked save
return value.

Skipped: earned route/key/kit, full lab-first/maze-first balance; deferred opening
identity/film relocation; exact art quality; hosted artifact acceptance (still
required before canonical promotion). No new cosmetic or combat tuning.

Evaluation: no additional production defect caught in this browser pass; the
native baseline already caught END-1. Browser characterized END-2–4 on the local
export of runtime6e6a70f. Adversarial probes beyond the happy path: durable-write
denial with exact-byte comparison, attempted exit while unsaved, and destroyed
page/cold Load rather than same-scene restoration. All passed, no script or
browser error; injected IDB storage-error messages are recorded separately.
No tests removed. Full acceptance/release remains unproven.

Matching-release follow-up on6b8ea07 passes all ending/durable/cold-Load checks
locally. First hosted run encountered the real randomized QTE reading lesson;
the observer's legacy-only `Press Enter to continue` match missed the current
`Press Space, Enter, or click Continue` caption. This was an observer stall,
not a combat crash. It now acknowledges the visible Enter instruction with a
real key press; no X/perfect timing or production flag is injected. Corrected
hosted acceptance is required before canonical promotion.

October5 delivery follow-up: corrected hosted ending passed14 real actions/
106 observations with no findings before promotion. Canonical laboratory
passed12 actions/87 observations. A subsequent canonical ending run stopped
before combat: after a22-second fixed reload delay the actual screenshot still
showed Godot's loading splash/progress, not Load Game; no script/browser error
was reported. This is BOOT-1, an observer's readiness race, not evidence of a
combat regression. Preserve its zero-action receipt/screenshot. Replace fixed
boot assumptions with bounded rendered New Game/title readiness (and actual
Load Game when a fixture exists), retain normal input and all storage checks.
If the title never appears within the bound, fail explicitly rather than
silently treating that as success. Corrected canonical acceptance passes13
actual actions/106 observations, exit0/no findings, rejected-save rollback/
disabled exit/Retry/confirmed completed cold Load. No runtime pack changed.
