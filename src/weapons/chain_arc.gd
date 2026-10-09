extends Weapon
## A spark leaves the Spark's nearer tip, hits the nearest enemy, then jumps between nearby enemies.
## `speed` scales the jump range, `area` the targeting range and blast sizes.
## Level-10 forms: tesla = Tesla Grid (no falloff, long jumps, faster) · storm = Thunderstorm (strikes nearest enemies)
##                 skin = Static Skin (shock everything near you; discharge when hit).

const TARGET_RANGE := 420.0
const JUMP_RANGE := 150.0

var hurt_cd := 0.0


func update(delta: float) -> void:
	super.update(delta)
	hurt_cd -= delta


func fire() -> void:
	match evo:
		"storm":
			_storm()
			return
		"skin":
			_discharge(1.0)
			timer = cooldown() * 0.7
			return
	var count := int(s.count)
	var en := game.enemies
	var starts := en.nearest_to_player(count, TARGET_RANGE * s.area)
	if starts.is_empty():
		timer = 0.2  # retry soon instead of wasting the cooldown
		return
	for i in count:
		var j := starts[i % starts.size()]
		_spark(game.player.tip_near(Vector2(en.px[j], en.py[j])), j, int(s.bounces), k())
	if evo == "tesla":
		timer = cooldown() * 0.75
	Sfx.play("zap")


func _spark(from: Vector2, first: int, hops: int, hit_k: float) -> void:
	var en := game.enemies
	var jump: float = JUMP_RANGE * s.speed * (2.0 if evo == "tesla" else 1.0)
	var keep := 1.0 if evo == "tesla" else 1.0 - maxf(0.0, Balance.CHAIN_FALLOFF + game.build.stat("falloff"))
	var visited := PackedInt32Array()
	var pts := PackedVector2Array([from])
	var j := first
	for h in hops + 1:
		if j < 0:
			break
		visited.append(en.uid[j])
		var pos := Vector2(en.px[j], en.py[j])
		var push: Vector2 = (pos - pts[pts.size() - 1]).normalized() * s.knockback
		pts.append(pos)
		strike(j, hit_k, push.x, push.y)
		hit_k *= keep
		j = en.nearest_to(pos.x, pos.y, jump, visited)
	game.fx.line(_jagged(pts), Balance.C_WEAPON, 0.16, 2.5)


## Thunderstorm: bolts from the sky on the enemies closest to the player. With fewer enemies
## than bolts, the closest ones get struck again.
func _storm() -> void:
	var en := game.enemies
	var strikes := 2 + int(s.count) * 2
	var targets := en.nearest_to_player(strikes, game.view_radius() * 0.8)
	if targets.is_empty():
		timer = 0.2
		return
	var blast: float = 55.0 * s.area
	for i in strikes:
		var j := targets[i % targets.size()]
		if en.dead[j]:
			continue  # already killed by an earlier bolt's blast
		var pos := Vector2(en.px[j], en.py[j])
		var c := en.query(pos.x, pos.y, blast)
		var hits := en.qbuf.slice(0, c)
		var crit := false
		for t in hits:
			crit = strike(t, k(0.8), 0.0, 0.0) or crit
		game.fx.line(_jagged(PackedVector2Array([pos + Vector2(randf_range(-60, 60), -520), pos])), Balance.C_WEAPON, 0.2, 3.0)
		game.fx.ring(pos.x, pos.y, blast, Balance.C_WEAPON, 0.25)
		if crit and int(s.bounces) > 0:
			var nxt := en.nearest_to(pos.x, pos.y, JUMP_RANGE * s.speed, PackedInt32Array())
			if nxt >= 0:
				_spark(pos, nxt, 2, k(0.6))
	Sfx.play("zap", 0.7)


## Static Skin: shock every enemy close to the player at once.
func _discharge(mult: float) -> void:
	var en := game.enemies
	var p := game.player.position
	var r: float = 210.0 * s.area
	var c := en.query(p.x, p.y, r)
	var targets := en.qbuf.slice(0, mini(c, 10 + int(s.bounces) * 2))
	var push: float = 120.0 * signf(s.knockback)
	for j in targets:
		var pos := Vector2(en.px[j], en.py[j])
		var dir := (pos - p).normalized()
		strike(j, k(mult * 1.6), dir.x * push, dir.y * push)
		game.fx.line(_jagged(PackedVector2Array([game.player.tip_near(pos), pos])), Balance.C_WEAPON, 0.14, 2.0)
	game.fx.ring(p.x, p.y, r, Color(Balance.C_WEAPON, 0.6), 0.2, 2.0)
	if not targets.is_empty():
		Sfx.play("zap", 1.2)


func on_player_hurt() -> void:
	if evo == "skin" and hurt_cd <= 0.0:
		hurt_cd = 0.4
		_discharge(2.0)


static func _jagged(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		out.append(a)
		var nrm := (b - a).orthogonal().normalized()
		for f in [0.33, 0.66]:
			out.append(a.lerp(b, f) + nrm * randf_range(-10.0, 10.0))
	out.append(pts[pts.size() - 1])
	return out
