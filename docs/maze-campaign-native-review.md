# Current-main feedback build: Windows and Linux

Extract the entire ZIP before launching. Keep the executable and its .pck file
together. Available 7336611 packages: Windows double-click Play.bat; Linux x86_64
run ./Play.sh (mark it executable if your archive utility dropped the
permission). These launchers select the Compatibility/OpenGL renderer used for
our native captures, not an unverified Forward+ default.

Use New Game for the ordinary opening and campaign. For a focused maze entrance
only, run the launcher with --maze-playtest. This diagnostic start does not carry
an earned campaign kit or prove normal progression. Controls: WASD, Space/Shift,
Tab. L opens the maze map; use its displayed hallway/current controls.

Download: https://github.com/Mhanna112-code/UnderwaterGame/releases/tag/main-feedback-7336611
Runtime source 7336611fcaeed8e03c875fdb3e0118facd7737df matches the earlier
canonical web runtime, not the newer e54e7ce emergency opener rollback. These
packages still have the immediate Cordys opener; use the canonical web link for
the repaired opening. Both macOS cross-exports, ZIP integrity and downloaded
archive SHA256 checks pass. Windows/Linux have the same native PCK; the Web
platform's PCK differs. Manifest/export logs are under
`evidence/native-main-7336611`; SHA256SUMS and BUILD-INFO ship with the release.
Full earned campaigns, balance matrix, audio/visual and target-machine acceptance
remain incomplete. No full-game readiness claim. Earlier bffe1b5 releases are
retained as historical feedback packages, not current downloads.

These are unsigned feedback exports, not installation packages. They have been
cross-exported on macOS; that is NOT Windows/Linux launch or playtest evidence.
Do not bypass a security warning you do not trust. Report the warning/error,
operating system and graphics hardware so we can assess it.

Save data is local to the build's Godot user-data directory, not the browser's
storage. Closing the game does not migrate browser saves into this package.
Report title/video/audio, movement/map, save/load, recovery and boss behavior.
Known open review areas: complete physical maze/resource progression, both route
orders, audible seams/mix, final repeated polish audit and target-machine testing.

Each package includes BUILD-INFO.json with its exact source commit. Package and
payload checksums are supplied separately; a successful export is not gameplay
acceptance. The canonical web game already serves this runtime. The opening
still uses direct Cordys and lacks the retained initial Angler. Tethys opening
and relocated Cordys intro remain deferred for explicit user review before main.
