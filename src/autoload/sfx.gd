extends Node
## Every sound is synthesised here at start-up: no audio files. Short effects
## play on a small pool of players; the cave drone and the heartbeat loop
## underneath, and the heartbeat gets louder the deeper the room.

const RATE := 22050

var _sounds := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _drone: AudioStreamPlayer
var _beat: AudioStreamPlayer
var beat_level := 0.0  # 0 silent .. 1 pounding

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_sounds = {
		"swing": _make(0.12, func(t, i): return _noise(i) * (1.0 - t / 0.12) * 0.35 * (0.5 + 0.5 * sin(t * 900.0))),
		"hit": _make(0.1, func(t, i): return (_sq(t * 180.0 * (1.0 - t * 4.0)) * 0.3 + _noise(i) * 0.2) * (1.0 - t / 0.1)),
		"hurt": _make(0.25, func(t, i): return _sq(t * (220.0 - t * 500.0)) * 0.35 * (1.0 - t / 0.25)),
		"candy": _make(0.12, func(t, _i): return _sq(t * (988.0 if t < 0.05 else 1318.0)) * 0.18 * (1.0 - t / 0.12)),
		"jump": _make(0.08, func(t, _i): return _sq(t * (300.0 + t * 2500.0)) * 0.12 * (1.0 - t / 0.08)),
		"kill": _make(0.3, func(t, i): return _noise(i / 3) * 0.4 * (1.0 - t / 0.3)),
		"rest": _make(0.9, func(t, _i): return (sin(TAU * 523.0 * t) + sin(TAU * 659.0 * t) * 0.7 + sin(TAU * 784.0 * t) * 0.5) * 0.12 * min(1.0, t * 20.0) * (1.0 - t / 0.9)),
		"page": _make(0.2, func(t, i): return _noise(i) * 0.15 * sin(t * PI / 0.2)),
		"roar": _make(1.2, func(t, i): return (_noise(i / 6) * 0.5 + _sq(t * (70.0 - t * 20.0)) * 0.3) * min(1.0, t * 8.0) * (1.0 - t / 1.2)),
		"thud": _make(0.35, func(t, _i): return sin(TAU * (55.0 - t * 60.0) * t) * 0.7 * exp(-t * 12.0)),
		"gate": _make(0.5, func(t, i): return (_noise(i / 4) * 0.4 + sin(TAU * 40.0 * t) * 0.4) * (1.0 - t / 0.5)),
		"whisper": _make(1.6, func(t, i): return _noise(i) * 0.12 * sin(t * PI / 1.6) * (0.6 + 0.4 * sin(t * 37.0))),
		"power": _make(1.0, func(t, _i): return _sq(t * (220.0 + t * 660.0)) * 0.15 * (1.0 - t)),
	}
	_drone = _loop_player(_make(4.0, func(t, i): return (sin(TAU * 49.0 * t) * 0.5 + sin(TAU * 73.5 * t) * 0.3 + _noise(i / 40) * 0.25) * (0.75 + 0.25 * sin(TAU * t / 4.0)) * 0.22, true))
	_beat = _loop_player(_make(1.25, func(t, _i):
		var a := sin(TAU * 48.0 * t) * exp(-t * 14.0)
		var b := sin(TAU * 44.0 * (t - 0.28)) * exp(-(t - 0.28) * 14.0) if t > 0.28 else 0.0
		return (a + b * 0.8) * 0.9, true))
	_drone.volume_db = -14.0
	_beat.volume_db = -60.0

func _process(delta: float) -> void:
	var target := lerpf(-60.0, -6.0, sqrt(clampf(beat_level, 0.0, 1.0)))
	_beat.volume_db = move_toward(_beat.volume_db, target, 30.0 * delta)

func _loop_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p

func start_ambience() -> void:
	if not _drone.playing:
		_drone.play()
		_beat.play()

func play(name: String, pitch := 1.0) -> void:
	if not _sounds.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()

static func _noise(i: int) -> float:
	var n := (i * 1103515245 + 12345) & 0x7fffffff
	n = (n ^ (n >> 11)) * 2654435761 & 0x7fffffff
	return float(n % 2000) / 1000.0 - 1.0

static func _sq(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

func _make(seconds: float, f: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(f.call(float(i) / RATE, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s
