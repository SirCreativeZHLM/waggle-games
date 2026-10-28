extends Node
## Procedurally synthesised sound effects and a short original menu loop.
## No audio files ship with the game, so there is nothing to license.

const RATE := 22050

var volume := 0.8
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams[&"hit"] = _make(520.0, 180.0, 0.14, "square", 0.5)
	_streams[&"whoosh"] = _make(0.0, 0.0, 0.22, "noise", 0.35, true)
	_streams[&"pin"] = _make(900.0, 300.0, 0.18, "square", 0.4)
	_streams[&"thud"] = _make(160.0, 60.0, 0.2, "sine", 0.9)
	_streams[&"beep"] = _make(660.0, 660.0, 0.12, "sine", 0.5)
	_streams[&"bounce"] = _make(300.0, 420.0, 0.08, "sine", 0.6)
	_streams[&"win"] = _melody([523.0, 659.0, 784.0, 1047.0], 0.12, 0.5)
	_streams[&"lose"] = _melody([392.0, 330.0, 262.0], 0.18, 0.5)
	_streams[&"cheer"] = _make(0.0, 0.0, 0.7, "noise", 0.3, true)
	_music = AudioStreamPlayer.new()
	_music.stream = _menu_loop()
	_music.volume_db = -14.0
	add_child(_music)


func play(name: StringName, pitch: float = 1.0) -> void:
	if not _streams.has(name) or volume <= 0.0:
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.volume_db = linear_to_db(volume)
			p.play()
			return


func music(on: bool) -> void:
	if on and not _music.playing and volume > 0.0:
		_music.play()
	elif not on:
		_music.stop()


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _make(f0: float, f1: float, dur: float, kind: String, vol: float, swell: bool = false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var v := 0.0
		match kind:
			"sine": v = sin(phase)
			"square": v = 1.0 if sin(phase) > 0.0 else -1.0
			"noise":
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
				v = lp * 2.0
		var env := sin(t * PI) if swell else pow(1.0 - t, 2.0)
		out[i] = v * env * vol
	return _wav(out)


func _melody(freqs: Array, note: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for f in freqs:
		var n := int(note * RATE)
		for i in n:
			var t := float(i) / n
			out.append((1.0 if sin(TAU * f * i / RATE) > 0.0 else -1.0) * pow(1.0 - t, 1.5) * vol * 0.6)
	return _wav(out)


func _menu_loop() -> AudioStreamWAV:
	# Original little pentatonic groove, 8 beats at 110 bpm, looped.
	var scale := [262.0, 294.0, 330.0, 392.0, 440.0, 523.0]
	var tune := [0, 2, 4, 2, 3, 4, 5, 4, 2, 3, 1, 0, 2, 4, 3, 1]
	var beat := 60.0 / 110.0 / 2.0
	var out := PackedFloat32Array()
	for idx in tune:
		var f: float = scale[idx]
		var n := int(beat * RATE)
		for i in n:
			var t := float(i) / n
			var lead := sin(TAU * f * i / RATE) * 0.5 + (1.0 if sin(TAU * f * 2.0 * i / RATE) > 0 else -1.0) * 0.1
			var bass := sin(TAU * (f * 0.5) * i / RATE) * 0.3
			out.append((lead + bass) * pow(1.0 - t, 0.7) * 0.5)
	var w := _wav(out)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = out.size()
	return w
