# Dev Log: Maze Map and Exploration Fixes

This update makes the maze map something you can use **while you play**, instead of a screen that stops everything, and clears away several things that got in the way while exploring.

## The map now sits in the corner
- **The maze map opens in the top-right corner**, where the small round minimap normally is, instead of covering most of the screen. Its key guide sits underneath and its legend beside it.
- **Everything else stays on screen** while it's open: your divers' health and oxygen, the controls list, and the Random Encounters button.
  - *Why:* the map used to hide all of this, so you lost track of your team every time you checked where you were.

## You can keep playing with the map open
- **Look around, swim, switch divers and use abilities** (Sonar, Swap, aiming) with the map open. The map only takes the keys it needs for turning walls and moving currents.
  - *Why:* checking the map shouldn't mean you can't move or react. Now you can plan your route and act on it at the same time.
- **Turning walls no longer closes the map.**
  - *Why:* the whole point of turning walls is to see the result on the map, so the map shutting itself was frustrating.
- **"Press E" interactions come first.** If you're next to something you can use (a poster, chest, switch, lever or rock), E uses it even with the map open. Enter still turns walls.
  - *Why:* E did two jobs, and turning a wall when you meant to read a poster was confusing.
- **Prompts and encounters still happen with the map open**: the "A draft leads under the wall" question, special encounters, and swimming out of the maze. The map closes itself when one of these appears, as it does for the inventory and the save menu.
  - *Why:* these used to silently do nothing while the map was up, which made them seem broken.

## Clearer prompts
- **"Press E to interact" and other on-screen messages no longer overlap the health and oxygen bars.** They now sit just above them.
  - *Why:* the message landed on top of your active diver's bars and was hard to read.
- **The draft question's buttons now simply say "Yes" and "No".**
- **The map's controls guide no longer lists the Random Encounters key.**
  - *Why:* that option is already shown on screen at all times, so repeating it on the map just added clutter.

## Easier to see who you're controlling
- **A green marker now floats over your active diver inside the maze**, just like in the rest of the ocean.
- **The green markers sit right above each diver's head** instead of floating high above them. That includes the one that shows who you're about to swap with.
  - *Why:* in the maze it wasn't always clear which diver you were controlling or picking, and the markers looked detached from the characters.

## Special encounters are easier to find
- **Special encounters in the maze now start when you swim through them at any normal height**, not only when you're skimming the floor.
  - *Why:* you had to hug the floor for them to trigger, so it was easy to swim right over one without noticing.

## Moving walls behave as expected
- **Only the inner side of a turning wall carries you along**, meaning the side facing the corridor between its two walls. Touching the outside just nudges you out of the way, and a wall swinging away from you leaves you where you are.
  - *Why:* brushing the outside of a wall could drag you along with it, or even pull you through to the other side.

## No more invisible walls
- **Removed several invisible walls that trapped divers**: near the maze entrance, by the dome, and around the current next to the broken rock. The real edges of the maze still stop you from leaving it.
  - *Why:* bumping into something you can't see feels like a bug, and it blocked paths players expected to be open.
