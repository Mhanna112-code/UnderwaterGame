# Bug Catalog: `verify/encounters.gd`

**Updated 2026-10-03**
**Scope:** normal-world site discovery, encounter dispatch, reward, and map-to-battle enemy identity.

## Current contract

`ItemGuardian` is a shared content query, not an in-world actor. Its records
name each site's position, radius, item, and enemy. `World._on_encounter_triggered()`
checks proximity first: outside a site it starts an ordinary encounter; inside
an unclaimed site it starts that site's mapped one-enemy reward encounter.
Special sites may open the diver chooser, while ordinary key-item sites start
their mapped party fight immediately. No visible guardian, ring, or query flag
is part of the product path.

## Bug catalog

| # | Bug | Blast radius | Test | Status |
|---|---|---|---|---|
| 1 | A guarded record names a missing site or enemy. | The feature exists in data but cannot build a real encounter. | Content graph invariant. | Green |
| 2 | Site-centre grapple anchors are mistaken for obstructing level geometry. | Valid sites are reported buried/walled off and release gates become noise. | Collision query excluding the intentional `grapple_anchor` affordance. | Fixed and green |
| 3 | Proximity dispatch drops the site's item or enemy and starts an ordinary pack. | Art, combat identity, and progression contradict one another. | Normal-entry site-to-Battle round trip for every site. | Green |
| 4 | Open-water encounter composition exceeds the level-one formation cap. | Early combat becomes unintentionally punishing. | Ordinary signal and pack-size assertion. | Green |

## Human boundary

The gate proves clear site volume, a straight collision-free approach after
excluding the target anchor, and real encounter construction. It does not claim
that a fixed recorded WASD path is the only or best route through a 3D world.
