extends Node
## Headless balance/perf harness. Plays a run with a simple bot.
## Usage: godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- char=triangle depth=0 god=1 seconds=900 pick=smart
## boss=<id> forces every boss event to that boss (and spawns it right away with bossnow=1).
## bench=mob|single (with evo=...): no waves or events, the player walks a fixed circle, and the weapon faces
##   mob    = a steady horde of BENCH_MOBS dots (HP as at `start`), measured in kills/s
##   single = one unkillable, armorless, boss-sized dummy circling the player at 80-240px, measured in DPS
##   crowd  = `targets` (default 10) unkillable, armorless, normal-sized dummies spread around the player the same way
##   clear  = CLEAR_HORDE enemies from the wave mix at `start` plus CLEAR_BOSSES, all at once; the bot plays normally
##            and the run stops when everything (splits and summons included) is dead: prints "CLEAR <seconds>".
##            The bot hunts (walks to the nearest enemy, then circles it) since god mode makes kiting pointless.
##   real   = a normal run from 0:00 (no god mode) with evo=weapon:passive as the only weapon: the bot levels it,
##            rushes the key passive, takes that evolution when offered (passive "-" = never evolve), fills the
##            other passives normally and always vents cores for the heal. Prints "REAL ..." when the run ends.
##            With start=<s> it jumps in mid-run already evolved (see _real_setup).
## Example: godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- char=circle evo=orbitals:hull bench=real seed=1
## Example: godot --headless --fixed-fps 60 res://tests/autoplay.tscn -- evo=orbitals:hull bench=single start=480 seconds=60

var game: Game
var args := {"char": "triangle", "depth": "0", "god": "0", "seconds": "900", "pick": "smart", "seed": "1", "shots": "", "out": "", "pause_at": "-1", "evo": "", "start": "0", "stand": "0", "name": "", "core": "0", "boss": "", "bossnow": "0", "bench": "", "targets": "10"}
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
var boss_seen := ""
var dummies := {}  # dummy uid -> slot index
var bosses_down := -1.0
var evolved_at := -1.0
var bosses_faced: PackedStringArray = []

const BENCH_MOBS := 150
const CLEAR_HORDE := 200
const MID_RUN_LEVEL := 20  # bench=real with start>0: player level when jumping in
const MID_RUN_PASSIVES := ["density", "hull", "frequency", "radius", "magnet"]  # filler at level 3, first three that fit
const CLEAR_BOSSES := ["boss_tetra", "boss_penta"]
const DUMMY_TYPE := "brute"  # no AI or summons; resized to boss scale for bench=single
const DUMMY_RADIUS := 52.0
# dummies circle the player while drifting between contact range and mid range
const DUMMY_NEAR := 80.0
const DUMMY_FAR := 240.0


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
	if args.boss != "":
		game.director.boss_override = args.boss
		if args.bossnow == "1":
			game.director._run_event({"kind": "boss", "pool": [args.boss]})
	if args.bench == "real":
		_real_setup()
	elif args.evo != "":
		_force_evolution(args.evo)
	if float(args.start) > 0.0:
		# jump into the middle of a run (skips earlier one-off events)
		game.time = float(args.start)
		next_report = game.time + 30.0
		while game.director.event_idx < Balance.EVENTS.size() and Balance.EVENTS[game.director.event_idx].t < game.time:
			game.director.event_idx += 1
	if args.bench != "" and args.bench != "real":
		_bench_setup()


## Real: swap the character's starting weapon for the tested one and play a full run.
func _real_setup() -> void:
	var b := game.build
	var id: String = args.evo.split(":")[0]
	for w in b.weapons.duplicate():
		b.weapons.erase(w)
	b.add_weapon(id)
	b.recompute()
	args.seconds = "1200"  # the run ends on death or on the final boss
	if float(args.start) > 0.0:
		# jump in at the moment a player would evolve: weapon maxed, key passive maxed, evolved
		# (base rows get Density maxed instead, so every row has the same passive budget)
		var pid: String = args.evo.split(":")[1]
		var key := pid if pid != "-" else "density"
		var w := b.weapon(id)
		w.level = Balance.WEAPON_MAX_LEVEL
		b.passives[key] = Balance.PASSIVES[key].max
		for extra in MID_RUN_PASSIVES:
			if b.passives.size() < Balance.MAX_PASSIVES and not b.passives.has(extra):
				b.passives[extra] = 3
		b.recompute()
		if pid != "-":
			b.evolve(w, pid)
			evolved_at = float(args.start)
		game.level = MID_RUN_LEVEL
		game.xp_next = Balance.xp_needed(MID_RUN_LEVEL)
		game.player.hp = b.max_hp


## Real: the distance this build wants enemies at — ring weapons let them close in, shooters keep range.
func _engage_range() -> float:
	var w := game.build.weapons[0]
	var a: float = w.s.area
	match w.id:
		"orbitals":
			return 88.0 * a * {"radius": 1.25, "hull": 0.72}.get(w.evo, 1.0)
		"pulse_ring":
			return 170.0 * a * (0.75 if w.evo == "frequency" else 1.0) * 0.55
		"chain_arc":
			if w.evo == "hull":
				return 210.0 * a * 0.6
		"line_laser":
			if w.evo == "sides":
				return 175.0 * a * 0.85
		"mines":
			if w.evo == "sides":
				return 110.0
	return 170.0


## Real: reach-aware kiting. Enemies closer than the engage range push the player away (bosses a bit
## further), dashes and bullets are dodged, gems are collected when it's calm, and the bot closes in
## when nothing is within reach.
func _real_move() -> void:
	var p := game.player.position
	var en := game.enemies
	var want := _engage_range()
	var push := Vector2.ZERO
	var nearest := 1e9
	var nearest_dir := Vector2.ZERO
	for j in en.n:
		if en.dead[j] or en.pd2[j] > 400.0 * 400.0:
			continue
		var d := p - Vector2(en.px[j], en.py[j])
		var len := d.length() + 0.001
		var gap := len - en.t_radius[en.typ[j]] - Balance.PLAYER_RADIUS
		if gap < nearest:
			nearest = gap
			nearest_dir = -d / len
		var keep := maxf(want, 170.0) if en.is_boss(j) else want
		if gap < keep:
			var f := (keep - gap) / keep
			push += d / len * f * f * 3.0
		if gap < 12.0:
			push += d / len * 4.0  # about to touch: get out
		if en.t_behavior[en.typ[j]] == Enemies.DASH and en.st[j] >= 1:
			var lane := Vector2(en.dx[j], en.dy[j])
			push += lane.orthogonal() * signf(lane.orthogonal().dot(d) + 0.01) * 2.0
	var dodge := Vector2.ZERO
	var hb := game.hostile
	for i in hb.n:
		var d := p - Vector2(hb.x[i], hb.y[i])
		if d.length_squared() < 120.0 * 120.0:
			dodge += d.normalized() * 6000.0 / maxf(d.length_squared(), 64.0)
	push += dodge
	var bi := en.boss_idx
	if bi >= 0 and en.type_ids[en.typ[bi]] == "boss_prism" and en.st[bi] in [1, 2]:
		# Octaprism beams: ride the middle of the nearest gap between beams as they rotate
		var bs: Dictionary = en.boss_state.get(en.uid[bi], {})
		if bs.has("ang"):
			var c := Vector2(en.px[bi], en.py[bi])
			var d := p - c
			var n: int = bs.get("beams", 4)
			var step := TAU / n
			var gap: float = bs.ang + step * 0.5 + roundf((d.angle() - bs.ang - step * 0.5) / step) * step
			var spot := c + Vector2.from_angle(gap + bs.get("spin", 0.0) * 0.15) * clampf(d.length(), 180.0, 320.0)
			# stay near the gap's middle, but still sidestep bullets inside it
			game.joystick.output = ((spot - p).limit_length(40.0) / 40.0 + dodge.limit_length(1.2)).limit_length(1.0)
			return
	for h in en.hazards:
		if h.kind == "blast":
			var d := p - Vector2(h.x, h.y)
			if d.length() < h.r + 40.0:
				push += (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * 6.0  # step out before it goes off
	if nearest > want + 60.0 and nearest < 1e8:
		push += nearest_dir * 0.6
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
		seek = (Vector2(g.x[best], g.y[best]) - p).normalized() * clampf(1.0 - push.length(), 0.2, 1.0)
	var circle := Vector2(cos(game.time * 0.25), sin(game.time * 0.25)) * 0.3
	game.joystick.output = (circle + seek + push).limit_length(1.0)


## Real: offer scoring for a single-weapon run aiming at one evolution.
func _real_score(o: Dictionary) -> float:
	var parts: PackedStringArray = args.evo.split(":")
	match o.kind:
		"evolve":
			return 100.0 if o.id == parts[0] and o.passive == parts[1] else -100.0
		"weapon":
			return 10.0 if o.id == parts[0] else -100.0
		"passive":
			if o.id == parts[1]:
				return 8.0 + randf()
			var b := game.build
			if o.new and parts[1] != "-" and not b.passives.has(parts[1]) and b.passives.size() >= Balance.MAX_PASSIVES - 1:
				return -10.0  # keep the last slot for the key passive
			return 3.0 + randf()
		"bonus":
			return 1.0
		"heal":
			return 0.5
	return -50.0  # overclocks: skipped to keep runs comparable


## Bench: silence the director and strip passives so only the weapon itself is measured.
func _bench_setup() -> void:
	game.director.event_idx = Balance.EVENTS.size()
	game.director.spawn_timer = 1e9
	game.build.passives.clear()
	game.build.recompute()
	if args.bench == "clear":
		_clear_setup()
	if args.bench == "single" or args.bench == "crowd":
		var en := game.enemies
		var t: int = en.type_index[DUMMY_TYPE]
		en.t_armor[t] = 0.0
		en.t_speed[t] = 0.0
		if args.bench == "single":
			en.t_radius[t] = DUMMY_RADIUS
		var count := 1 if args.bench == "single" else int(args.targets)
		for k in count:
			var p := game.player.position + _dummy_offset(k, count)
			dummies[en.uid[en.spawn(DUMMY_TYPE, p.x, p.y, 1e6)]] = k


## Clear: the whole horde closes in from just off screen, bosses from random edges.
func _clear_setup() -> void:
	var d := game.director
	d.update(0.0)  # hp_mult for the current time
	var types: Dictionary = d.phase().types
	var c := game.player.position
	var r := game.view_radius() + 40.0
	for k in CLEAR_HORDE:
		var a := TAU * k / CLEAR_HORDE + randf_range(-0.02, 0.02)
		var rr := r + randf() * 160.0
		game.enemies.spawn(d._weighted(types), c.x + cos(a) * rr, c.y + sin(a) * rr, d.hp_mult)
	for id in CLEAR_BOSSES:
		var p := d.spawn_point(80.0)
		game.enemies.spawn(id, p.x, p.y, 1.0)


func _clear_done() -> bool:
	var en := game.enemies
	for j in en.n:
		if not en.dead[j]:
			return false
	return true


## Clear bot: close in on the nearest enemy, then circle it (keeps trail weapons dropping).
## Ring weapons hold the enemy at their ring radius instead of on top of the player.
func _hunt() -> void:
	var en := game.enemies
	var best := -1
	for j in en.n:
		if not en.dead[j] and (best < 0 or en.pd2[j] < en.pd2[best]):
			best = j
	if best < 0:
		return
	var to := Vector2(en.px[best], en.py[best]) - game.player.position
	var reach := en.t_radius[en.typ[best]] + 60.0
	var w := game.build.weapons[0]
	if w.id == "orbitals":
		reach = 88.0 * w.s.area * {"radius": 1.25, "hull": 0.72}.get(w.evo, 1.0)
	elif w.id == "line_laser" and w.evo == "sides":
		reach = 175.0 * w.s.area * 0.9
	var dist := to.length()
	if dist > reach + 15.0:
		game.joystick.output = to.normalized()
	elif dist < reach - 15.0:
		game.joystick.output = -to.normalized()
	else:
		game.joystick.output = to.normalized().orthogonal() * 0.6


## Dummy k of `count`: evenly spread in angle, distances staggered so the pack covers near and far.
func _dummy_offset(k: int, count: int) -> Vector2:
	var t := game.time
	var dist := lerpf(DUMMY_NEAR, DUMMY_FAR, 0.5 + 0.5 * sin(t * 0.5 + k * 2.39996))
	var a := t * 0.3 + TAU * k / count
	return Vector2(cos(a), sin(a)) * dist


func _bench_update() -> void:
	if args.bench == "clear":
		var secs := game.time - float(args.start)
		if bosses_down < 0.0 and secs > 1.0 and game.enemies.boss_idx < 0:
			bosses_down = secs
		if _clear_done() or secs >= float(args.seconds):
			var w := game.build.weapons[0]
			var left := 0
			for j in game.enemies.n:
				left += 0 if game.enemies.dead[j] else 1
			print("CLEAR %-24s %-15s time=%6.1f bosses=%6.1f left=%3d kills=%4d" % [args.evo, w.display_name(), secs, bosses_down, left, game.kills])
			get_tree().quit()
		_hunt()
		return
	game.joystick.output = Vector2(cos(game.time * 0.8), sin(game.time * 0.8)) * 0.6
	var en := game.enemies
	var c := game.player.position
	if args.bench == "mob":
		var alive := 0
		for j in en.n:
			if not en.dead[j]:
				alive += 1
		var r := game.view_radius() + 40.0
		for k in BENCH_MOBS - alive:
			var a := randf() * TAU
			en.spawn("dot", c.x + cos(a) * r, c.y + sin(a) * r, game.director.hp_mult)
		return
	var count := dummies.size()
	for j in en.n:
		if dummies.has(en.uid[j]):
			var off := _dummy_offset(dummies[en.uid[j]], count)
			en.px[j] = c.x + off.x
			en.py[j] = c.y + off.y
			en.kx[j] = 0.0
			en.ky[j] = 0.0


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
	elif args.core == "2":
		# evolutions ready: they should show up in the level-up pool
		for pid in w.data.evolutions:
			b.passives[pid] = Balance.PASSIVES[pid].max
		b.recompute()
		game.pending_levels = 1


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
		if args.out != "" and not levelup_shot_taken and (game.level >= 3 or args.core != "0"):
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
		_real_report("WIN" if game.player.hp > 0 else "DEATH")
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
	if args.bench != "" and args.bench != "real":
		_bench_update()
	if args.bench == "real":
		# the 10:00 boss is always Hexcore: the bot can't handle Octaprism, and a coin flip there drowns the weapon signal
		game.director.boss_override = "boss_hex" if game.time < 700.0 else ""
		_real_move()
	frames += 1
	var bi := game.enemies.boss_idx
	var boss_now := game.enemies.type_ids[game.enemies.typ[bi]] if bi >= 0 else ""
	if boss_now != boss_seen:
		print("[boss] t=%s %s -> %s" % [UI.fmt_time(game.time), boss_seen, boss_now])
		boss_seen = boss_now
		if boss_now != "" and not bosses_faced.has(boss_now):
			bosses_faced.append(boss_now)
	if game.time >= next_report:
		next_report += 30.0
		_report("t")
	if game.time >= float(args.seconds) + float(args.start):
		_real_report("TIMEOUT")
		_report("STOP")
		get_tree().quit()


func _pick() -> void:
	var offers: Array = game.levelup.offers
	if args.bench == "real":
		var best: Dictionary = {"kind": "skip"}
		var best_score := 0.0
		for o in offers:
			var sc := _real_score(o)
			if sc > best_score:
				best_score = sc
				best = o
		# reroll level-ups (not cores) that offer nothing toward the target, like a player fishing for the key
		var is_core := offers.any(func(o): return o.kind == "bonus")
		if best_score < 5.0 and not is_core and game.build.rerolls > 0:
			game.build.rerolls -= 1
			game.levelup.offers = game.build.make_offers()
			return
		if best.kind == "evolve":
			evolved_at = game.time
		game.on_offer_chosen(best)
		return
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
				"overclock": score += 1.5
				"bonus": score += 1.0
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
		print("EVO %-24s %-15s dps=%7.0f kills=%5d kps=%6.1f" % [args.evo, w.display_name(), game.damage_by.get(w.display_name(), 0.0) / maxf(secs, 1.0), game.kills, game.kills / maxf(secs, 1.0)])


func _real_report(result: String) -> void:
	if args.bench != "real":
		return
	var w := game.build.weapons[0]
	var passives: PackedStringArray = []
	for id in game.build.passives:
		passives.append("%s%d" % [id, game.build.passives[id]])
	print("REAL %-22s %-15s %-7s time=%6.1f lvl=%2d evo=%6.1f taken=%6.0f kills=%5d | %s | bosses=%s" % [args.evo, w.display_name(), result,
			game.time, game.level, evolved_at, game.damage_taken, game.kills, " ".join(passives), ",".join(bosses_faced)])


func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [args.out, args.name if args.name != "" else args.char, tag])
	print("shot ", tag)
