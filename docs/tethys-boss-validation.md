# Tethys boss validation

This PR build contains Glassgoat's `Mermaid_Freak.fbx` as **Tethys, the final boss**. It does not replace Goblin grunts; Glassgoat said their eventual replacements will be fish enemies.

Open the deployed build with `?boss=1` and choose **Play Tethys Boss Test**. The ordinary URL still exercises PR #54's normal world, guardian and random-grunt encounters.

Browser-captured evidence from the exported build:

- [query-only title action](evidence/tethys-boss-title.png)
- [native-scale Tethys battle](evidence/tethys-boss-battle.png)

## Implemented for the validation build

- native imported scale and dedicated boss framing;
- provisional red materials because the delivered FBX contains no usable red material or texture;
- Swim Start → Swim Loop → Swim End → Idle entrance sequence;
- Double Scratch as two hits, pressuring the evasion pool;
- Tail Sweep as party-wide armour-piercing damage;
- Poison Breath as party-wide poison for three turns;
- playable provisional roles for Tail Slam, Tongue Slayer and Spinning Death;
- authored weak/strong hit reactions and death animation;
- deterministic six-move cycle so a reviewer can see every attack.

## Still requires Glassgoat's final art/design handoff

- a GLB with embedded red materials/textures, or the FBX plus its texture folder;
- confirmation that **Tethys** is the final display name;
- authoritative in-world scale beside the divers;
- final numbers and precise rules for the six attacks;
- the final-boss story trigger, arena, rewards and ending progression.

The red material and unspecified move roles are deliberately labelled provisional. The build proves that the rig, clips, combat integration and web path work without claiming unfinished art or balance is final.
