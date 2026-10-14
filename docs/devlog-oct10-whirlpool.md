# Dev Log: Upright Maze Whirlpool

A quick visual update to the whirlpool guarding the corridor in the maze.

## The maze whirlpool stands upright
- **The whirlpool ring now stands on its edge like a wheel** instead of lying flat. Its hole faces straight down the corridor, so you see the swirl head-on as you swim toward it. It still spins.
  - *Why:* a flat ring on the floor was easy to miss. Standing it up makes the danger obvious from down the corridor.
- **The ring fits the corridor.** It sits on the floor and fills the space between the walls without poking through them.
  - *Why:* the first version was wider than the corridor and floated above the floor, so it looked out of place.
- **It pulls you in exactly the same way as before.** Only the look changed. The warning, the drag and the catch zone are untouched.
- **The whirlpool at the ocean blockade and the small holes in the maze hallway are unchanged.**

## Behind the scenes
- New dev shortcut: launching with `--dev --whirlpool-front` puts the party right in front of the maze corridor whirlpool, facing it.
