extends Node

## Global Audio Manager
## Handles continuous background music playback and interactive keyboard sound effects.

const BG_LOOP_PATH: String = "res://data/audio/bgloop.mp3"
const KEYBOARD_EFFECT_PATH: String = "res://data/audio/keyboardpressing_effect.mp3"

var bgm_player: AudioStreamPlayer = null
var keyboard_player: AudioStreamPlayer = null
var _stop_typing_timer: Timer = null
var _active_typing_keys: Dictionary = {}

const IGNORED_KEYS = [
	KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
	KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bgm_player()
	_setup_keyboard_player()

# ----------------- Background Music -----------------

func _setup_bgm_player() -> void:
	if bgm_player != null:
		return
		
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	_load_bgm_stream()
	bgm_player.finished.connect(_on_bgm_finished)

func _load_bgm_stream() -> void:
	if ResourceLoader.exists(BG_LOOP_PATH):
		var stream = load(BG_LOOP_PATH)
		if stream is AudioStreamMP3:
			stream.loop = true
			stream.loop_offset = 0.0
		bgm_player.stream = stream

func _on_bgm_finished() -> void:
	# Fallback if loop flag reaches the end to guarantee continuous replay without gaps
	if bgm_player:
		bgm_player.play()

func play_bgm(fade_duration: float = 0.0) -> void:
	if bgm_player == null:
		_setup_bgm_player()
	if bgm_player.stream == null:
		_load_bgm_stream()
	if not is_inside_tree() or not bgm_player.is_inside_tree():
		return
	if bgm_player.stream and not bgm_player.playing:
		if fade_duration > 0.0:
			bgm_player.volume_db = -80.0
			bgm_player.play()
			var tween = create_tween()
			tween.tween_property(bgm_player, "volume_db", 0.0, fade_duration)
		else:
			bgm_player.volume_db = 0.0
			bgm_player.play()

func stop_bgm() -> void:
	if bgm_player and bgm_player.playing:
		bgm_player.stop()

func pause_bgm() -> void:
	if bgm_player:
		bgm_player.stream_paused = true

func resume_bgm() -> void:
	if bgm_player:
		bgm_player.stream_paused = false

func is_bgm_playing() -> bool:
	return bgm_player != null and bgm_player.playing

# ----------------- Keyboard Typing Sound Effect -----------------

func _setup_keyboard_player() -> void:
	if keyboard_player != null:
		return
		
	keyboard_player = AudioStreamPlayer.new()
	keyboard_player.name = "KeyboardFXPlayer"
	keyboard_player.bus = "Master"
	keyboard_player.volume_db = -3.0
	add_child(keyboard_player)
	
	if ResourceLoader.exists(KEYBOARD_EFFECT_PATH):
		var stream = load(KEYBOARD_EFFECT_PATH)
		if stream is AudioStreamMP3:
			stream.loop = true
			stream.loop_offset = 0.0
		keyboard_player.stream = stream
		
	keyboard_player.finished.connect(func():
		if not _active_typing_keys.is_empty() and keyboard_player:
			keyboard_player.play()
	)
		
	_stop_typing_timer = Timer.new()
	_stop_typing_timer.name = "StopTypingTimer"
	_stop_typing_timer.one_shot = true
	_stop_typing_timer.wait_time = 0.09
	_stop_typing_timer.timeout.connect(_on_typing_timeout)
	add_child(_stop_typing_timer)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
		
	var key_event := event as InputEventKey
	var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	
	if key_event.pressed:
		if code in IGNORED_KEYS:
			return
		_active_typing_keys[code] = true
		_start_typing_sound()
	else:
		_active_typing_keys.erase(code)
		if _active_typing_keys.is_empty():
			if _stop_typing_timer:
				_stop_typing_timer.start(0.09)

func _start_typing_sound() -> void:
	if _stop_typing_timer and not _stop_typing_timer.is_stopped():
		_stop_typing_timer.stop()
		
	if keyboard_player and keyboard_player.stream:
		if not keyboard_player.playing:
			keyboard_player.play()
		elif keyboard_player.stream_paused:
			keyboard_player.stream_paused = false

func _on_typing_timeout() -> void:
	if _active_typing_keys.is_empty():
		_stop_typing_sound()

func _stop_typing_sound() -> void:
	if keyboard_player and keyboard_player.playing:
		keyboard_player.stream_paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_active_typing_keys.clear()
		_stop_typing_sound()
