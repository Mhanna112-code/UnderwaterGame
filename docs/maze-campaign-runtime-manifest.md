# Maze and campaign runtime and asset manifest

Status: local integration source identity, not a delivery manifest. Current baseline 493b1d8 includes current main and PR98. PR97 reconciliation is local; focused gate receipts record the uncommitted merge before its checkpoint commit. There is no combined hosted artifact.

| Artifact | Identity | Verification |
| --- | --- | --- |
| Integration checkout | /Users/tomriddle1/underwatergame-maze-campaign-integration | Dedicated integration/maze-campaign worktree; unrelated opening worktree preserved |
| Starting main | f9ae00c38dae4e3f06ae250f5a3f880a46e4dd42 | Refreshed origin/main |
| PR96 campaign parent | 27a5b5253256a26733f8a320c3c6b4f97c64dece | Remote PR head checked |
| PR98 reviewed opening | c3da257d115385b423306ef61e0214ebf7416f0c | Remote PR head checked |
| PR97 maze | 55e851556c69e3745fdc38ddd2b381244e087b05 | Remote PR head checked |
| Combined web export | None | Not exported/deployed |
| Windows package | None | Not exported/launch-tested/playtested |
| Linux package | None | Not exported/launch-tested/playtested |

Carry source hashes and provenance from audio-manifest.md, deep-zone-asset-manifest.md and opening-prologue-asset-manifest.md when imported. Record model/media source hashes, runtime derivatives, renderer, engine/templates, exact export source, archive and served-PCK checksums before delivery. Do not hand-merge generated PCKs or package developer saves.

Local engine available at /opt/homebrew/bin/godot. Check its actual version/templates before export. Initial disk inspection reports approximately 6 GiB free; monitor during import/export and do not erase user assets to make space.

Local reconciliation checks used Godot 4.7.1.stable.official.a13da4feb and bounded 60-second gtimeout commands. Each command uses --headless --path /Users/tomriddle1/underwatergame-maze-campaign-integration --script res://verify/<gate>.gd. Receipts cover maze_minimap, enemy_moves, opening_prologue_state, deep_zone_maze_transition and ability_popup_video. Headless results are not visual/audio acceptance. The later disk check reported 5.5 GiB free.
