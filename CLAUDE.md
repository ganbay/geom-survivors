# Geom Survivors: notes for Claude

A portrait, one-thumb survivors-like game for Android, built with Godot 4.7 (GL Compatibility). Everything is drawn in code as neon shapes. The README covers the design and how to build.

## Read first
- **`NOTES.md`** is the running session log. Read it before any balance, weapon or upgrade work. It has a "Current characters, weapons and upgrades" reference, the latest playtest results and the open decisions. Add a new dated section, and update the reference, whenever a session changes balance or mechanics. Sections dated before 2026-10-09 describe the old multi-weapon game.

## Where the code lives
- `src/data/balance.gd`: every balance number (characters, weapon and passive upgrade trees, overclocks, enemies, waves, events, depths), the palette and the damage formula.
- `src/weapons/*.gd`: weapon behavior, one per character. Each extends `weapon.gd` and branches on `evo`, the form picked at level 10.
- `src/core/build.gd`: the stat sheet summed from weapon levels, passives, milestone picks and overclocks (`recompute`), the hit roll (`roll_hit`, `strike`) and level-up offers.
- `src/core/bullets.gd`: the player's projectiles.
- `src/core/enemies.gd`: enemies, boss attack patterns and hazards. `director.gd` handles spawning.
- `tests/autoplay.gd`: the headless test bot, including the balance tests (`bench=` modes, documented at the top of the file).

## Balance testing
- Run the game headless: `godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- <args>`
- `evo=<weapon>:<path>` picks the character and the options taken at weapon levels 4, 7 and 10, for example `evo=orbitals:a-b-c`.
- Judge balance with realistic full runs (`bench=real start=360`, no god mode, 10+ seeds). Results vary a lot between seeds.
- Use the DPS tests (`mob`, `single`, `crowd`, `clear`) only for diagnosis. Some level-10 forms are built for defense or utility rather than damage, so similar damage numbers aren't the goal.
- After changing a weapon, run a quick `bench=single` on it to catch script errors. For example, a GDScript `:=` fails when the value's type is Variant.
