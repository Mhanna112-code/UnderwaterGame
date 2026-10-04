# Maze and campaign integration audit log

## October 4 2026 foundation inspection

Previous goal turn classification: progress. The saved plan was materially updated to include approved puppets and verification contracts. This continuation read the objective file and refreshed current sources; no previous integration process was live.

Observed sources: current main f9ae00c, PR96 27a5b52, PR98 c3da257, PR97 55e8515. Full IDs are in the runtime manifest. The isolated opening and maze review builds are not combined-build evidence.

Actions: created clean integration/maze-campaign checkout; preserved unrelated generated changes in the opening checkout; saved Page revision 5 and initial execution artifacts before functional changes.

Tests: none run in this entry. Runtime, audio, web/native and human acceptance remain unverified. Initial catalog risks are code-inspected or approved-contract gaps, not claimed reproductions.

Next: integrate baseline, record actual conflicts and first behavioral reproduction; preserve failed evidence and separate harness failures from game failures.

## October 4 2026 semantic merge reconciliation

Previous conversational turn supplied goal text without changing implementation; classified no implementation progress. Revalidated the active objective, unchanged PR heads and unfinished local merge, then took the next safe source action.

Baseline: 493b1d8 merges current main f9ae00c and reviewed opening c3da257. Pending maze parent: 55e8515. No unrelated opening-checkout edits were discarded. Generated import metadata was temporarily stashed separately before the maze merge and regenerated rather than blindly replayed.

Resolved eight runtime-file conflicts and the map-test conflict per hunk. Preserved GameAudio, current strings/status glossary, clean uncropped Grapple video and modern menu layout; added Marc's popup layer/live Control demos, standalone inventory adapter and revived stage actor handling. Retained Marc's maze-specific puzzle initialization, proximity discovery, L-map controls, independent wall/current manipulation, live geometry-derived current paths and map help. Removed duplicate map color constants caused by automatic merge. Map expectations now describe those real controls, not the obsolete H-driven current relocation.

Corrected the Door.fbx resource path's filename case. Disabled the sphere-room developer starting override for production. Obsolete import sidecars for three already-absent portrait sources were removed; the actual images had already been removed in the baseline. Conflicting portrait imports had identical settings except UIDs, so the current stable UIDs were preserved. Other generated metadata was regenerated; this did not delete source assets.

Godot import exited 0 with no script/parse errors. Generated missing-UID warnings were retained in /tmp/underwater-maze-campaign-merge-import.log, not misreported as a flawless cold checkout.

Focused existing gates: maze_minimap, enemy_moves, opening_prologue_state, deep_zone_maze_transition and ability_popup_video all exited 0 with no script errors; complete short receipts are saved alongside this audit. These are narrow baseline checks, not integrated campaign acceptance. The transition gate checks scene/HUD presence only; a fresh party still passes it. No real puppet/Cordys victory, coherent maze checkpoint, normal traversal, listening round, web export or native package is proven.

Next action: read the state consumers completely, write the INT-01 conservation reproduction, and repair the actual World-to-maze party/inventory boundary. Do not move to delivery with this known state-loss risk unresolved.

## October 4 2026 INT-01 live campaign handoff

Source before change: 2e19f29. Read World, MazeLevel, secret excursion, Diver, CombatantStats, RouteState, SaveManager, SceneHandoff, TitleScreen and relevant spell types completely; module contract saved in the bug catalog.

Reproduction: new accepting gate `maze_campaign_handoff` constructs six bounded valid party configurations (every active diver, with/without a downed companion). It uses actual SpellTree learning and the normal physics proximity entrance, not the private transition method. Expected stats, effects, kit, inventory, relics and campaign flags are independently recorded before scene replacement. All six failed, with 166 loss findings and no script errors. An initial invalid SpellTree fixture was corrected before reproduction and is not game-failure evidence.

Repair: a single-use SceneHandoff transfers a CampaignSession; MazeLevel retains the real CombatantStats resources and inventory and applies saved earned kit, ability lock and Sonar clock to its replacement nodes. Campaign relics remain separate from Marc's door-key list. Global encounter preference is retained without overriding the strong room's forced-encounter policy. The outer checkpoint/selected slot are retained by the session for subsequent persistence work. Failed scene construction releases the pending handoff and exposes retry rather than leaving stale state for another review.

Verification: new six-case gate, existing deep_zone_maze_transition, maze_minimap and opening_prologue_state all exit 0 with no script errors. Godot import and diff whitespace check pass. Receipts saved under docs/evidence/maze-campaign-integration/.

Limits: fixture deliberately begins near the entrance and skips onboarding; no normal-navigation or visual proof is claimed. This is a live handoff, not durable maze loading. Secret-room return still reconstructs state, Maze battles still contain placeholder Tethys dispatch and recovery, and campaign relic access in maze spell consumers remains to integrate. No web/native export or preview was published. Continue state/recovery before delivery.
