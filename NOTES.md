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

## Current weapons, upgrades and evolutions (as of 2026-09-25)

A snapshot of how everything works right now. The numbers live in `src/data/balance.gd`; the behavior lives in `src/weapons/*.gd`, `src/core/bullets.gd` (projectile flags) and `src/core/build.gd` (`apply_mods`). Update this section whenever balance changes.

### How stats are combined
- The final stats are the weapon's base values, plus its level-up changes, plus global bonuses from passives, overclocks and resonance (`Build.apply_mods`).
- Global bonuses of the same kind are added together, then applied once:
  - Damage: can't go below ×0.2.
  - Cooldown: can't go below ×0.35. Nothing fires faster than every 0.05s.
  - Area, speed and duration: added together, then multiplied in.
  - Count and pierce: flat bonuses.
- Resonance stacks on top:
  - VERTEX tier 1: +1 pierce.
  - ORBIT tier 1: +1 count.
  - PULSE tier 1: ×1.2 area.
  - CHAIN tier 1: +2 jumps.
- Special cases:
  - Fractal Shot's pierce is always set to 0.
  - Pulse Ring ignores bonus count from Sides and Hair Trigger.
- Crit is one global chance, rolled on every hit; a crit does ×2 damage. Anchor and Redline are multipliers checked on every hit.
- Knockback is fixed per weapon; nothing upgrades it.

### Passives (4 slots, each passive level adds the listed amount)
| Passive | Per level | Max | Tag | Key for (evolution) |
|---|---|---|---|---|
| Sides | +1 count (not Pulse Ring) | 2 | VERTEX | Star Burst, Polygon Cage, Minefield |
| Radius | +10% area | 5 | PULSE | Event Horizon, Shockwave, Supernova |
| Frequency | −7% cooldown | 5 | CHAIN | Metronome, Lighthouse, Tesla Grid |
| Velocity | +10% speed and duration | 5 | ORBIT | Railgun, Saturn, Ricochet Blade |
| Entropy | +6% crit | 5 | FRACTURE | Ricochet, Thunderstorm, Mandelbrot |
| Density | +10% damage | 5 | — | Prism, Guillotine, Singularity |
| Hull | +20 max HP, +0.25 HP/s regen | 5 | — | Aegis, Static Skin, Fortress |
| Magnet | +30% pickup range, +5% XP | 5 | — | Implosion, Möbius, Attractor |

Evolution rules:
- **When it's offered:** once a weapon reaches level 6 and its key passive is maxed, the evolution joins the level-up pool (weight 2.6).
- **Claiming:** evolving claims that passive, so the other two weapons keyed to it can't use it.
- **Banishing:** evolution cards can't be banished.

### Weapons: base stats, level-ups, level-6 totals, and what each stat does
Level-up changes are listed for levels 2 through 6. The level-6 totals exclude passives.

**Vertex Shot** (VERTEX; Triangle's starting weapon)
- Base: 10 damage, 0.7s cooldown, 1 shot, 1 pierce, speed 560, duration 1.1, knockback 60.
- Level-ups: +1 shot · +4 damage · −0.12s cooldown · +1 shot and +1 pierce · +6 damage and +1 shot.
- Level 6: 20 damage, 0.58s cooldown, 4 shots, 2 pierce.
- Stats: each shot aims at a different nearest enemy within 620px, and extras fan out. Area = triangle size (8px × area). Range = speed × duration.
- Evolutions:
  - **Star Burst** (Sides): doubles the final shot count, bonuses included.
  - **Railgun** (Velocity): shots pierce everything, fly ×2.2 faster, are ×1.5 bigger and do ×1.6 damage.
  - **Ricochet** (Entropy): each hit bounces the shot to the nearest other enemy within 280px. 2 bounces, +1 per crit (up to 10).

**Orbitals** (ORBIT; Circle's starting weapon)
- Base: 11 damage, 2 orbiters, spin 2.6, re-hit timer 0.3s, knockback 90.
- Level-ups: +1 orbiter · +4 damage and +15% area · +1 orbiter · +5 damage and +0.5 spin · +1 orbiter and +20% area.
- Level 6: 20 damage, 5 orbiters, area 1.35, spin 3.1.
- Stats:
  - Cooldown is how long before the same enemy can be hit again (min 0.12s), not a fire rate.
  - Area scales both the ring radius (88px × area) and the orbiter size (12px × area).
  - Speed is spin speed.
  - ORBIT resonance tier 2: once a second, every orbiter shoots a spark for 0.5× damage.
- Evolutions:
  - **Saturn** (Velocity): spins ×1.3 faster with ×1.3 orbiters, plus an outer ring of count+2 orbiters at 1.7× radius spinning the other way.
  - **Event Horizon** (Radius): ring ×1.25, orbiters ×1.6, ×1.25 damage. Pulls non-boss enemies within twice the ring radius toward the ring (strength 1000 ÷ mass).
  - **Aegis** (Hull): tight ring (×0.72), orbiters ×1.3, spins ×1.3 faster, ×1.5 damage, ×2 knockback. Orbiters destroy enemy bullets and heal 0.5 HP per bullet.

**Pulse Ring** (PULSE; Square's starting weapon)
- Base: 12 damage, 2.2s cooldown, 1 ring, speed 1.0, knockback 160.
- Level-ups: +5 damage · +20% area · −0.35s cooldown · +8 damage and +15% area · +1 ring.
- Level 6: 25 damage, 1.85s cooldown, 2 rings, area 1.35.
- Stats:
  - Maximum ring radius is 170px × area.
  - A ring reaches full size in 0.42s ÷ speed.
  - Each ring hits an enemy once. Extra rings follow 0.22s apart.
  - PULSE resonance tier 2 reverses the knockback into a pull.
- Evolutions:
  - **Shockwave** (Radius): ×1.5 damage and slows enemies it hits by 50% for 2s.
  - **Metronome** (Frequency): a beat every 0.45 × cooldown. Beats 1–3 are small rings (×0.75 radius, ×0.4 damage); every 4th is a big ring (×1.6 radius, ×2.2 damage, screen shake).
  - **Implosion** (Magnet): rings start at full size and collapse inward, doing ×1.8 damage and pulling enemies in. Each pulse also pulls in XP within 1.2 × ring radius.

**Line Laser** (VERTEX, PULSE)
- Base: 30 damage, 1.2s cooldown, 1 beam, knockback 30.
- Level-ups: +8 damage · −0.25s cooldown · +30% area · +1 beam · +14 damage.
- Level 6: 52 damage, 0.95s cooldown, 2 beams, area 1.3.
- Stats:
  - Beams are always 480px long; area only changes the width (10px × area).
  - The first beam targets the closest enemy and the others target random nearby enemies.
  - Beams hit everything along them, so pierce doesn't matter.
- Evolutions:
  - **Prism** (Density): every beam becomes a fan of 3 (±0.28 rad).
  - **Lighthouse** (Frequency): count beams stay on permanently and rotate at 2.4 rad/s. They're 400px long and 9px × area wide, and deal ×0.7 damage every 0.1s. Cooldown isn't used.
  - **Polygon Cage** (Sides): each cooldown, a polygon with 5 + count sides and radius 175px × area follows you for 1.4s. Its edges deal ×0.7 damage every 0.15s to enemies touching them.

**Chain Arc** (CHAIN)
- Base: 9 damage, 1.3s cooldown, 1 spark, 2 jumps, knockback 0 in practice (the listed 20 is never applied).
- Level-ups: +2 jumps · +5 damage · +1 spark · +2 jumps and −0.2s cooldown · +8 damage and +1 spark.
- Level 6: 22 damage, 1.1s cooldown, 3 sparks, 6 jumps.
- Stats:
  - Each spark starts at a nearby enemy within 420px, then jumps to the nearest enemy it hasn't hit within 150px (fixed; area doesn't change it).
  - Damage drops ×0.88 per jump.
  - If no enemy is in range, it tries again after 0.2s.
- Evolutions:
  - **Tesla Grid** (Frequency): no damage drop-off, 300px jumps, fires every 0.75 × cooldown.
  - **Thunderstorm** (Entropy): 2 + 2 × count bolts strike the enemies nearest you (within 0.8 × view radius). If there are fewer enemies than bolts, the closest are struck again. Each bolt has a 55px × area blast at ×0.8 damage, and a crit bolt also sends a 2-jump spark at ×0.6.
  - **Static Skin** (Hull): every 0.7 × cooldown, shocks up to 10 + 2 × jumps enemies within 210px × area for ×1.6 damage. Getting hit triggers a ×3.2 discharge (at most once every 0.4s).

**Rhombus** (VERTEX, ORBIT)
- Base: 14 damage, 1.8s cooldown, 1 rhombus, speed 480, duration 0.55, knockback 70.
- Level-ups: +6 damage · +1 rhombus · +25% area · +8 damage and −0.25s cooldown · +1 rhombus.
- Level 6: 28 damage, 1.55s cooldown, 3 rhombuses, area 1.25.
- Stats:
  - Flies out and gets pulled back with acceleration speed ÷ duration, so a longer duration throws further.
  - Pierces everything and forgets its hits when it turns around, so it can hit the same enemies on the way back. Lasts at most 6s.
  - Size is 14px × area.
- Evolutions:
  - **Möbius** (Magnet): ×1.4 size, flies out a second time after returning, and pulls in XP it passes.
  - **Ricochet Blade** (Velocity): doesn't return. Flies ×1.4 faster for 3.5s with ×1.4 damage, jumping to a new enemy within 280px on each hit (8 times, +1 per crit) and bouncing off the screen edges.
  - **Guillotine** (Density): one blade at ×0.55 speed and ×3.4 size, dealing ×(0.6 + 0.35 × count) damage. It re-hits everything it overlaps every 0.2s, with ×0.3 knockback.

**Square Grenades** (PULSE, FRACTURE; id `mines`)
- Base: 30 damage, 1.3s cooldown, 1 grenade, duration 8 (only used by Minefield), knockback 200.
- Level-ups: +12 damage · +1 grenade · +25% area · −0.3s cooldown and +12 damage · +1 grenade and +20% area.
- Level 6: 54 damage, 1.0s cooldown, 3 grenades, area 1.45.
- Stats:
  - Throws count grenades at the nearest enemies within 420px. They fly for 0.45s and explode on landing (85px × area blast).
  - With no enemy in range, it tries again after 0.2s.
  - PULSE resonance tier 2 turns the knockback into a pull.
- Evolutions:
  - **Fortress** (Hull): grenades land as turrets that last 6s and shoot the nearest enemy within 280px every 0.4s for ×0.7 damage. At most 4 + count turrets.
  - **Singularity** (Density): throws 1 grenade. On landing it pulls non-boss enemies within 230px × area for 0.7s, then explodes in a 170px × area blast for ×(1 + count) × 0.6 damage.
  - **Minefield** (Sides): stops throwing. While you move, drops a mine every 0.28 × cooldown ÷ 1.5 s (at least 0.12s), up to 26 mines, each lasting as long as its duration (8s). Mines arm after 0.5s, trigger at 26px, blast 80px × area, and set off nearby mines 0.12s later.

**Fractal Shot** (VERTEX, FRACTURE)
- Base: 18 damage, 1.4s cooldown, 1 shot, speed 340, duration 1.6, 1 split level, knockback 50.
- Level-ups: +6 damage · +1 split level · +1 shot · +8 damage and −0.2s cooldown · +1 split level.
- Level 6: 32 damage, 1.2s cooldown, 2 shots, 3 split levels.
- Stats:
  - On its first hit, a shot splits into 3 (±0.6 rad). Each split has ×0.7 damage, ×0.6 lifetime and ×0.72 size, and doesn't hit the same enemy again.
  - The "split levels" stat (`bounces` in the code) is how many times it keeps splitting.
- Evolutions:
  - **Mandelbrot** (Entropy): one extra split level, ×1.5 damage on the main shot, and every shot is a guaranteed crit.
  - **Supernova** (Radius): ×0.8 speed and ×1.5 damage. The shot grows 90% bigger per second as it flies, then explodes on its first hit or at the end of its life. The blast is 5× its current radius for ×2.2 damage, followed by 8 fragments at ×0.4.
  - **Attractor** (Magnet): a vortex that moves at 220, lasts 3s and deals ×1.3 damage at ×1.1 size. It homes on the nearest enemy within 320px, pulls non-boss enemies within 150px × size, and re-hits every 0.3s. When it ends, it splits into 3 + split-levels fractal shots at ×0.8 damage, which split further.

### Resonance (count items carrying the tag, weapons and passives alike; tier 1 at 2 items, tier 2 at 4)
| Tag | Tier 1 | Tier 2 |
|---|---|---|
| VERTEX | +1 pierce | VERTEX projectiles split into 2 shards on kill |
| ORBIT | +1 orbiter / rhombus | Orbiters fire a spark every second |
| PULSE | +20% area | PULSE hits pull instead of push |
| CHAIN | +2 jumps | Any hit has a 12% chance to arc |
| FRACTURE | Kills have a 12% chance to burst into 3 shards | 30% chance, and shard kills can burst again |

### Where each build stands
See the playtest table in the 2026-09-25 section above.
- **Too strong:** Metronome and Shockwave (Pulse Ring).
- **Strong:** Aegis (by outlasting enemies), Guillotine, Supernova, Star Burst, Ricochet.
- **Weak, and damage buffs didn't help:** Railgun, Attractor, Mandelbrot, Ricochet Blade, and the Line Laser family (Line Laser, Prism, Lighthouse, Polygon Cage). They need changes to how they control space.
