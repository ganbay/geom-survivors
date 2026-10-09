# Session notes

## 2026-09-24

**Slots**
- Weapon slots cut from 4 to 3. Passive slots stay at 4.

**Overclocks**
- They no longer appear in level-ups. Elites and the 5:00 and 10:00 bosses drop a core that offers 3 random overclocks, or **Vent Core** (a free level-up and a 30% heal).
- 8 new ones, 16 in total: Hair Trigger, Focus Lens, Redline, Bulwark, Resonator, Stasis Field, Last Stand, Volatile Matter.
- Fixed the double minus on cost lines ("− -30%").

**Evolutions**
- They're now level-up cards. Once a weapon and its key passive are both maxed, the evolution can show up, with about the same chance as upgrading a weapon you own.
- Evolution cards can't be banished.

**Bosses**
- Each slot picks one of two bosses at random:
  - 5:00: Tetragon Prime (three charges in a row) or **Pentarch** (mortars and bullet fans)
  - 10:00: Hexcore (creeping spiral) or **Octaprism** (sweeping lasers and teleports)
  - 15:00: The Polygon or **The Singularity** (gravity pull and a closing ring of bullets)
- A boss more than 420px away now speeds up to catch you. Before, only Tetragon could catch a kiting player.
- HP and speed changes: Pentarch 2300 HP, Octaprism 7000 HP, Hexcore speed 80. These were tuned only against the test bot, so they need testing by hand.
- Fixed the HUD boss name sometimes pointing at the wrong enemy.

**Testing**
- New test bot option: `boss=<id> bossnow=1` spawns a chosen boss straight away.
- 6 god-mode runs: every 5:00 boss died, and 3 of 6 runs were wins (the old code won 1 of 4).
- No script errors.

**Still open**
- Character look: suggested a bright white centre, a glow on the floor under the player and a motion trail. Waiting for a pick.

## 2026-09-25: weapon and evolution balance pass

Nothing from this session is committed yet. Code changes are in `src/weapons/*`, `src/data/balance.gd`, `src/core/bullets.gd`, `src/core/build.gd` and `tests/autoplay.gd`.

**Stat rules**
- Area no longer makes Line Laser beams longer (480px; Lighthouse 400px) or Chain Arc jumps longer (150px; Tesla Grid doubles it). Area still sets beam width, ring sizes, blast sizes, Polygon Cage size and Static Skin radius. The rule: fixed range unless an upgrade says it changes range.
- Pulse Ring ignores bonus count from Sides and Hair Trigger. Its own level-6 "+1 ring" still works.
- Speed now makes Pulse Ring expand faster (it has a base `speed` stat of 1.0).
- How each stat affects each weapon:
  - Orbitals: cooldown is the per-enemy re-hit timer (min 0.12s), not a fire rate.
  - Rhombus: range = speed²/(speed/duration).
  - Fractal Shot: pierce is always 0.
  - Chain Arc: damage drops 12% per jump.
  - Details are in the weapon scripts.

**Bug fixes**
- Rhombus now forgets its hits when it turns around, so the return pass can hit the same enemies again.
- Fast bullets can no longer pass through small enemies. When a bullet moves further in one frame than its radius plus 7px, it's tested against a circle covering the whole step (`bullets.gd`). This only affects Railgun.

**Weapon changes (final values)**
- Vertex Shot:
  - Cooldown 0.7s, starts with 1 pierce.
  - Railgun: normal volleys where every shot pierces infinitely, flies 2.2× faster, is 1.5× bigger and does 1.6× damage. The old single fused bolt is gone.
  - Star Burst: doubles the final shot count, bonuses included. The old ring of shots is gone.
- Orbitals:
  - Base damage 11 (was 8).
  - Event Horizon: ring 1.25× (was 1.5×), orbiters 1.6×, 1.25× damage, pull 1000.
- Pulse Ring:
  - Metronome: beats come every 0.45 × cooldown. Small pulses are 0.75× size at 0.4× damage; every 4th is a big ring at 1.6× size and 2.2× damage.
- Line Laser:
  - Damage 30 (was 16), cooldown 1.2s (was 1.6s).
  - Lighthouse and Polygon Cage beams do 0.7× damage.
- Chain Arc:
  - Base jumps 2 (was 3).
  - Tesla Grid fires 25% faster (was 30%).
  - Thunderstorm now strikes the enemies nearest the player; leftover bolts strike them again. Damage 0.8× (was 1.3×).
- Rhombus:
  - Ricochet Blade: jumps to a new enemy on each hit (8 times) plus screen-edge bounces, 1.4× damage.
- Square Mines → **Square Grenades**:
  - Lobs grenades at the nearest enemies (420px range, 0.45s flight), which explode on landing. Cooldown 1.3s.
  - Fortress: grenades land as turrets; at most 4 + count turrets, 0.7× damage.
  - Singularity: a thrown black hole that pulls for 0.7s, then detonates at (1 + count) × 0.6 damage.
  - Minefield: unchanged, leaves a trail of mines and doesn't throw.
- Fractal Shot:
  - Damage 18 (was 14). Split shots keep 70% of their parent's damage (was 60%).
  - Mandelbrot: the main shot also always crits and does 1.5× damage.
  - Attractor: 1.3× damage, 220 speed, 1.1× size, 3s life.

**Test harness** (`tests/autoplay.gd`, `bench=` with `evo=weapon:passive`, where passive `-` means the base weapon at max level)
- `mob`: 150 dots kept topped up, HP as at the `start` time. Scores kills/s.
- `single`: one boss-sized, armorless dummy that can't die and circles at 80–240px. Scores DPS.
- `crowd targets=N`: N normal-sized dummies that can't die. Scores DPS.
- `clear`: 200 enemies from the wave mix plus Tetragon and Pentarch, god mode, with a bot that hunts enemies. Scores time until everything is dead.
- `real start=360`: the main playtest.
  - Setup: plays Circle and starts at 6:00 at level 20 with the weapon evolved, the key passive maxed and three filler passives (Density, Hull, Frequency) at level 3. Base-weapon rows get Density maxed instead.
  - Play: no god mode. The bot levels only that weapon, fights at the weapon's range, dodges bullets and blasts, and rides the gaps between Octaprism's beams. It always vents cores instead of taking overclocks.
  - The 10:00 boss is forced to Hexcore (see below).
- Command for one run: `godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- char=circle evo=mines:hull bench=real seed=1 start=360`
- Runs vary a lot from seed to seed (about ±115s survival). Use at least 10 seeds.

**Playtest results** (`bench=real`, 10 seeds per build, after tuning)

| Build | Survival | Reached 15:00 | Won |
|---|---|---|---|
| Metronome | 22:11 | 100% | 80% |
| Aegis | 21:23 | 90% | 60% |
| Shockwave | 20:55 | 100% | 70% |
| Ricochet (Vertex) | 18:52 | 90% | 10% |
| Supernova | 17:32 | 90% | 10% |
| Guillotine | 17:18 | 100% | 40% |
| Star Burst | 16:40 | 60% | 40% |
| Event Horizon | 16:01 | 50% | 0% |
| Möbius | 16:01 | 50% | 0% |
| Saturn | 15:44 | 80% | 0% |
| Vertex Shot base | 15:23 | 90% | 0% |
| Grenades base | 15:22 | 40% | 20% |
| Implosion | 15:07 | 70% | 0% |
| Minefield | 14:43 | 60% | 0% |
| Static Skin | 14:37 | 20% | 0% |
| Rhombus base | 14:34 | 60% | 0% |
| Fractal Shot base | 13:55 | 50% | 0% |
| Pulse Ring base | 13:47 | 30% | 0% |
| Fortress | 13:45 | 20% | 0% |
| Chain Arc base | 13:29 | 10% | 0% |
| Singularity | 13:07 | 0% | 0% |
| Thunderstorm | 13:04 | 30% | 0% |
| Lighthouse | 12:57 | 0% | 0% |
| Tesla Grid | 12:36 | 10% | 0% |
| Ricochet Blade | 12:17 | 0% | 0% |
| Prism | 12:16 | 10% | 0% |
| Orbitals base | 12:01 | 20% | 0% |
| Polygon Cage | 11:48 | 0% | 0% |
| Mandelbrot | 11:28 | 0% | 0% |
| Line Laser base | 10:50 | 0% | 0% |
| Railgun | 10:30 | 0% | 0% |
| Attractor | 10:22 | 0% | 0% |

**What the results show**
- Pulse Ring's evolutions (Metronome, Shockwave) are probably too strong. Push-back plus slow means they take almost no damage.
- Railgun, Attractor, Mandelbrot, Ricochet Blade and the Line Laser family barely improved even with +40–60% damage. They get overrun around 10:00 (250+ enemies when Hexcore arrives). They need changes to how they control space, such as knockback, slows, or aiming split shots at nearby enemies, not bigger numbers.
- Evolutions whose key passive adds no damage (Velocity for Railgun and Ricochet Blade, Magnet for Attractor) start behind the base weapon, which gets Density's +50% damage in that slot instead.
- Aegis wins by outlasting enemies rather than out-damaging them. That fits its role.

**Still open**
- **Octaprism may be overtuned.** When the bot faced it at 10:00, it died within about 15s almost every time, even while sitting in the gap between the beams. Its bullet rings plus the horde overwhelmed it. Needs testing by hand. That's why the 10:00 boss is forced to Hexcore in `bench=real`.
- Decide next: redesign the builds that ignored damage buffs, or tone down Metronome and Shockwave.
- Line Laser's level-4 "+30% area" upgrade now only makes beams wider.
- The playtest bot uses one weapon and plays worse than a person. Compare builds by ranking, not by absolute win rate.

## 2026-10-09: one-weapon overhaul (branch `overhaul/one-weapon`)

Everything above this section describes the old multi-weapon game and is kept as history.

**What changed**
- **One weapon per character.** Triangle: Vertex Shot. Square: Rods (the reworked Orbitals). Circle: Pulse Ring. Spark (new, lightning-bolt shape): Chain Arc.
- **Removed:** Line Laser, Rhombus, Square Grenades and Fractal Shot, the weapon slots, tags and resonance, passive-keyed evolutions, the Sides passive and the Resonator overclock.
- **10-level trees.** The weapon and each passive have 10 levels. Weapon levels 4, 7 and 10 and passive levels 5 and 10 are milestones: taking that level opens a second picker with 2–3 options. The weapon's level-10 option is its new form (the old evolutions where they still fit).
- **Damage formula:** `(weapon damage × k × attack damage × crit damage + bonus damage × k) × damage multiplier`. The hit is rolled when it lands, not when it's fired.
- **Cooldown:** reductions multiply (−10% twice is ×0.81).
- **Attacks come from the pointy part.** Triangle turns to face its target and shoots from the tip; Square's rods grow from its corners and its body spins with them; Spark's arcs leave the nearer tip.
- **Colors.** Each character has one color (red, green, blue, yellow) used for its body, attacks, XP gems and UI accent. All enemies, enemy bullets and danger markers are violet to magenta. Heals are white.
- **Overclocks:** 21 now. Glass Core is a damage multiplier; six new ones; an overclock can be limited to the weapons it works for.
- **Save:** run history from before the overhaul is cleared once (save version 2). Best times and depth unlocks are kept.
- **Test bot:** `evo=<weapon>:<path>`, where the path is the options taken at levels 4, 7 and 10 (`a-b-c`).

**Choices made while building it (worth a second look)**
- **k, the sub-hit factor.** Weak secondary hits (Metronome's small beats, later chain jumps, shards, kill blasts) scale bonus damage by the same factor as weapon damage. Otherwise flat bonus damage would be worth far more on them than on a normal hit.
- **Rods and cooldown.** Rods hit an enemy once per pass, so a re-hit timer did nothing. Cooldown reduction now shortens the sweep (rods spin faster), which makes it the same effect as spin speed for this weapon.
- **Rods count hits as attacks** for "every Nth attack" effects (Double Tap, Overcharge), because they never fire.
- **Deadeye** got "crits ricochet to another enemy" (up to 3 per shot) on top of its stats, so level 10 changes how it plays.
- **Velocity level 5** offers move speed as its second option instead of "+1 pierce / +1 jump", which did nothing for Square and Circle.
- **Secondary damage never triggers kill effects.** Shards, arcs, kill blasts and shocks can't set each other off.

**Still open**
- **Pacing.** The weapon is offered at the same weight as before, so a player who always takes it reaches level 10 around 3:00. The bot ended a 20-minute win at level 39; a full build needs 49 level-ups.
- **Nothing is balanced yet.** The numbers are a first draft; see the baseline below.
- **Red vs. magenta.** Triangle's red is the closest player color to the enemy band. Swap to cyan if it reads badly on a phone.
- **Octaprism** is still untested by hand; the bot still forces Hexcore at 10:00.


## Current characters, weapons and upgrades (as of 2026-10-09)

A snapshot of how everything works right now. The numbers live in `src/data/balance.gd`; the behavior lives in `src/weapons/*.gd`, `src/core/build.gd` (`recompute`, `roll_hit`) and `src/core/game.gd` (kill and hit effects). Update this section whenever balance changes.

### How a hit is computed
`hit = (weapon damage × k × attack damage × crit damage + bonus damage × k) × damage multiplier`
- **Weapon damage:** the weapon's base damage plus every "+N weapon damage" (never below 1).
- **Attack damage:** 1 + every "+x% damage" (never below ×0.2).
- **Crit damage:** only on a crit. ×2.0 plus every "+x% crit damage". Crit chance is the character's plus upgrades.
- **Bonus damage:** flat, not scaled by attack damage or crit.
- **Damage multiplier:** 1 + Glass Core, plus Anchor (standing still), Redline (below 50% HP), Slipstream and Running Start (moving), Bloodlust (5s after every 100 kills). Read when the hit lands.
- **k:** 1 for a normal hit. Lower for weak secondary hits, ×2 on an Overcharge attack.
- Enemy armor is subtracted afterwards.

Other rules:
- **Cooldown:** base × (1 + step) for every step. Floor 0.05s.
- **Area, speed, knockback, width:** added together, then multiplied in (never below ×0.3).
- **What each stat means per weapon:**

| Stat | Vertex Shot | Rods | Pulse Ring | Chain Arc |
|---|---|---|---|---|
| count | projectiles | rods | rings | sparks |
| area | projectile size | rod length | ring size | targeting range, blast size |
| speed | projectile speed and range | spin | ring expansion | jump range |
| cooldown | time between volleys | sweep time (spin) | time between pulses | time between sparks |

### Characters
| Character | Color | HP | Speed | Armor | Crit | Pickup | Weapon |
|---|---|---|---|---|---|---|---|
| Triangle | red | 80 | 235 | 0 | 10% | 90 | Vertex Shot |
| Square | green | 130 | 185 | 2 | 0 | 80 | Rods |
| Circle | blue | 100 | 205 | 0 | 0 | 135 | Pulse Ring |
| Spark | yellow | 90 | 215 | 0 | 5% | 100 | Chain Arc |

### Weapons
Levels 4, 7 and 10 are pick-one. "WD" is weapon damage.

**Vertex Shot** (Triangle)
- Base: 10 damage, 0.7s cooldown, 1 shot, 1 pierce, speed 560, flies 1.1s, knockback 60. Each shot aims at a different nearest enemy within 620px; extras fan out.
- 2: +1 projectile · 3: +20% speed, +5 WD
- **4:** Volley (+2 projectiles, −5 WD) / High Velocity (+30% speed, +5 WD) / Keen Edge (+10% crit, +20% crit damage)
- 5: −10% cooldown · 6: +1 projectile, +1 pierce
- **7:** Rapid Fire (−10% cooldown, +1 projectile, +1 pierce) / Heavy Shot (+7 WD, +30% damage, +30% size) / Precision (+10% crit, +30% crit damage, +1 pierce)
- 8: +20% speed, +20% size · 9: −10% cooldown
- **10:**
  - **Focus Fire:** every shot aims at the closest enemy in a tight fan. +2 pierce.
  - **Star Burst:** doubles the projectile count. +20 bonus damage, −5 WD.
  - **Deadeye:** crits ricochet to another enemy within 280px (3 per shot). +10 WD, +10% crit, +50% crit damage, −10% cooldown.

**Rods** (Square; id `orbitals`)
- Base: 11 damage, 2 rods, 90px long, 7px half-width, spin 2.6 rad/s, knockback 90. Rods sit on the corners (opposite ones first), then on edge midpoints from the fifth. Each rod hits everything along it once per pass.
- 2: +1 rod · 3: +20% length, +4 WD
- **4:** Extra Rod (+1 rod, −3 WD) / Flywheel (+25% spin, +5 WD) / Long Reach (+25% length, +20% width)
- 5: −10% sweep time · 6: +1 rod, +10% length
- **7:** Buzzsaw (−10% sweep time, +20% spin) / Heavy Rods (+7 WD, +30% damage, +30% width) / Battering Ram (+40% knockback, +20% length, +10 bonus)
- 8: +20% spin, +15% length · 9: −10% sweep time
- **10:**
  - **Saturn:** a second set of rods floats from 1.1× to 1.8× reach and spins the other way at 0.8× speed.
  - **Aegis:** rods ×0.75 length, k 1.5, double knockback. Rods destroy enemy bullets and heal 0.5 HP per bullet.
  - **Event Horizon:** +25% length. Non-boss enemies within 1.8× reach are dragged in to 0.6× reach.

**Pulse Ring** (Circle)
- Base: 12 damage, 2.2s cooldown, 1 ring, 170px, full size in 0.42s, knockback 160. A ring hits each enemy once; extra rings follow 0.22s apart.
- 2: +5 WD · 3: +20% size
- **4:** Quick Pulse (−15% cooldown) / Wide Band (+25% size, +20% ring speed) / Hard Pulse (+6 WD, +40% knockback)
- 5: −10% cooldown · 6: +1 ring
- **7:** Steady Beat (−10% cooldown, +15% size) / Amplitude (+8 WD, +30% damage) / Sharp Wave (+10% crit, +30% crit damage)
- 8: +20% size, +5 WD · 9: −10% cooldown
- **10:**
  - **Shockwave:** k 1.5, and slows enemies it hits by 50% for 2s.
  - **Metronome:** a beat every 0.45 × cooldown. Beats 1–3 are small rings (×0.75 size, k 0.4); every 4th is big (×1.6 size, k 2.2).
  - **Implosion:** rings start at full size and collapse inward at k 1.8, pulling enemies in and collecting XP within 1.2× ring size.

**Chain Arc** (Spark)
- Base: 9 damage, 1.3s cooldown, 1 spark, 2 jumps, knockback 20. A spark starts at a nearest enemy within 420px × area, then jumps to the nearest unhit enemy within 150px × speed. Each jump loses 12%.
- 2: +2 jumps · 3: +5 WD, +15% jump range
- **4:** Fork (+1 spark, −3 WD) / Long Chain (+2 jumps, +5 WD) / Live Wire (+10% crit, +20% crit damage)
- 5: −10% cooldown · 6: +1 spark, +1 jump
- **7:** Overload (−10% cooldown, +1 spark) / Conductor (+7 WD, +30% damage, jumps lose 6%) / Far Reach (+30% jump range, +2 jumps, +10 bonus)
- 8: +2 jumps, +20% jump range · 9: −10% cooldown
- **10:**
  - **Tesla Grid:** no loss per jump, double jump range, fires every 0.75 × cooldown.
  - **Thunderstorm:** 2 + 2 × sparks bolts on the enemies nearest you (within 0.8 × view radius), each a 55px × area blast at k 0.8. A crit bolt also sends a 2-jump spark at k 0.6.
  - **Static Skin:** every 0.7 × cooldown, shocks up to 10 + 2 × jumps enemies within 210px × area at k 1.6. Getting hit triggers a k 3.2 discharge (at most every 0.4s).

### Passives (pick 4 of 8, 10 levels each)
| Passive | Levels 1–4 | Level 5 (pick one) | Levels 6–9 | Level 10 (pick one) |
|---|---|---|---|---|
| Damage | +10% damage | Power: +30% damage / Payload: +10 bonus | +20% damage | Overwhelm: +50% damage / Warhead: +20 bonus / Bloodlust: every 100 kills, +30% all damage for 5s |
| Cooldown | −5% | Tempo: −9% / Quickstep: −5%, +8% move speed | −5% | Frenzy: −12% / Double Tap: −6%, every 5th attack fires twice / Adrenaline: −30% for 3s after being hit |
| Critical | +5% chance | Sharp Eye: +7% chance / Brutality: +40% crit damage | +25% crit damage | Devastate: +75% crit damage / Marksman: +10% chance / Arc Crits: crits arc for 50% of the hit |
| Area | +8% | Expanse: +15% / Impact: +8%, +20% knockback | +8% | Vastness: +25% / Undertow: +10%, hits pull instead of push / Chain Reaction: kills explode 15% of the time |
| Velocity | +8% speed | Rush: +15% / Stride: +8%, +5% move speed | +8% | Hypersonic: +25% / Splinter: kills throw 2 shards / Tailwind: +10%, +10% move speed |
| Hull | +15 max HP, +0.2 HP/s | Bulk: +40 HP / Plating: +1.5 armor | same as 1–4 | Colossus: +60 HP / Bastion: +3 armor / Reactive Plating: being hit shocks enemies within 200px at k 3 |
| Magnet | +20% pickup range, +3% XP | Long Arm: +40% range / Scholar: +10% XP | same as 1–4 | Savant: +15% XP / Vacuum: pulls all XP on screen every 30s / Recycler: XP pickups heal 0.2 HP |
| Agility | +3% move speed | Sprint: +6% / Afterimage: +0.1s invulnerability after a hit | +3% | Dash: +10% / Running Start: +20% all damage while moving / Blur: 10% chance to dodge a hit |

- Only passives can be banished.
- Secondary hit sizes: shards k 0.5, kill blasts k 0.6 (70px × area), arcs half of the hit that caused them.

### Overclocks (from cores only, one of each per run)
| Overclock | Gives | Costs |
|---|---|---|
| Glass Core | +30% all damage | −30% max HP |
| Heavy Field | +35% area | −12% move speed |
| Overdrive | −22% cooldown | Take +25% damage |
| Greed Lattice | +35% XP, +50% pickup range | Enemies +15% HP |
| Tunnel Vision (Vertex Shot only) | +2 pierce, +20% damage | One fewer level-up option |
| Anchor | +60% all damage while standing still | −10% move speed |
| Momentum | +25% move speed | −15% damage |
| Siphon | Kills heal 0.4 HP | No heal drops or regen |
| Hair Trigger (not Pulse Ring) | +1 projectile / rod / spark | −20% damage |
| Focus Lens | +20% crit chance | −15% area |
| Redline | +60% all damage below 50% HP | Healing halved |
| Bulwark | +4 armor, +30 max HP | +20% cooldown |
| Stasis Field | Enemies 15% slower | −20% speed stat |
| Last Stand | Survive one lethal hit at 50% HP | −25% max HP |
| Volatile Matter | Kills explode 25% of the time | Enemies deal +15% damage |
| Heavy Rounds (new) | +15 bonus damage | +15% cooldown |
| Executioner (new) | +100% crit damage | −10% crit chance |
| Fracture Core (new) | Kills burst into 3 shards 20% of the time | Enemies +10% HP |
| Arc Coil (new) | Hits arc to a nearby enemy 12% of the time | −10% damage |
| Slipstream (new) | +30% all damage while moving | −15% all damage while standing still |
| Overcharge (new) | Every 4th attack deals double | +10% cooldown |

### Where each build stands
See the baseline table in the 2026-10-09 section. Nothing has been tuned since the overhaul.
