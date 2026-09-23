class_name Balance
extends RefCounted
## Every tunable number in the game lives here.
## Units: distances in pixels (screen is 720 wide), time in seconds.

# ---------------------------------------------------------------- palette
# Rule: cool colors = player side, warm colors = enemies, green = XP, gold = rare.
const C_BG := Color(0.02, 0.02, 0.05)
const C_GRID := Color(0.07, 0.08, 0.16)
const C_GRID_MAJOR := Color(0.11, 0.12, 0.25)
const C_PLAYER := Color(0.25, 0.95, 1.0)
const C_WEAPON := Color(0.55, 0.95, 1.0)
const C_XP := Color(0.3, 1.0, 0.45)
const C_XP_BIG := Color(0.2, 0.9, 1.0)
const C_HEAL := Color(1.0, 0.35, 0.45)
const C_GOLD := Color(1.0, 0.82, 0.3)
const C_DANGER := Color(1.0, 0.18, 0.2)
const C_TEXT := Color(0.85, 0.95, 1.0)
const C_TEXT_DIM := Color(0.5, 0.6, 0.75)

const TAG_COLORS := {
	"VERTEX": Color(0.3, 0.95, 1.0),
	"ORBIT": Color(0.5, 0.6, 1.0),
	"PULSE": Color(0.3, 1.0, 0.7),
	"CHAIN": Color(1.0, 0.9, 0.3),
	"FRACTURE": Color(1.0, 0.5, 0.85),
}

# ---------------------------------------------------------------- run
const RUN_LENGTH := 900.0          # final boss spawns at 15:00
const MAX_WEAPONS := 4
const MAX_PASSIVES := 4
const OFFER_COUNT := 3
const REROLLS := 2
const BANISHES := 1
const SKIPS := 1
const OVERCLOCK_OFFER_CHANCE := 0.22   # chance that one card is replaced by an Overclock
const CRIT_MULT := 2.0
const PLAYER_RADIUS := 16.0
const PLAYER_IFRAMES := 0.5
const GEM_MERGE_LIMIT := 260       # above this, new gems merge into existing ones
const HEAL_DROP_CHANCE := 0.004
const MAGNET_DROP_CHANCE := 0.0015
const ENEMY_SOFT_CAP := 420        # lowered automatically on slow devices
const ENEMY_MIN_CAP := 160

## XP needed to go from `level` to level+1.
static func xp_needed(level: int) -> int:
	return int(5.0 + level * 6.0 + level * level * 0.45 + pow(level, 3.0) * 0.012)

# ---------------------------------------------------------------- characters
const CHARACTERS := {
	"triangle": {
		"name": "TRIANGLE", "sides": 3,
		"hp": 80.0, "speed": 235.0, "armor": 0.0, "crit": 0.10, "pickup": 90.0,
		"start": "vertex_shot",
		"desc": "Fast and fragile. +10% crit chance.",
	},
	"square": {
		"name": "SQUARE", "sides": 4,
		"hp": 130.0, "speed": 185.0, "armor": 2.0, "crit": 0.0, "pickup": 80.0,
		"start": "pulse_ring",
		"desc": "Slow and armored. Takes 2 less damage per hit.",
	},
	"circle": {
		"name": "CIRCLE", "sides": 0,
		"hp": 100.0, "speed": 205.0, "armor": 0.0, "crit": 0.0, "pickup": 135.0,
		"start": "orbitals",
		"desc": "Balanced. Much larger pickup range.",
	},
}

# ---------------------------------------------------------------- weapons
# `base` = level 1 stats. `levels[i]` = deltas applied when reaching level i+2.
# `evolutions`: passive id -> evolution. A max-level weapon + an owned passive evolves at a core.
# Each passive is the key for exactly 3 weapons, and is CLAIMED by the first weapon that uses it.
# Stat keys: damage, cooldown, count, speed, pierce, area, duration, bounces, knockback
const WEAPONS := {
	"vertex_shot": {
		"name": "Vertex Shot", "tags": ["VERTEX"],
		"desc": "Fires triangles at the nearest enemies.",
		"base": {"damage": 10.0, "cooldown": 0.85, "count": 1, "speed": 560.0, "pierce": 0, "area": 1.0, "duration": 1.1, "knockback": 60.0},
		"levels": [{"count": 1}, {"damage": 4.0}, {"cooldown": -0.12}, {"count": 1, "pierce": 1}, {"damage": 6.0, "count": 1}],
		"evolutions": {
			"sides": {"name": "Star Burst", "desc": "Every volley also fires a ring of triangles in all directions."},
			"velocity": {"name": "Railgun", "desc": "All shots fuse into one huge bolt: infinite pierce, x2.2 speed, x1.5 damage per projectile. Fires slower."},
			"entropy": {"name": "Ricochet", "desc": "Shots bounce to a new enemy on every hit. 2 bounces, +1 per crit."},
		},
	},
	"orbitals": {
		"name": "Orbitals", "tags": ["ORBIT"],
		"desc": "Circles orbit you, hitting whatever they touch.",
		"base": {"damage": 8.0, "cooldown": 0.3, "count": 2, "speed": 2.6, "area": 1.0, "knockback": 90.0},
		"levels": [{"count": 1}, {"damage": 4.0, "area": 0.15}, {"count": 1}, {"damage": 5.0, "speed": 0.5}, {"count": 1, "area": 0.2}],
		"evolutions": {
			"velocity": {"name": "Saturn", "desc": "Adds a larger outer ring spinning the other way. All orbiters grow and spin faster."},
			"radius": {"name": "Event Horizon", "desc": "Ring grows 50% wider and gravity drags nearby enemies into it."},
			"hull": {"name": "Aegis", "desc": "Tight ring that destroys enemy bullets (each block heals 0.5 HP). +50% damage, double knockback."},
		},
	},
	"pulse_ring": {
		"name": "Pulse Ring", "tags": ["PULSE"],
		"desc": "Emits an expanding ring that damages everything it crosses.",
		"base": {"damage": 12.0, "cooldown": 2.2, "count": 1, "area": 1.0, "knockback": 160.0},
		"levels": [{"damage": 5.0}, {"area": 0.2}, {"cooldown": -0.35}, {"damage": 8.0, "area": 0.15}, {"count": 1}],
		"evolutions": {
			"radius": {"name": "Shockwave", "desc": "Rings slow enemies by 50% for 2s and deal 50% more damage."},
			"frequency": {"name": "Metronome", "desc": "Small, rapid pulses. Every 4th beat is a big ring that hits twice as hard."},
			"magnet": {"name": "Implosion", "desc": "Rings collapse inward from the edge, dragging enemies and all XP inside toward you."},
		},
	},
	"line_laser": {
		"name": "Line Laser", "tags": ["VERTEX", "PULSE"],
		"desc": "Fires a piercing beam in the direction you move.",
		"base": {"damage": 16.0, "cooldown": 1.6, "count": 1, "area": 1.0, "duration": 1.0, "knockback": 30.0},
		"levels": [{"damage": 8.0}, {"cooldown": -0.25}, {"area": 0.3}, {"count": 1}, {"damage": 14.0}],
		"evolutions": {
			"density": {"name": "Prism", "desc": "Each beam splits into a fan of three."},
			"frequency": {"name": "Lighthouse", "desc": "Beams become permanent and sweep around you in a circle."},
			"sides": {"name": "Polygon Cage", "desc": "Fires laser walls in a polygon around you. Enemies crossing them burn."},
		},
	},
	"chain_arc": {
		"name": "Chain Arc", "tags": ["CHAIN"],
		"desc": "A spark jumps between nearby enemies.",
		"base": {"damage": 9.0, "cooldown": 1.3, "count": 1, "bounces": 3, "area": 1.0, "knockback": 20.0},
		"levels": [{"bounces": 2}, {"damage": 5.0}, {"count": 1}, {"bounces": 2, "cooldown": -0.2}, {"damage": 8.0, "count": 1}],
		"evolutions": {
			"frequency": {"name": "Tesla Grid", "desc": "No damage falloff, double jump range, fires 30% faster."},
			"entropy": {"name": "Thunderstorm", "desc": "Lightning strikes random enemies across the screen, each with a small blast."},
			"hull": {"name": "Static Skin", "desc": "Shocks every enemy near you at once, and discharges whenever you get hit."},
		},
	},
	"boomerang": {
		"name": "Rhombus", "tags": ["VERTEX", "ORBIT"],
		"desc": "Throws rhombuses that fly out and come back, hitting on both passes.",
		"base": {"damage": 14.0, "cooldown": 1.8, "count": 1, "speed": 480.0, "area": 1.0, "duration": 0.55, "knockback": 70.0},
		"levels": [{"damage": 6.0}, {"count": 1}, {"area": 0.25}, {"damage": 8.0, "cooldown": -0.25}, {"count": 1}],
		"evolutions": {
			"magnet": {"name": "Möbius", "desc": "40% larger, flies out a second time and collects XP it passes."},
			"velocity": {"name": "Ricochet Blade", "desc": "Rhombuses no longer return: they bounce off the screen edges for 3.5s."},
			"density": {"name": "Guillotine", "desc": "One giant, slow blade that grinds whatever it touches many times."},
		},
	},
	"mines": {
		"name": "Square Mines", "tags": ["PULSE", "FRACTURE"],
		"desc": "Drops mines that explode when an enemy comes near.",
		"base": {"damage": 30.0, "cooldown": 1.5, "count": 1, "area": 1.0, "duration": 8.0, "knockback": 200.0},
		"levels": [{"damage": 12.0}, {"count": 1}, {"area": 0.25}, {"cooldown": -0.3, "damage": 12.0}, {"count": 1, "area": 0.2}],
		"evolutions": {
			"hull": {"name": "Fortress", "desc": "Mines become turrets that shoot nearby enemies for 6s."},
			"density": {"name": "Singularity", "desc": "Drops one black-hole mine: it pulls enemies in, then detonates for massive damage."},
			"sides": {"name": "Minefield", "desc": "Leave a trail of small mines while moving. Explosions set off nearby mines."},
		},
	},
	"fractal": {
		"name": "Fractal Shot", "tags": ["VERTEX", "FRACTURE"],
		"desc": "A slow shot that splits into three smaller shots when it hits.",
		"base": {"damage": 14.0, "cooldown": 1.4, "count": 1, "speed": 340.0, "pierce": 0, "area": 1.0, "duration": 1.6, "bounces": 1, "knockback": 50.0},
		"levels": [{"damage": 6.0}, {"bounces": 1}, {"count": 1}, {"damage": 8.0, "cooldown": -0.2}, {"bounces": 1}],
		"evolutions": {
			"entropy": {"name": "Mandelbrot", "desc": "Splits one extra time and every split shot is a guaranteed crit."},
			"radius": {"name": "Supernova", "desc": "The shot swells as it flies, then explodes in a big blast that scatters fragments."},
			"magnet": {"name": "Attractor", "desc": "A slow homing vortex that pulls enemies into it, then splits."},
		},
	},
}
const WEAPON_MAX_LEVEL := 6

# ---------------------------------------------------------------- passives
# `per_level` is added once per level.
const PASSIVES := {
	"sides":     {"name": "Sides",     "tags": ["VERTEX"],   "max": 2, "per_level": {"count": 1},       "desc": "+1 projectile / orbiter / spark for every weapon."},
	"radius":    {"name": "Radius",    "tags": ["PULSE"],    "max": 5, "per_level": {"area": 0.10},     "desc": "+10% area."},
	"frequency": {"name": "Frequency", "tags": ["CHAIN"],    "max": 5, "per_level": {"cooldown": -0.07},"desc": "-7% cooldown."},
	"velocity":  {"name": "Velocity",  "tags": ["ORBIT"],    "max": 5, "per_level": {"speed": 0.10, "duration": 0.10}, "desc": "+10% projectile speed and duration."},
	"entropy":   {"name": "Entropy",   "tags": ["FRACTURE"], "max": 5, "per_level": {"crit": 0.06},     "desc": "+6% crit chance. Crits deal double damage."},
	"density":   {"name": "Density",   "tags": [],           "max": 5, "per_level": {"damage": 0.10},   "desc": "+10% damage."},
	"hull":      {"name": "Hull",      "tags": [],           "max": 5, "per_level": {"max_hp": 20.0, "regen": 0.25}, "desc": "+20 max HP, +0.25 HP/s regeneration."},
	"magnet":    {"name": "Magnet",    "tags": [],           "max": 5, "per_level": {"pickup": 0.30, "xp": 0.05}, "desc": "+30% pickup range, +5% XP."},
}

# ---------------------------------------------------------------- resonance
# Each item counts once per tag it carries (weapons AND passives).
const RESONANCE_THRESHOLDS := [2, 4]
const RESONANCE := {
	"VERTEX":   ["VERTEX projectiles pierce +1.", "VERTEX projectiles split into 2 shards on kill."],
	"ORBIT":    ["ORBIT weapons get +1 orbiter / rhombus.", "Orbitals fire a spark at the nearest enemy every second."],
	"PULSE":    ["PULSE weapons get +20% area.", "PULSE hits pull enemies toward their center."],
	"CHAIN":    ["CHAIN sparks jump +2 more times.", "Any hit has a 12% chance to arc to a nearby enemy."],
	"FRACTURE": ["Kills have a 12% chance to burst into 3 shards.", "Burst chance 30%. Shard kills can burst again."],
}

# ---------------------------------------------------------------- overclocks
# Powerful trade-offs. Each can be taken once per run.
const OVERCLOCKS := {
	"glass":    {"name": "Glass Core",     "desc": "+40% damage.",                 "cost": "-30% max HP.",                "mods": {"damage": 0.40, "max_hp_mult": -0.30}},
	"heavy":    {"name": "Heavy Field",    "desc": "+35% area.",                   "cost": "-12% move speed.",            "mods": {"area": 0.35, "move": -0.12}},
	"overdrive":{"name": "Overdrive",      "desc": "-22% cooldown.",               "cost": "Take +25% damage.",           "mods": {"cooldown": -0.22, "taken": 0.25}},
	"greed":    {"name": "Greed Lattice",  "desc": "+35% XP, +50% pickup range.",  "cost": "Enemies have +15% HP.",       "mods": {"xp": 0.35, "pickup": 0.5, "enemy_hp": 0.15}},
	"tunnel":   {"name": "Tunnel Vision",  "desc": "+2 pierce, +20% damage.",      "cost": "One fewer level-up option.",  "mods": {"pierce": 2, "damage": 0.20, "offers": -1}},
	"anchor":   {"name": "Anchor",         "desc": "+60% damage while standing still.", "cost": "-10% move speed.",   "mods": {"anchor": 0.60, "move": -0.10}},
	"momentum": {"name": "Momentum",       "desc": "+25% move speed.",             "cost": "-15% damage.",                "mods": {"move": 0.25, "damage": -0.15}},
	"vampire":  {"name": "Siphon",         "desc": "Kills heal 0.4 HP.",           "cost": "No more heal drops or regen.", "mods": {"lifesteal": 0.4, "no_heal": 1}},
}

# ---------------------------------------------------------------- enemies
# behavior: chase, dash, shoot, split, elite, boss
# armor: flat damage removed from every hit (min 1).  cap: max damage per hit (0 = none).
const ENEMIES := {
	"dot":      {"sides": 0, "radius": 7.0,  "hp": 4.0,   "speed": 100.0, "damage": 5.0,  "xp": 1, "mass": 0.6, "armor": 0.0, "cap": 0.0,  "color": Color(1.0, 0.25, 0.75), "behavior": "chase"},
	"shard":    {"sides": 3, "radius": 9.0,  "hp": 6.0,   "speed": 125.0, "damage": 5.0,  "xp": 1, "mass": 0.6, "armor": 0.0, "cap": 0.0,  "color": Color(0.75, 0.4, 1.0),  "behavior": "chase"},
	"darter":   {"sides": 3, "radius": 14.0, "hp": 14.0,  "speed": 75.0,  "damage": 10.0, "xp": 2, "mass": 0.8, "armor": 0.0, "cap": 0.0,  "color": Color(1.0, 0.55, 0.15), "behavior": "dash"},
	"hexagon":  {"sides": 6, "radius": 18.0, "hp": 32.0,  "speed": 62.0,  "damage": 10.0, "xp": 3, "mass": 1.2, "armor": 0.0, "cap": 0.0,  "color": Color(0.75, 0.4, 1.0),  "behavior": "split"},
	"pentagon": {"sides": 5, "radius": 16.0, "hp": 22.0,  "speed": 70.0,  "damage": 8.0,  "xp": 3, "mass": 1.0, "armor": 0.0, "cap": 0.0,  "color": Color(1.0, 0.4, 0.3),   "behavior": "shoot"},
	"brute":    {"sides": 4, "radius": 22.0, "hp": 70.0,  "speed": 52.0,  "damage": 16.0, "xp": 6, "mass": 3.0, "armor": 5.0, "cap": 0.0,  "color": Color(0.9, 0.2, 0.5),   "behavior": "chase"},
	"star":     {"sides": -5,"radius": 30.0, "hp": 650.0, "speed": 58.0,  "damage": 20.0, "xp": 30,"mass": 8.0, "armor": 0.0, "cap": 14.0, "color": Color(1.0, 0.3, 0.55),  "behavior": "elite"},
	"boss_tetra":{"sides": 4, "radius": 52.0, "hp": 3200.0, "speed": 80.0, "damage": 25.0, "xp": 80, "mass": 50.0, "armor": 3.0, "cap": 0.0, "color": Color(1.0, 0.35, 0.2), "behavior": "boss"},
	"boss_hex": {"sides": 6, "radius": 58.0, "hp": 11000.0,"speed": 65.0, "damage": 30.0, "xp": 150,"mass": 50.0, "armor": 4.0, "cap": 0.0, "color": Color(0.8, 0.35, 1.0), "behavior": "boss"},
	"boss_final":{"sides": 3, "radius": 70.0, "hp": 38000.0,"speed": 75.0, "damage": 35.0, "xp": 0, "mass": 80.0, "armor": 5.0, "cap": 0.0, "color": Color(1.0, 0.2, 0.45), "behavior": "boss"},
}
const DARTER_DASH_SPEED := 430.0
const DARTER_TELEGRAPH := 0.65
const DARTER_DASH_TIME := 0.45
const DARTER_COOLDOWN := 3.2
const SHOOTER_RANGE := 280.0
const SHOOTER_COOLDOWN := 3.2
const ENEMY_BULLET_SPEED := 190.0
const HEX_SPLIT_COUNT := 3

## Enemy contact/bullet damage multiplier over time.
static func enemy_damage_mult(t: float) -> float:
	return 1.0 + t / 60.0 * 0.04

## Enemy HP multiplier over time (t in seconds).
static func enemy_hp_mult(t: float) -> float:
	return 1.0 + t / 60.0 * 0.2 + pow(t / 60.0, 2.0) * 0.018

# ---------------------------------------------------------------- waves
# Each phase lasts until the next one's `t`. interval = seconds between spawn batches.
const WAVES := [
	{"t": 0,   "interval": 1.00, "batch": 3, "max": 45,  "types": {"dot": 1.0}},
	{"t": 45,  "interval": 0.80, "batch": 4, "max": 70,  "types": {"dot": 0.8, "darter": 0.2}},
	{"t": 105, "interval": 0.70, "batch": 4, "max": 100, "types": {"dot": 0.6, "darter": 0.25, "pentagon": 0.15}},
	{"t": 180, "interval": 0.60, "batch": 5, "max": 130, "types": {"dot": 0.5, "darter": 0.2, "pentagon": 0.1, "hexagon": 0.2}},
	{"t": 240, "interval": 0.55, "batch": 5, "max": 160, "types": {"dot": 0.45, "hexagon": 0.25, "brute": 0.15, "pentagon": 0.15}},
	{"t": 330, "interval": 0.50, "batch": 6, "max": 200, "types": {"dot": 0.4, "darter": 0.2, "brute": 0.2, "pentagon": 0.2}},
	{"t": 420, "interval": 0.45, "batch": 6, "max": 240, "types": {"dot": 0.35, "hexagon": 0.3, "brute": 0.2, "pentagon": 0.15}},
	{"t": 540, "interval": 0.38, "batch": 9, "max": 300, "types": {"dot": 0.3, "darter": 0.25, "brute": 0.25, "pentagon": 0.2}},
	{"t": 660, "interval": 0.34, "batch": 11, "max": 340, "types": {"dot": 0.3, "hexagon": 0.25, "brute": 0.25, "darter": 0.2}},
	{"t": 780, "interval": 0.30, "batch": 13, "max": 400, "types": {"dot": 0.25, "darter": 0.2, "hexagon": 0.2, "brute": 0.2, "pentagon": 0.15}},
	{"t": 900, "interval": 0.60, "batch": 5, "max": 150, "types": {"dot": 0.5, "shard": 0.5}},
]

# One-off events: swarm = ring of enemies around the player, elite = a Star, boss = boss.
const EVENTS := [
	{"t": 90,  "kind": "swarm", "type": "dot", "count": 30},
	{"t": 150, "kind": "elite", "type": "star"},
	{"t": 210, "kind": "swarm", "type": "darter", "count": 16},
	{"t": 300, "kind": "boss",  "type": "boss_tetra"},
	{"t": 380, "kind": "elite", "type": "star"},
	{"t": 450, "kind": "swarm", "type": "brute", "count": 14},
	{"t": 500, "kind": "elite", "type": "star"},
	{"t": 600, "kind": "boss",  "type": "boss_hex"},
	{"t": 690, "kind": "swarm", "type": "hexagon", "count": 22},
	{"t": 720, "kind": "elite", "type": "star"},
	{"t": 810, "kind": "elite", "type": "star"},
	{"t": 840, "kind": "swarm", "type": "dot", "count": 60},
	{"t": 900, "kind": "boss",  "type": "boss_final"},
]

# ---------------------------------------------------------------- depth (difficulty tiers)
# Cumulative: Depth 3 applies modifiers 1..3. Unlocked by winning the previous depth.
const DEPTHS := [
	{"desc": "Base game."},
	{"desc": "Enemies +20% HP.",               "mods": {"enemy_hp": 0.20}},
	{"desc": "Enemies +10% speed.",            "mods": {"enemy_speed": 0.10}},
	{"desc": "-1 reroll.",                     "mods": {"rerolls": -1}},
	{"desc": "Elites spawn twice.",            "mods": {"elite_double": 1}},
	{"desc": "Enemy damage +25%.",             "mods": {"enemy_damage": 0.25}},
	{"desc": "Bosses +30% HP.",                "mods": {"boss_hp": 0.30}},
	{"desc": "XP -15%.",                       "mods": {"xp": -0.15}},
	{"desc": "Enemies +10% speed.",            "mods": {"enemy_speed": 0.10}},
	{"desc": "No banish, no skip.",            "mods": {"banishes": -1, "skips": -1}},
	{"desc": "Enemies +25% HP. Good luck.",    "mods": {"enemy_hp": 0.25}},
]
