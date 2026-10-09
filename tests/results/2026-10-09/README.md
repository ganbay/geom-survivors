# Raw bot results, 2026-10-09

One line per bot game, as printed by `tests/autoplay.gd`. The summaries and what they mean are in `NOTES.md` under the pass with the same number.

| File | What it is |
|---|---|
| `pass3_generic_from_6min.txt` | `evo=<weapon>:<path> bench=real start=360`, 10 seeds per path, generic passives. Before the Pulse Ring 10 damage / Rods length buffs. |
| `pass3_dps.txt` | `bench=single` and `bench=mob`, 60s at 8:00, weapon alone. Same game state as above. |
| `pass4_builds_from_6min.txt`, `pass4_builds_from_0min.txt` | `build=<form> bench=real`, 10 seeds per form, from 6:00 and from 0:00. Same game state as pass 3. |
| `pass6_builds_from_6min.txt`, `pass6_builds_from_0min.txt` | The same test after the fifth- and sixth-pass changes (commit `e36d079`), with three bot builds reordered. |
| `pass6_dps.txt` | `bench=single` and `bench=mob` at commit `e36d079`. |

Reading a `REAL` line: path, form, result, `time` = seconds survived (a win ends when the final boss dies), `lvl` = player level, `evo` = when the level-10 form was taken, `taken` = damage taken, then the passives and the bosses faced.

The first baseline (before the second-pass weapon changes) was not kept; its table is in `NOTES.md`.
