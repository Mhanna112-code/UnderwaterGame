# Deep-zone authored blocker bug catalog

Scope: the one-time Bomb Bot and Sword Slayer fights which block the normal
route to the laboratory. These are authored encounters, never ordinary random
roster entries.

| ID | Bug a plausible implementation could ship | Cheapest gate which catches it | Status |
| --- | --- | --- | --- |
| DZ-BLOCK-001 | The route requests Bomb Bot, but Battle silently falls back to the Angler actor. | Ask the production actor factory for `bomb_bot` and require its exact identity and model-backed class. | Red test added. |
| DZ-BLOCK-002 | Bomb Bot imports, but one or more move records are disabled, point at the wrong FBX fragment, expose the source typo to players, or advertise a mechanic the current combat runtime does not execute. | Require three player-facing move names, all three real clip fragments (including delivered `LightingBlast`), exact formulas, and resolve Sonic Bump's live Blindness effect. | Covered by `verify/deep_zone_blockers.gd`. |
| DZ-BLOCK-003 | A clip resolves by name but produces no visible rig motion. | Play each move on the production actor and require a positive duration; sample representative skeletal pose before/after Lightning Blast. | Red test added. |
| DZ-BLOCK-004 | Raw FBX scale produces a tiny, huge, sunk, or unusably wide actor in battle. | Measure the normalized production actor's visible bounds before the real-resolution battle framing pass. | Red test added. |
| DZ-BLOCK-005 | Bomb Bot or Sword Slayer can appear in the ordinary random roster. | Require authored-only actor IDs to be absent from `EnemyRoster`, then exercise protected and open-water dispatch. | Planned lifecycle slice. |
| DZ-BLOCK-006 | Entering a blocker site starts twice, starts the wrong enemy, or fails to mark the encounter in progress. | Production World trigger decision table and one physical-entry journey. | Planned lifecycle slice. |
| DZ-BLOCK-007 | Losing, fleeing, or closing a blocker battle falsely marks victory or leaves the blocker permanently unavailable. | Result decision table across win/loss/flee/retry, then a real loss/re-entry journey. | Planned lifecycle slice. |
| DZ-BLOCK-008 | Winning does not retire the encounter, unlock the next objective, or survive save/load. | Real World win callback plus persistence round trip and revisit. | Planned lifecycle slice. |
| DZ-BLOCK-009 | The fight is technically functional but model, camera, labels, VFX, or attack read are visually defective at 1280x720. | Retained production-battle captures and repeated visual audit until a clean round. | Planned visual pass. |
| DZ-BLOCK-010 | A player can swim around the staged guard and reach the lab without resolving either blocker. | Normal-entry route traversal attempts around, above and below each production choke point. | Planned spatial blocker pass; trigger lifecycle alone does not claim this. |
| DZ-BLOCK-011 | Repeated loss/restart or save/load testing leaks the three unparented tutorial Slot control trees each time World is destroyed. | Instantiate and destroy the two Worlds used by this lifecycle gate; Godot's ObjectDB/CanvasItem leak report must stay silent. | Covered by explicit World ownership cleanup discovered during this gate. |
