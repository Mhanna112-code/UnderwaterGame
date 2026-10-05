# Maze and campaign runtime and asset manifest

Status: feedback artifact delivered; final integration acceptance remains open.
Initial baseline 493b1d8 includes current main and PR98. PR97's initial merge and
its October 4 portrait/switch follow-ups are now reconciled. Current working
source includes those follow-ups and the user-confirmed puzzle exit correction;
the last verified hosted runtime is dcb7650. Native downloads still use 1ccf92f.

| Artifact | Identity | Verification |
| --- | --- | --- |
| Integration checkout | /Users/tomriddle1/underwatergame-maze-campaign-integration | Dedicated integration/maze-campaign worktree; unrelated opening worktree preserved |
| Starting main | f9ae00c38dae4e3f06ae250f5a3f880a46e4dd42 | Refreshed origin/main |
| PR96 campaign parent | 27a5b5253256a26733f8a320c3c6b4f97c64dece | Remote PR head checked |
| PR98 reviewed opening | c3da257d115385b423306ef61e0214ebf7416f0c | Remote PR head checked |
| PR97 maze | 58c6ed07944676631002794e4649220d3c5bf264 | Refreshed October 4; initial 55e8515 plus d5bf893/58c6ed0 integrated deliberately |
| Last verified combined web export | dcb7650c3d459b7dd6f033f0866ada7ff0e05f5a | Latest PR100 head; stable feedback alias; normal title/real L-map and served-pack checksum pass |
| Windows x86_64 | 1ccf92ff0aa07bbf2b4a8612435ea5322968c0e9 | Exported, PE32+ identified, ZIP integrity and published digest match; not target-launched/playtested |
| Linux x86_64 | 1ccf92ff0aa07bbf2b4a8612435ea5322968c0e9 | Exported, ELF x86_64 identified, ZIP integrity and published digest match; not target-launched/playtested |

Feedback alias: https://underwatergame-maze-campaign-review.vercel.app/
Review guide: /review.html. Deployment dpl_9cwPgCqLQtKLxaiuavjD6amzxecj,
READY preview in immortaldemongods-projects/underwatergame. No public promotion.
PCK 92,417,000 bytes, SHA256
48a82da824be2710940fe086cab03e0be3fa5c2d06f38214bee4bad36ccdf788.
Real browser requests completed against the same hashed endpoint; fresh contexts
rendered normal title and current L-map controls without captured script errors.
This is not normal-route/full-traversal/storage/audio acceptance.

Draft PR https://github.com/Mhanna112-code/UnderwaterGame/pull/100 . Unsigned
feedback packages: https://github.com/Mhanna112-code/UnderwaterGame/releases/tag/pr100-feedback-1ccf92f .
Windows ZIP 110,352,698 bytes, SHA256
2b931562b224d34f0297de499ff39a6e29445db6457e4283c75fa1a24bcc2c0f.
Linux ZIP 100,751,322 bytes, SHA256
d3f59f6442172bb765cae443b87e0c313b460e2d995ef9e52ab208aa7cf77d34.
GitHub's published asset digests match and anonymous download endpoints return
200. Native executables/pack/launcher hashes are inside BUILD-INFO.json.
No Docker daemon is available here, so no container Linux launch is claimed.
These earlier packages do not yet contain the puzzle exit correction. Web and
native SHA are separate explicit fields in hosted build-info.json and PR100.

Engine/template 4.7.1.stable.official.a13da4feb. Official export-template archive
SHA256 86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72
matches the GitHub release asset digest. Only x86_64 release templates were
extracted; Windows is unsigned. Native launchers select gl_compatibility.

## October 4 character-delivery working increment (not yet shipped)

Source admission: nine bespoke spells from Max.fbx, Musashi.fbx and Buxky.fbx,
through three compact `.res` libraries; complete previous FBX skins/motions
remain. Exact hashes/mapping/omissions are in deep-zone-asset-manifest.md.
Native Godot 4.7.1 Compatibility captures inspect actual casts, including
full-party Mending/Revival at 720x480 and 1280x720. They do not establish web
playback, normal earning, Windows/Linux launch or a complete polish round.

Remote snapshots now PR97 bbadaaf1816944beb88a975d658c4961d5866640 and PR99
7e52dfc6b8986416cf52ae7438502e7d6f6797c6. PR100 still contains the older
58c6ed0 maze plus current repairs; later deltas are explicitly pending in the
plan/ledger. Do not label the preview as containing every new remote change.

Only task-generated temporary preview output was moved, recoverably, to
`/Volumes/Totallynotaharddrive/underwater-generated-archive.YZPzri/underwater-maze-feedback.93l45P`
when internal space ran low. No source asset or user save was removed.

## Earlier checkpoints (historical, not current artifact status)

Carry source hashes and provenance from audio-manifest.md, deep-zone-asset-manifest.md and opening-prologue-asset-manifest.md when imported. Record model/media source hashes, runtime derivatives, renderer, engine/templates, exact export source, archive and served-PCK checksums before delivery. Do not hand-merge generated PCKs or package developer saves.

Local engine available at /opt/homebrew/bin/godot. Check its actual version/templates before export. Initial disk inspection reports approximately 6 GiB free; monitor during import/export and do not erase user assets to make space.

Local reconciliation checks used Godot 4.7.1.stable.official.a13da4feb and bounded 60-second gtimeout commands. Each command uses --headless --path /Users/tomriddle1/underwatergame-maze-campaign-integration --script res://verify/<gate>.gd. Receipts cover maze_minimap, enemy_moves, opening_prologue_state, deep_zone_maze_transition and ability_popup_video. Headless results are not visual/audio acceptance. The later disk check reported 5.5 GiB free.

INT-04 native checkpoint checks ran on dc2e207 plus the checkpoint increment, with Godot 4.7.1 and 240-second bounds. Receipts identify each verifier under docs/evidence/maze-campaign-integration/. All nine final processes exited 0 without script errors. PR97 and PR98 heads were rechecked unchanged at 55e8515/c3da257. Disk most recently reported approximately 3.2 GiB free. No combined export, served bytes or platform archive exists; do not use historical hosted review builds as evidence for these changes.

Checkpoint increment: a5c8f15. World return/history receipts ran on a5c8f15 plus the return increment, engine unchanged and 120/240-second bounds. Twelve generated return cases and nine affected regressions exited 0 without script errors. Latest disk check: approximately 2.9 GiB free. No shipped artifact exists yet.
