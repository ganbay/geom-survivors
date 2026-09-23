extends Weapon
## Drops mines that explode when enemies come close.
## Evolutions: hull = Fortress (mines become turrets) · density = Singularity (one black-hole mine)
##             sides = Minefield (trail of small chain-reacting mines while moving).

const ARM_TIME := 0.5
const TRIGGER_R := 26.0
const PULL_TIME := 0.7

# each mine: {pos, age, fuse (-1 = idle), shot (turret timer)}
var mines: Array = []
var trail_t := 0.0


func max_mines() -> int:
	match evo:
		"sides": return 26
		"hull": return 6 + int(s.count)
		"density": return 3
	return 14


func fire() -> void:
	if evo == "sides":
		return  # Minefield drops mines from update() while moving
	var p := game.player.position
	var drops := 1 if evo == "density" else int(s.count)
	for k in drops:
		var a := randf() * TAU
		_place(p + Vector2(cos(a), sin(a)) * randf_range(20.0, 60.0))


func _place(pos: Vector2) -> void:
	mines.append({"pos": pos, "age": 0.0, "fuse": -1.0, "shot": 0.3})
	if mines.size() > max_mines():
		mines.pop_front()


func update(delta: float) -> void:
	super.update(delta)
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
			if evo == "density":
				m.fuse = PULL_TIME
			else:
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


## Singularity: drag enemies toward the mine before it detonates.
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


## Fortress: the mine shoots at the nearest enemy.
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
	game.bullets.spawn(pos.x, pos.y, dir.x * 540.0, dir.y * 540.0, 0.7, dmg() * 0.8, Bullets.Kind.TRI, src, 0, 0, 0.8, 30.0)
	m.aim = dir


func draw(ci: CanvasItem) -> void:
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
				var size := 6.0 if evo == "sides" else 9.0
				var blink := 1.0 if not armed or fmod(m.age, 0.8) > 0.12 else 1.8
				Shapes.draw_neon_poly(ci, Transform2D(0.0, pos) * Shapes.points(4, size * blink, PI / 4.0), col, 2.0, 0.2)


func clear() -> void:
	mines.clear()
