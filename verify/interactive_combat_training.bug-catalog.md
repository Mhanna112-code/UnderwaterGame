# Interactive combat training bug catalog

| ID | Regression to catch | Cheapest proving test |
| --- | --- | --- |
| INTERACTIVE-TRAINING-1 | Combat Help only exposes a static guide or the short opening replay, leaving the five-move lesson unreachable. | Instantiate the normal world menu and press the named training button. |
| INTERACTIVE-TRAINING-2 | The training button launches the compact opening profile instead of the five authored move stages. | Inspect the live `active_tutorial_script()` contract after opening battle. |
| INTERACTIVE-TRAINING-3 | Optional practice changes campaign HP, oxygen, or XP when it is ended. | Snapshot the party, end training, and compare restored values. |
