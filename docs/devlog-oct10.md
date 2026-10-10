# Dev Log: Secret Room Rocks, Ambushes and Cleaner Messages

This update tidies up the secret item room, makes hidden enemies feel like a real surprise, and stops on-screen messages from piling on top of each other.

## Secret item room rocks
- **The breakable rocks are now brown**, the same colour as the other rocks you can break.
  - *Why:* they used to be blue-grey to blend in with the scenery, which made them hard to tell apart from rocks you can't break.
- **The rocks are spread further apart** across the room.
  - *Why:* they were bunched together, so the room felt cramped and it was hard to pick out each rock.
- **No rock sits inside a wall any more.** Each rock now keeps a clear gap from the walls around it.
  - *Why:* a couple of rocks were half-buried in the west wall.

## Enemies hiding in rocks
- **Breaking a rock with an enemy inside now shows the enemies swimming into view** before the fight, the same effect as random encounters in the open ocean. "Something was hiding in the rock!" shows while they appear.
  - *Why:* the fight used to start with no build-up, and the "hiding in the rock" message only showed up after the battle was already over.
- **You fight the same enemies you saw appear.**

## Special encounters
- **Downed divers can now take part in special encounters in the maze.** If they don't win, they come back still downed, with nothing lost.
  - *Why:* turning away a downed diver with "That diver needs recovery" was an extra rule nobody needed. The open ocean already allowed it.
- **The "The guardian holds its ground. Come back and try again." message is gone.**
  - *Why:* it covered the screen after every loss without telling you anything new.

## Messages no longer overlap
- **"Danger: Whirlpool ahead" now waits its turn.** If another message like "You escaped." is on screen, the whirlpool warning appears once that message clears.
  - *Why:* in the maze the two messages landed on top of each other and were impossible to read.

## Behind the scenes
- New tutorial demo clips for the grapple and shockwave special encounters.
- Godot refreshed its import settings for the art files.
- The special encounter test now checks the new downed-diver rule.
