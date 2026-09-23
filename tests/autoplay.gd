extends Node
## Headless balance/perf harness. Plays a run with a simple bot.
## Usage: godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- char=triangle depth=0 god=1 seconds=900 pick=smart

var game: Game
var args := {"char": "triangle", "depth": "0", "god": "0", "seconds": "900", "pick": "smart", "seed": "1", "shots": "", "out": "", "pause_at": "-1", "evo": "", "start": "0", "stand": "0", "name": "", "core": "0"}
var over_wait := 0
var pause_wait := 0
var shots: Array[float] = []
var levelup_shot_taken := false
var choose_wait := 0
var frame_us := 0
var frames := 0
var worst_us := 0
var next_report := 30.0
var start_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	Save.read_only = true
	seed(int(args.seed))
	for v in args.shots.split(",", false):
		shots.append(float(v))
	Save.run_config = {"character": args.char, "depth": int(args.depth)}
	game = load("res://scenes/game.tscn").instantiate()
	game.god_mode = args.god == "1"
	add_child(game)
	start_ms = Time.get_ticks_msec()
	if args.evo != "":
		_force_evolution(args.evo)
	if float(args.start) > 0.0:
		# jump into the middle of a run (skips earlier one-off events)
		game.time = float(args.start)
		next_report = game.time + 30.0
		while game.director.event_idx < Balance.EVENTS.size() and Balance.EVENTS[game.director.event_idx].t < game.time:
			game.director.event_idx += 1


## evo=weapon:passive -> max the weapon, add the passive, evolve (passive "-" = max level, unevolved).
func _force_evolution(spec: String) -> void:
	var parts := spec.split(":")
	var b := game.build
	for w in b.weapons.duplicate():
		if w.id != parts[0]:
			b.weapons.erase(w)
	if b.weapon(parts[0]) == null:
		b.add_weapon(parts[0])
	var w := b.weapon(parts[0])
	w.level = Balance.WEAPON_MAX_LEVEL
	if parts[1] != "-":
		b.passives[parts[1]] = 1
		b.recompute()
		b.evolve(w, parts[1])
	b.recompute()
	b.rerolls = 0
	game.god_mode = true
	if args.core == "1":
		# a second weapon that competes for the same key, plus all three keys, then a core
		b.add_weapon("line_laser")
		b.weapon("line_laser").level = Balance.WEAPON_MAX_LEVEL
		for pid in w.data.evolutions:
			b.passives[pid] = Balance.PASSIVES[pid].max
		b.recompute()
		game.pending_cores = 1


func _process(_delta: float) -> void:
	if game.state == Game.State.PAUSED:
		if float(args.pause_at) >= 0.0 and args.out != "":
			pause_wait += 1
			if pause_wait < 4:
				return
			_shot("pause")
			args.pause_at = "-1"
		game.close_pause()
		return
	if float(args.pause_at) >= 0.0 and game.time >= float(args.pause_at):
		game.open_pause()
		return
	if game.state == Game.State.CHOOSING:
		if args.out != "" and not levelup_shot_taken and (game.level >= 3 or args.core == "1"):
			choose_wait += 1
			if choose_wait < 4:
				return
			levelup_shot_taken = true
			_shot("levelup")
		_pick()
		return
	if not shots.is_empty() and game.time >= shots[0]:
		_shot("t%03d" % int(shots.pop_front()))
	if game.state == Game.State.OVER:
		if args.out != "":
			over_wait += 1
			if over_wait < 4:
				return
			_shot("gameover")
		_report("END (%s)" % ("WIN" if game.victory_timer <= 0.0 and game.player.hp > 0 else "DEATH"))
		get_tree().quit()
		return
	# bot: potential field — repelled by enemies/bullets, attracted to gems, drifts in a big circle
	var p := game.player.position
	var en := game.enemies
	var push := Vector2.ZERO
	var danger := 0.0
	for j in en.n:
		if en.dead[j] or en.pd2[j] > 260.0 * 260.0:
			continue
		var d := p - Vector2(en.px[j], en.py[j])
		var dist := maxf(d.length() - en.t_radius[en.typ[j]], 8.0)
		if game.build.weapon("orbitals") and en.t_behavior[en.typ[j]] != Enemies.BOSS:
			dist += 70.0  # melee build: let enemies come into the orbit
		var w := 1.0 / (dist * dist) * 4000.0
		if en.t_behavior[en.typ[j]] == Enemies.DASH and en.st[j] >= 1:
			# step sideways out of a dash lane
			var lane := Vector2(en.dx[j], en.dy[j])
			push += lane.orthogonal() * signf(lane.orthogonal().dot(d) + 0.01) * 2.0
		push += d.normalized() * w
		danger += w
	var hb := game.hostile
	for i in hb.n:
		var d := p - Vector2(hb.x[i], hb.y[i])
		if d.length_squared() < 120.0 * 120.0:
			push += d.normalized() * 6000.0 / maxf(d.length_squared(), 64.0)
	var g := game.gems
	var best := -1
	var bd := 500.0 * 500.0
	for i in g.n:
		var d2 := (Vector2(g.x[i], g.y[i]) - p).length_squared()
		if g.kind[i] == Gems.CORE or g.kind[i] == Gems.HEAL and game.player.hp < game.build.max_hp * 0.6:
			d2 *= 0.1
		if d2 < bd:
			bd = d2
			best = i
	var seek := Vector2.ZERO
	if best >= 0:
		seek = (Vector2(g.x[best], g.y[best]) - p).normalized() * clampf(1.0 - danger, 0.2, 1.0)
	var circle := Vector2(cos(game.time * 0.25), sin(game.time * 0.25)) * 0.4
	game.joystick.output = (circle + seek + push).limit_length(1.0)
	if args.stand == "1":
		game.joystick.output = Vector2.ZERO
	frames += 1
	if game.time >= next_report:
		next_report += 30.0
		_report("t")
	if game.time >= float(args.seconds) + float(args.start):
		_report("STOP")
		get_tree().quit()


func _pick() -> void:
	var offers: Array = game.levelup.offers
	if args.evo != "":
		game.on_offer_chosen({"kind": "skip"})  # keep the build frozen
		return
	var pick: Dictionary = offers[0]
	if args.pick == "smart":
		# prefer evolutions, then upgrades of owned weapons, then new weapons, then passives
		var best := -1.0
		for o in offers:
			var score := randf()
			match o.kind:
				"evolve": score += 100.0 + randf()
				"weapon": score += 5.0 if not o.new else 3.0
				"passive": score += 2.5 if not o.new else 2.0
				"overclock": score += 1.0
			if score > best:
				best = score
				pick = o
	else:
		pick = offers.pick_random()
	game.on_offer_chosen(pick)


func _report(tag: String) -> void:
	var names: PackedStringArray = []
	for w in game.build.weapons:
		names.append("%s%d" % [w.display_name(), w.level])
	for id in game.build.passives:
		names.append("%s%d" % [id, game.build.passives[id]])
	var real := (Time.get_ticks_msec() - start_ms) / 1000.0
	print("[%s] t=%s lv=%d kills=%d hp=%d/%d en=%d bul=%d gems=%d hb=%d | real %.1fs (%.2f ms/frame) | %s" % [
		tag, UI.fmt_time(game.time), game.level, game.kills, game.player.hp, game.build.max_hp,
		game.enemies.n, game.bullets.n, game.gems.n, game.hostile.n, real, real * 1000.0 / maxf(frames, 1), ", ".join(names)])
	if args.evo != "":
		var w := game.build.weapons[0]
		var secs := game.time - float(args.start)
		print("EVO %-24s %-15s dps=%7.0f kills=%5d" % [args.evo, w.display_name(), game.damage_by.get(w.display_name(), 0.0) / maxf(secs, 1.0), game.kills])


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [args.out, args.name if args.name != "" else args.char, tag])
	print("shot ", tag)
