class_name Director
extends RefCounted
## Spawns enemies over time from Balance.WAVES and Balance.EVENTS.

const BOSS_NAMES := {"boss_tetra": "TETRAGON PRIME", "boss_hex": "HEXCORE", "boss_final": "THE POLYGON"}

var game: Game
var spawn_timer := 0.5
var event_idx := 0
var hp_mult := 1.0
var cap := Balance.ENEMY_SOFT_CAP
var depth_hp := 0.0
var boss_hp := 0.0
var elite_count := 1
var depth_damage := 1.0


func _init(g: Game) -> void:
	game = g
	depth_hp = game.depth_mods.get("enemy_hp", 0.0)
	boss_hp = game.depth_mods.get("boss_hp", 0.0)
	elite_count = 2 if game.depth_mods.has("elite_double") else 1
	depth_damage = 1.0 + game.depth_mods.get("enemy_damage", 0.0)


func phase() -> Dictionary:
	var p: Dictionary = Balance.WAVES[0]
	for w in Balance.WAVES:
		if game.time >= w.t:
			p = w
	return p


func update(delta: float) -> void:
	var t := game.time
	hp_mult = Balance.enemy_hp_mult(t) * (1.0 + depth_hp + game.build.enemy_hp_bonus)
	game.enemies.damage_mult = depth_damage * Balance.enemy_damage_mult(t)
	var ph := phase()
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer += ph.interval
		var limit := mini(ph.max, cap)
		var types: Dictionary = ph.types
		for k in ph.batch:
			if game.enemies.n >= limit:
				break
			var id := _weighted(types)
			var p := spawn_point(Balance.ENEMIES[id].radius)
			game.enemies.spawn(id, p.x, p.y, hp_mult)
	while event_idx < Balance.EVENTS.size() and Balance.EVENTS[event_idx].t <= t:
		_run_event(Balance.EVENTS[event_idx])
		event_idx += 1


func _run_event(e: Dictionary) -> void:
	match e.kind:
		"swarm":
			var count: int = e.count
			var r := game.view_radius() + 40.0
			var c := game.player.position
			for k in count:
				var a := TAU * k / count
				game.enemies.spawn(e.type, c.x + cos(a) * r, c.y + sin(a) * r, hp_mult)
			game.hud.banner("SWARM", Balance.C_DANGER, 1.5)
		"elite":
			for k in elite_count:
				var p := spawn_point(40.0)
				game.enemies.spawn(e.type, p.x, p.y, hp_mult * 0.5 + 0.5)
			game.hud.banner("ELITE STAR — DROPS A CORE", Balance.C_GOLD, 2.0)
		"boss":
			var p := spawn_point(80.0)
			var mult := (1.0 + depth_hp) * (1.0 + boss_hp)
			game.enemies.spawn(e.type, p.x, p.y, mult)
			game.hud.banner("⚠ " + BOSS_NAMES[e.type], Balance.C_DANGER, 3.0)
			game.fx.shake(8.0)
			Sfx.play("boss")


func _weighted(types: Dictionary) -> String:
	var total := 0.0
	for id in types:
		total += types[id]
	var r := randf() * total
	for id in types:
		r -= types[id]
		if r <= 0.0:
			return id
	return types.keys()[0]


## Random point just outside the visible area, slightly biased toward where the player is heading.
func spawn_point(margin: float) -> Vector2:
	var half := game.view_size() * 0.5 + Vector2(margin + 30.0, margin + 30.0)
	var c := game.player.position
	var v := game.player.velocity
	if v.length_squared() > 100.0 and randf() < 0.35:
		# ahead of the player
		var dir := v.normalized().rotated(randf_range(-0.7, 0.7))
		var tx := half.x / maxf(absf(dir.x), 0.001)
		var ty := half.y / maxf(absf(dir.y), 0.001)
		return c + dir * minf(tx, ty)
	var per := 2.0 * (half.x + half.y)
	var r := randf() * per * 2.0
	if r < half.x * 2.0:
		return c + Vector2(-half.x + r, -half.y)
	r -= half.x * 2.0
	if r < half.x * 2.0:
		return c + Vector2(-half.x + r, half.y)
	r -= half.x * 2.0
	if r < half.y * 2.0:
		return c + Vector2(-half.x, -half.y + r)
	r -= half.y * 2.0
	return c + Vector2(half.x, -half.y + r)
