# Tethys boss validation

This PR build contains Glassgoat's `Mermaid_Freak.fbx` as **Tethys, the final boss**. It does not replace Goblin grunts; Glassgoat said their eventual replacements will be fish enemies.

Open the deployed build with `?boss=1` and choose **Play Tethys Boss Test**. The ordinary URL still exercises PR #54's normal world, guardian and random-grunt encounters.

Browser-captured evidence from the exported build:

- [query-only title action](evidence/tethys-boss-title.png)
- [native-scale, front-facing Tethys battle](evidence/tethys-boss-battle.png)
- [labelled non-humanoid animation reel](evidence/tethys-nonhumanoid-animation.gif) — the production battle camera plays the swim phases, all six attacks, both hit reactions and death.

## What “the 17 animations work” means

Godot imports all **17 raw takes**, but they are not 17 character motions:

- **13 character motions**: Idle; Swim Start/Loop/End; Poison Breath; Spinning Death; Double Scratch; Tail Slam; Tail Sweep; Strong Hit; Weak Hit; Death; Tongue Slayer.
- **4 deliberately excluded base/helper takes**: Base Pose, CameraAction, LightAction and Plane_032Action.

The verification gate samples the imported rig itself. Every one of the 13 character motions measurably changes the pose of the **311-bone Skeleton3D**, every sampled pose is distinct from the other motions, and the visible mesh carries a Skin bound to that same skeleton. The six attacks are additionally observed starting from `Battle._do_boss_turn()`, so the evidence covers production combat dispatch rather than a detached animation viewer.

## Implemented for the validation build

- native imported scale and dedicated boss framing;
- an engine-side saturated-red material because Godot exposes no usable surface material from the FBX; Glassgoat confirmed that the saturated red is intentional and the creature was designed for a very dark arena;
- model-specific +Z facing at encounter start and before every boss attack, rather than applying the humanoid/Goblin -Z convention and showing the boss's back;
- Swim Start → Swim Loop → Swim End → Idle entrance sequence;
- Double Scratch as two hits, pressuring the evasion pool;
- Tail Sweep as party-wide armour-piercing damage;
- Poison Breath as party-wide poison for three turns;
- playable provisional roles for Tail Slam, Tongue Slayer and Spinning Death;
- authored weak/strong hit reactions and death animation;
- deterministic six-move cycle so a reviewer can see every attack.

## Still requires final encounter design

- confirmation that **Tethys** is the final display name;
- authoritative in-world scale beside the divers;
- final numbers and precise rules for the six attacks;
- the dark broken-lab arena, lighting, close-up entrance, story trigger, rewards and ending progression.

The standalone title button remains an explicitly accepted animation-review route, not the final story entrance. The build proves that the rig, clips, facing, combat integration and web path work without claiming the eventual arena, lighting or balance is final.
