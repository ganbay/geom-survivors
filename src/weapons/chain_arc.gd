extends Weapon
## A spark leaves the Spark's nearest point, hits the nearest enemy, then jumps between nearby enemies.
## A jump can go to any enemy except the one it just hit, so a spark can come back to the same enemy.
## `speed` scales the jump range, `area` the targeting range and blast size.
## Level-10 forms: cascade = Cascade (each jump hits harder) · detonate = Detonation (no jumps: a blast on the
##                 first target that grows with the jump count) · field = Static Field (enemy bullets that
##                 miss the player throw a spark).

const TARGET_RANGE := 420.0
const JUMP_RANGE := 150.0

# Detonation: sparks still to go off, as [delay, rank among the nearest enemies, k]
var pending: Array = []


func update(delta: float) -> void:
	super.update(delta)
	for i in range(pending.size() - 1, -1, -1):
		var d: Array = pending[i]
		d[0] -= delta
		if d[0] <= 0.0:
			pending.remove_at(i)
			# aimed when it goes off, so a spark never wastes itself on an enemy that already died
			var en := game.enemies
			var near := en.nearest_to_player(int(d[1]) + 1, TARGET_RANGE * s.area)
			if not near.is_empty():
				var j := _ranked(near, int(d[1]))
				_detonate(game.player.tip_near(Vector2(en.px[j], en.py[j])), j, d[2])
				Sfx.play("boom")


## The enemy at `rank` when `near` is ordered by distance to the player (the last one if there are fewer).
func _ranked(near: PackedInt32Array, rank: int) -> int:
	var order := Array(near)
	order.sort_custom(func(a, b): return game.enemies.pd2[a] < game.enemies.pd2[b])
	return order[mini(rank, order.size() - 1)]


func fire() -> void:
	var count := int(s.count)
	var en := game.enemies
	var starts := en.nearest_to_player(count, TARGET_RANGE * s.area)
	if starts.is_empty():
		timer = 0.2  # retry soon instead of wasting the cooldown
		return
	if evo == "detonate":
		# each spark goes off a moment after the last one, at the next-nearest enemy
		for i in count:
			pending.append([i * Balance.DETONATE_GAP, i % starts.size(), k()])
		return
	for i in count:
		var j := starts[i % starts.size()]
		_spark(game.player.tip_near(Vector2(en.px[j], en.py[j])), j, int(s.bounces), k())
	Sfx.play("zap")


func _spark(from: Vector2, first: int, hops: int, hit_k: float) -> void:
	var en := game.enemies
	var jump: float = JUMP_RANGE * s.speed
	var gain := 1.0 + Balance.CASCADE_GAIN if evo == "cascade" else 1.0
	var last := PackedInt32Array([0])
	var pts := PackedVector2Array([from])
	var j := first
	for h in hops + 1:
		if j < 0:
			break
		last[0] = en.uid[j]
		var pos := Vector2(en.px[j], en.py[j])
		var push: Vector2 = (pos - pts[pts.size() - 1]).normalized() * s.knockback
		pts.append(pos)
		strike(j, hit_k, push.x, push.y)
		hit_k *= gain
		j = en.nearest_to(pos.x, pos.y, jump, last)
	game.fx.line(_jagged(pts), Balance.C_WEAPON, 0.16, 2.5)


## Detonation: no jumps. The spark blows up on its target; every jump the weapon has widens the blast.
func _detonate(from: Vector2, target: int, hit_k: float) -> void:
	var en := game.enemies
	var pos := Vector2(en.px[target], en.py[target])
	var r: float = (Balance.DETONATE_RADIUS + Balance.DETONATE_PER_JUMP * int(s.bounces)) * s.area
	var c := en.query(pos.x, pos.y, r)
	var hits := en.qbuf.slice(0, c)
	for j in hits:
		var push: Vector2 = (Vector2(en.px[j], en.py[j]) - pos).normalized() * s.knockback
		strike(j, hit_k * Balance.DETONATE_K, push.x, push.y)
	game.fx.line(_jagged(PackedVector2Array([from, pos])), Balance.C_WEAPON, 0.16, 2.5)
	game.fx.ring(pos.x, pos.y, r, Balance.C_WEAPON, 0.3, 4.0)


## Static Field: a bullet that missed throws one spark at the nearest enemy.
func on_bullet_missed() -> void:
	var en := game.enemies
	var starts := en.nearest_to_player(1, TARGET_RANGE * s.area)
	for j in starts:
		_spark(game.player.tip_near(Vector2(en.px[j], en.py[j])), j, int(s.bounces), 1.0)
		Sfx.play("zap", 1.3)


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


func clear() -> void:
	pending.clear()
