# Geom Survivors

A portrait, one-thumb survivors-like roguelite for Android, built with Godot 4.7. Every visual is a neon geometric shape generated in code.

## Run it

Open the project in Godot 4.7 and press F5, or run `godot --path .`. Drag anywhere to move (mouse or touch). WASD and the arrow keys also work. Esc pauses.

## Design at a glance

- 15-minute runs with bosses at 5:00, 10:00 and 15:00. Each slot picks one of two bosses at random, and each boss has its own attack pattern: Tetragon Prime or Pentarch, then Hexcore or Octaprism, then The Polygon or The Singularity.
- **One weapon per character.** Triangle fires Vertex Shot from its tip, Square sweeps Rods from its corners, Circle emits Pulse Rings, and Spark throws Chain Arcs from its tips.
- **Color-coded sides.** Each character owns one color (red, green, blue, yellow) for its body, attacks, XP and HUD. Everything hostile is violet to magenta.
- **10-level upgrade trees.** The weapon and each passive have 10 levels. Weapon levels 4, 7 and 10 and passive levels 5 and 10 are milestones where you pick one of several options; the weapon's level-10 pick changes how it works.
- 8 passives, 4 passive slots.
- **Damage:** `(weapon damage × attack damage × crit damage + bonus damage) × damage multiplier`. Cooldown reductions multiply together.
- **Overclocks:** 21 strong bonuses, each with a permanent drawback. Elites and bosses drop a core that offers 3 of them; you can also vent the core for a free level-up and a 30% heal.
- **No permanent power progression.** Winning only unlocks the next Depth (0–10), which adds a stacking difficulty modifier.

## Tuning and assets

- All balance numbers live in `src/data/balance.gd`.
- Drop-in assets (they override the synthesized placeholders automatically):
  - Font: `assets/font.ttf`
  - Music: `audio/music/menu.ogg` and `audio/music/run.ogg`
  - Sound effects: `audio/sfx/<name>.ogg`, where `<name>` is one of: shoot, hit, kill, xp, level, evolve, hurt, pulse, laser, zap, boom, boss, dash, heal, magnet, click, select, gameover, win

## Balance test bot

```sh
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- char=triangle seed=3 seconds=900
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- evo=orbitals:a-b-c bench=single start=420 seconds=60
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- boss=boss_prism bossnow=1 god=1 seconds=60
```

`evo=<weapon>:<path>` fixes the options taken at weapon levels 4, 7 and 10 (`a-b-c`). Balance tests: `bench=real start=360` plays a realistic run from 6:00 with the weapon in its level-10 form. `bench=mob|single|crowd|clear` measure raw damage and clear speed. See the top of `tests/autoplay.gd` and `NOTES.md`.

The bot never writes to the player's save file.

## Android

The `Android` export preset is included. Building needs the Android SDK (platform-tools and build-tools) configured in Godot's Editor Settings.

Debug APK (signed with Godot's debug keystore, arm64 + armv7):

```sh
godot --headless --export-debug "Android" build/GeomSurvivors-debug.apk
adb install -r build/GeomSurvivors-debug.apk
adb logcat -s godot   # script errors and prints
```

Bump `version/code` in `export_presets.cfg` for each build you hand out, so Android treats it as an update.
