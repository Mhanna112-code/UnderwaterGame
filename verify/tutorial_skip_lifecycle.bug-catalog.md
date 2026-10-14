# Tutorial skip lifecycle

Scope: real Inventory lesson selection, Battle input waits and World replay return. Covers QT3/QT6/QT10 from quick_tutorial.bug-catalog.md.

The public surface is Inventory > Combat Help > Quick/Full and the visible Skip Tutorial button. Await boundaries include narration confirmation, hover, target click, attack animation, QTE explanation, live timing and completion. Pending callbacks must not outlive their ownership or mutate the restored earned stats/inventory. IO includes SaveManager and timers; this test creates its own unused developer slot, not slots 0/1/2, and checks file bytes stay unchanged.

## Cases and oracles

Generate both profiles across intro, move, target, dodge instruction, live dodge and completion/finale. Only Full has a hover-only explanation wait. Assert Skip is actually visible/enabled in every state; input through its button must emit exactly one skipped result, free World.battle, release pause and leave inventory, original stats/sonar and on-disk checkpoint unchanged. Wait through delayed callbacks after return. This catches disabled/hidden Skip, coroutine re-entry and practice/save leaks; it is not a snapshot of private control arrangement. Direct signals drive actual actions, but do not establish browser pointer hit-testing.

Wrong-but-stable UI with a stuck result fails; behavior-preserving helper refactors need not change these observable state/result checks. Phase detection reads the live UI/log to reach each await boundary; it does not inject completion, move results or HP. Long Full finale is reached through real moves. The state space has more than five shapes, so the phase/profile matrix is generated rather than testing only one convenient Skip click.

Skipped: boss/QTE global balance, arbitrary maze hazards and earned opening presentation. They have separate acceptance checks. Current test's saved baseline is a fixture representing an already recovered player, not an earned entire campaign.

Evaluation: 235 World skip checks, 249 embedded-maze skip checks, 34 real completion/item checks and 36 actual defeat/Retry/Exit checks pass. Loss uses an explicitly adversarial strong-enemy/fragile-party fixture and real normal combat resolution, not an injected result or a claim about the practice Angler's difficulty. All earlier failing fixture/timing diagnostics remain in evidence. First-time loss/milestone plumbing is separately covered by tutorial_loss_choice.gd; that test labels its injected result honestly. Browser pointer hit-testing remains a separate gate.
