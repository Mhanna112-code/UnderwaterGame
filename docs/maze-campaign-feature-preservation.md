# Maze and campaign feature preservation

Refreshed October 4, 2026. Integration branch: integration/maze-campaign. Baseline current main f9ae00c38dae4e3f06ae250f5a3f880a46e4dd42. PR96 27a5b5253256a26733f8a320c3c6b4f97c64dece; PR98 c3da257d115385b423306ef61e0214ebf7416f0c; PR97 55e851556c69e3745fdc38ddd2b381244e087b05. Refresh again if upstream changes.

| System | Authoritative behavior | Integration action | Acceptance status |
| --- | --- | --- | --- |
| Current-main combat/tutorial/spells | Modern rules, automatic learned/equipped access, PR86 two-turn Headbutt | Retain current main changes through campaign import | Source retained; enemy-move gate passes, full combat regression pending |
| PR96/98 opening and world | Reviewed opening, durable recovery, optional tutorial, assets/audio and independent lab/maze branches | Merge intended campaign work; do not restore rejected PR88 storyboard | Merged at 493b1d8; opening-state gate passes, complete journey pending |
| Marc maze geometry/puzzles | PR97 walls, currents, whirlpools, posters, rocks, hidden rooms, doors and map | Preserve genuine new deltas; reconcile shared consumers | Locally reconciled; import/map/scene-construction checks pass, real route pending |
| Maze encounter policy | Forced encounters in strong room, normal policies elsewhere | Local override without corrupting campaign preference; contextual R/E | Not integrated |
| Party and inventory | Actual campaign party/resources/earned kit/relics | Replace fresh-party boundaries; retain separate maze keys | Not implemented |
| Persistence/recovery | Coherent scene/checkpoint snapshot, no completed-opening replay | Saved/unsaved geometry and inventory rollback together | Not implemented |
| Puppets | Approved three-enemy wave then two-enemy wave, one reward | Replace secret Tethys; independent lab flags, no premature win/refill | Not implemented |
| Finale | Defeatable campaign Cordys, Tethys solely in lab | Explicit dispatch, normal rules, attainable no-lab win | Not implemented |
| Shared media/UI/revival | Current clean media lifecycle plus Marc live demos and revived actors | Semantic hunk reconciliation, not whole-file replacement | Locally reconciled; existing video gate passes, live demos/revival unverified |
| Audio | Existing owner and settings; paired INTRO/LOOP without crossfade | Exploration in maze; continuous battle across puppets; final music Cordys | Not integrated |
| Delivery | Stable combined feedback alias, matching Windows/Linux builds | Critical smoke first; final collaborator approval separate | Not delivered |

CurrentRide remains an unconnected prototype. World Deep's stronger ordinary enemy table and broad combat rebalancing remain separately tracked, not silently implemented or declared resolved here.
