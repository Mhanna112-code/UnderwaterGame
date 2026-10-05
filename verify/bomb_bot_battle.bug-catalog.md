# Bomb Bot actual-fight observer

Generated with design-tests, 2026-10-05. Scope: native World encounter →
rendered Battle controls → actual AnimationPlayer signals → rewarded victory
and restored World ownership. This fixture places the party at the blocker;
it does not establish earned travel or campaign balance.

## Module and public contract

`bomb_bot_battle.gd` is a SceneTree CLI verifier. It observes the real
`AnimationPlayer.animation_started` signal and `Battle.finished`, presses
available move/target controls, and exits nonzero on timeout, loss, absent
attack evidence, incomplete progression or failure to return World control.
The load-bearing requirement is that a construction-only test cannot detect
an attack/victory crash. A drawing idle mesh is not proof of an attack.

IO: imported FBX takes, timers, seeded combat randomness, real frame dispatch,
World progression and isolated native user data. Branches: initial trigger,
live battle, finished battle, elapsed/idle deadlines, target/move/main menus,
signal hookup and final outcome assertions. The authored move catalogue uses
`lightingblast`, `slingpunch`, `sonic_bump` fragments; production Goblin resolves
fragments case-insensitively and ignoring spaces. The delivered take really
emits `rig|Bombot(Attack)Lighting Blast`, with a space and the artist's spelling.
The companion browser verifier observes mouse-driven rendered feedback, not
these native animation signals; its historical receipts are separate.

## Bug catalog

| ID | Failure mode | Blast radius / plausibility | Test type | Status |
| --- | --- | --- | --- | --- |
| BB-NATIVE-01 | The verifier reports no attack when the real imported take contains spaces. | False merge blocker and misleading missing-animation diagnosis; recorded attack signal uses `Lighting Blast` while the observer compared `lightingblast`. | Captured real-fight regression, repeat on unchanged runtime | Fixed observer; focused actual fight passes |
| BB-NATIVE-02 | A successful fixture victory passes without any real enemy attack. | A broken dispatch can be hidden by construction/idle animation; victory alone is insufficient. | Invariant on actual AnimationPlayer signals | Existing nonempty named-attack assertion retained |
| BB-NATIVE-03 | Attack or victory crashes or leaves the next blocker/control unavailable. | Mandatory laboratory route stalls; World handoff has several owners. | Actual fight with strict engine-error scan and progression/ownership assertions | Existing contract retained |

## Test plan and critique

Run the existing actual-fight CLI after correcting only its space normalization.
It must finish `won`, record a named Bomb Bot attack emitted during enemy turns,
persist Bomb Bot defeat, expose Sword Slayer, restore World control and produce
no engine/script errors. Preserve the original full-suite false-negative trace.
Do not inject a signal, call the private callback in a unit test, fabricate a
victory or relax the nonempty attack requirement.

Wrong-but-stable idle/death-only output still fails; casing/space changes in
an otherwise identical imported take should not fail. The retained raw clip
names make a mistaken classification auditable. This is a bounded captured bug,
not a generic normalization property suite: no production parser is changed.

## Skipped

- Every Bomb Bot move over a distribution of seeds: useful later attack-kit
  coverage, but this regression requires at least one actual dispatched attack.
- Native fixture as casual/skilled balance evidence: deliberately excluded;
  the earned-journey observer and full campaign matrix own that requirement.
- Current browser/Marc hardware crash acceptance: separate browser test still
  required; native signals cannot close that report.

## Evaluation

Original fixed-source suite: fight won after 27 presses/1,892 enemy-turn frames,
with actual `Lighting Blast` signal, but empty recognized attack set and exit1.
This demonstrates an observer false negative, not missing production animation.
Focused corrected run: won after27 presses/1,889 enemy-turn frames; actual
`Lighting Blast` recognized, progression and World return pass, terminal0 and
no engine/script errors. Production runtime is unchanged. No all-suite-green
claim; browser/platform/earned campaign requirements remain separate.
