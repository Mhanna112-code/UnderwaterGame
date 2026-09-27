# Tutorial modal camera handoff — bug catalog

## Scope

The public player contract is: after dismissing the final post-tutorial
ability modal, the player can immediately use the mouse to look around the
world.  While the modal is still visible, the modal owns input and the world
camera must not move behind it.

`World._unhandled_input()` is the production camera entry point.  The
post-tutorial modal is the `CharacterAbilityPopup` autoload.  Its public
surface for this contract is `open(pages)`, the visible Close button's
terminal action, and its `closed` signal.

## Candidate bugs

| Rank | Bug | Blast radius / plausibility | Test |
| --- | --- | --- | --- |
| P0 | Closing the tutorial modal leaves the tree paused or the popup visible, so free-world input never resumes. | This strands every first-time player after the tutorial. The popup intentionally pauses the tree and does its cleanup in a separate close path. | Captured contract test: open, dismiss, and assert the world is unpaused and the panel is hidden. |
| P0 | The close handoff leaves camera look disabled or prevents the first world mouse event from reaching `World._unhandled_input()`. | Players can only rotate with keyboard arrows despite the HUD promising mouse look. The camera’s event handler is deliberately `unhandled`, so any remaining UI input owner can block it. | End-to-end input contract: dismiss the real popup, dispatch a real mouse press/motion, and assert yaw changes. |
| P1 | The modal leaks mouse motion to the world while it is visible. | A player trying to read the modal can rotate the world behind it; lower impact, but an input ownership regression. | Negative contract: motion while the real modal is open must leave yaw unchanged. |

## Skipped

- Browser pointer-lock permission behavior is not covered by this headless
  contract. It requires a browser user gesture and belongs in a browser-level
  smoke test after the Godot-side state handoff is proven.
- Pixel appearance of the popup/video is covered by `ability_popup_video.gd`;
  it is unrelated to camera ownership.

## Evaluation

### Bugs caught

- `verify/swim.gd` was sampling the chase camera after a count of **idle**
  frames even though `World._move_camera()` runs on **physics** frames and
  intentionally smooths the orbit. It produced the false failure
  `CAMERA HARD-CODED` after a valid mouse turn. The probe now waits 0.40
  seconds of real physics time and retains the original 1 m orbit threshold.

### Bugs characterized

- On PR 90, the full tutorial-skip path starts a real battle, opens all five
  ability pages, unpauses on its rendered terminal Close action, accepts the
  next mouse press, and changes both yaw and visible camera orbit.
- The open modal prevents world camera rotation behind it.

### Investigation results

- The reported `SubViewportContainer` cause was retracted for this popup:
  `CharacterAbilityPopup` only creates an off-screen `SubViewport` to render
  the WASD image. It does not create a `SubViewportContainer`, so that node
  cannot be the post-close input owner.
- The remaining browser pointer-lock risk is bounded but not erased: the
  Godot-side handoff is now covered; an actual browser test still needs a
  Playwright installation and a browser user gesture to test platform pointer
  capture itself.

## Test design self-critique

- Each assertion observes player-facing state or an actual input consequence,
  not a private call order.
- The test would fail if a behavior-preserving refactor retained the same
  close/input behavior; it does not depend on particular node nesting beyond
  finding the panel’s visible state.
- The primary test specifically catches the reported “mouse or arrows look,
  but only arrows work after the tutorial” defect.
