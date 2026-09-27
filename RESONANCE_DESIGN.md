# Design problem: resonance tiers that can't be reached (2026-09-27)

Found while reviewing how weapons and resonance synergize. Nothing has been changed yet; this is the open problem and the options.

## The problem

Resonance counts every weapon and passive that carries a tag (`Build.count_tags`). Tier 1 needs 2 items and tier 2 needs 4 (`RESONANCE_THRESHOLDS := [2, 4]`). A build holds at most 3 weapons (`MAX_WEAPONS`) and 4 passives.

Counting every item in the game that carries each tag:

| Tag | Items with the tag | Max count | Tier 2 reachable? |
|---|---|---|---|
| VERTEX | Vertex Shot, Line Laser, Rhombus, Fractal Shot, Sides | 4 (3 weapons + Sides) | Yes |
| PULSE | Pulse Ring, Line Laser, Square Grenades, Radius | 4 (exactly) | Yes, with only one exact build |
| ORBIT | Orbitals, Rhombus, Velocity | 3 | Only with the Resonator overclock |
| FRACTURE | Square Grenades, Fractal Shot, Entropy | 3 | Only with the Resonator overclock |
| CHAIN | Chain Arc, Frequency | 2 | **Never** (Resonator only brings it to 3) |

The Resonator overclock adds +1 to every tag you hold. It only drops from cores, so ORBIT and FRACTURE tier 2 depend on luck. CHAIN tier 2 ("any hit has a 12% chance to arc") is dead content.

## Tier effects that do nothing on some tagged weapons

Tier 1 only affects weapons that carry the tag (`Build.apply_mods`). Some combinations have no effect:

- **VERTEX tier 1** (+1 pierce) does nothing for Line Laser (beams already hit everything) or Fractal Shot (its pierce is forced to 0).
- **VERTEX tier 2** (split on kill) doesn't apply to Line Laser, because beams aren't projectiles.
- **PULSE tier 2** (pull instead of push) doesn't apply to Line Laser, because lasers have no push or pull.
- **ORBIT tier 2** (sparks) only affects Orbitals, not Rhombus.

Line Laser is already one of the weak families (see NOTES.md). It also gets the least out of both of its tags.

## Options for CHAIN

The code allows any number of tags on weapons and passives, so each option is a data change in `src/data/balance.gd`.

| Option | Effect | Risk |
|---|---|---|
| Add CHAIN to **Entropy** (passive) | Makes tier 2 reachable: Chain Arc + Frequency + Entropy + one more CHAIN item, or + Resonator. It fits Thunderstorm's crit-spark theme. | Low. A passive's tag counts toward the total but gives no weapon the tier-1 bonus. It still needs a 4th item, so it may need to be combined with another option. |
| Add CHAIN to **Pulse Ring** | Makes a second CHAIN weapon. Pulse Ring doesn't use `bounces`, so tier 1 does nothing to it directly. | Low. It gives the Square character's starting weapon a second route. |
| Add CHAIN to **Fractal Shot** | Makes a second CHAIN weapon. | **High.** CHAIN tier 1 adds +2 `bounces`, which Fractal Shot uses as split levels (3 becomes 5 at level 6), making it a huge buff. |
| Lower the tier-2 threshold for CHAIN (per-tag thresholds) | No tag changes. | Needs a code change to support per-tag thresholds, and makes the rule less consistent. |

With Entropy and Pulse Ring both tagged CHAIN, you get Chain Arc + Pulse Ring + Frequency + Entropy = 4, so tier 2 is reachable without Resonator.

## Options for ORBIT and FRACTURE

- Add a tag to one more item for each: for example ORBIT on Hull or Magnet, and FRACTURE on Density or Vertex Shot.
- Or decide that these tier 2s are meant to require Resonator, and say so in its description.

## Next steps

1. Decide which tags to add.
2. Check each new tag's tier-1 effect on the weapon it's added to (as with Fractal Shot's `bounces`).
3. Run `bench=real` for the affected weapons over 10+ seeds and record the results in NOTES.md.
