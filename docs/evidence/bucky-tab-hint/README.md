# Bucky wall hint: TAB switching key

Gameplay source: `a4c24455775d6eb0d967e526062726d47a68bc10`.

User-reported missing control hint repaired with this exact displayed copy:
`Use Bucky's Shockwave to break the wall. (TAB)`.
Only the text changes; proximity, active-diver selection, ability, wall
destruction and consumed-wall save/load remain unchanged.

- `red.log`: existing real puzzle approach fails OPEN-049 without the key.
- `narrow.log` / `wide.log`: same approach, real Tab/E Shockwave, departure,
  destroyed-wall prompt retirement and save/load pass. Native 720x480 and
  1280x720 screenshots inspected; copy fits without clipping or minimap overlap.
- Existing browser guidance gate also requires the rendered parenthesized key.
  It uses an isolated recovered-checkpoint position fixture, normal title Load,
  actual movement/Tab/E and OCR, not a forced wall-destruction signal.

Hosted focused verification passed with zero errors; OCR confirms `(TAB)` at
actual puzzle contact and return. Real Tab/E breaks the wall and restores
Shallows text. See `browser/result.json`, screenshots and run log.

Published to the same https://underwatergame-opening-prologue-review.vercel.app/
alias, deployment `dpl_5GtyyDdbeRPWUnKeMzaWCQyGwKCB` (READY).
PCK: 104,161,224 bytes. SHA-256:
`662f76afbcb8890ea3c965a5f0948c63191c7143418aa979edec287f59cae581`.
Hosted download matches export. Main remains on
`dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`. No complete opening replay is claimed for this
text-only change; the full opening was verified on its preceding gameplay build.
