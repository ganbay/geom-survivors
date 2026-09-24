extends Weapon
## Lobs grenades at the nearest enemies; they explode where they land.
## Evolutions: hull = Fortress (grenades land as turrets) · density = Singularity (black-hole grenade)
##             sides = Minefield (no throwing: trail of small chain-reacting mines while moving).

const ARM_TIME := 0.5
const TRIGGER_R := 26.0
const PULL_TIME := 0.7
const FLIGHT_TIME := 0.45
const THROW_RANGE := 420.0
const ARC_HEIGHT := 60.0

# grenades in the air: {from, to, t}
var grenades: Array = []
# things on the ground: {pos, age, fuse (-1 = idle), shot (turret timer)}
var mines: Array = []
var trail_t := 0.0


func max_mines() -> int:
	match evo:
		"sides": return 26
		"hull": return 4 + int(s.count)
	return 6


func fire() -> void:
	if evo == "sides":
		return  # Minefield drops mines from update() while moving
	var throws := 1 if evo == "density" else int(s.count)
	var targets := game.enemies.nearest_to_player(throws, THROW_RANGE)
	if targets.is_empty():
		timer = 0.2  # retry soon instead of wasting the cooldown
		return
	var p := game.player.position
	for k in throws:
		var j := targets[k % targets.size()]
		var to := Vector2(game.enemies.px[j], game.enemies.py[j])
		if k >= targets.size():
			to += Vector2.from_angle(randf() * TAU) * 50.0
		grenades.append({"from": p, "to": to, "t": 0.0})
	Sfx.play("shoot", 0.5)


func _place(pos: Vector2) -> Dictionary:
	var m := {"pos": pos, "age": 0.0, "fuse": -1.0, "shot": 0.3}
	mines.append(m)
	if mines.size() > max_mines():
		mines.pop_front()
	return m


func _land(pos: Vector2) -> void:
	match evo:
		"hull":
			_place(pos)
		"density":
			_place(pos).fuse = PULL_TIME
		_:
			_explode(pos)


func update(delta: float) -> void:
	super.update(delta)
	for k in range(grenades.size() - 1, -1, -1):
		var g: Dictionary = grenades[k]
		g.t += delta
		if g.t >= FLIGHT_TIME:
			grenades.remove_at(k)
			_land(g.to)
	if evo == "sides" and not game.player.is_still():
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = maxf(0.28 * s.cooldown / 1.5, 0.12)
			_place(game.player.position - game.player.facing * 24.0)
	var en := game.enemies
	var life: float = 6.0 if evo == "hull" else s.duration
	var k := mines.size() - 1
	while k >= 0:
		if k >= mines.size():
			k -= 1
			continue
		var m: Dictionary = mines[k]
		m.age += delta
		if m.age > life and m.fuse < 0.0:
			mines.remove_at(k)
			k -= 1
			continue
		var pos: Vector2 = m.pos
		if evo == "hull":
			_turret(m, delta)
		elif m.fuse >= 0.0:
			m.fuse -= delta
			if evo == "density":
				_pull(pos, delta)
			if m.fuse <= 0.0:
				mines.remove_at(k)
				_explode(pos)
		elif m.age >= ARM_TIME and en.query(pos.x, pos.y, TRIGGER_R) > 0:
			mines.remove_at(k)
			_explode(pos)
		k -= 1


func _blast_radius() -> float:
	match evo:
		"density": return 170.0 * s.area
		"sides": return 80.0 * s.area
	return 85.0 * s.area


func _explode(pos: Vector2) -> void:
	var en := game.enemies
	var blast := _blast_radius()
	var d := dmg()
	match evo:
		"density": d *= (1.0 + s.count) * 0.6
	var c := en.query(pos.x, pos.y, blast)
	var hits := en.qbuf.slice(0, c)  # copy: hits can kill and split enemies
	for j in hits:
		var dir := Vector2(en.px[j] - pos.x, en.py[j] - pos.y).normalized()
		var kb: float = s.knockback * (-0.8 if game.build.tier("PULSE") >= 2 else 1.0)
		var crit := randf() < game.build.crit
		en.hit(j, d * (Balance.CRIT_MULT if crit else 1.0), dir.x * kb, dir.y * kb, display_name())
	var col := Color(0.7, 0.55, 1.0) if evo == "density" else Color(0.4, 1.0, 0.8)
	game.fx.ring(pos.x, pos.y, blast, col, 0.3, 4.0)
	game.fx.burst(pos.x, pos.y, col, 6, 10.0)
	if evo == "density":
		game.fx.shake(6.0)
	if evo == "sides":
		# chain reaction: nearby mines go off shortly after
		for m in mines:
			if m.fuse < 0.0 and (m.pos as Vector2).distance_to(pos) < blast:
				m.fuse = 0.12
	Sfx.play("boom", 0.6 if evo == "density" else 1.0)


## Singularity: drag enemies toward the black hole before it detonates.
func _pull(pos: Vector2, delta: float) -> void:
	var en := game.enemies
	var c := en.query(pos.x, pos.y, 230.0 * s.area)
	for q in c:
		var j := en.qbuf[q]
		if en.is_boss(j):
			continue
		var ox := pos.x - en.px[j]
		var oy := pos.y - en.py[j]
		var dist := sqrt(ox * ox + oy * oy) + 0.001
		var pull := 1600.0 * delta / en.t_mass[en.typ[j]]
		en.kx[j] += ox / dist * pull
		en.ky[j] += oy / dist * pull


## Fortress: the turret shoots at the nearest enemy.
func _turret(m: Dictionary, delta: float) -> void:
	m.shot -= delta
	if m.shot > 0.0:
		return
	m.shot = 0.4
	var pos: Vector2 = m.pos
	var j := game.enemies.nearest_to(pos.x, pos.y, 280.0, PackedInt32Array())
	if j < 0:
		return
	var dir := Vector2(game.enemies.px[j] - pos.x, game.enemies.py[j] - pos.y).normalized()
	game.bullets.spawn(pos.x, pos.y, dir.x * 540.0, dir.y * 540.0, 0.7, dmg() * 0.7, Bullets.Kind.TRI, src, 0, 0, 0.8, 30.0)
	m.aim = dir


func draw(ci: CanvasItem) -> void:
	for g in grenades:
		var f: float = g.t / FLIGHT_TIME
		var pos: Vector2 = (g.from as Vector2).lerp(g.to, f) + Vector2(0.0, -sin(PI * f) * ARC_HEIGHT)
		var col := Color(0.7, 0.55, 1.0) if evo == "density" else Color(0.4, 1.0, 0.8)
		Shapes.draw_neon_poly(ci, Transform2D(0.0, pos) * Shapes.points(4, 8.0, g.t * 12.0), col, 2.0, 0.3)
	for m in mines:
		var pos: Vector2 = m.pos
		var armed: bool = m.age >= ARM_TIME
		match evo:
			"hull":
				var col := Color(0.5, 0.95, 1.0)
				Shapes.draw_neon_poly(ci, Transform2D(0.0, pos) * Shapes.points(4, 12.0, PI / 4.0), col, 2.5, 0.15)
				var aim: Vector2 = m.get("aim", Vector2.UP)
				Shapes.draw_neon_line(ci, pos, pos + aim * 16.0, col, 3.0)
			"density":
				var col := Color(0.7, 0.55, 1.0)
				var pulse := 1.0 + 0.15 * sin(m.age * 10.0)
				Shapes.draw_neon_poly(ci, Transform2D(0.0, pos) * Shapes.points(4, 14.0 * pulse, m.age), col, 3.0, 0.3)
				if m.fuse >= 0.0:
					var f: float = m.fuse / PULL_TIME
					Shapes.draw_neon_ring(ci, pos, 230.0 * s.area * f, Color(col, 0.6), 2.0, 40)
			_:
				var col := Color(0.4, 1.0, 0.8) if armed else Color(0.4, 1.0, 0.8, 0.4)
				var blink := 1.0 if not armed or fmod(m.age, 0.8) > 0.12 else 1.8
				Shapes.draw_neon_poly(ci, Transform2D(0.0, pos) * Shapes.points(4, 6.0 * blink, PI / 4.0), col, 2.0, 0.2)


func clear() -> void:
	grenades.clear()
	mines.clear()
