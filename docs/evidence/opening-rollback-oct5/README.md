# Remove automatic Cordys opener — October 5

Miguel requested removal of the broken immediate-Cordys handoff, not the
previously deferred Tethys redesign. This selectively removes that handoff and
its direct-Cordys bypass, preserving the other combat, tutorial, save and maze
changes from Marc's combined commit.

The restored sequence is opening movie → controllable quiet exploration →
actual swimming for at least four seconds and three metres → one visible
Angler. Idle/camera-only input cannot trigger either combat or the Cordys film.
The older Cordys interruption **after genuine Angler defeat remains**, followed
by saved full recovery and the existing tutorial. This is not the Tethys opener
or a claim that the entire campaign/balance is accepted.

## Native acceptance

All logs under `native/` use the disposable verification project and its owned
high-numbered save slots, not the player's ordinary saves. The red log retains
six findings against main before the repair. Independent repaired gates pass:
actual idle/look/swim/visible roster; trigger boundary/property matrix;
state migration; one Battle ownership; video milestone/fallback/save behavior;
ordinary Angler kit contract; real-button Angler kill → later Cordys responses
→ recovery → fresh title Load. Movies alone are fast-forwarded in native tests.
No stats, damage, victory, completion or recovery results are manufactured.

## Publication

Runtime source `e54e7ce4b0a261079b588c6609fdf5c803d9c53c`; rebuilt main artifact
commit `43e76b6`. Web PCK 94,993,116 bytes,
SHA256 `42d6a9fc9e79b93ddd87b04eb65fb75c1a089a35a567140b2d33d2ec7dc5f5a5`.
Candidate `dpl_CvXtKRopw2XpHb1dQun2CJVBNUnt`:
https://underwatergame-9xma17t3d-immortaldemongods-projects.vercel.app/.
Actual metadata and all four game assets match local bytes; fresh title has
New Game and no captured errors. The title screenshot was visually inspected.
This exact artifact was promoted to https://underwatergame.vercel.app/ after
native acceptance and an isolated browser New Game/checkpoint/movie probe.
No new PR, no repointing of old feedback aliases, no broad commit revert.

## Retained browser failure / limit

The first concurrent browser traversal failed **before the opening**: visible
New Game reported that it could not start the saved run. No prologue phase or
script error occurred. The retained recording's later frame shows the explicit
save-start error, not a missing/click-disabled opener. An isolated fresh probe
read the actual IndexedDB checkpoint successfully, entered `opening_video`
on its first New Game attempt and found the real slot key. No persistence
guard was disabled, player save modified or production save code changed.
The failure's underlying intermittent cause is not established; it is not
erased or counted as a successful full browser traversal. The independent
full-video repeat and canonical identity checks are recorded separately.

The headed repeat reached Angler during its intended idle interval and remains
a failed traversal, not a pass. Its failure did not show immediate Cordys;
the actual screen shows the restored Angler. The test did not record raw key
events then, so external input/interference is not established as the cause.
An independent probe of the actual exported PCK's trigger returns false for
60 seconds of stationary/no-input time. No game predicate was weakened.

## Independent canonical acceptance

`canonical-assets/receipt.json`: actual metadata and four game assets exactly
match local files, title New Game is visible, errors=[], passed=true.
`canonical-opening/result.json`: fresh isolated Chromium, actual New Game
and full movie/title, 15 seconds idle and camera-only input stay in exploration,
then actual W starts one visible Angler after the four-second interval; no
Cordys film or encounter occurs beforehand, errors=[], failure=null, terminal0.
This run records raw key events as well as public phases. Its screenshot and
continuous recording are retained; the Angler and idle screenshots were
visually inspected. This is complete real-video opener-entry acceptance, not
an exported whole-campaign or browser recovery/Load pass. The latter handoff is
covered by the separately disclosed native real-button journey.

The original victory bridge/setup and recovery text files are byte-unchanged
from main before the repair; only World's automatic dispatch and Battle's
direct-Cordys bypass changed. The later Cordys sequence is deliberately retained.

Full campaign, balance matrix, tutorial redesign and Windows/Linux
target-machine playtests are outside this emergency repair. The larger goal
remains paused; this emergency repair does not resume its full suite.
