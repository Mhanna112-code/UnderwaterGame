# Automatic Sonar and encounters after the opening

Runtime commit: `42d8bf2fbed156b67e82d7b41026d9f57f282029`.

Contract: completed opening recovery enables Sonar through the existing
oxygen-aware activation and enables random encounters before the healthy
checkpoint is written. Optional training is not required. Existing cost,
range, encounter rates and Q/R controls are unchanged. Later saved Off
choices remain Off on Load; completed older checkpoints with no setting
fields adopt On. Unfinished openings do not acquire Sonar prematurely.

- `recovery-red.log`: actual opening journey failed live/HUD and saved-state
  assertions before implementation. Disabled encounters blocked ordinary play.
- `recovery-green.log`: actual combat → aftermath → recovery/Continue →
  ordinary combat → death/restart/title Load, both settings retained.
- `rendered-recovery-green.log`, `recovery-sonar-encounters-on.png`: same
  production handoff rendered at 1280×720; HUD shows both On.
- `round-trip-green.log`: eight Q/R preference/active-diver combinations
  through real save request and title Load; completed legacy and unfinished
  migration; invalid boolean rejection; oxygen-empty Sonar stays honestly Off.
- `invalid-load-green.log`, `optional-training-green.log`: existing affected
  recovery/validation/training gates.
- `denied-save-retry-green.log`: rejected recovery checkpoint keeps gameplay
  paused; Retry persists both enabled systems and later restart retains them.

All green logs checked for script/engine/infinite-loop errors, not just exit
status. An initial test-only GDScript inference error was repaired before
accepting the round-trip result. Only owned temporary test slots were used.

Clean exact export: 93,320,308 bytes, PCK SHA-256
`0205efe8814794676d4414f85b8ed5216a91aee0be78106b99a683a101986ca7`.
Candidate: https://underwatergame-npr1v6jn5-immortaldemongods-projects.vercel.app/
(`dpl_5aws4NhxmoY8WqypFv3GVU6DcHxK`).

Hosted ordinary New Game/full movies/real combat/recovery/cold Load: passed
in 94.228 seconds to recovery control, zero console/runtime errors, both
fields true in the actual IndexedDB checkpoint before and after cold Load.
Screenshots inspected: `browser-recovered-world.png`, `browser-loaded-world.png`.
Sonar's unchanged cost is observable after Load (O2 97, still On), not disabled
or faked for verification. `browser-result.json` and `browser-green.log` record
the whole journey without query shortcuts or completion injection.
Existing review alias refreshed and its unauthenticated metadata verified:
https://underwatergame-opening-prologue-review.vercel.app/.
Public main remains `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`.
This packet does not mark the larger final visual/audio audit complete.
