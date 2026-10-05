# Marc main follow-up, October 5

Miguel authorized direct main follow-ups after PR100 merged as ab9e409.
This corrects two confirmed omissions; it does not retroactively claim
every Marc behavior received full campaign acceptance.

## Changes

- Port #99 b60a5980's ordinary random boost ceiling from 25% to 10%.
  Preserve authored Evasion in ordinary factories and reference/floor
  Evasion in the explicit legacy comparison route. Integer rounding still
  applies. Swordfish and Frilled Shark's fixed authored tables are unchanged;
  Battle's already integrated learned-spell bonus remains separate.
- Port #99 b241a219's light-blue blockade waypoint. It points at the actual
  entrance blockade, follows the active diver and updates after Tab. Because
  the integrated campaign makes training optional, completed prologue recovery
  enables it without requiring tutorial completion. It hides within six metres
  and during combat, encounter reveal, aiming, menus/title or maze ownership.
  Breaking the target removes it; cold Load of a consumed target does not
  recreate it. Regional Shallows/Deep/Bucky text is retained unchanged.

## Evidence and boundaries

The new bug-catalog-driven checks reproduced the old failures before fixes:
39 ordinary stat samples, 89 legacy samples and missing World waypoint.
Both 96-seed stat runs now pass. The real World lifecycle check passes in
headless and native Metal modes, including actual Tab/F wall breaking and
a disposable serialized checkpoint cold-loaded through Title. The rendered
1280x720 arrow frame was inspected. Existing learned-spell scaling, combat
and checkpoint-load-failure checks pass. New checks are registered in gates.

These do not prove a full campaign, genuine Run probability, browser save
durability or an exhaustive visual-polish round. Tethys opening changes and
refreshed Windows/Linux packages remain deferred. Web artifact identity and
delivery receipts are recorded separately in build-info and evidence.

Remote intake was rechecked: #97 bba8b80337c07298763a28c9c1109382091bc480
and #99 86878faedb71e81072b1d200f4ccbfc6f0507210 are unchanged from the
PR100 deadline intake. No newly pushed remote commit was silently excluded
at this check.

## Delivery confirmed

Source repair 97bd48f and fresh generated Web artifact a8bc4e9 are pushed
to main. The exported-build browser check passed normal title, diagnostic
maze entrance, actual swimming/E chest acquisition, earned L controls and
lesson/map layouts at 1280x720, 720x480 and 360x640 with no captured script
errors. Small-layout frames were inspected. This is scoped acceptance,
not a complete campaign or browser checkpoint test.

The same inspected pack was promoted to production deployment
`dpl_4vRT6zsVn9Dff4sAvnk9F3Hx5jCn`. Both existing URLs are updated:
https://underwatergame.vercel.app/ and
https://underwatergame-maze-campaign-review.vercel.app/.
Both actual hosted PCK endpoints were downloaded and hashed, matching
93,316,404 bytes and SHA256
`189095a31249e420b3db142e9aa2c0b9be41e7a7392eeb92970e5b31396eec5a`.
Hosted metadata identifies runtime source
`97bd48fb4f4c28f45fb2e55e9095b41a2b8691ba`; the main delivery commit
includes the generated pack rather than leaving Git hosting on stale assets.
