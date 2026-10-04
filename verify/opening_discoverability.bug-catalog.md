# Opening handoff and lab-guard discoverability

| ID | Failure | Decisive evidence | Status |
| --- | --- | --- | --- |
| OPEN-032 | Optional training text is hidden behind the recovered active diver. | Real rendered recovery/Load, label separated from active silhouette, OCR reads whole label at wide/narrow/tall. | baseline screenshot confirmed |
| OPEN-046 | Save crystal occupies the camera foreground and hides diver/action at puzzle approach. | Native real camera near save point; close crystal fades but ground landmark/contact/save remain usable. | baseline confirmed |
| GUARD-01 | Undefeated Sword Slayer disappears until the first guard is defeated. | Completed World contains both visible models, and each stays until its own defeat. | baseline confirmed |
| GUARD-02 | Guardian's visible centre is 6 m left of its gate opening. | Measured transformed visual-bounds centre on gate centreline; rendered approaches after facing. | baseline confirmed |
| GUARD-03 | Correctly centred guardian is still hidden behind the chase-camera diver. | Rendered centreline approach must show its silhouette above the player's head; transformed guard top exceeds projected active head. | discovered after green geometry test |

Public surfaces: recovered World/title Load, physical camera/diver positions,
normal optional beacon and save-point contact, staged guardian models and route
state. Physics gates remain sequential and full-width: centering a visible
guardian must not create a side-lane bypass. Rendering-only observations cannot
prove combat/win; those remain separate real fight gates.

Self-critique: a node with correct position can contain an offset mesh, so the
oracle uses visible mesh bounds plus actual rendered views. A label's existence
does not prove readability: OCR/inspection can reject green geometry. Crystal
fade is not accepted without an actual near-camera render and usable save.

Skipped: new landmark art, replacing the field-gate design, changing maze/room
geometry or removing sequential access; outside this targeted correction.

## Evaluation, 2026-10-04

OPEN-032/046 and GUARD-01/02 caught on initial rendered audit. GUARD-03 was
discovered after a green geometry pass, then rejected through screenshot review.
Current native 1280x720, 720x480 and 720x900 renders are inspected; OCR reads
"Optional Combat Training" in all three. The nearby crystal becomes hidden at
camera distance under 2.5 m, while the real contact volume restores the party
and the normal save request retains completed-opening state. Both undefeated
guards render before their own fights, centered and above the active silhouette.
The physical flood/side-lane gate still passes: presentation is not a bypass.

Crystal shader distance fading was rejected visually in Compatibility despite
valid property settings; explicit camera-distance opacity replaces it. A fixed
pixel-separation test was corrected for viewport scale, with independent OCR and
inspection retained. Exact hosted render/whole-opening checks remain separate.

Adversarial harness check: a script-class filter in `find_children` could select
zero SavePoints. The test now inspects the World's actual save-point owners and
requires a nonzero near-camera witness. Earlier rendered evidence remains valid,
but the formerly vacuous structural clause is not counted as proof.
