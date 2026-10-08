# Dev Log - October 8

A short, focused batch: tutorial captions that **stay still**, a **Skip Tutorial**
button that always does what it says, **no repeat pop-ups** on tutorial replays, and
two small balance tweaks. Each change is listed with what it does and why.

---

## Tutorial captions no longer bounce

- **The battle log no longer flashes between caption pages.** When you pressed
  Continue, the battle log reappeared for a frame or two before the next page
  hid it again. That made the whole bottom panel grow and shrink, so the
  caption text jumped up and down on every page.
  *Why:* the text you're trying to read should never move while you're reading it.
- **New pages open cleanly.** A page that appears right after an action (like
  "Electric Touch's own power is 0…" or "Your party's HP is shown…") used to show
  the log for its first frame, making the panel jump 64 pixels and drop back.
  The QTE explanation page had the same problem. Both now hide the log from the
  very first frame.
  *Why:* same as above. It was the most noticeable bounce in the first tutorial.
- **Red highlight boxes no longer change the panel's size.** The box around a
  stat row only made room for its border while it was showing, so the row grew
  6 pixels when highlighted. Between two pages that both highlight a row, the
  panel dipped and came back. The room for the border is now always reserved.
  *Why:* the bounce was small, but it made the panel look shaky at exactly the
  moment a page asks you to look at it.
- **Special encounter captions get the panel to themselves.** While its caption
  pages are up, everything except the caption, Continue and Skip Tutorial is
  hidden, and the panel holds its normal size. Longer pages fill the freed space
  instead of resizing the panel, and the panel only grows if a page truly doesn't
  fit. Everything comes back once the captions are done.
  *Why:* the special encounter shows several pages back to back before you do
  anything, so this is where the movement was most obvious. Its pages don't
  point at the stats or menus, so they can safely step aside. The first
  tutorial keeps everything visible, because its pages point at the stat rows
  and buttons.

## Skip Tutorial

- **Skipping always ends on "Skipping the tutorial fight."** Pressing Skip partway
  through a step (for example during Bucky's "Click the highlighted Angler to
  attack.") used to leave that step's instruction on screen, or let the
  interrupted step write over the skip message. Now skipping clears every
  caption and menu, and nothing from the interrupted step can come back. This
  covers both the first tutorial and the special encounter tutorial.
  *Why:* the screen should always match what the button just did. Seeing an
  instruction after choosing to skip is confusing.

## No repeat pop-ups on tutorial replays

- **The Character Abilities pop-up only appears after your first tutorial fight.**
  Replaying the fight from Combat Help used to bring up the whole onboarding
  carousel again. It's still available any time from the Esc menu's Character
  Abilities button.
  *Why:* a replay is for practising the fight, not for re-reading the
  introduction you've already seen.

## Balance

- **Cordys's Defense is back to 4** (it was lowered to 2 yesterday).
  *Why:* with the +3 buff to his other stats, 2 made him too easy to chip down.
  4 matches the rest of the buff and keeps the final boss feeling like a final
  boss. Tethys stays at Defense 1.
- **Maxilani's swap portraits move 1.5% faster.**
  *Why:* a light nudge to make her special encounter minigame a little more
  demanding without changing how it plays.

---

## Still open

- Some automated checks were already failing and still fail: the puppet fight,
  the campaign ending, the lab route, the prologue hand-off, the tutorial exit,
  the tutorial QTE layout, the ability onboarding, and one combat-feedback
  check. Their scripted runs need retuning for the new balance and layout.
- Several automated tests start a new game in real save slots 2 and 4. They
  should be switched to throwaway test slots so they never touch a player's
  saves.

---

# Later on October 8

## Tethys

- **Tethys no longer heals herself.** She now simply repeats her six attacks in a
  fixed order: Double Scratch, Tail Sweep, Poison Breath, Tail Slam, Tongue Slayer,
  Spinning Death.
  *Why:* without the random heal the fight is a fair, readable race, and players
  can learn and plan around her attack order.
- **Tail Slam's accuracy is 4** (was 3).
  *Why:* at 3 it tied Maxilani's Evasion of 3, and a tie is a dodge, so one of
  Tethys's heaviest attacks could never touch Maxilani. Now it can hit every diver,
  and its QTE gives players a way to dodge it by timing.
- **The lab cutscene looks like the opening cutscene.** The film fills the screen,
  with a small "Skip Cutscene" button in the bottom-right corner. The old version had
  a smaller bordered window, a heading and a large centred Skip button.
  *Why:* the two cutscenes should feel like part of the same game. The old Skip
  button also had keyboard focus, so pressing Enter or Space skipped the scene by
  accident. The new one only responds to the mouse, and Esc still skips.
- **New "Computer recovered" text after beating Tethys:** "From the Tethys corpse
  you retrieve the computer. The records show that the scientists who created such
  monstrosity were being influenced by mental abilities of an unknown being that
  lies beyond the laboratory." followed by "Suggested next step: explore the maze
  via the ramp beyond the laboratory."
  *Why:* it explains where the computer came from and what it reveals, and points
  the story at the being beyond the lab.

## Combat log

- **Hits that do no damage now read "-0" instead of "affected"**, or name their
  effect when they have one (for example "Poison 2"). A double hit that Defense
  fully absorbs reads "Bucky -0/-0".
  *Why:* "affected" didn't say what happened. "-0" matches the floating number,
  and naming the effect tells you what the hit actually did.

## Dev tools

- **New launch option `--tethys-front`** starts dev mode with the lab unlocked,
  just outside its door and facing it.
  *Why:* it makes testing the Tethys fight and cutscene quick.
- **Dev teleports now face the right way** when they move you out of the maze.
  *Why:* leaving the maze overwrote the camera direction, so you arrived facing
  sideways.
