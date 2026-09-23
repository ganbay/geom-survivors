class_name Weapon
extends RefCounted
## Base weapon. Stats come from Balance.WEAPONS, then get modified by Build (passives, resonance, overclocks).

const STAT_LABELS := {
	"damage": "%+d damage", "cooldown": "%+.2fs cooldown", "count": "%+d amount", "pierce": "%+d pierce",
	"area": "%+d%% area", "speed": "%+d%% speed", "duration": "%+d%% duration", "bounces": "%+d jumps",
}

var id: String
var data: Dictionary
var tags: Array
var level := 1
var evo := ""  # passive id this weapon evolved with ("" = not evolved)
var evolved: bool:
	get:
		return evo != ""
var game: Game
var s := {}          # final stats after all modifiers
var timer := 0.3
var src := 0         # source index for damage tracking


func init(g: Game, weapon_id: String) -> Weapon:
	game = g
	id = weapon_id
	data = Balance.WEAPONS[id]
	tags = data.tags
	src = game.bullets.source_id(display_name())
	return self


func display_name() -> String:
	return data.evolutions[evo].name if evolved else data.name


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func recompute() -> void:
	var st: Dictionary = (data.base as Dictionary).duplicate()
	for l in level - 1:
		var lv: Dictionary = data.levels[l]
		for k in lv:
			st[k] = st.get(k, 0) + lv[k]
	game.build.apply_mods(self, st)
	s = st


## Current damage per hit, including situational multipliers (e.g. Anchor).
func dmg() -> float:
	return s.damage * game.dynamic_damage_mult()


func update(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		timer += maxf(s.cooldown, 0.05)
		fire()


func fire() -> void:
	pass


func draw(_ci: CanvasItem) -> void:
	pass


func clear() -> void:
	pass


## Called when the player takes a hit.
func on_player_hurt() -> void:
	pass


## Text for the upgrade that takes this weapon from level `lv - 1` to `lv`.
static func level_text(weapon_id: String, lv: int) -> String:
	var d: Dictionary = Balance.WEAPONS[weapon_id]
	if lv <= 1:
		return d.desc
	var parts: PackedStringArray = []
	var deltas: Dictionary = d.levels[lv - 2]
	for k in deltas:
		var v = deltas[k]
		match k:
			"area", "speed", "duration":
				if weapon_id == "orbitals" and k == "speed":
					parts.append("+%d%% orbit speed" % int(v / 2.6 * 100.0))
				else:
					parts.append(STAT_LABELS[k] % int(v * 100.0))
			"count":
				parts.append("+%d %s" % [v, _count_word(weapon_id)])
			_:
				parts.append(STAT_LABELS[k] % v)
	return ", ".join(parts)


static func _count_word(weapon_id: String) -> String:
	match weapon_id:
		"orbitals": return "orbiter"
		"pulse_ring": return "ring"
		"line_laser": return "beam"
		"chain_arc": return "spark"
		"boomerang": return "rhombus"
		"mines": return "mine"
	return "projectile"


## Direction to aim at when nothing is targeted.
func facing() -> Vector2:
	return game.player.facing
