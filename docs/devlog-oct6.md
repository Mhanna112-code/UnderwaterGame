# Dev Log - October 6

This update makes battles easier to read, makes the bosses tougher, adds more
autosaves, and fills the maze with surprise fights. Here's what changed, grouped by
area of the game.

---

## Battles

The battle menu got a cleanup so players see less clutter and only find details when
they want them.

- **Cleaner move buttons.** Each button now shows only the move's name. The yellow
  number in the top-right corner (the move's power) and the blue number in the
  bottom-right corner (its oxygen cost) are still there.
- **Details on hover.** Hovering over a move opens a box with everything you need to
  know:
  - who it targets
  - how much damage it does
  - how much it heals
  - what effects it causes, like Bleed
- **No more pausing mid-battle.** The pause screen during fights has been removed.
- **Clearer misses.** Moves that weaken an enemy used to say "its agility drops" even
  when the enemy dodged. Now a miss simply says "You use Slow, but the Angler evades!"
- **No running from bosses.** Against Tethys and Cordys, the Run button is greyed out
  and says "No escape from a boss."
- **Bleed works more simply.** A wound only gets worse when you use another Bleed
  move on it, and it can only stack up three times per fight.
- **Lowering an enemy's Evasion works right away**, instead of waiting until the
  enemy's next turn.

## Bosses and moves

- **Cordys is tougher.** Every one of his stats went up by 3, and two of his attacks
  (Octo Stab and Electric Shooting) now hit a little harder.
- **Current Snare**, one of Maxilani's moves, now makes an enemy easier to hit instead
  of slowing it down.
- **Clearer move descriptions.** Several moves were renamed in their descriptions to
  make them easier to understand. For example, Weaken now says "Lowers defense" and
  its upgraded version says "Greatly lowers defense."
- **Clearer healing spells.** Their descriptions now state exactly how much health
  they restore.

## Tutorial and help

- When it's Bucky's turn in the first tutorial battle, the game now points out that
  his move costs 16 oxygen and shows where that number appears on the button.
- The Bleed explanation in the help menu was rewritten to match the new rules. Its
  sections are now spaced apart so they're easier to read.
- The full help menu is now available inside the maze, not just in the open ocean.
- New demo videos were added for the grapple and shockwave abilities.

## Saving

- **More autosaves.** The game now saves automatically:
  - before returning to the title screen, with an "Autosaving…" message so players
	know it's happening
  - right before each boss fight
- **Clearer save points.** Every save point now shows an orange "Save your progress."
  banner. The extra white text that used to float above maze save points is gone.

## The maze and the ocean

- **Surprise fights in the maze.** Random enemy encounters can now happen anywhere in
  the maze, just like in the open ocean. One special room still always has a fight.
- **Less clutter on screen.** The objective text in the bottom-left corner of the maze
  was removed. Ability-unlocking key items no longer fill up the inventory list.
- **Sonar effect.** When Maxilani's sonar is on, a ring now pulses outward from her
  body.
- **Whirlpools are unchanged for now.** A new swirling-particle look for whirlpools
  was started, but it's switched off until it's finished.

## Tools for testing (not visible to players)

- **Teleport.** In developer mode, testers can press G to open a map and jump to any
  spot, or press T to jump to wherever the camera is pointing. This makes it much
  faster to test any part of the game.
- **Return to title** now works in developer mode.
- Notes in the code were shortened to make it easier for the team to work with.

---

## Still to decide

- **Should every hit always do at least 1 damage?** Today a hit always does at least
  1. Removing that rule would let heavily armored enemies shrug off weak attacks
  entirely, and one early tutorial attack would then do no damage.
- **Should the "upgraded" weakening moves actually be stronger?** Right now Weaken and
  Slow do the same amount whether or not they're upgraded.
- **Is Cordys now too hard?** In our automated test fight, the party now loses to him.
  He may need a small adjustment.
