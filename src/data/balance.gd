class_name Balance
extends RefCounted
## Every tunable number in the game lives here.
## Units: distances in pixels (screen is 720 wide), time in seconds.

# ---------------------------------------------------------------- palette
# Rule: each character owns one color (body, shots, XP, HUD accent). Everything hostile sits in the
# violet-to-magenta band, which no character uses. White = heal, gold = rare.
const C_BG := Color(0, 0, 0)
const C_GRID := Color(0.07, 0.08, 0.16)
const C_GRID_MAJOR := Color(0.11, 0.12, 0.25)
const C_HEAL := Color(0.92, 1.0, 0.95)
const C_GOLD := Color(1.0, 0.82, 0.3)
const C_DANGER := Color(1.0, 0.2, 0.75)
const C_PASSIVE := Color(0.75, 0.8, 0.9)
const C_OVERCLOCK := Color(1.0, 0.6, 0.2)
const C_TEXT := Color(0.85, 0.95, 1.0)
const C_TEXT_DIM := Color(0.5, 0.6, 0.75)
# Set from the selected character by set_character().
static var C_PLAYER := Color(1.0, 0.3, 0.25)
static var C_WEAPON := Color(1.0, 0.55, 0.5)
static var C_XP := Color(1.0, 0.7, 0.65)
static var C_XP_BIG := Color(1.0, 0.45, 0.4)


## Switches the player-side colors to this character's.
static func set_character(id: String) -> void:
	var c: Color = CHARACTERS[id].color
	C_PLAYER = c
	C_WEAPON = c.lerp(Color.WHITE, 0.35)
	C_XP = c.lerp(Color.WHITE, 0.55)
	C_XP_BIG = c.lerp(Color.WHITE, 0.2)

# ---------------------------------------------------------------- run
const RUN_LENGTH := 900.0          # final boss spawns at 15:00
const MAX_PASSIVES := 4
const OFFER_COUNT := 3
const REROLLS := 2
const BANISHES := 1
const SKIPS := 1
# Level-up offer weights: things you already own show up far more often than new ones.
const OFFER_W_WEAPON := 2.6
const OFFER_W_OWNED_PASSIVE := 2.0
const OFFER_W_NEW_PASSIVE := 0.5
const OVERCLOCK_CHOICES := 3           # overclock cards offered by a core (elite / boss drop)
const CRIT_MULT := 2.0                 # crit damage before upgrades
const COOLDOWN_FLOOR := 0.05
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
# One weapon per character. `sides`: 0 = circle, 3+ = polygon, negative = star with that many points.
const CHARACTERS := {
	"triangle": {
		"name": "TRIANGLE", "sides": 3, "color": Color(1.0, 0.3, 0.25),
		"hp": 80.0, "speed": 235.0, "armor": 0.0, "crit": 0.10, "pickup": 90.0,
		"start": "vertex_shot",
		"desc": "Fast and fragile. +10% crit chance. Shoots from its tip.",
	},
	"square": {
		"name": "SQUARE", "sides": 4, "color": Color(0.3, 1.0, 0.45),
		"hp": 130.0, "speed": 185.0, "armor": 2.0, "crit": 0.0, "pickup": 80.0,
		"start": "orbitals",
		"desc": "Slow and armored. Takes 2 less damage per hit. Rods sweep from its corners.",
	},
	"circle": {
		"name": "CIRCLE", "sides": 0, "color": Color(0.3, 0.6, 1.0),
		"hp": 100.0, "speed": 205.0, "armor": 0.0, "crit": 0.0, "pickup": 135.0,
		"start": "pulse_ring",
		"desc": "Balanced. Much larger pickup range. Pulses in every direction.",
	},
	"spark": {
		"name": "SPARK", "sides": -4, "color": Color(1.0, 0.9, 0.3),
		"hp": 90.0, "speed": 215.0, "armor": 0.0, "crit": 0.05, "pickup": 100.0,
		"start": "chain_arc",
		"desc": "Quick and light. +5% crit chance. Lightning leaps from its four points.",
	},
}

# ---------------------------------------------------------------- damage
# hit = (weapon damage x k x attack damage x crit damage + bonus damage x k) x damage multiplier
#   weapon damage  = the weapon's base `damage` + every "wd"
#   attack damage  = 1 + every "damage"
#   crit damage    = CRIT_MULT + every "crit_dmg", only on a crit
#   bonus damage   = every "bonus"
#   multiplier     = 1 + every "mult" + situational ones (anchor, redline, moving, streak)
#   k              = sub-hit factor: 1 for a normal hit, less for weak secondary hits
# cooldown = base x (1 + step) for every "cooldown" step, so -10% twice is x0.81.

# ---------------------------------------------------------------- weapons
# No weapon pushes enemies by itself: knockback only comes from upgrades (flat "knockback").
# `base` = level 1 stats. `levels[i]` is what reaching level i+2 gives: a mods Dictionary, or at a
# milestone an Array of options {name, mods, desc?, evo?} the player picks one of.
# A level-10 option's `evo` switches the weapon script into that form.
const WEAPONS := {
	"vertex_shot": {
		"name": "Vertex Shot",
		"desc": "Fires triangles at the nearest enemies.",
		"base": {"damage": 10.0, "cooldown": 0.7, "count": 1, "speed": 560.0, "pierce": 1, "duration": 1.1},
		"levels": [
			{"count": 1},
			{"speed": 0.20, "wd": 5},
			[{"name": "Volley", "mods": {"count": 2, "wd": -5}},
			 {"name": "High Velocity", "mods": {"speed": 0.30, "wd": 5}},
			 {"name": "Keen Edge", "mods": {"crit": 0.10, "crit_dmg": 0.20}}],
			{"cooldown": -0.10},
			{"count": 1, "pierce": 1},
			[{"name": "Rapid Fire", "mods": {"cooldown": -0.10, "count": 1, "pierce": 1}},
			 {"name": "Heavy Shot", "mods": {"wd": 7, "damage": 0.30, "area": 0.30}},
			 {"name": "Precision", "mods": {"crit": 0.10, "crit_dmg": 0.30, "pierce": 1}}],
			{"speed": 0.20, "area": 0.20},
			{"cooldown": -0.10},
			[{"name": "Focus Fire", "evo": "focus", "desc": "After a hit, a shot turns toward another enemy for as long as it has pierce left. It can go back and forth between two.", "mods": {"pierce": 2}},
			 {"name": "Star Burst", "evo": "burst", "desc": "Doubles the projectile count.", "mods": {"bonus": 20, "wd": -5}},
			 {"name": "Deadeye", "evo": "deadeye", "desc": "A crit doesn't use up pierce.", "mods": {"wd": 10, "crit": 0.10, "crit_dmg": 0.50, "cooldown": -0.10}}],
		],
	},
	"orbitals": {
		"name": "Rods",
		"desc": "Rods reach out from your body, evenly spaced, and sweep around you.",
		"base": {"damage": 11.0, "cooldown": 1.0, "count": 2, "speed": 2.6},
		"levels": [
			{"count": 1},
			{"area": 0.20, "wd": 4},
			[{"name": "Extra Rod", "mods": {"count": 1, "wd": -3}},
			 {"name": "Flywheel", "mods": {"speed": 0.25, "wd": 5}},
			 {"name": "Long Reach", "mods": {"area": 0.25, "width": 0.20}}],
			{"speed": 0.10},
			{"count": 1, "area": 0.10},
			[{"name": "Buzzsaw", "mods": {"speed": 0.30}},
			 {"name": "Heavy Rods", "mods": {"wd": 7, "damage": 0.30, "width": 0.30}},
			 {"name": "Battering Ram", "mods": {"knockback": 80, "area": 0.20, "bonus": 10}}],
			{"speed": 0.20, "area": 0.15},
			{"speed": 0.10},
			[{"name": "Saturn", "evo": "saturn", "desc": "A second, longer set of rods spins the other way.", "mods": {}},
			 {"name": "Aegis", "evo": "aegis", "desc": "Shorter rods that destroy enemy bullets and hit 50% harder.", "mods": {"knockback": 90}},
			 {"name": "Event Horizon", "evo": "horizon", "desc": "Rods drag nearby enemies in.", "mods": {"area": 0.25}}],
		],
	},
	"pulse_ring": {
		"name": "Pulse Ring",
		"desc": "Emits an expanding ring that damages everything it crosses.",
		"base": {"damage": 10.0, "cooldown": 2.2, "count": 1, "speed": 1.0},
		"levels": [
			{"wd": 5},
			{"area": 0.20},
			[{"name": "Quick Pulse", "mods": {"cooldown": -0.15}},
			 {"name": "Wide Band", "mods": {"area": 0.25, "speed": 0.20}},
			 {"name": "Hard Pulse", "mods": {"crit": 0.10, "crit_dmg": 0.30}}],
			{"cooldown": -0.10},
			{"speed": 0.20, "wd": 5},
			[{"name": "Steady Beat", "mods": {"cooldown": -0.10, "area": 0.15}},
			 {"name": "Amplitude", "mods": {"wd": 8, "damage": 0.30}},
			 {"name": "Sharp Wave", "mods": {"crit": 0.20}}],
			{"area": 0.30},
			{"cooldown": -0.10},
			[{"name": "Double Pulse", "evo": "double", "desc": "Every pulse sends a second ring.", "mods": {"count": 1, "cooldown": 0.15}},
			 {"name": "Repulsor", "evo": "repulsor", "desc": "Every 3rd ring knocks enemies back and wipes out the enemy bullets it crosses.", "mods": {}},
			 {"name": "Tide", "evo": "tide", "desc": "The ring never fades: it sweeps in and out without stopping, hitting on every pass. Cooldown reduction makes it sweep much faster.", "mods": {}}],
		],
	},
	"chain_arc": {
		"name": "Chain Arc",
		"desc": "A spark jumps between nearby enemies, and can come back to one it already hit.",
		"base": {"damage": 9.0, "cooldown": 1.3, "count": 1, "bounces": 2, "speed": 1.0},
		"levels": [
			{"bounces": 2},
			{"wd": 5, "speed": 0.15},
			[{"name": "Fork", "mods": {"count": 1, "wd": -3}},
			 {"name": "Long Chain", "mods": {"bounces": 2, "wd": 5}},
			 {"name": "Live Wire", "mods": {"crit": 0.10, "crit_dmg": 0.20}}],
			{"cooldown": -0.10},
			{"count": 1, "bounces": 1},
			[{"name": "Overload", "mods": {"cooldown": -0.10, "count": 1}},
			 {"name": "Conductor", "mods": {"wd": 7, "damage": 0.30}},
			 {"name": "Far Reach", "mods": {"speed": 0.30, "bounces": 2, "bonus": 10}}],
			{"bounces": 2, "speed": 0.20},
			{"cooldown": -0.10},
			[{"name": "Cascade", "evo": "cascade", "desc": "Each jump hits 12% harder than the one before.", "mods": {}},
			 {"name": "Detonation", "evo": "detonate", "desc": "Sparks stop jumping and explode on their first target instead, 20% harder. Every jump you have makes the blast bigger.", "mods": {}},
			 {"name": "Static Field", "evo": "field", "desc": "Enemy bullets miss you half the time, and every miss throws a spark at the enemies.", "mods": {"bullet_miss": 0.5, "max_hp_mult": 0.30}}],
		],
	},
}
const WEAPON_MAX_LEVEL := 10
const CASCADE_GAIN := 0.12        # Cascade: damage gained per jump
const DETONATE_RADIUS := 60.0     # Detonation: blast radius with no jumps
const DETONATE_PER_JUMP := 12.0   # ... and what each jump adds
const DETONATE_K := 1.2
const DETONATE_GAP := 0.12        # seconds between one volley's sparks, so stacked blasts read as separate hits
const REPULSOR_EVERY := 3
const REPULSOR_KNOCKBACK := 240.0

# ---------------------------------------------------------------- passives
# `levels[i]` is what level i+1 gives, in the same format as weapon levels. Milestones at 5 and 10.
const PASSIVES := {
	"damage": {"name": "Damage", "desc": "More damage on every hit.", "levels": [
		{"damage": 0.10}, {"damage": 0.10}, {"damage": 0.10}, {"damage": 0.10},
		[{"name": "Power", "mods": {"damage": 0.30}},
		 {"name": "Payload", "mods": {"bonus": 10}}],
		{"damage": 0.20}, {"damage": 0.20}, {"damage": 0.20}, {"damage": 0.20},
		[{"name": "Overwhelm", "mods": {"damage": 0.50}},
		 {"name": "Warhead", "mods": {"bonus": 20}},
		 {"name": "Bloodlust", "mods": {"streak": 0.30}}],
	]},
	"cooldown": {"name": "Cooldown", "desc": "Attack more often.", "levels": [
		{"cooldown": -0.05}, {"cooldown": -0.05}, {"cooldown": -0.05}, {"cooldown": -0.05},
		[{"name": "Tempo", "mods": {"cooldown": -0.09}},
		 {"name": "Quickstep", "mods": {"cooldown": -0.05, "move": 0.08}}],
		{"cooldown": -0.05}, {"cooldown": -0.05}, {"cooldown": -0.05}, {"cooldown": -0.05},
		[{"name": "Frenzy", "mods": {"cooldown": -0.12}},
		 {"name": "Double Tap", "mods": {"cooldown": -0.06, "echo": 5}},
		 {"name": "Adrenaline", "mods": {"hurt_haste": 0.30}}],
	]},
	"crit": {"name": "Critical", "desc": "Crit more often, then crit harder.", "levels": [
		{"crit": 0.05}, {"crit": 0.05}, {"crit": 0.05}, {"crit": 0.05},
		[{"name": "Sharp Eye", "mods": {"crit": 0.07}},
		 {"name": "Brutality", "mods": {"crit_dmg": 0.40}}],
		{"crit_dmg": 0.25}, {"crit_dmg": 0.25}, {"crit_dmg": 0.25}, {"crit_dmg": 0.25},
		[{"name": "Devastate", "mods": {"crit_dmg": 0.75}},
		 {"name": "Marksman", "mods": {"crit": 0.10}},
		 {"name": "Arc Crits", "mods": {"crit_arc": 0.50}}],
	]},
	"area": {"name": "Area", "desc": "Bigger attacks.", "levels": [
		{"area": 0.08}, {"area": 0.08}, {"area": 0.08}, {"area": 0.08},
		[{"name": "Expanse", "mods": {"area": 0.15}},
		 {"name": "Impact", "mods": {"area": 0.08, "knockback": 40}}],
		{"area": 0.08}, {"area": 0.08}, {"area": 0.08}, {"area": 0.08},
		[{"name": "Vastness", "mods": {"area": 0.25}},
		 {"name": "Undertow", "mods": {"area": 0.10, "knockback": 60, "pull": 1}},
		 {"name": "Chain Reaction", "mods": {"volatile": 0.15}}],
	]},
	"velocity": {"name": "Velocity", "desc": "Faster attacks: shots fly, rods spin, rings spread and arcs reach further.", "levels": [
		{"speed": 0.08}, {"speed": 0.08}, {"speed": 0.08}, {"speed": 0.08},
		[{"name": "Rush", "mods": {"speed": 0.15}},
		 {"name": "Stride", "mods": {"speed": 0.08, "move": 0.05}}],
		{"speed": 0.08}, {"speed": 0.08}, {"speed": 0.08}, {"speed": 0.08},
		[{"name": "Hypersonic", "mods": {"speed": 0.25}},
		 {"name": "Splinter", "mods": {"split_kill": 1}},
		 {"name": "Tailwind", "mods": {"speed": 0.10, "move": 0.10}}],
	]},
	"hull": {"name": "Hull", "desc": "More HP and regeneration.", "levels": [
		{"max_hp": 15.0, "regen": 0.2}, {"max_hp": 15.0, "regen": 0.2}, {"max_hp": 15.0, "regen": 0.2}, {"max_hp": 15.0, "regen": 0.2},
		[{"name": "Bulk", "mods": {"max_hp": 40.0}},
		 {"name": "Plating", "mods": {"armor": 1.5}}],
		{"max_hp": 15.0, "regen": 0.2}, {"max_hp": 15.0, "regen": 0.2}, {"max_hp": 15.0, "regen": 0.2}, {"max_hp": 15.0, "regen": 0.2},
		[{"name": "Colossus", "mods": {"max_hp": 60.0}},
		 {"name": "Bastion", "mods": {"armor": 3.0}},
		 {"name": "Reactive Plating", "mods": {"hurt_shock": 1}}],
	]},
	"magnet": {"name": "Magnet", "desc": "Longer pickup range and more XP.", "levels": [
		{"pickup": 0.20, "xp": 0.03}, {"pickup": 0.20, "xp": 0.03}, {"pickup": 0.20, "xp": 0.03}, {"pickup": 0.20, "xp": 0.03},
		[{"name": "Long Arm", "mods": {"pickup": 0.40}},
		 {"name": "Scholar", "mods": {"xp": 0.10}}],
		{"pickup": 0.20, "xp": 0.03}, {"pickup": 0.20, "xp": 0.03}, {"pickup": 0.20, "xp": 0.03}, {"pickup": 0.20, "xp": 0.03},
		[{"name": "Savant", "mods": {"xp": 0.15}},
		 {"name": "Vacuum", "mods": {"xp_pulse": 30}},
		 {"name": "Recycler", "mods": {"xp_heal": 0.2}}],
	]},
	"agility": {"name": "Agility", "desc": "Move faster.", "levels": [
		{"move": 0.03}, {"move": 0.03}, {"move": 0.03}, {"move": 0.03},
		[{"name": "Sprint", "mods": {"move": 0.06}},
		 {"name": "Afterimage", "mods": {"iframes": 0.1}}],
		{"move": 0.03}, {"move": 0.03}, {"move": 0.03}, {"move": 0.03},
		[{"name": "Dash", "mods": {"move": 0.10}},
		 {"name": "Running Start", "mods": {"moving": 0.20}},
		 {"name": "Blur", "mods": {"dodge": 0.10}}],
	]},
}
const PASSIVE_MAX_LEVEL := 10
const STREAK_KILLS := 100     # Bloodlust: kills needed to trigger
const STREAK_TIME := 5.0
const HASTE_TIME := 3.0       # Adrenaline: how long the cooldown cut lasts after a hit
const SHOCK_RADIUS := 200.0   # Reactive Plating
const SHOCK_K := 3.0

# ---------------------------------------------------------------- upgrade text
# stat key -> [format, kind]. kind: "i" flat number, "p" percent, "f" one decimal, "t" fixed text with one number.
const STAT_TEXT := {
	"wd": ["%+d weapon damage", "i"], "damage": ["%+d%% damage", "p"], "bonus": ["%+d bonus damage", "i"],
	"crit": ["%+d%% crit chance", "p"], "crit_dmg": ["%+d%% crit damage", "p"], "mult": ["%+d%% all damage", "p"],
	"cooldown": ["%+d%% cooldown", "p"], "count": ["%+d projectile", "i"], "pierce": ["%+d pierce", "i"],
	"bounces": ["%+d jumps", "i"], "area": ["%+d%% area", "p"], "width": ["%+d%% rod width", "p"],
	"speed": ["%+d%% attack speed", "p"], "knockback": ["%+d knockback", "i"],
	"max_hp": ["%+d max HP", "i"], "regen": ["%+.1f HP/s", "f"], "armor": ["%+.1f armor", "f"],
	"move": ["%+d%% move speed", "p"], "pickup": ["%+d%% pickup range", "p"], "xp": ["%+d%% XP", "p"],
	"iframes": ["%+.1fs invulnerability after a hit", "f"],
	"streak": ["Every 100 kills: +%d%% all damage for 5s", "p"],
	"echo": ["Every %dth attack fires twice", "i"],
	"hurt_haste": ["-%d%% cooldown for 3s after being hit", "p"],
	"crit_arc": ["Crits arc to a nearby enemy for %d%% of the hit", "p"],
	"pull": ["Knockback pulls enemies toward you instead of pushing them", "t"],
	"max_hp_mult": ["%+d%% max HP", "p"],
	"volatile": ["Kills have a %d%% chance to explode", "p"],
	"split_kill": ["Kills throw 2 shards", "t"],
	"hurt_shock": ["Being hit shocks nearby enemies", "t"],
	"xp_pulse": ["Every %ds, pulls in all XP on screen", "i"],
	"xp_heal": ["XP pickups heal %.1f HP", "f"],
	"moving": ["+%d%% all damage while moving", "p"],
	"dodge": ["%d%% chance to dodge a hit", "p"],
}
# Per-weapon wording for the stats that mean something different on each weapon.
const WEAPON_WORDS := {
	"vertex_shot": {"count": "%+d projectile", "area": "%+d%% projectile size", "speed": "%+d%% projectile speed"},
	"orbitals": {"count": "%+d rod", "area": "%+d%% rod length", "speed": "%+d%% spin speed", "cooldown": "%+d%% spin speed"},
	"pulse_ring": {"count": "%+d ring", "area": "%+d%% ring size", "speed": "%+d%% ring speed"},
	"chain_arc": {"count": "%+d spark", "area": "%+d%% range and blast size", "speed": "%+d%% jump range"},
}
# Stats shown as their inverse: a rod has no cooldown, so cutting it reads as the spin it adds.
const INVERTED_WORDS := {"orbitals": ["cooldown"]}


## Readable list of what a mods Dictionary does, worded for `weapon_id` ("" = generic).
static func mods_text(mods: Dictionary, weapon_id := "") -> String:
	var parts: PackedStringArray = []
	var words: Dictionary = WEAPON_WORDS.get(weapon_id, {})
	for k in mods:
		if not STAT_TEXT.has(k):
			continue
		var fmt: String = words.get(k, STAT_TEXT[k][0])
		var v: float = mods[k]
		if k in INVERTED_WORDS.get(weapon_id, []):
			v = 1.0 / (1.0 + v) - 1.0
		match STAT_TEXT[k][1]:
			"p":
				parts.append(fmt % roundi(v * 100.0))
			"i":
				parts.append(fmt % int(v))
			"f":
				parts.append(fmt % v)
			_:
				parts.append(fmt)
	return ", ".join(parts)


## Card text for one milestone option.
static func option_text(opt: Dictionary, weapon_id := "") -> String:
	var stats := mods_text(opt.get("mods", {}), weapon_id)
	if opt.has("desc"):
		return opt.desc if stats == "" else "%s %s." % [opt.desc, stats]
	return stats + "."

# ---------------------------------------------------------------- overclocks
# Powerful trade-offs, offered only by cores (dropped by elites and bosses). Each can be taken once per run.
# `weapons` limits an overclock to the weapons it does something for.
const OVERCLOCKS := {
	"glass":    {"name": "Glass Core",     "desc": "+30% all damage.",             "cost": "-30% max HP.",                "mods": {"mult": 0.30, "max_hp_mult": -0.30}},
	"heavy":    {"name": "Heavy Field",    "desc": "+35% area.",                   "cost": "-12% move speed.",            "mods": {"area": 0.35, "move": -0.12}},
	"overdrive":{"name": "Overdrive",      "desc": "-22% cooldown.",               "cost": "Take +25% damage.",           "mods": {"cooldown": -0.22, "taken": 0.25}},
	"greed":    {"name": "Greed Lattice",  "desc": "+35% XP, +50% pickup range.",  "cost": "Enemies have +15% HP.",       "mods": {"xp": 0.35, "pickup": 0.5, "enemy_hp": 0.15}},
	"tunnel":   {"name": "Tunnel Vision",  "desc": "+2 pierce, +20% damage.",      "cost": "One fewer level-up option.",  "mods": {"pierce": 2, "damage": 0.20, "offers": -1}, "weapons": ["vertex_shot"]},
	"anchor":   {"name": "Anchor",         "desc": "+60% all damage while standing still.", "cost": "-10% move speed.",   "mods": {"anchor": 0.60, "move": -0.10}},
	"momentum": {"name": "Momentum",       "desc": "+25% move speed.",             "cost": "-15% damage.",                "mods": {"move": 0.25, "damage": -0.15}},
	"vampire":  {"name": "Siphon",         "desc": "Kills heal 0.4 HP.",           "cost": "No more heal drops or regen.", "mods": {"lifesteal": 0.4, "no_heal": 1}},
	"trigger":  {"name": "Hair Trigger",   "desc": "+1 projectile / rod / spark.", "cost": "-20% damage.",                "mods": {"count": 1, "damage": -0.20}, "weapons": ["vertex_shot", "orbitals", "chain_arc"]},
	"focus":    {"name": "Focus Lens",     "desc": "+20% crit chance.",            "cost": "-15% area.",                  "mods": {"crit": 0.20, "area": -0.15}},
	"redline":  {"name": "Redline",        "desc": "+60% all damage below 50% HP.", "cost": "All healing is halved.",     "mods": {"redline": 0.60, "heal_mult": -0.5}},
	"bulwark":  {"name": "Bulwark",        "desc": "+4 armor, +30 max HP.",        "cost": "+20% cooldown.",              "mods": {"armor": 4.0, "max_hp": 30.0, "cooldown": 0.20}},
	"stasis":   {"name": "Stasis Field",   "desc": "Enemies move 15% slower.",     "cost": "-20% attack speed (shots, spin, rings, jump range).", "mods": {"enemy_speed": -0.15, "speed": -0.20}},
	"phoenix":  {"name": "Last Stand",     "desc": "Once per run, a lethal hit leaves you at 50% HP instead.", "cost": "-25% max HP.", "mods": {"revive": 1, "max_hp_mult": -0.25}},
	"volatile": {"name": "Volatile Matter","desc": "Kills have a 25% chance to explode, hurting nearby enemies.", "cost": "Enemies deal +15% damage.", "mods": {"volatile": 0.25, "enemy_damage": 0.15}},
	"rounds":   {"name": "Heavy Rounds",   "desc": "+15 bonus damage on every hit.", "cost": "+15% cooldown.",            "mods": {"bonus": 15, "cooldown": 0.15}},
	"executioner": {"name": "Executioner", "desc": "+100% crit damage.",           "cost": "-10% crit chance.",           "mods": {"crit_dmg": 1.0, "crit": -0.10}},
	"fracture": {"name": "Fracture Core",  "desc": "Kills have a 20% chance to burst into 3 shards.", "cost": "Enemies have +10% HP.", "mods": {"shards": 0.20, "enemy_hp": 0.10}},
	"arc":      {"name": "Arc Coil",       "desc": "Hits have a 12% chance to arc to a nearby enemy.", "cost": "-10% damage.", "mods": {"arc": 0.12, "damage": -0.10}},
	"slipstream": {"name": "Slipstream",   "desc": "+30% all damage while moving.", "cost": "-15% all damage while standing still.", "mods": {"moving": 0.30, "standing": -0.15}},
	"overcharge": {"name": "Overcharge",   "desc": "Every 4th attack deals double damage.", "cost": "+10% cooldown.",     "mods": {"overcharge": 4, "cooldown": 0.10}},
}
const VOLATILE_RADIUS := 70.0
const VOLATILE_K := 0.6       # blast damage as a fraction of a weapon hit
const SHARD_K := 0.5
const ARC_K := 0.5            # Arc Coil arcs carry this share of the hit that caused them
const REVIVE_IFRAMES := 2.0

# ---------------------------------------------------------------- enemies
# behavior: chase, dash, shoot, split, elite, boss
# armor: flat damage removed from every hit (min 1).  cap: max damage per hit (0 = none).
# Colors stay inside the hostile violet-to-magenta band (see palette).
const ENEMIES := {
	"dot":      {"sides": 0, "radius": 7.0,  "hp": 4.0,   "speed": 100.0, "damage": 5.0,  "xp": 1, "mass": 0.6, "armor": 0.0, "cap": 0.0,  "color": Color(1.0, 0.3, 0.85), "behavior": "chase"},
	"shard":    {"sides": 3, "radius": 9.0,  "hp": 6.0,   "speed": 125.0, "damage": 5.0,  "xp": 1, "mass": 0.6, "armor": 0.0, "cap": 0.0,  "color": Color(0.7, 0.45, 1.0),  "behavior": "chase"},
	"darter":   {"sides": 3, "radius": 14.0, "hp": 14.0,  "speed": 75.0,  "damage": 10.0, "xp": 2, "mass": 0.8, "armor": 0.0, "cap": 0.0,  "color": Color(0.95, 0.6, 1.0), "behavior": "dash"},
	"hexagon":  {"sides": 6, "radius": 18.0, "hp": 32.0,  "speed": 62.0,  "damage": 10.0, "xp": 3, "mass": 1.2, "armor": 0.0, "cap": 0.0,  "color": Color(0.6, 0.35, 1.0),  "behavior": "split"},
	"pentagon": {"sides": 5, "radius": 16.0, "hp": 22.0,  "speed": 70.0,  "damage": 8.0,  "xp": 3, "mass": 1.0, "armor": 0.0, "cap": 0.0,  "color": Color(0.8, 0.3, 1.0),   "behavior": "shoot"},
	"brute":    {"sides": 4, "radius": 22.0, "hp": 70.0,  "speed": 52.0,  "damage": 16.0, "xp": 6, "mass": 3.0, "armor": 5.0, "cap": 0.0,  "color": Color(0.85, 0.2, 0.7),   "behavior": "chase"},
	"star":     {"sides": -5,"radius": 30.0, "hp": 650.0, "speed": 58.0,  "damage": 20.0, "xp": 30,"mass": 8.0, "armor": 0.0, "cap": 14.0, "color": Color(1.0, 0.4, 0.9),  "behavior": "elite"},
	"boss_tetra":{"sides": 4, "radius": 52.0, "hp": 3200.0, "speed": 80.0, "damage": 25.0, "xp": 80, "mass": 50.0, "armor": 3.0, "cap": 0.0, "color": Color(0.95, 0.3, 0.8), "behavior": "boss"},
	"boss_penta":{"sides": 5, "radius": 50.0, "hp": 2300.0, "speed": 70.0, "damage": 22.0, "xp": 80, "mass": 50.0, "armor": 3.0, "cap": 0.0, "color": Color(0.8, 0.4, 1.0), "behavior": "boss"},
	"boss_hex": {"sides": 6, "radius": 58.0, "hp": 11000.0,"speed": 80.0, "damage": 30.0, "xp": 150,"mass": 50.0, "armor": 4.0, "cap": 0.0, "color": Color(0.65, 0.35, 1.0), "behavior": "boss"},
	"boss_prism":{"sides": 8, "radius": 56.0, "hp": 7000.0,"speed": 60.0, "damage": 30.0, "xp": 150,"mass": 50.0, "armor": 4.0, "cap": 0.0, "color": Color(1.0, 0.35, 0.9), "behavior": "boss"},
	"boss_final":{"sides": 3, "radius": 70.0, "hp": 38000.0,"speed": 75.0, "damage": 35.0, "xp": 0, "mass": 80.0, "armor": 5.0, "cap": 0.0, "color": Color(1.0, 0.25, 0.75), "behavior": "boss"},
	"boss_void":{"sides": 0, "radius": 64.0, "hp": 36000.0,"speed": 55.0, "damage": 35.0, "xp": 0, "mass": 80.0, "armor": 5.0, "cap": 0.0, "color": Color(0.75, 0.3, 1.0), "behavior": "boss"},
}
# Boss roster. Each boss event picks one of its pool at random. `final` bosses end the run when killed.
const BOSSES := {
	"boss_tetra": {"name": "TETRAGON PRIME", "hint": "Chains three charges"},
	"boss_penta": {"name": "PENTARCH",       "hint": "Artillery: keep moving"},
	"boss_hex":   {"name": "HEXCORE",        "hint": "Spiral fortress"},
	"boss_prism": {"name": "OCTAPRISM",      "hint": "Sweeping lasers"},
	"boss_final": {"name": "THE POLYGON",    "hint": "Grows sides as it breaks", "final": true},
	"boss_void":  {"name": "THE SINGULARITY","hint": "Gravity pulls you in", "final": true},
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
	return 1.0 + t / 60.0 * 0.06

## Enemy HP multiplier over time (t in seconds).
static func enemy_hp_mult(t: float) -> float:
	return 1.0 + t / 60.0 * 0.25 + pow(t / 60.0, 2.0) * 0.028

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

# One-off events: swarm = ring of enemies around the player, elite = a Star, boss = one boss picked from `pool`.
const EVENTS := [
	{"t": 90,  "kind": "swarm", "type": "dot", "count": 30},
	{"t": 150, "kind": "elite", "type": "star"},
	{"t": 210, "kind": "swarm", "type": "darter", "count": 16},
	{"t": 300, "kind": "boss",  "pool": ["boss_tetra", "boss_penta"]},
	{"t": 380, "kind": "elite", "type": "star"},
	{"t": 450, "kind": "swarm", "type": "brute", "count": 14},
	{"t": 500, "kind": "elite", "type": "star"},
	{"t": 600, "kind": "boss",  "pool": ["boss_hex", "boss_prism"]},
	{"t": 690, "kind": "swarm", "type": "hexagon", "count": 22},
	{"t": 720, "kind": "elite", "type": "star"},
	{"t": 810, "kind": "elite", "type": "star"},
	{"t": 840, "kind": "swarm", "type": "dot", "count": 60},
	{"t": 900, "kind": "boss",  "pool": ["boss_final", "boss_void"]},
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
