extends Node
## Sound effects + music.
## Placeholder SFX are synthesized at startup. To replace one, drop a file named
## res://audio/sfx/<name>.ogg (or .wav) — e.g. audio/sfx/kill.ogg. Music: res://audio/music/<name>.ogg

const RATE := 22050
const VOICES := 12
# minimum seconds between two plays of the same sound (prevents noise walls)
const MIN_GAP := {"kill": 0.035, "xp": 0.03, "shoot": 0.06, "hit": 0.05, "zap": 0.06, "boom": 0.05, "pulse": 0.1, "laser": 0.08}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var last_play := {}
var music: AudioStreamPlayer
var xp_streak := 0
var xp_streak_t := 0.0
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	add_child(music)
	_build_sounds()
	apply_volume()


func apply_volume() -> void:
	var sv: float = Save.get_setting("sfx", 0.8)
	var mv: float = Save.get_setting("music", 0.7)
	for p in players:
		p.volume_db = linear_to_db(maxf(sv, 0.0001))
	music.volume_db = linear_to_db(maxf(mv, 0.0001))


func _process(delta: float) -> void:
	xp_streak_t -= delta
	if xp_streak_t <= 0.0:
		xp_streak = 0


func play(sound: String, pitch := 1.0) -> void:
	if not streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = MIN_GAP.get(sound, 0.0)
	if gap > 0.0 and now - last_play.get(sound, -1.0) < gap:
		return
	last_play[sound] = now
	if sound == "xp":
		# pickups climb in pitch while you keep collecting
		xp_streak = mini(xp_streak + 1, 24)
		xp_streak_t = 0.6
		pitch *= pow(2.0, xp_streak / 24.0)
	elif sound == "kill":
		pitch *= randf_range(0.85, 1.15)
	var p := players[_next]
	_next = (_next + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = pitch
	p.play()


func play_music(track: String) -> void:
	for ext in ["ogg", "mp3", "wav"]:
		var path := "res://audio/music/%s.%s" % [track, ext]
		if ResourceLoader.exists(path):
			var s = load(path)
			if music.stream == s and music.playing:
				return
			music.stream = s
			music.play()
			return
	music.stop()


func stop_music() -> void:
	music.stop()


# ------------------------------------------------------------------ synthesis

func _build_sounds() -> void:
	var defs := {
		"shoot":  func(): return _tone(900.0, 620.0, 0.045, "square", 0.10),
		"hit":    func(): return _noise(0.03, 0.12, 0.0),
		"kill":   func(): return _tone(560.0, 170.0, 0.08, "sine", 0.28),
		"xp":     func(): return _tone(1100.0, 1350.0, 0.05, "sine", 0.16),
		"level":  func(): return _arp([523.0, 659.0, 784.0, 1047.0], 0.07, "square", 0.16),
		"evolve": func(): return _arp([392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0], 0.08, "square", 0.18),
		"hurt":   func(): return _mix(_tone(190.0, 70.0, 0.2, "saw", 0.3), _noise(0.12, 0.25, 0.0)),
		"pulse":  func(): return _tone(240.0, 60.0, 0.28, "sine", 0.35),
		"laser":  func(): return _tone(1600.0, 280.0, 0.14, "saw", 0.14),
		"zap":    func(): return _mix(_tone(1800.0, 900.0, 0.07, "square", 0.08), _noise(0.07, 0.12, 0.0)),
		"boom":   func(): return _mix(_noise(0.3, 0.35, 0.85), _tone(120.0, 40.0, 0.3, "sine", 0.4)),
		"boss":   func(): return _tone(110.0, 50.0, 1.1, "saw", 0.35, 7.0),
		"dash":   func(): return _noise(0.2, 0.2, 0.5),
		"heal":   func(): return _tone(600.0, 950.0, 0.2, "sine", 0.25),
		"magnet": func(): return _tone(300.0, 1400.0, 0.35, "sine", 0.25),
		"click":  func(): return _tone(1000.0, 900.0, 0.025, "square", 0.12),
		"select": func(): return _tone(700.0, 1050.0, 0.09, "sine", 0.25),
		"gameover": func(): return _tone(320.0, 70.0, 0.9, "saw", 0.3),
		"win":    func(): return _arp([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.11, "square", 0.18),
	}
	for sound in defs:
		var custom := _load_custom(sound)
		streams[sound] = custom if custom else defs[sound].call()


func _load_custom(sound: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/sfx/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	return w


func _osc(phase: float, wave: String) -> float:
	match wave:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(phase, 1.0) * 2.0 - 1.0
	return sin(phase * TAU)


func _tone_samples(f0: float, f1: float, dur: float, wave: String, vol: float, trem := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var env := minf(1.0, i / (RATE * 0.004)) * pow(1.0 - t, 2.0)
		if trem > 0.0:
			env *= 0.6 + 0.4 * sin(t * dur * trem * TAU)
		out[i] = _osc(phase, wave) * env * vol
	return out


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float, trem := 0.0) -> AudioStreamWAV:
	return _wav(_tone_samples(f0, f1, dur, wave, vol, trem))


func _noise(dur: float, vol: float, lowpass: float) -> AudioStreamWAV:
	return _wav(_noise_samples(dur, vol, lowpass))


func _noise_samples(dur: float, vol: float, lowpass: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var v := randf_range(-1.0, 1.0)
		prev = lerpf(v, prev, lowpass)
		out[i] = prev * pow(1.0 - t, 2.0) * vol
	return out


func _arp(freqs: Array, step: float, wave: String, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone_samples(f, f, step * 1.6, wave, vol))
		out.resize(out.size() - int(step * 0.6 * RATE))
	return _wav(out)


func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var da := a.data
	var db := b.data
	var n := maxi(da.size(), db.size()) / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var va := da.decode_s16(i * 2) / 32767.0 if i * 2 < da.size() else 0.0
		var vb := db.decode_s16(i * 2) / 32767.0 if i * 2 < db.size() else 0.0
		out[i] = va + vb
	return _wav(out)
