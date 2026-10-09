class_name Weapon
extends RefCounted
## Base weapon. Stats come from Balance.WEAPONS plus the build's stat sheet (levels, passives, overclocks).

var id: String
var data: Dictionary
var level := 1
var evo := ""  # form picked at level 10 ("" = not evolved); set by Build.recompute
var evolved: bool:
	get:
		return evo != ""
var game: Game
var s := {}          # final stats
var timer := 0.3
var src := 0         # source index for damage tracking
var attacks := 0
var charged := false # the current attack deals double (Overcharge)


func init(g: Game, weapon_id: String) -> Weapon:
	game = g
	id = weapon_id
	data = Balance.WEAPONS[id]
	src = game.bullets.source_id(display_name())
	return self


func display_name() -> String:
	if evolved:
		return game.build.picked("weapon", id, Balance.WEAPON_MAX_LEVEL).get("name", data.name)
	return data.name


func recompute() -> void:
	var b := game.build
	var base: Dictionary = data.base
	s = {
		"damage": maxf(base.damage + b.stat("wd"), 1.0),
		"cooldown": base.cooldown * b.cd_mult,
		"count": maxi(1, int(base.get("count", 1)) + int(b.stat("count"))),
		"pierce": int(base.get("pierce", 0)) + int(b.stat("pierce")),
		"bounces": int(base.get("bounces", 0)) + int(b.stat("bounces")),
		"area": maxf(0.3, 1.0 + b.stat("area")),
		"width": maxf(0.3, 1.0 + b.stat("width")),
		"speed": base.get("speed", 1.0) * maxf(0.3, 1.0 + b.stat("speed")),
		"duration": base.get("duration", 1.0),
		# Undertow flips every push into a pull
		"knockback": base.get("knockback", 0.0) * maxf(0.0, 1.0 + b.stat("knockback")) * (-1.0 if b.stat("pull") > 0.0 else 1.0),
	}


## Seconds between attacks right now.
func cooldown() -> float:
	return maxf(s.cooldown * game.build.haste_mult(), Balance.COOLDOWN_FLOOR)


## Sub-hit factor for the current attack: `mult`, doubled on an Overcharge attack.
func k(mult := 1.0) -> float:
	return mult * 2.0 if charged else mult


## Hits enemy `j` with this weapon. Returns whether it was a crit.
func strike(j: int, hit_k: float, push_x: float, push_y: float) -> bool:
	return game.build.strike(j, s.damage, hit_k, push_x, push_y, display_name())


func update(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		timer += cooldown()
		attack()


## One attack: counts it for Overcharge and Double Tap, then fires.
func attack() -> void:
	var b := game.build
	attacks += 1
	charged = b.overcharge > 0 and attacks % b.overcharge == 0
	fire()
	if b.echo > 0 and attacks % b.echo == 0:
		fire()
	charged = false


func fire() -> void:
	pass


func draw(_ci: CanvasItem) -> void:
	pass


func clear() -> void:
	pass


## Called when the player takes a hit.
func on_player_hurt() -> void:
	pass
