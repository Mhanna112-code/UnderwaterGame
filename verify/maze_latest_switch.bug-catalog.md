# Marc's October 4 switch fixes

Current consumers: MazeLevel routes real E to switch/poster, highlights the same
poster, and forwards screen mouse positions to SwitchMinigameModal's public
drawing API. Its traveling portraits consume directed rungs. Upstream 58c6ed0
reduces both reaches and chooses the nearer switch/poster; d5bf893 permits a
direct lane 0→2 rung rather than silently replacing it with an adjacent lane.

Tests name two bugs: nonadjacent drag snaps to the wrong lane (rung endpoints
and actual traveling portrait destination); a nearby switch steals E from the
closer poster (actual parsed E and visible modal owner). Coordinates are local
fixtures for these consumers, not physical maze traversal evidence. Test a short
invalid drag and reverse two-lane drag as boundaries. Preserve forced-room policy
and input ownership through the existing affected gate. No private production
resolver or injected puzzle success is used.

Evaluation: both defects reproduced before the upstream patches. After deliberate
cherry-picks, the same consumer contracts pass in headless and native 1x runs,
and the real poster and spanning arrow PNGs were inspected. Initial green
fixtures were invalid: a fixed eight-second deadline under concurrent load
missed the portrait tween; old proximity samples no longer overlapped after
Marc reduced reach; one-frame room entry delivered E during a deferred explainer.
The corrected fixture checks actual current distances, settles/dismisses the
real explainer and waits boundedly for the actual portrait transition. None of
those fixture repairs changed game logic. Existing nine map/save/swap and nine
strong-room input-policy cases remain clean. Full puzzle/maze traversal is open.
