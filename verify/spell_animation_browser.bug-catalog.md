# Exported authored-cast acceptance

SPELL-ANIM-07 and shared delivery contracts are in
`spell_animation_delivery.bug-catalog.md`.

Public interface: identified exported title, temporary Spell Test kit, actual
World swimming/random encounter and rendered move/target buttons clicked by
mouse. Boundaries: pack/browser/renderer, OCR, timers, screenshots, missing
controls and script errors. No saved game is modified by this review route.

Failure: native clips pass while the web build cannot select/target/resolve an
authored cast, or only displays a selected-move heading. Blast radius: player
cannot use delivered animations. Require real outcome text AND actual O2 cost,
capture early/impact/late frames, reject missing controls or browser errors.
This cannot pass merely because a heading or ambient animation appears.
Refactors preserving these visible controls/outcomes should pass.

Skipped: all-nine browser gesture coverage, earned campaign progression,
subjective pacing, other hardware/browser brands and full-game polish.
Native full-party phases and live served-pack checksum are separate oracles.

Prior investigation: first exported real cast resolved but visual inspection
found occlusion. This gate's captures complement functional assertions; they
are not automatic proof that a screenshot looks good.
