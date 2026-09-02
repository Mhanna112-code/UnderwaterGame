# Diver Boy Grapple Intercept Playtest

This branch contains the playable Diver Boy special-encounter prototype.

## Manual web build

https://underwatergame-diver-boy-playtest.vercel.app

The build is hosted in a separate Vercel project so it does not replace or
modify the existing UnderwaterGame deployments.

## How to test

1. Open the link and click **CLICK TO START PLAYTEST**.
2. Move the mouse to aim the grapple reticle.
3. Left-click the orange threats before they reach Diver Boy.
4. Avoid the blue decoys. Grappling one damages the player.
5. Refresh the page to restart the encounter.

## Expected behavior

- The encounter starts directly in battle as Diver Boy.
- Eight orange threats must be intercepted.
- Orange threats that reach the player deal damage.
- Blue decoys must be left alone; hitting one deals damage.
- The mouse is captured only after the explicit start click in web builds.

## Automated verification

Run:

```sh
godot --headless --path . --script verify/grapple_intercept.gd
```

The verification expects all eight threats to be intercepted, no threat
impacts, and one deliberate decoy penalty.
