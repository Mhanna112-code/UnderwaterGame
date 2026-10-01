# Intro crawl readability bug catalog

## Scope

`game/intro_crawl.gd` presents the first-run narrative. Its public behavior is
that a line stays visible long enough to read on supported browser heights.

## Bugs

| ID | Failure mode | Blast radius | Test |
| --- | --- | --- | --- |
| CRAWL-1 | A fixed total scroll duration makes the narrative move too fast at ordinary browser height. | A first-time player cannot read the game’s opening premise. | Contract calculation at 720px. |
| CRAWL-2 | A pace tuned for a tall desktop viewport becomes unreadable in a shorter browser window. | Smaller laptop/browser windows regress while a single local capture still looks acceptable. | Contract calculation at 540px and 360px. |

## Skipped

- Exact font rendering and prose quality: visual/editorial concerns, not stable
  behavioral contracts.
- Click/E skip behavior: covered separately by `intro_crawl_click_skip_probe.gd`.
- Full rendered browser capture: required for PR evidence after export, but not
  reproducible by a headless timing calculation.
