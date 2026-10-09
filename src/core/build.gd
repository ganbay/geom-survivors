class_name Build
extends RefCounted
## The player's build: one weapon, passives, overclocks, and the stat sheet they add up to.

const WEAPON_SCRIPTS := {
	"vertex_shot": preload("res://src/weapons/vertex_shot.gd"),
	"orbitals": preload("res://src/weapons/orbitals.gd"),
	"pulse_ring": preload("res://src/weapons/pulse_ring.gd"),
	"chain_arc": preload("res://src/weapons/chain_arc.gd"),
}

var game: Game
var character: Dictionary
var weapons: Array[Weapon] = []  # always one; kept as a list for the HUD, pause and history loops
var passives := {}            # id -> level
var choices := {}             # "<item id>:<level>" -> index of the option picked at that milestone
var overclocks: Array[String] = []
var banished := {}
var rerolls := Balance.REROLLS
var banishes := Balance.BANISHES
var skips := Balance.SKIPS

# derived stats
var sum := {}                 # every additive stat, summed over weapon levels, passives and overclocks
var atk_mult := 1.0
var cd_mult := 1.0
var crit := 0.0
var crit_mult := Balance.CRIT_MULT
var bonus := 0.0
var last_crit := false        # whether the most recent roll_hit() was a crit
var pickup_radius := 100.0
var max_hp := 100.0
var regen := 0.0
var move_speed := 200.0
var armor := 0.0
var taken_mult := 1.0
var xp_mult := 1.0
var offer_count := 3
var lifesteal := 0.0
var no_heal := false
var enemy_hp_bonus := 0.0
var enemy_speed_bonus := 0.0
var enemy_damage_bonus := 0.0
var heal_mult := 1.0
var has_revive := false
var revive_used := false
var echo := 0                 # every Nth attack fires twice (0 = off)
var overcharge := 0           # every Nth attack deals double (0 = off)
var haste_t := 0.0            # Adrenaline: time left on the cooldown cut


func _init(g: Game, char_id: String, depth_mods: Dictionary) -> void:
	game = g
	character = Balance.CHARACTERS[char_id]
	rerolls = maxi(0, Balance.REROLLS + int(depth_mods.get("rerolls", 0)))
	banishes = maxi(0, Balance.BANISHES + int(depth_mods.get("banishes", 0)))
	skips = maxi(0, Balance.SKIPS + int(depth_mods.get("skips", 0)))
	xp_mult = 1.0 + depth_mods.get("xp", 0.0)


func weapon(id: String) -> Weapon:
	for w in weapons:
		if w.id == id:
			return w
	return null


func add_weapon(id: String) -> void:
	var w: Weapon = WEAPON_SCRIPTS[id].new()
	w.init(game, id)
	weapons.append(w)
	recompute()


# ------------------------------------------------------------------ upgrade tables

## What reaching `level` of an item gives: a mods Dictionary, or an Array of options at a milestone.
static func level_entry(kind: String, id: String, level: int) -> Variant:
	if kind == "weapon":
		return Balance.WEAPONS[id].levels[level - 2] if level >= 2 else {}
	return Balance.PASSIVES[id].levels[level - 1]


## The options to pick from at this level ([] when it's a plain level).
static func level_options(kind: String, id: String, level: int) -> Array:
	var e: Variant = level_entry(kind, id, level)
	return e if e is Array else []


## The option taken at a milestone ({} if that level is plain or not reached).
func picked(kind: String, id: String, level: int) -> Dictionary:
	var opts := level_options(kind, id, level)
	var idx: int = choices.get("%s:%d" % [id, level], -1)
	return opts[idx] if idx >= 0 and idx < opts.size() else {}


## Names of the milestone options taken so far for one item, in level order.
func picked_names(kind: String, id: String, level: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for l in range(1, level + 1):
		var o := picked(kind, id, l)
		if not o.is_empty():
			out.append(o.name)
	return out


# ------------------------------------------------------------------ stats

func stat(key: String) -> float:
	return sum.get(key, 0.0)


func _add_mods(mods: Dictionary) -> void:
	for k in mods:
		if k == "cooldown":
			cd_mult *= 1.0 + mods[k]  # cooldown steps multiply, so they can never reach zero
		else:
			sum[k] = sum.get(k, 0.0) + mods[k]


func _add_levels(kind: String, id: String, level: int) -> String:
	var evo := ""
	for l in range(1, level + 1):
		var e: Variant = level_entry(kind, id, l)
		if e is Array:
			var o := picked(kind, id, l)
			_add_mods(o.get("mods", {}))
			evo = o.get("evo", evo)
		else:
			_add_mods(e)
	return evo


func recompute() -> void:
	sum = {}
	cd_mult = 1.0
	for w in weapons:
		var evo := _add_levels("weapon", w.id, w.level)
		if evo != w.evo:
			w.evo = evo
			w.src = game.bullets.source_id(w.display_name())
	for id in passives:
		_add_levels("passive", id, passives[id])
	for id in overclocks:
		_add_mods(Balance.OVERCLOCKS[id].mods)
	atk_mult = maxf(0.2, 1.0 + stat("damage"))
	crit = character.crit + stat("crit")
	crit_mult = Balance.CRIT_MULT + stat("crit_dmg")
	bonus = stat("bonus")
	pickup_radius = character.pickup * (1.0 + stat("pickup"))
	var old_max := max_hp
	max_hp = (character.hp + stat("max_hp")) * (1.0 + stat("max_hp_mult"))
	no_heal = sum.has("no_heal")
	regen = 0.0 if no_heal else stat("regen")
	move_speed = character.speed * (1.0 + stat("move"))
	armor = character.armor + stat("armor")
	taken_mult = 1.0 + stat("taken")
	offer_count = Balance.OFFER_COUNT + int(stat("offers"))
	lifesteal = stat("lifesteal")
	enemy_hp_bonus = stat("enemy_hp")
	enemy_speed_bonus = stat("enemy_speed")
	enemy_damage_bonus = stat("enemy_damage")
	heal_mult = maxf(0.0, 1.0 + stat("heal_mult"))
	has_revive = sum.has("revive")
	echo = int(stat("echo"))
	overcharge = int(stat("overcharge"))
	xp_mult = (1.0 + game.depth_mods.get("xp", 0.0)) * (1.0 + stat("xp"))
	for w in weapons:
		w.recompute()
	if game.player:
		game.player.on_max_hp_changed(old_max, max_hp)


## Cooldown factor from temporary effects (Adrenaline).
func haste_mult() -> float:
	return 1.0 - stat("hurt_haste") if haste_t > 0.0 else 1.0


## Final damage of one hit (see the formula in Balance). `k` scales weak secondary hits.
func roll_hit(weapon_damage: float, k := 1.0, force_crit := false) -> float:
	last_crit = force_crit or randf() < crit
	var d := weapon_damage * k * atk_mult
	if last_crit:
		d *= crit_mult
	return (d + bonus * k) * game.damage_mult()


## Rolls a hit and applies it to enemy `j`. Returns whether it was a crit.
func strike(j: int, weapon_damage: float, k: float, push_x: float, push_y: float, source: String, force_crit := false) -> bool:
	var amount := roll_hit(weapon_damage, k, force_crit)
	var was_crit := last_crit
	var en := game.enemies
	if was_crit and sum.has("crit_arc"):
		game.queue_arc(en.px[j], en.py[j], en.uid[j], amount * stat("crit_arc"))
	en.hit(j, amount, push_x, push_y, source)
	return was_crit


# ------------------------------------------------------------------ level-up offers

## Offer = {kind: "weapon"|"passive"|"heal", id, level (new level), new: bool}
func make_offers() -> Array:
	var pool: Array = []
	var weights: Array[float] = []
	for w in weapons:
		if w.level < Balance.WEAPON_MAX_LEVEL:
			pool.append({"kind": "weapon", "id": w.id, "level": w.level + 1, "new": false})
			weights.append(Balance.OFFER_W_WEAPON)
	for id in Balance.PASSIVES:
		if banished.has(id):
			continue
		var lv: int = passives.get(id, 0)
		if lv > 0:
			if lv < Balance.PASSIVE_MAX_LEVEL:
				pool.append({"kind": "passive", "id": id, "level": lv + 1, "new": false})
				weights.append(Balance.OFFER_W_OWNED_PASSIVE)
		elif passives.size() < Balance.MAX_PASSIVES:
			pool.append({"kind": "passive", "id": id, "level": 1, "new": true})
			weights.append(Balance.OFFER_W_NEW_PASSIVE)
	var count := maxi(1, offer_count)
	var offers: Array = []
	while offers.size() < count and not pool.is_empty():
		var total := 0.0
		for wt in weights:
			total += wt
		var r := randf() * total
		var pick := 0
		for k in weights.size():
			r -= weights[k]
			if r <= 0.0:
				pick = k
				break
		offers.append(pool[pick])
		pool.remove_at(pick)
		weights.remove_at(pick)
	if offers.is_empty():
		offers.append({"kind": "heal", "id": "heal", "level": 1, "new": false})
	return offers


## The pick-one cards for a milestone offer ([] when the offer's level is a plain one).
func make_option_offers(o: Dictionary) -> Array:
	var out := []
	if not o.kind in ["weapon", "passive"]:
		return out
	var opts := level_options(o.kind, o.id, o.level)
	for i in opts.size():
		out.append({"kind": "option", "item": o.kind, "id": o.id, "level": o.level, "index": i, "new": false})
	return out


## Core offers: a few random overclocks. Declining is always possible (see Game).
func make_overclock_offers() -> Array:
	var oc := available_overclocks()
	oc.shuffle()
	var offers: Array = []
	for id in oc.slice(0, Balance.OVERCLOCK_CHOICES):
		offers.append({"kind": "overclock", "id": id, "level": 1, "new": true})
	return offers


func available_overclocks() -> Array:
	var out := []
	for id in Balance.OVERCLOCKS:
		if overclocks.has(id) or banished.has(id):
			continue
		var only: Array = Balance.OVERCLOCKS[id].get("weapons", [])
		if only.is_empty() or (not weapons.is_empty() and only.has(weapons[0].id)):
			out.append(id)
	return out


func apply_offer(o: Dictionary) -> void:
	match o.kind:
		"weapon":
			weapon(o.id).level = o.level
		"passive":
			passives[o.id] = o.level
		"option":
			choices["%s:%d" % [o.id, o.level]] = o.index
			if o.item == "weapon":
				weapon(o.id).level = o.level
			else:
				passives[o.id] = o.level
		"overclock":
			overclocks.append(o.id)
		"heal":
			game.player.heal(game.build.max_hp * 0.3)
	recompute()


## Card text for a level-up offer.
func offer_text(o: Dictionary) -> String:
	var wid := weapons[0].id if not weapons.is_empty() else ""
	var opts := level_options(o.kind, o.id, o.level)
	if not opts.is_empty():
		var names: PackedStringArray = []
		for opt in opts:
			names.append(opt.name)
		return "Choose one: " + " / ".join(names)
	var text := Balance.mods_text(level_entry(o.kind, o.id, o.level), wid)
	if o.new:
		return "%s %s." % [Balance.PASSIVES[o.id].desc, text]
	return text + "."
