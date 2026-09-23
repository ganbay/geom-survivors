class_name Game
extends Node2D
## Owns one run: creates all systems, runs them in a fixed order each frame, and handles run events.

enum State { RUNNING, CHOOSING, PAUSED, OVER }

var character_id := "triangle"
var depth := 0
var depth_mods := {}
var god_mode := false  # debug

var state := State.RUNNING
var time := 0.0
var level := 1
var xp := 0
var xp_next := 10
var kills := 0
var pending_levels := 0
var pending_cores := 0
var damage_by := {}
var victory_timer := -1.0

var build: Build
var director: Director
var grid: GridBackground
var gems: Gems
var enemies: Enemies
var bullets: Bullets
var hostile: HostileBullets
var weapon_layer: Node2D
var player: Player
var fx: Fx
var camera: Camera2D
var hud: Hud
var joystick: Joystick
var levelup: LevelUpUI
var pause_ui: PauseUI
var gameover: GameOverUI

var _arc_queue: Array = []  # CHAIN tier-2 arcs, resolved after all weapons fired
var _frame_ema := 1.0 / 60.0
var _slow_time := 0.0


func _ready() -> void:
	character_id = Save.run_config.get("character", "triangle")
	depth = Save.run_config.get("depth", 0)
	depth_mods = _collect_depth_mods(depth)
	Shapes.low_quality = Save.get_setting("low_quality", false)
	RenderingServer.set_default_clear_color(Balance.C_BG)

	grid = GridBackground.new()
	add_child(grid)
	gems = Gems.new()
	add_child(gems)
	enemies = Enemies.new()
	add_child(enemies)
	weapon_layer = Node2D.new()
	weapon_layer.material = Shapes.get_add_material()
	weapon_layer.draw.connect(_draw_weapons)
	add_child(weapon_layer)
	bullets = Bullets.new()
	add_child(bullets)
	hostile = HostileBullets.new()
	add_child(hostile)
	player = Player.new()
	player.material = Shapes.get_add_material()
	add_child(player)
	fx = Fx.new()
	add_child(fx)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	hud = Hud.new()
	add_child(hud)
	var joy_layer := CanvasLayer.new()
	joy_layer.layer = 4
	add_child(joy_layer)
	joystick = Joystick.new()
	joystick.material = Shapes.get_add_material()
	joy_layer.add_child(joystick)
	levelup = LevelUpUI.new()
	add_child(levelup)
	pause_ui = PauseUI.new()
	add_child(pause_ui)
	gameover = GameOverUI.new()
	add_child(gameover)

	build = Build.new(self, character_id, depth_mods)
	director = Director.new(self)
	player.setup(self, character_id)
	gems.setup(self)
	enemies.setup(self)
	enemies.material = Shapes.get_add_material()
	bullets.setup(self)
	hostile.setup(self)
	fx.setup(self)
	hud.setup(self)
	levelup.setup(self)
	pause_ui.setup(self)
	gameover.setup(self)

	enemies.speed_mult = 1.0 + depth_mods.get("enemy_speed", 0.0)
	build.recompute()
	player.hp = build.max_hp
	build.add_weapon(Balance.CHARACTERS[character_id].start)
	xp_next = Balance.xp_needed(level)
	Sfx.play_music("run")


static func _collect_depth_mods(d: int) -> Dictionary:
	var mods := {}
	for i in range(1, d + 1):
		var m: Dictionary = Balance.DEPTHS[i].get("mods", {})
		for k in m:
			mods[k] = mods.get(k, 0.0) + m[k]
	return mods


func view_size() -> Vector2:
	return get_viewport_rect().size / camera.zoom


func view_radius() -> float:
	return view_size().length() * 0.5


func dynamic_damage_mult() -> float:
	if build.anchor > 0.0 and player.is_still():
		return 1.0 + build.anchor
	return 1.0


# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	if state != State.RUNNING:
		return
	# never simulate huge steps: on a very slow frame the game slows down instead of tunneling
	delta = minf(delta, 1.0 / 25.0)
	_govern_performance(delta)
	time += delta

	var input := joystick.output
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if kb != Vector2.ZERO or wasd != Vector2.ZERO:
		input = (kb + wasd).limit_length(1.0)
		joystick.idle_hint = false
	player.update(delta, input)

	director.update(delta)
	enemies.update(delta)
	for w in build.weapons:
		w.update(delta)
	bullets.update(delta)
	hostile.update(delta)
	_process_arcs()
	enemies.compact()
	gems.update(delta)
	fx.update(delta)

	camera.position = player.position + fx.shake_offset
	grid.center = player.position
	grid.queue_redraw()
	weapon_layer.queue_redraw()
	enemies.render()
	bullets.render()
	hostile.render()
	gems.render()
	fx.render()
	hud.update(delta)

	if victory_timer > 0.0:
		victory_timer -= delta
		if victory_timer <= 0.0:
			_end_run(true)
	elif state == State.RUNNING:
		_maybe_open_choice()


func _draw_weapons() -> void:
	for w in build.weapons:
		w.draw(weapon_layer)


## Lowers enemy cap and particle count on devices that can't keep up.
func _govern_performance(delta: float) -> void:
	_frame_ema = lerpf(_frame_ema, delta, 0.05)
	if _frame_ema > 1.0 / 45.0:
		_slow_time += delta
		if _slow_time > 2.0:
			_slow_time = 0.0
			director.cap = maxi(Balance.ENEMY_MIN_CAP, int(director.cap * 0.85))
			fx.particle_budget = maxf(0.3, fx.particle_budget * 0.8)
	else:
		_slow_time = maxf(0.0, _slow_time - delta)


# ------------------------------------------------------------------ combat hooks (called by systems)

func on_damage(amount: float, source: String) -> void:
	damage_by[source] = damage_by.get(source, 0.0) + amount


func on_hit(i: int, amount: float, source: String) -> void:
	# CHAIN resonance tier 2: any hit may arc to a nearby enemy
	if source != "Arc" and build.tier("CHAIN") >= 2 and randf() < 0.12:
		_arc_queue.append([enemies.px[i], enemies.py[i], enemies.uid[i], amount * 0.5])


func _process_arcs() -> void:
	var skip := PackedInt32Array()
	var queue := _arc_queue
	_arc_queue = []
	for a in queue:
		skip.clear()
		skip.append(a[2])
		var j := enemies.nearest_to(a[0], a[1], 140.0, skip)
		if j >= 0:
			var to := Vector2(enemies.px[j], enemies.py[j])
			enemies.hit(j, a[3], 0.0, 0.0, "Arc")
			fx.line(PackedVector2Array([Vector2(a[0], a[1]), to]), Balance.TAG_COLORS.CHAIN, 0.12, 2.0)


func on_kill(x: float, y: float, source: String) -> void:
	kills += 1
	Sfx.play("kill")
	if build.lifesteal > 0.0:
		player.heal(build.lifesteal)
	# FRACTURE resonance: kills burst into shards (shard kills only chain at tier 2)
	var t := build.tier("FRACTURE")
	if t > 0 and (source != "Fracture" or t >= 2):
		if randf() < (0.30 if t >= 2 else 0.12):
			shard_burst(x, y, 3)


func shard_burst(x: float, y: float, count: int) -> void:
	if bullets.n > 400:
		return
	var src := bullets.source_id("Fracture")
	var d := (6.0 + time / 60.0 * 1.5) * build.dmg_mult
	var off := randf() * TAU
	for k in count:
		var a := off + TAU * k / count
		bullets.spawn(x, y, cos(a) * 420.0, sin(a) * 420.0, 0.4, d, Bullets.Kind.SHARD, src, 1, 0, 1.0, 30.0)


func on_boss_killed(id: String, x: float, y: float) -> void:
	fx.shake(18.0)
	fx.ring(x, y, 300.0, Balance.C_GOLD, 0.8, 6.0)
	fx.burst(x, y, Balance.C_GOLD, 40, 60.0)
	hostile.clear_all()
	Sfx.play("evolve")
	if id == "boss_final":
		hud.banner("THE POLYGON IS BROKEN", Balance.C_GOLD, 3.0)
		victory_timer = 2.5
	else:
		gems.drop_core(x, y)
		hud.banner("BOSS DOWN", Balance.C_GOLD, 2.0)


func on_core_collected() -> void:
	pending_cores += 1


func add_xp(v: int) -> void:
	Sfx.play("xp")
	xp += maxi(1, roundi(v * build.xp_mult))
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		pending_levels += 1
		xp_next = Balance.xp_needed(level)


# ------------------------------------------------------------------ choices (level-ups / cores)

func _maybe_open_choice() -> void:
	if pending_cores > 0:
		pending_cores -= 1
		var offers: Array = []
		for opt in build.evolution_options():
			var w: Weapon = opt.weapon
			offers.append({"kind": "evolve", "id": w.id, "passive": opt.passive, "level": w.level, "new": false})
		var sub := "Pick one. The passive used becomes CLAIMED." if offers.size() > 0 else "Nothing can evolve yet"
		if offers.is_empty():
			offers.append({"kind": "bonus", "id": "bonus", "level": 1, "new": false})
		_open_choice("CORE", sub, offers, false, Balance.C_GOLD)
		Sfx.play("evolve")
	elif pending_levels > 0:
		pending_levels -= 1
		_open_choice("LEVEL UP", "LV %d · choose one" % level, build.make_offers(), true, Balance.C_XP)
		Sfx.play("level")


func _open_choice(title: String, sub: String, offers: Array, tools: bool, color: Color) -> void:
	state = State.CHOOSING
	joystick.release()
	get_tree().paused = true
	levelup.open(title, sub, offers, tools, color)


func on_offer_chosen(o: Dictionary) -> void:
	match o.kind:
		"evolve":
			var w := build.weapon(o.id)
			build.evolve(w, o.passive)
			hud.banner(w.display_name().to_upper(), Balance.C_GOLD, 2.0)
			fx.ring(player.position.x, player.position.y, 200.0, Balance.C_GOLD, 0.6, 5.0)
		"bonus":
			player.heal(build.max_hp * 0.3)
			pending_levels += 1
		"skip":
			pass
		_:
			build.apply_offer(o)
	levelup.close()
	get_tree().paused = false
	state = State.RUNNING


# ------------------------------------------------------------------ pause / end

func open_pause() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	joystick.release()
	get_tree().paused = true
	pause_ui.open()


func close_pause() -> void:
	pause_ui.visible = false
	get_tree().paused = false
	state = State.RUNNING


func _notification(what: int) -> void:
	# auto-pause when the app goes to background
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and state == State.RUNNING:
			open_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button toggles pause instead of quitting mid-run
		if state == State.RUNNING:
			open_pause()
		elif state == State.PAUSED:
			close_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if state == State.RUNNING:
			open_pause()
		elif state == State.PAUSED:
			close_pause()


func on_player_died() -> void:
	if state == State.OVER:
		return
	fx.burst(player.position.x, player.position.y, Balance.C_PLAYER, 40, 30.0)
	_end_run(false)


func _end_run(won: bool) -> void:
	state = State.OVER
	joystick.release()
	var unlocked := 0
	if won:
		var before := Save.depth_unlocked()
		Save.record_win(depth)
		if Save.depth_unlocked() > before:
			unlocked = Save.depth_unlocked()
	Save.record_run(character_id, depth, time, won)
	Sfx.play("win" if won else "gameover")
	get_tree().paused = true
	gameover.open(won, unlocked)


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func quit_to_menu() -> void:
	get_tree().paused = false
	Sfx.stop_music()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
