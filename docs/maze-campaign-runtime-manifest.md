# Maze and campaign runtime and asset manifest

Status: feedback artifact delivered; final integration acceptance remains open.
Initial baseline 493b1d8 includes current main and PR98. PR97's initial merge and
its October 4 portrait/switch follow-ups are now reconciled. Current working
source includes those follow-ups; the last verified hosted source is e7986ab.

| Artifact | Identity | Verification |
| --- | --- | --- |
| Integration checkout | /Users/tomriddle1/underwatergame-maze-campaign-integration | Dedicated integration/maze-campaign worktree; unrelated opening worktree preserved |
| Starting main | f9ae00c38dae4e3f06ae250f5a3f880a46e4dd42 | Refreshed origin/main |
| PR96 campaign parent | 27a5b5253256a26733f8a320c3c6b4f97c64dece | Remote PR head checked |
| PR98 reviewed opening | c3da257d115385b423306ef61e0214ebf7416f0c | Remote PR head checked |
| PR97 maze | 58c6ed07944676631002794e4649220d3c5bf264 | Refreshed October 4; initial 55e8515 plus d5bf893/58c6ed0 integrated deliberately |
| Last verified combined web export | e7986ab4cd649b349c2a9e77871f05fab5a499bc | Stable feedback alias; normal title/real L-map and served-pack checksum pass |
| Windows x86_64 | e7986ab4cd649b349c2a9e77871f05fab5a499bc | Exported without errors; PE32+ identified; not target-launched/playtested; refresh for latest source before packaging |
| Linux x86_64 | e7986ab4cd649b349c2a9e77871f05fab5a499bc | Exported without errors; ELF x86_64 identified; not target-launched/playtested; refresh for latest source before packaging |

Feedback alias: https://underwatergame-maze-campaign-review.vercel.app/
Review guide: /review.html. Verified deployment dpl_GfZuuQsbDX2Vj4ZwTfVNPEWEFWb1,
READY preview in immortaldemongods-projects/underwatergame. No public promotion.
PCK 92,415,496 bytes, SHA256
35775819bd9d2e244cf8923a1cc789cbd1ffc5f2f5eb5458ade106da27c74dea.
Real browser requests completed against the same hashed endpoint; fresh contexts
rendered normal title and current L-map controls without captured script errors.
This is not normal-route/full-traversal/storage/audio acceptance.

Engine/template 4.7.1.stable.official.a13da4feb. Official export-template archive
SHA256 86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72
matches the GitHub release asset digest. Only x86_64 release templates were
extracted; Windows is unsigned. Native launchers select gl_compatibility.

## Earlier checkpoints (historical, not current artifact status)

Carry source hashes and provenance from audio-manifest.md, deep-zone-asset-manifest.md and opening-prologue-asset-manifest.md when imported. Record model/media source hashes, runtime derivatives, renderer, engine/templates, exact export source, archive and served-PCK checksums before delivery. Do not hand-merge generated PCKs or package developer saves.

Local engine available at /opt/homebrew/bin/godot. Check its actual version/templates before export. Initial disk inspection reports approximately 6 GiB free; monitor during import/export and do not erase user assets to make space.

Local reconciliation checks used Godot 4.7.1.stable.official.a13da4feb and bounded 60-second gtimeout commands. Each command uses --headless --path /Users/tomriddle1/underwatergame-maze-campaign-integration --script res://verify/<gate>.gd. Receipts cover maze_minimap, enemy_moves, opening_prologue_state, deep_zone_maze_transition and ability_popup_video. Headless results are not visual/audio acceptance. The later disk check reported 5.5 GiB free.

INT-04 native checkpoint checks ran on dc2e207 plus the checkpoint increment, with Godot 4.7.1 and 240-second bounds. Receipts identify each verifier under docs/evidence/maze-campaign-integration/. All nine final processes exited 0 without script errors. PR97 and PR98 heads were rechecked unchanged at 55e8515/c3da257. Disk most recently reported approximately 3.2 GiB free. No combined export, served bytes or platform archive exists; do not use historical hosted review builds as evidence for these changes.

Checkpoint increment: a5c8f15. World return/history receipts ran on a5c8f15 plus the return increment, engine unchanged and 120/240-second bounds. Twelve generated return cases and nine affected regressions exited 0 without script errors. Latest disk check: approximately 2.9 GiB free. No shipped artifact exists yet.
