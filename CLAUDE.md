# Geom Survivors: notes for Claude

A portrait, one-thumb survivors-like game for Android, built with Godot 4.7 (GL Compatibility). Everything is drawn in code as neon shapes. The README covers the design and how to build.

## Read first
- **`NOTES.md`** is the running session log. Read it before any balance, weapon or evolution work. It has a "Current weapons, upgrades and evolutions" reference, the latest playtest results and the open decisions. Add a new dated section, and update the reference, whenever a session changes balance or mechanics.

## Where the code lives
- `src/data/balance.gd`: every balance number (weapons, passives, resonance, overclocks, enemies, waves, events, depths).
- `src/weapons/*.gd`: weapon behavior. Each extends `weapon.gd`, and evolutions branch on `evo`, the key passive's id.
- `src/core/build.gd`: how passives, overclocks and resonance are applied (`apply_mods`), plus level-up offers and evolutions.
- `src/core/bullets.gd`: the player's projectiles and their special behaviors (the `F_*` flags).
- `src/core/enemies.gd`: enemies, boss attack patterns and hazards. `director.gd` handles spawning.
- `tests/autoplay.gd`: the headless test bot, including the balance tests (`bench=` modes, documented at the top of the file).

## Balance testing
- Run the game headless: `godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- <args>`
- Judge balance with realistic full runs (`bench=real start=360`, no god mode, 10+ seeds). Results vary a lot between seeds.
- Use the DPS tests (`mob`, `single`, `crowd`, `clear`) only for diagnosis. Some evolutions are built for defense or utility rather than damage, so similar damage numbers aren't the goal.
- After changing a weapon, run a quick `bench=single` on it to catch script errors. For example, a GDScript `:=` fails when the value's type is Variant.
