# Geom Survivors

A portrait, one-thumb survivors-like roguelite for Android, built with Godot 4.7. Every visual is a neon geometric shape generated in code.

## Run it

Open the project in Godot 4.7 and press F5, or run `godot --path .`. Drag anywhere to move (mouse or touch). WASD and the arrow keys also work. Esc pauses.

## Design at a glance

- 15-minute runs with bosses at 5:00, 10:00 and 15:00. Each slot picks one of two bosses at random, and each boss has its own attack pattern: Tetragon Prime or Pentarch, then Hexcore or Octaprism, then The Polygon or The Singularity.
- 3 characters (Triangle, Square, Circle), 8 weapons, 8 passives.
- 3 weapon slots and 4 passive slots.
- **Resonance:** items carry tags (VERTEX, ORBIT, PULSE, CHAIN, FRACTURE). Holding 2 or 4 items with the same tag unlocks bonuses.
- **Evolutions:** each weapon has 3 evolutions, each keyed by a different passive, 24 in total. Once a weapon and its key passive are both at max level, the evolution can show up as a level-up card. Evolving *claims* that passive, so no other weapon can use it.
- **Overclocks:** 16 strong bonuses, each with a permanent drawback. Elites and bosses drop a core that offers 3 of them; you can also vent the core for a free level-up and a 30% heal.
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
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- evo=orbitals:radius start=420 seconds=90 stand=1
godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- boss=boss_prism bossnow=1 god=1 seconds=60
```

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
