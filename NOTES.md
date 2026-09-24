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
