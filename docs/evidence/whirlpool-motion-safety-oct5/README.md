# Whirlpool interrupted motion and nonlethal damage

Bounded follow-up to2a8c24e, not PR100 release acceptance. Production sources
and verification drivers are fingerprinted in source.sha256. No player slots
are written; public preview/main are not updated by this packet.

## Real failures and repairs

- Actual World hazard removal left a surviving shared diver suction-locked;
  real W did not move it. The hazard now tracks its motion and relinquishes
  model/rotation/movement ownership at a physically checked return position.
- Killing the engine timers initially canceled then immediately recaptured
  the actor, charging2HP. Canceled actors can leave the core before recapture.
- A validated live JSON load initially restored6HP, then the old timer made
  it4HP. World cancels hazard motion after complete preflight and before
  applying loaded poses/resources; Maze has the corresponding restore hook.
- Disabling an active Maze retained spiral/vanish locks and accepted caught
  poses as stable saves. Area handoff cancels motion; snapshot availability
  refuses busy hazards.
- A new solid CSG block around the old departure passed triangle-only shape
  clearance, leaving the actor wholly buried. Return validation now checks
  standalone CSG-box solid volumes as well as physical capsule surfaces.
- Removing the caught actor emitted engine freed-lambda ERROR before its own
  callback guard ran. Timed callbacks now resolve WeakRefs rather than
  capturing an actor node. A reused old physics overlap also captured a
  teleported actor20m away; entry validates the current capsule/zone overlap.
- Actual suction revived0HP to1 and reported−1 damage, even with damage0.
  Living divers retain the nonlethal1HP floor; downed divers stay0. Damage
  signals report real nonnegative loss; suction never charges Oxygen.
- The shared gate runner now rejects engine ERROR and SCRIPT ERROR despite
  child exit0. Its public CLI probes preserve a healthy-child positive control.

## Runtime evidence

The final-source command receipts cover:

- Captured authored World removal with real W release.
-18 cases: three actors × spiral/vanish × owner removal/killed scheduler/live
  JSON restore. Loaded positions/resources remain stable beyond the old deadline.
- Fresh inactive authored Maze overlap (characterized green, not a repair).
-6 cases: actual active Corridor4 × three actors × spiral/vanish, deactivate/
  reactivate with resumed real W and transient snapshot refusal.
-24 cases: three capsules × Static/CSG solids ×0/90° yaw × spiral/vanish;
  independent solid-volume/capsule checks and real clear-direction WASD.
-36 actual completions: three capsules × HP0/1/2/7 × damage0/2/10; exact HP,
  nonnegative signals, visibility/release/reset and0O2.
-6 real rig deletions plus a replacement actor's successful completion, and
  three existing external lock/hidden-model/non-default-mask owners untouched.
-24 existing obstructed/open LOS pairs preserve meaningful suction.
- Native Metal/AppleM1 repeats authored removal/resumed W; this is a runtime
  receipt, not final visual polish or Windows/Linux testing.
- Existing physical lab ramp/shared ownership, earned-map/current traversal
  and first-person grapple preservation are checked separately.

Godot4.7.1. Every final receipt must have terminal exit0 and no engine/script
ERROR or infinite-loop output. Counts are coverage dimensions, not release
readiness. Original reds and rejected observers are retained separately.

## Observer corrections, not product fixes

- Ordinary resumed swimming owns model X lean; the hazard-owned Z roll/yaw
  must be restored, not a permanently fixed whole-model rotation.
- Generated deactivation cases use independent live scenes. Reusing a canceled
  actor while teleporting out/back with the hazard disabled retained deliberate
  core-exit grace and was not a new-arrival test.
- W into the newly rotated wall was physically blocked, not movement-locked.
  An independent capsule motion cast now selects a clear WASD direction before
  requiring real swimming. No-clear-direction still fails.
- The old40-frame LOS positive leg could sample the authored damage blink.
  It now waits90 physics frames, retaining every exact reset/resource assertion.
- The current-route chest approach allowed .45m early stopping while the tall
  diver was raised by the plinth.1.8m nominal horizontal offset could exceed
  the2.4m3D interaction range.1.4m and a measured approach receipt preserve real
  E acquisition/first L/return; production interaction range is unchanged.
- The first ad-hoc shell process-substitution probe failed to import the runner;
  it is not harness evidence. The committed self-test uses public CLI exit status.

## Still open in the full plan

Battle/modal/root-warning ownership, full standalone restore and World save
refusal, hall lane/shaft visuals and safe traversal, autosaves, normal earned
campaign balance and confirmed campaign pivot/completion, browser durability/
BombBot/audio, final full gates, exact-source web/desktop delivery and six
fresh campaign visual areas. No new PR, main push, canonical promotion, issue
closure or merge is authorized or claimed by this batch.
