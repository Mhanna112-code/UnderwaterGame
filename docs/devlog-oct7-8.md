# Dev Log - October 7-8

These two days were about making combat **easier to read**, keeping **bosses and
Bleed fair**, giving players a **clearer sense of progress**, making the **maze's
final stretch** feel like an event, and polishing the **tutorials** so they stay
still and behave predictably. Each change is listed with what it does and why.

---

## Reading a fight at a glance

- **Move buttons list their effects** ("Damage; ACC +6", "Enemy DEF -3" in red,
  "Heal 10 HP (party)").
  *Why:* the old one-line descriptions ("Fast, reliable") didn't tell you what a move
  actually does. Short effect tags let you compare moves without opening tooltips.
- **Tooltips show your real numbers** ("Maxilani's STR (3) plus ACC (3), minus the
  target's DEF") and use short stat names.
  *Why:* it makes it obvious that damage follows your actual stats, and short names
  (STR, DEF) match the stat panels.
- **The yellow damage line shows one number: the damage you'll really deal.** It
  counts your Strength and the target's Defense. It appears when you hover a target,
  stays up during the attack, and clears when the turn ends.
  *Why:* working out power + STR - DEF in your head is a chore. One clear number
  beats a range.
- **A MISS sign appears between the stat panels when an attack can't hit.**
  *Why:* misses used to be invisible until the attack failed. Now you can see in
  advance that the enemy's Evasion is too high.
- **No more flicker when hovering targets.** The space for the yellow damage line is
  kept while you choose a target, so the buttons don't jump under the mouse.
  *Why:* the line appearing and disappearing resized the menu, which made it flicker.
- **A blinking red marker sits over the target you're hovering.**
  *Why:* with several enemies on screen it wasn't always clear which one a button
  meant.
- **"-0" and floor stats.** A stat that can't drop further shows "(-0)", and enemies
  that can't go below a base value show "(Floor Stat)". A hit for 0 shows "-0"
  instead of "ABSORBED", and the log says "DEF -0, it can't go any lower".
  *Why:* the old preview promised drops that never happened. Every number now
  matches what really lands.
- **Visual effects.** Red flash when hurt, green bubbles for healing, red arrows
  when a stat drops, green arrows for boosts, yellow flash for Stun, blood drops and
  a poison cloud when those tick, and small Bleed and Poison icons by the HP bars.
  *Why:* combat was mostly text. The effects show who was affected and how without
  reading the log.
- **Previews for items and heals.** Hovering a diver with a booster shows "+2" in
  green on their stats. Potions and heals show a green stretch on the HP bar. Revive
  shows the downed diver's card in grey with the HP it would restore.
  *Why:* you can see whether an item is worth using before you spend it.
- **Messages that tell the truth.** Missed stat moves say "You use Slow, but the
  Angler evades!", immune bosses say "Cordys is immune to Weaken", and items say
  "Used a Potion" instead of "Found a Potion".
  *Why:* each of these described something that hadn't happened.

## Bleed and statuses

- **Bleed amounts are flat:** the Angler's Bite applies 2, Scuba Stabbing applies 1.
  **Divers can't bleed more than 5 per turn.**
  *Why:* Bleed scaled with Strength and never wore off, so against 10-HP divers it was
  the deadliest thing in the game. Flat amounts and a cap keep it threatening, not
  fight-ending.
- **Going down clears every status.**
  *Why:* revived divers were coming back still bleeding and losing HP straight away.
- **Bleed and Poison tick after the diver has swum back to their spot** (or after an
  item's effect has shown).
  *Why:* the tick used to land in the middle of your own attack and looked like your
  move had hurt you.
- **Dev mode puts every status on random fights only,** never on bosses or puppets.
  *Why:* the dev statuses are for checking how statuses look, not for testing boss
  fights.

## Moves and items

- **Healing Current heals the whole party.**
  *Why:* Maxilani's only heal was a weaker version of Bucky's single-target one. A
  party heal gives her a clear role.
- **Move tuning:**
  - **Heavy Kick:** 8 power, +1 accuracy, 8 O2
  - **Heavy Slam:** 12 power, 10 O2
  - **Precise Jab:** +2 accuracy
  - **Weaken, Slow and their Empowered versions:** +1 accuracy (was +2)
  - **Current Snare:** lowers Evasion

  *Why:* to balance Bucky's options against each other, and to stop "near-unmissable"
  moves from making Evasion meaningless.
- **Teamwork against Cordys.** Musashi's Precise Jab (ACC 2 + 2 = 4) is dodged by
  Cordys, and that dodge spends 4 of his 5 Evasion, leaving 1. Bucky's Heavy Kick
  (ACC 1 + 1 = 2) then beats that 1 and connects. Cordys acts first each round, then
  Musashi, then Bucky, so both get their turn before his Evasion refills.
  *Why:* Bucky's low Accuracy means he rarely lands a hit on his own. This gives
  players a deliberate way to set him up.
- **Bucky learns Mending Current first** (level 2), then Heavy Slam (level 3).
  *Why:* a heal early on makes the party much more forgiving than a second heavy hit.
- **Items:**
  - Potion restores 10 HP; Attack Tonic and Defense Shell give +2.
  - Only one Attack Tonic *or* Defense Shell per battle (on top of the existing
    Focus Tonic / Slipstream Oil rule).
  - Item buttons show just "Heal 10 HP" or "DEF +2", with full details on hover.

  *Why:* stacking boosters trivialised fights, and the old descriptions were cut
  off on the buttons.
- **Single-target moves can target your own divers.**
  *Why:* more tactical freedom, and it lets testers check moves on any target.

## Bosses

- **Tethys and Cordys can heal themselves** (10% HP and remove Bleed) on 20% / 15% of
  their turns, and only when hurt.
  *Why:* with Bleed piling up, bosses melted. A chance to recover keeps the fights
  tense without making them a grind.
- **Cordys: +3 to every stat (Defense 4),** his two main attacks hit a little harder,
  and he can't be run from. His Defense was briefly lowered to 2 and is back to 4.
  *Why:* the final boss was weaker than some regular enemies.
- **Cordys hides in a cave until his puppets are beaten, then the camera pans over
  to show him coming out.**
  *Why:* it turns the puppet fight into a real step toward the finale, and gives the
  boss an entrance.
- **Cordys and his puppets are solid.** Bumping into them asks "A great danger is
  detected here…"
  *Why:* you could swim straight through them, and the question popped up from far
  away.
- **Puppet fight:** first wave at 9 HP each; it opens with "These enemies are guarding
  a nearby entity...", held long enough to read; the extra banners after it are gone.
  *Why:* the first wave was uneven (5-HP and 14-HP enemies mixed), the opening line
  flashed past, and leftover banners appeared at the wrong time.

## Special encounters

- **Maxilani's swap portraits move 1.5% faster.**
  *Why:* a slight speed-up to her minigame.

## Progress and levels

- **XP is visible:** a gold bar on each diver's battle card, an animated fill and
  LEVEL UP after wins, and Level / XP / Spell Points on the Spell Tree page.
  *Why:* players couldn't tell how close they were to their next spell.
- **Max level is 10, and you're told when a diver has unlocked everything.**
  *Why:* level 10 gives exactly enough points for the biggest spell tree, so there's
  a clear finish line.
- **Enemies give 20 XP** (was 10).
  *Why:* reaching the last spells took around 100 fights. Now it's about 50.

## Saving

- **Autosave right after beating Tethys and the puppets** (not Cordys, so the ending
  can still offer a replay of that fight).
  *Why:* losing a boss win to a crash or a later defeat is the worst kind of setback.
- **Every save message reads "Progress saved to Slot X."**
  *Why:* the old messages varied and didn't say where your progress went.
- **Game over: "Continue from Last Autosave"** shows, on hover, when that save was
  made and each diver's level and HP. Tooltips on the other options are gone.
  *Why:* it lets you decide which option to pick knowing exactly where you'll land.

## The world and maze

- **Whirlpools drop you just beside them, on the side you came from,** instead of
  back at a save point. The ones in the hall between the boss rooms deal 1 damage,
  and divers flash red when hurt.
  *Why:* being thrown back to a save point felt like a heavy punishment for a small
  mistake.
- **The hall's save point moved inside Cordys' room, next to the door.**
  *Why:* it gives players a save right before the final fight.
- **Distant labels disappear** beyond about 100 units instead of shrinking to specks.
  *Why:* far-away labels cluttered the screen without being readable.

## Tutorials

- **The opening Angler is slightly easier to hit,** so the first attack lands.
- **Missing is explained just before Bucky's Crushing Haymaker,** pointing at the MISS
  sign. That step also mentions the move's Oxygen cost.
- **The yellow damage line is explained on Musashi's Precise Tap turn.**

  *Why:* new players were told "this attack will miss" on their very first move,
  which was discouraging. Each idea is now introduced at the moment it matters.
- **Captions no longer bounce.**
  - The battle log used to reappear for a frame between caption pages, and on the
    first frame of a page opened right after an action (and on the QTE page). The
    whole panel grew and shrank, so the text jumped up and down. The log now stays
    hidden from the first frame of a page until the captions are done.
  - Red highlight boxes made a stat row 6 pixels taller only while showing, so the
    panel dipped between two highlighted pages. The border room is now always
    reserved.
  - In the special encounter, while its caption pages are up, only the caption,
    Continue and Skip Tutorial are shown and the panel holds its size. Longer pages
    use the freed space, and the panel only grows if a page truly doesn't fit. The
    first tutorial keeps everything visible because its pages point at the stat rows
    and buttons.

  *Why:* text you're reading should never move while you're reading it.
- **Skip Tutorial always ends on "Skipping the tutorial fight."** Skipping partway
  through a step (for example during Bucky's "Click the highlighted Angler to
  attack.") used to leave that step's instruction on screen. Now nothing from the
  interrupted step can come back, in both tutorials.
  *Why:* the screen should match what the button just did.
- **The Character Abilities pop-up only appears after your first tutorial fight,**
  not when you replay it from Combat Help. It's still available any time from the
  Esc menu.
  *Why:* a replay is for practising the fight, not for re-reading the introduction.

---

## Still open

- Some automated checks were already failing and still fail (the puppet fight, the
  campaign ending, the lab route, the prologue hand-off and a few tutorial layout
  checks). Their scripted runs need retuning for the new balance and layout.
- The "at least 1 damage" rule differs between newer and older moves. Whether to
  unify it is still to be decided.
