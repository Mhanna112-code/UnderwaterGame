# Early reward-rock discovery, October 5

Miguel identified that optional training does not make the first reward rocks
self-explanatory. The shipped brown rocks had no nearby switch/ability/reward
instruction. This is a contextual addition, not mandatory onboarding.

After the opening, an active diver within three metres of an intact loot rock
sees: "Break rocks for items: (TAB) Bucky, (F) Shockwave."
Selected Bucky sees: "Break this rock for items: (F) Shockwave."
The prompt applies consistently to reward rocks, including the first three;
it does not imply every scenery rock is breakable or every ambush grants loot.
Moving away, switching to a distant diver or breaking the rock restores normal
regional guidance. Deep/puzzle guidance keeps priority. No hint counter/save
migration or change to reward amounts, cooldowns or controls was introduced.

Bug-catalog-driven tests reproduced missing instructions and minimap occlusion
at 360x640. Real W/Tab/F, 36 generated proximity points, reward inventory gain,
consumed-state cold Title Load and three native viewport captures pass. Small
screens put the prompt below controls/minimap; frames inspected. Shallows,
local Deep/puzzle guidance and Marc's blockade arrow checks pass. An older
unfinished-Load test fixture was corrected to the actual World save contract,
not by weakening production validation. See verification catalog and evidence.

Runtime source: 17e4705cc4e90053f2cabd27b99a55180879329d.
Fresh Web pack: 93,317,092 bytes, SHA256
934713634cb34dfb9dc840688a65abd21ecf631c5072ab8c31e4112e28c26f27.
The immutable preview passed the hosted real Title Load/W/Tab/F approach,
break and swim-to-pickup flow with "Picked up a Potion" visible and no
captured script errors. Manual-slot coordinates and instant-pickup assumptions
in the observer were corrected; their failed receipts are preserved separately.
Native and browser frames inspected. Public delivery keeps the same URLs;
none of this claims a full fresh-opening/campaign or browser durability audit.

Published on main and both existing public/review URLs. Both actual hosted
PCK endpoints were downloaded and hashed against the source/bytes/SHA above;
they match the checked preview. Receipt: evidence/reward-rock-guidance/hosted-packs.jsonl.
