extends Weapon
## A spark hits the nearest enemy, then jumps between nearby enemies.
## Evolutions: frequency = Tesla Grid (no falloff, long jumps, faster) · entropy = Thunderstorm (random strikes)
##             hull = Static Skin (shock everything near you; discharge when hit).

var hurt_cd := 0.0


func update(delta: float) -> void:
	super.update(delta)
	hurt_cd -= delta


func fire() -> void:
	match evo:
		"entropy":
			_storm()
			return
		"hull":
			_discharge(1.0)
			timer = s.cooldown * 0.7
			return
	var count := int(s.count)
	var starts := game.enemies.nearest_to_player(count, 420.0)
	if starts.is_empty():
		timer = 0.2  # retry soon instead of wasting the cooldown
		return
	for k in count:
		_spark(game.player.position, starts[k % starts.size()], int(s.bounces), dmg())
	if evo == "frequency":
		timer = s.cooldown * 0.7
	Sfx.play("zap")


func _spark(from: Vector2, first: int, hops: int, d: float) -> void:
	var en := game.enemies
	var jump: float = 150.0 * s.area * (2.0 if evo == "frequency" else 1.0)
	var visited := PackedInt32Array()
	var pts := PackedVector2Array([from])
	var j := first
	for h in hops + 1:
		if j < 0:
			break
		visited.append(en.uid[j])
		var pos := Vector2(en.px[j], en.py[j])
		pts.append(pos)
		var crit := randf() < game.build.crit
		en.hit(j, d * (Balance.CRIT_MULT if crit else 1.0), 0.0, 0.0, display_name())
		if evo != "frequency":
			d *= 0.88
		j = en.nearest_to(pos.x, pos.y, jump, visited)
	game.fx.line(_jagged(pts), Balance.TAG_COLORS.CHAIN, 0.16, 2.5)


## Thunderstorm: bolts from the sky on random enemies anywhere on screen.
func _storm() -> void:
	var en := game.enemies
	if en.n == 0:
		timer = 0.2
		return
	var strikes := 2 + int(s.count) * 2
	var view2 := pow(game.view_radius() * 0.8, 2.0)
	var blast: float = 55.0 * s.area
	for k in strikes:
		var j := -1
		for attempt in 12:
			var cand := randi() % en.n
			if not en.dead[cand] and en.pd2[cand] < view2:
				j = cand
				break
		if j < 0:
			continue
		var pos := Vector2(en.px[j], en.py[j])
		var c := en.query(pos.x, pos.y, blast)
		var targets := en.qbuf.slice(0, c)
		var crit := randf() < game.build.crit
		for t in targets:
			en.hit(t, dmg() * 1.3 * (Balance.CRIT_MULT if crit else 1.0), 0.0, 0.0, display_name())
		game.fx.line(_jagged(PackedVector2Array([pos + Vector2(randf_range(-60, 60), -520), pos])), Balance.TAG_COLORS.CHAIN, 0.2, 3.0)
		game.fx.ring(pos.x, pos.y, blast, Balance.TAG_COLORS.CHAIN, 0.25)
		if crit and int(s.bounces) > 0:
			var nxt := en.nearest_to(pos.x, pos.y, 150.0, PackedInt32Array())
			if nxt >= 0:
				_spark(pos, nxt, 2, dmg() * 0.6)
	Sfx.play("zap", 0.7)


## Static Skin: shock every enemy close to the player at once.
func _discharge(mult: float) -> void:
	var en := game.enemies
	var p := game.player.position
	var r: float = 210.0 * s.area
	var c := en.query(p.x, p.y, r)
	var targets := en.qbuf.slice(0, mini(c, 10 + int(s.bounces) * 2))
	mult *= 1.6
	for j in targets:
		var pos := Vector2(en.px[j], en.py[j])
		var dir := (pos - p).normalized()
		var crit := randf() < game.build.crit
		en.hit(j, dmg() * mult * (Balance.CRIT_MULT if crit else 1.0), dir.x * 120.0, dir.y * 120.0, display_name())
		game.fx.line(_jagged(PackedVector2Array([p, pos])), Balance.TAG_COLORS.CHAIN, 0.14, 2.0)
	game.fx.ring(p.x, p.y, r, Color(Balance.TAG_COLORS.CHAIN, 0.6), 0.2, 2.0)
	if not targets.is_empty():
		Sfx.play("zap", 1.2)


func on_player_hurt() -> void:
	if evo == "hull" and hurt_cd <= 0.0:
		hurt_cd = 0.4
		_discharge(2.0)


static func _jagged(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		out.append(a)
		var nrm := (b - a).orthogonal().normalized()
		for k in [0.33, 0.66]:
			out.append(a.lerp(b, k) + nrm * randf_range(-10.0, 10.0))
	out.append(pts[pts.size() - 1])
	return out
