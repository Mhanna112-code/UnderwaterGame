# No-refill evidence correction — October 5

These logs compare the same math-policy seeds and unchanged thresholds before
and after removing unsupported victory healing. Current Battle grants no
ordinary win refill. Its battle-only statuses still end on scene exit, so the
corrected observers retain status cleanup without refilling HP or Oxygen.
Legitimate `gain_xp()` level-up filling remains in the ordinary-route model.

| Screen | Before (unsupported healing) | Corrected, no win refill |
|---|---|---|
| Casual two-artifact route | 91.2%,28.6 HP on successes | 89.6%,25.7 HP |
| Skilled two-artifact route | 100%,29.5 HP | 100%,27.2 HP |
| Casual two-blocker sequence | 99.2% | 98.0% |
| Skilled two-blocker sequence | 100% | 100% |

Both corrected commands exit0/no engine or script error; no acceptance band
was relaxed and no runtime tuning was made. `ordinary-before.log` and
`blockers-before.log` are explicitly misleading baselines, not shipped balance
claims. The corrected logs are `ordinary-current.log`/`blockers-current.log`.

This removes one confirmed **verification defect**. It does not establish
full current consumer fidelity, earned spells/rest access, actual travel,
New Game lab-first/maze-first policies, puppets/Cordys attainability or human
playtesting. The remaining simulator stat/XP/order/learning gaps are cataloged
in `verify/balance.bug-catalog.md` and
`verify/deep_zone_blocker_balance.bug-catalog.md`.
Existing live lab route teleports between encounters; boss balance supplies XP
to a target level. They are narrower fixtures and cannot substitute for the
requested genuine earned-resource campaign journeys.
