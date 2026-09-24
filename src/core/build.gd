class_name Build
extends RefCounted
## The player's build: weapons, passives, overclocks, resonance tiers and the stats they produce.

const WEAPON_SCRIPTS := {
	"vertex_shot": preload("res://src/weapons/vertex_shot.gd"),
	"orbitals": preload("res://src/weapons/orbitals.gd"),
	"pulse_ring": preload("res://src/weapons/pulse_ring.gd"),
	"line_laser": preload("res://src/weapons/line_laser.gd"),
	"chain_arc": preload("res://src/weapons/chain_arc.gd"),
	"boomerang": preload("res://src/weapons/boomerang.gd"),
	"mines": preload("res://src/weapons/mines.gd"),
	"fractal": preload("res://src/weapons/fractal.gd"),
}

var game: Game
var character: Dictionary
var weapons: Array[Weapon] = []
var passives := {}            # id -> level
var overclocks: Array[String] = []
var banished := {}
var claimed := {}             # passive id -> weapon id that evolved with it
var rerolls := Balance.REROLLS
var banishes := Balance.BANISHES
var skips := Balance.SKIPS

# derived stats
var dmg_mult := 1.0
var cd_mult := 1.0
var area_mult := 1.0
var speed_mult := 1.0
var dur_mult := 1.0
var extra_count := 0
var extra_pierce := 0
var crit := 0.0
var pickup_radius := 100.0
var max_hp := 100.0
var regen := 0.0
var move_speed := 200.0
var armor := 0.0
var taken_mult := 1.0
var xp_mult := 1.0
var offer_count := 3
var anchor := 0.0
var lifesteal := 0.0
var no_heal := false
var enemy_hp_bonus := 0.0
var enemy_speed_bonus := 0.0
var enemy_damage_bonus := 0.0
var redline := 0.0
var heal_mult := 1.0
var resonance_bonus := 0
var volatile := 0.0
var has_revive := false
var revive_used := false
var tag_counts := {}
var tiers := {}


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


func tier(tag: String) -> int:
	return tiers.get(tag, 0)


func add_weapon(id: String) -> void:
	var w: Weapon = WEAPON_SCRIPTS[id].new()
	w.init(game, id)
	weapons.append(w)
	recompute()


# ------------------------------------------------------------------ stats

func recompute() -> void:
	var sum := {}
	for id in passives:
		var per: Dictionary = Balance.PASSIVES[id].per_level
		for k in per:
			sum[k] = sum.get(k, 0.0) + per[k] * passives[id]
	for id in overclocks:
		var mods: Dictionary = Balance.OVERCLOCKS[id].mods
		for k in mods:
			sum[k] = sum.get(k, 0.0) + mods[k]
	dmg_mult = maxf(0.2, 1.0 + sum.get("damage", 0.0))
	cd_mult = maxf(0.35, 1.0 + sum.get("cooldown", 0.0))
	area_mult = 1.0 + sum.get("area", 0.0)
	speed_mult = 1.0 + sum.get("speed", 0.0)
	dur_mult = 1.0 + sum.get("duration", 0.0)
	extra_count = int(sum.get("count", 0))
	extra_pierce = int(sum.get("pierce", 0))
	crit = character.crit + sum.get("crit", 0.0)
	pickup_radius = character.pickup * (1.0 + sum.get("pickup", 0.0))
	var old_max := max_hp
	max_hp = (character.hp + sum.get("max_hp", 0.0)) * (1.0 + sum.get("max_hp_mult", 0.0))
	regen = 0.0 if sum.has("no_heal") else sum.get("regen", 0.0)
	move_speed = character.speed * (1.0 + sum.get("move", 0.0))
	armor = character.armor + sum.get("armor", 0.0)
	taken_mult = 1.0 + sum.get("taken", 0.0)
	offer_count = Balance.OFFER_COUNT + int(sum.get("offers", 0))
	anchor = sum.get("anchor", 0.0)
	lifesteal = sum.get("lifesteal", 0.0)
	no_heal = sum.has("no_heal")
	enemy_hp_bonus = sum.get("enemy_hp", 0.0)
	enemy_speed_bonus = sum.get("enemy_speed", 0.0)
	enemy_damage_bonus = sum.get("enemy_damage", 0.0)
	redline = sum.get("redline", 0.0)
	heal_mult = maxf(0.0, 1.0 + sum.get("heal_mult", 0.0))
	resonance_bonus = int(sum.get("resonance", 0))
	volatile = sum.get("volatile", 0.0)
	has_revive = sum.has("revive")
	var xp_bonus: float = sum.get("xp", 0.0)
	xp_mult = (1.0 + game.depth_mods.get("xp", 0.0)) * (1.0 + xp_bonus)
	tag_counts = count_tags()
	tiers.clear()
	for tag in tag_counts:
		tiers[tag] = tier_for(tag_counts[tag])
	for w in weapons:
		w.recompute()
	if game.player:
		game.player.on_max_hp_changed(old_max, max_hp)


static func tier_for(count: int) -> int:
	var t := 0
	for th in Balance.RESONANCE_THRESHOLDS:
		if count >= th:
			t += 1
	return t


func count_tags(extra_tags: Array = []) -> Dictionary:
	var c := {}
	for w in weapons:
		for tag in w.tags:
			c[tag] = c.get(tag, 0) + 1
	for id in passives:
		for tag in Balance.PASSIVES[id].tags:
			c[tag] = c.get(tag, 0) + 1
	for tag in extra_tags:
		c[tag] = c.get(tag, 0) + 1
	if resonance_bonus > 0:
		for tag in c:
			c[tag] += resonance_bonus
	return c


## Applies global modifiers to one weapon's stat dictionary.
func apply_mods(w: Weapon, st: Dictionary) -> void:
	st.damage = st.damage * dmg_mult
	st.cooldown = st.cooldown * cd_mult
	st.count = st.get("count", 1) + extra_count
	st.area = st.get("area", 1.0) * area_mult
	st.speed = st.get("speed", 0.0) * speed_mult
	st.duration = st.get("duration", 1.0) * dur_mult
	st.pierce = st.get("pierce", 0) + extra_pierce
	st.bounces = st.get("bounces", 0)
	st.knockback = st.get("knockback", 50.0)
	if w.has_tag("VERTEX") and tier("VERTEX") >= 1:
		st.pierce += 1
	if w.has_tag("ORBIT") and tier("ORBIT") >= 1:
		st.count += 1
	if w.has_tag("PULSE") and tier("PULSE") >= 1:
		st.area *= 1.2
	if w.has_tag("CHAIN") and tier("CHAIN") >= 1:
		st.bounces += 2
	if w.id == "fractal":
		st.pierce = 0  # fractal splits instead of piercing
	if w.id == "pulse_ring":
		st.count -= extra_count  # rings only come from its own level-ups


func vertex_flags() -> int:
	return Bullets.F_SPLIT_KILL if tier("VERTEX") >= 2 else 0


# ------------------------------------------------------------------ evolution

## All possible evolutions right now: [{weapon, passive}] for max-level weapons x max-level, unclaimed keys.
func evolution_options() -> Array:
	var out := []
	for w in weapons:
		if w.evolved or w.level < Balance.WEAPON_MAX_LEVEL:
			continue
		for pid in w.data.evolutions:
			if passive_maxed(pid) and not claimed.has(pid):
				out.append({"weapon": w, "passive": pid})
	return out


func passive_maxed(pid: String) -> bool:
	return passives.get(pid, 0) >= Balance.PASSIVES[pid].max


func evolve(w: Weapon, passive_id: String) -> void:
	w.evo = passive_id
	claimed[passive_id] = w.id
	w.src = game.bullets.source_id(w.display_name())
	recompute()


## Status line for one evolution path of a weapon.
func evolution_status(weapon_id: String, pid: String) -> String:
	var evo_name: String = Balance.WEAPONS[weapon_id].evolutions[pid].name
	var pname: String = Balance.PASSIVES[pid].name
	if claimed.has(pid):
		if claimed[pid] == weapon_id:
			return "✦ %s (evolved)" % evo_name
		return "✗ %s — %s taken by %s" % [evo_name, pname, _weapon_name(claimed[pid])]
	if passive_maxed(pid):
		return "✓ %s ← %s (max)" % [evo_name, pname]
	if passives.has(pid):
		return "· %s ← %s %d/%d (needs max)" % [evo_name, pname, passives[pid], Balance.PASSIVES[pid].max]
	return "· %s ← %s" % [evo_name, pname]


func _weapon_name(id: String) -> String:
	var w := weapon(id)
	return w.display_name() if w else Balance.WEAPONS[id].name


# ------------------------------------------------------------------ level-up offers

## Offer = {kind: "weapon"|"passive"|"evolve"|"heal", id, level (new level), new: bool}
## Level-up offers. Evolutions join the pool once a weapon and its key passive are both maxed.
func make_offers() -> Array:
	var pool: Array = []
	var weights: Array[float] = []
	for opt in evolution_options():
		var ew: Weapon = opt.weapon
		pool.append({"kind": "evolve", "id": ew.id, "passive": opt.passive, "level": ew.level, "new": false})
		weights.append(Balance.OFFER_W_EVOLUTION)
	for id in Balance.WEAPONS:
		if banished.has(id):
			continue
		var w := weapon(id)
		if w:
			if w.level < Balance.WEAPON_MAX_LEVEL:
				pool.append({"kind": "weapon", "id": id, "level": w.level + 1, "new": false})
				weights.append(Balance.OFFER_W_OWNED_WEAPON)
		elif weapons.size() < Balance.MAX_WEAPONS:
			pool.append({"kind": "weapon", "id": id, "level": 1, "new": true})
			weights.append(Balance.OFFER_W_NEW_WEAPON)
	for id in Balance.PASSIVES:
		if banished.has(id):
			continue
		var lv: int = passives.get(id, 0)
		if lv > 0:
			if lv < Balance.PASSIVES[id].max:
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
		if not overclocks.has(id) and not banished.has(id):
			out.append(id)
	return out


func apply_offer(o: Dictionary) -> void:
	match o.kind:
		"weapon":
			if o.new:
				add_weapon(o.id)
			else:
				weapon(o.id).level += 1
		"passive":
			passives[o.id] = passives.get(o.id, 0) + 1
		"overclock":
			overclocks.append(o.id)
		"heal":
			game.player.heal(game.build.max_hp * 0.3)
	recompute()


func offer_tags(o: Dictionary) -> Array:
	match o.kind:
		"weapon":
			return Balance.WEAPONS[o.id].tags
		"passive":
			return Balance.PASSIVES[o.id].tags
	return []


## Human-readable synergy hints for an offer: resonance progress and evolution links.
func offer_hints(o: Dictionary) -> Array[String]:
	var hints: Array[String] = []
	if o.new:
		var tags := offer_tags(o)
		var after := count_tags(tags)
		for tag in tags:
			var before_n: int = tag_counts.get(tag, 0)
			var after_n: int = after[tag]
			var bt := tier_for(before_n)
			var at := tier_for(after_n)
			if at > bt:
				hints.append("★ %s %d→%d: %s" % [tag, before_n, after_n, Balance.RESONANCE[tag][at - 1]])
			else:
				var next_th := 0
				for th in Balance.RESONANCE_THRESHOLDS:
					if after_n < th:
						next_th = th
						break
				if next_th > 0:
					hints.append("%s %d/%d" % [tag, after_n, next_th])
	match o.kind:
		"weapon":
			# show all three evolution paths and whether their keys are available
			if o.new or o.level == Balance.WEAPON_MAX_LEVEL:
				for pid in Balance.WEAPONS[o.id].evolutions:
					hints.append(evolution_status(o.id, pid))
		"passive":
			if not o.new and o.level >= Balance.PASSIVES[o.id].max and not claimed.has(o.id):
				for wid in Balance.WEAPONS:
					var w := weapon(wid)
					if w and not w.evolved and Balance.WEAPONS[wid].evolutions.has(o.id):
						hints.append("✦ Max level: unlocks %s for %s" % [Balance.WEAPONS[wid].evolutions[o.id].name, w.data.name])
			if o.new:
				if claimed.has(o.id):
					hints.append("Evolution key already used by %s" % _weapon_name(claimed[o.id]))
				else:
					for wid in Balance.WEAPONS:
						var evos: Dictionary = Balance.WEAPONS[wid].evolutions
						if evos.has(o.id):
							var owned := weapon(wid) != null and not weapon(wid).evolved
							hints.append("%s Key for %s → %s" % ["✦" if owned else "·", Balance.WEAPONS[wid].name, evos[o.id].name])
	return hints
