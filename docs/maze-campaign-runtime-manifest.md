# Maze and campaign runtime and asset manifest

Status: feedback artifact delivered; final integration acceptance remains open.
Initial baseline 493b1d8 includes current main and PR98. PR97's initial merge and
its October 4 portrait/switch follow-ups are now reconciled. Current working
source includes those follow-ups and the user-confirmed puzzle exit correction.
Current feedback runtime is bffe1b5, with Marc's shared status/pause/popup and
map/control/door admission. Windows/Linux use that same runtime source.
This is still partial upstream integration, not full route/polish acceptance.

| Artifact | Identity | Verification |
| --- | --- | --- |
| Integration checkout | /Users/tomriddle1/underwatergame-maze-campaign-integration | Dedicated integration/maze-campaign worktree; unrelated opening worktree preserved |
| Starting main | f9ae00c38dae4e3f06ae250f5a3f880a46e4dd42 | Refreshed origin/main |
| PR96 campaign parent | 27a5b5253256a26733f8a320c3c6b4f97c64dece | Remote PR head checked |
| PR98 reviewed opening | c3da257d115385b423306ef61e0214ebf7416f0c | Remote PR head checked |
| PR97 integrated maze | 58c6ed07944676631002794e4649220d3c5bf264 | Initial 55e8515 plus d5bf893/58c6ed0 integrated deliberately; later work pending |
| PR97 refreshed remote | 4ec659870c09ad95b9d14fc689c1712b57b95a50 | New f698bee/4ec6598 range read/classified; radius sites, new underpass/barriers, F/Swap/orb, no ordinary victory restore and first-map changes remain separate admissions |
| PR99 refreshed remote | 86878faedb71e81072b1d200f4ccbfc6f0507210 | Shared pause/popup/caption/status/Bleed/EVA admitted; remaining message queue/learned-stat/guidance subset pending |
| Current source boundary | b916637 (6cc66c7 earned map plus incoming b064f99 orb) | Authored Stun/Angler patch preserved; sphere gaps, map/chest and shooter-owned orb code combined. Verification is source-local, not the deployed build |
| Latest combined web export | bffe1b50edd23199d346fac6b4ca71903b70acc0 | Exported pack, ordinary title, actual L controls and portable badges checked locally/immutable/stable; screenshots inspected |
| Review documentation | e28b20149be0f8bf79ca17376b5546829f0264b4 | Same-source native links, partial integration limits and current controls |
| Windows x86_64 | bffe1b50edd23199d346fac6b4ca71903b70acc0 | Exported, PE32+ identified, ZIP integrity and published digest match; not target-launched/playtested |
| Linux x86_64 | bffe1b50edd23199d346fac6b4ca71903b70acc0 | Exported, ELF x86_64 identified, ZIP integrity and published digest match; not target-launched/playtested |

Feedback alias: https://underwatergame-maze-campaign-review.vercel.app/
Review guide: /review.html. Current deployment
`dpl_7zY9uB1rgm6BDDHzJxsua5K8aufo` / immutable `f24zqpswq`, READY preview,
same browser-accepted runtime pack as `m40s353e5` with updated guide/metadata.
PCK 93,214,808 bytes, SHA256
`7b69e987e2c127f505da3224087f931edd40a466b6135f31047b7b0b04dcc826`.
Existing alias explicitly assigned; fresh stable browser rerun passes. Local,
immutable and stable title/L/portable key controls pass with inspected screenshots.
No campaign traversal/storage/listening acceptance follows from that smoke.
Main/public remain unchanged.

Windows/Linux current prerelease:
https://github.com/Mhanna112-code/UnderwaterGame/releases/tag/pr100-feedback-bffe1b5
Windows ZIP 111,120,289 bytes, SHA256
`d48756ae7ba2617869815c807c72d1b9a57e6019dad59ebf4dd9d8c766a606b5`.
Linux ZIP 101,518,930 bytes, SHA256
`26ee2c2381d32731e6f99f640df7499ce7f366e069c1d8daf48d38990db3bf04`.
Both ZIPs pass integrity; executable architectures verified and GitHub asset
digests match. Anonymous download endpoints return 200. Payload/launcher hashes
and explicit untested target-platform flags are inside BUILD-INFO.json. Current
launchers are Play.bat and Play.sh; no Windows/Linux target launch is claimed.

Rejected 2559d97 export: checksum/title/L smoke passed, but visually broken
arrow badges failed MAP-8. Never assigned to the alias; strengthened browser
negative reproduces the failure against its original pack. See bug catalog.

## Earlier b0bee59 / 1ccf92f artifacts (historical)

Deployment dpl_77kdAJvGn1ekQY5RJKNJ1dJZEUmT,
READY preview in immortaldemongods-projects/underwatergame. No public promotion.
PCK 93,209,800 bytes, SHA256
de249eed5c6a1db0074c608c23738df1159b59b27034d2184ae10ffd0b014132.
Real browser requests completed against the same hashed endpoint; fresh contexts
rendered normal title and current L-map controls without captured script errors.
Hosted real Swift Strike selected/targeted by mouse, early/impact/late frames
inspected, damage 3 and O2 100→92; no captured browser errors. This is not all-nine
browser gestures, normal earning, full traversal, storage or audio acceptance.

Draft PR https://github.com/Mhanna112-code/UnderwaterGame/pull/100 . Unsigned
feedback packages: https://github.com/Mhanna112-code/UnderwaterGame/releases/tag/pr100-feedback-1ccf92f .
Windows ZIP 110,352,698 bytes, SHA256
2b931562b224d34f0297de499ff39a6e29445db6457e4283c75fa1a24bcc2c0f.
Linux ZIP 100,751,322 bytes, SHA256
d3f59f6442172bb765cae443b87e0c313b460e2d995ef9e52ab208aa7cf77d34.
GitHub's published asset digests match and anonymous download endpoints return
200. Native executables/pack/launcher hashes are inside BUILD-INFO.json.
No Docker daemon is available here, so no container Linux launch is claimed.
These earlier packages contain neither the puzzle exit correction nor the nine
delivered spell clips. Web and
native SHA are separate explicit fields in hosted build-info.json and PR100.

Engine/template 4.7.1.stable.official.a13da4feb. Official export-template archive
SHA256 86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72
matches the GitHub release asset digest. Only x86_64 release templates were
extracted; Windows is unsigned. Native launchers select gl_compatibility.

## October 4 character-delivery increment

Source admission: nine bespoke spells from Max.fbx, Musashi.fbx and Buxky.fbx,
through three compact `.res` libraries; complete previous FBX skins/motions
remain. Exact hashes/mapping/omissions are in deep-zone-asset-manifest.md.
Native Godot 4.7.1 Compatibility captures inspect actual casts, including
full-party Mending/Revival at 720x480 and 1280x720. They do not establish web
all-nine browser playback, normal earning, Windows/Linux launch or a complete
polish round. Hosted actual Swift Strike now supplies separate web evidence.

Remote snapshots now PR97 f3018f4e402da942d8c2e262aeb0aead70a238f1 and PR99
d5134bf293487cbae8b8f8cdeaf0fb1c2233dfd9. PR100 still contains the older
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
