# Resolved effect feedback

FEED-001: Electric Touch reports its requested EVA reduction rather than the
actual clamped reduction, including a fictitious EVA -3 against Cordys EVA 0.
This makes a real combat system teach false progress and obscures move choice.

Public surface: CombatRules.resolve return effects, actual defender stats and
the ordinary Battle result log/floating feedback that consumes those effects.
Boundary: strict ACC/EVA miss versus landed hit; requested reduction versus
available base/current pool; repeat applications at zero.

Bounded property table spans Accuracy 0/1/3/5 and Evasion 0/1/2/3/4. Require
landed feedback to equal the independently observed base-EVA change, no
invented positive reduction at zero, and no target-effect claim after a miss.
Wrong-but-stable requested amounts fail without pinning formatting internals
or changing combat stats. Independently inspect real Cordys feedback afterward.

Module responsibility: shared, deterministic move arithmetic and mutations,
not presentation timing or AI. Public resolve returns hit/damage/effects; its
CombatantStats input owns the clamped reductions. No external IO or randomness.
Branches include strict ACC/EVA miss, successful QTE dodge, damage floor,
effect-kind dispatch, self-cost-after-resolution, and empty/lasting status text.
Comments require committing self cost even on a miss and not applying it before
the current roll. Existing tests cover numerical rules but missed effect text.

Self-critique: a requested-but-unclamped amount fails against observed stats;
renaming an internal helper does not affect the public outcome oracle. Only the
existing user-facing EVA numeric token is parsed, not spacing/layout snapshots.

Evaluation: baseline fails nine cases; repaired resolver passes all 20. Feedback
uses the actual returned change, or reports EVA unchanged. Miss/damage/cost/stat
rules are untouched. Repeated-zero behavior is included in the bounded table;
actual rendered feedback remains a separate higher-layer requirement.

Skipped: general combat/stat redesign and cosmetic wording of other status
messages. Existing Defense reduction already reports the returned change.
