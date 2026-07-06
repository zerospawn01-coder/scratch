extends Node

var _player_pool: Array[AudioStreamPlayer] = []
var _pool_size: int = 8

var snd_hack: AudioStreamWAV
var snd_buy: AudioStreamWAV
var snd_hit: AudioStreamWAV
var snd_win: AudioStreamWAV
var snd_lose: AudioStreamWAV

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	# Generate sounds
	snd_hack = _gen_hack_sound()
	snd_buy = _gen_buy_sound()
	snd_hit = _gen_hit_sound()
	snd_win = _gen_win_sound()
	snd_lose = _gen_lose_sound()
	
	# Create pool of players
	for i in range(_pool_size):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_player_pool.append(player)

func _get_idle_player() -> AudioStreamPlayer:
	for p in _player_pool:
		if not p.playing:
			return p
	return _player_pool[0]

func play_hack() -> void:
	_play(snd_hack)

func play_buy() -> void:
	_play(snd_buy)

func play_hit() -> void:
	_play(snd_hit)

func play_win() -> void:
	_play(snd_win)

func play_lose() -> void:
	_play(snd_lose)

func _play(stream: AudioStreamWAV) -> void:
	if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
		return
	var player = _get_idle_player()
	player.stream = stream
	player.play()

func _gen_hack_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	
	var duration = 0.08
	var num_samples = int(duration * stream.mix_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / stream.mix_rate
		var progress = float(i) / num_samples
		var freq = lerpf(800.0, 1600.0, progress)
		var env = 1.0 - progress
		var val = sin(2.0 * PI * freq * t) * env * 0.4
		data[i] = int(128 + val * 127)
		
	stream.data = data
	return stream

func _gen_buy_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	
	var duration = 0.25
	var num_samples = int(duration * stream.mix_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / stream.mix_rate
		var progress = float(i) / num_samples
		var freq = 880.0 if progress < 0.35 else 1109.0
		var env = 1.0 - progress
		var val = sin(2.0 * PI * freq * t) * env * 0.5
		data[i] = int(128 + val * 127)
		
	stream.data = data
	return stream

func _gen_hit_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	
	var duration = 0.12
	var num_samples = int(duration * stream.mix_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var progress = float(i) / num_samples
		var env = 1.0 - progress
		var val = (randf() * 2.0 - 1.0) * env * 0.5
		data[i] = int(128 + val * 127)
		
	stream.data = data
	return stream

func _gen_win_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	
	var duration = 0.6
	var num_samples = int(duration * stream.mix_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / stream.mix_rate
		var progress = float(i) / num_samples
		var freq = 523.25
		if progress > 0.75:
			freq = 1046.50
		elif progress > 0.5:
			freq = 783.99
		elif progress > 0.25:
			freq = 659.25
			
		var env = 1.0 - progress
		var val = sin(2.0 * PI * freq * t) * env * 0.4
		data[i] = int(128 + val * 127)
		
	stream.data = data
	return stream

func _gen_lose_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	
	var duration = 0.8
	var num_samples = int(duration * stream.mix_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / stream.mix_rate
		var progress = float(i) / num_samples
		var freq = lerpf(300.0, 80.0, progress)
		var env = 1.0 - progress
		var tone = sin(2.0 * PI * freq * t)
		var noise = (randf() * 2.0 - 1.0) * 0.3
		var val = (tone * 0.7 + noise * 0.3) * env * 0.5
		data[i] = int(128 + val * 127)
		
	stream.data = data
	return stream
