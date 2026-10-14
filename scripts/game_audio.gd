extends Node
signal event_played(kind: String, location: Vector3, pitch: float)
const KINDS := ["step", "kick", "bounce", "post", "net", "goal"]
@export_group("Sound files")
@export var step_sound: AudioStream = preload("res://assets/audio/step.wav")
@export var kick_sound: AudioStream = preload("res://assets/audio/kick.wav")
@export var bounce_sound: AudioStream = preload("res://assets/audio/bounce.wav")
@export var post_sound: AudioStream = preload("res://assets/audio/post.wav")
@export var net_sound: AudioStream = preload("res://assets/audio/net.wav")
@export var goal_sound: AudioStream = preload("res://assets/audio/goal.wav")
@export_group("Mix")
@export var streams: Dictionary[String, AudioStream] = {}
@export var effect_volumes := {"step": -10.0, "kick": -2.0, "bounce": -14.0, "post": -7.0, "net": -10.0, "goal": -11.0}
@export_range(-60, 0) var ambience_volume_db := -32.0
@export var ambience_stream: AudioStreamWAV
@export_range(4, 20) var voice_count := 10
var voices: Array[AudioStreamPlayer3D] = []
var next_voice := 0
var ambience: AudioStreamPlayer

func _ready() -> void:
	for kind in KINDS:
		if not streams.has(kind) or streams[kind] == null:
			streams[kind] = get(kind + "_sound")
	for index in range(voice_count):
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 15
		voice.max_distance = 80
		add_child(voice)
		voices.append(voice)
	ambience = AudioStreamPlayer.new()
	var bed: AudioStreamWAV = ambience_stream if ambience_stream else load("res://assets/audio/ambience.wav")
	bed = bed.duplicate()
	bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed.loop_end = int(bed.get_length() * bed.mix_rate)
	ambience.stream = bed
	ambience.volume_db = ambience_volume_db
	add_child(ambience)
	ambience.play()

func play_effect(kind: String, location: Vector3, pitch: float = 1) -> void:
	if not streams.has(kind):
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.stream = streams[kind]
	voice.global_position = location
	voice.pitch_scale = clampf(pitch, 0.4, 1.4)
	voice.volume_db = effect_volumes.get(kind, -10.0)
	voice.play()
	event_played.emit(kind, location, pitch)

func stop_effects() -> void:
	for voice in voices:
		voice.stop()

func _exit_tree() -> void:
	stop_effects()
	if ambience != null:
		ambience.stop()
		ambience.stream = null
	for voice in voices:
		voice.stream = null
	streams.clear()
