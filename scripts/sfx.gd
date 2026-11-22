extends Node

## Procedural sound effects - no audio files needed.

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_streams["shot"] = _noise_burst(0.09, 0.5, 950.0)
	_streams["enemy_shot"] = _noise_burst(0.08, 0.24, 420.0)
	_streams["hit"] = _blip(1400.0, 0.05, 0.22)
	_streams["kill"] = _sweep(760.0, 170.0, 0.24, 0.32)
	_streams["hurt"] = _sweep(240.0, 65.0, 0.28, 0.42)
	_streams["wave"] = _chord([523.25, 659.25, 783.99], 0.42, 0.24)
	_streams["start"] = _chord([392.0, 523.25], 0.32, 0.28)
	_streams["over"] = _sweep(300.0, 55.0, 0.8, 0.36)


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = vol_db - 5.0
	p.play()


func _noise_burst(dur: float, vol: float, tone: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var env: float = exp(-20.0 * t)
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.35)
		buf[i] = (prev + sin(TAU * tone * t) * 0.30) * env * vol
	return _wav(buf)


func _blip(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		buf[i] = sin(TAU * freq * t) * exp(-28.0 * t) * vol
	return _wav(buf)


func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var k := float(i) / float(n)
		var f: float = lerpf(f0, f1, k)
		phase += TAU * f / float(rate)
		var env: float = minf(1.0, t / 0.008) * exp(-3.4 * t / dur)
		buf[i] = sin(phase) * env * vol
	return _wav(buf)


func _chord(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = minf(1.0, t / 0.02) * exp(-2.6 * t / dur)
		var s := 0.0
		for f in freqs:
			s += sin(TAU * float(f) * t)
		buf[i] = s / float(freqs.size()) * env * vol
	return _wav(buf)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 22050
	s.stereo = false
	s.data = data
	return s
