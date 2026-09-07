# Diver Boy Grapple Intercept Playtest

This branch contains the playable Diver Boy special-encounter prototype.

## Integrated PR #50 web build

https://underwatergame-pr50-main-integrated.vercel.app/?special=1

The build is hosted in a separate Vercel project, so it does not replace or
modify an existing UnderwaterGame deployment. The query-only review action
opens the real guardian warning and diver chooser without requiring a trip
across the map.

## How to test

1. Open the link and click **Play Special Encounter Test**.
2. Click **Enter**, select **Diver Boy**, and click **Send Them In**.
3. When Grapple Intercept begins, click once to capture the pointer.
4. Move the mouse to aim at each yellow weak spot and left-click twice.
5. Avoid the blue decoys. Grappling one damages the player.
6. Refresh the page to restart the encounter.

## Expected behavior

- The review route opens the same chooser and special battle used by guardians.
- Five orange threats must be intercepted.
- Orange threats that reach the player deal damage.
- Blue decoys must be left alone; hitting one deals damage.
- The mouse is captured only after the explicit start click in web builds.

## Automated verification

Run:

```sh
godot --headless --path . --script verify/grapple_intercept.gd
```

The verification expects all five threats to be intercepted, no threat
impacts, and one deliberate decoy penalty.
