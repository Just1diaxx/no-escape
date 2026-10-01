extends Control
class_name MainMenu

signal continue_pressed
signal new_game_pressed

# Containers for in-place transitions
@onready var main_nav: VBoxContainer = %MainNav
@onready var settings_nav: VBoxContainer = %SettingsNav
@onready var confirm_nav: VBoxContainer = %ConfirmNav

# Main Buttons
@onready var continue_btn: Button = %ContinueButton
@onready var new_game_btn: Button = %NewGameButton
@onready var settings_btn: Button = %SettingsButton
@onready var quit_btn: Button = %QuitButton

# Sub-labels
@onready var continue_sub_label: Label = %ContinueSubLabel

# Settings Controls
@onready var fullscreen_btn: Button = %FullscreenButton
@onready var window_size_row: HBoxContainer = %WindowSizeRow
@onready var window_size_btn: Button = %WindowSizeButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_val_label: Label = %VolumeValueLabel
@onready var mute_btn: Button = %MuteButton
@onready var settings_back_btn: Button = %SettingsBackButton

# Confirm Controls
@onready var confirm_yes_btn: Button = %ConfirmYesButton
@onready var confirm_cancel_btn: Button = %ConfirmCancelButton

var _original_btn_texts: Dictionary = {}

func _ready() -> void:
	_setup_button_hover_effects()
	_update_save_display()
	_setup_settings_defaults()
	_setup_signals()
	
	if has_node("/root/AudioManager") and not AudioManager.is_bgm_playing():
		AudioManager.play_bgm(0.8)
	
	# Initial states
	main_nav.visible = true
	main_nav.modulate.a = 1.0
	settings_nav.visible = false
	settings_nav.modulate.a = 0.0
	confirm_nav.visible = false
	confirm_nav.modulate.a = 0.0

func _setup_button_hover_effects() -> void:
	var buttons = [continue_btn, new_game_btn, settings_btn, quit_btn, settings_back_btn, confirm_cancel_btn]
	for btn in buttons:
		if btn:
			_original_btn_texts[btn] = btn.text
			btn.mouse_entered.connect(func(): _on_button_hover(btn, true))
			btn.mouse_exited.connect(func(): _on_button_hover(btn, false))

func _on_button_hover(btn: Button, hovered: bool) -> void:
	if not _original_btn_texts.has(btn):
		return
	var base_text = _original_btn_texts[btn]
	if hovered:
		btn.text = "> " + base_text
		btn.add_theme_color_override("font_color", Color("#38bdf8"))
	else:
		btn.text = base_text
		btn.remove_theme_color_override("font_color")

func _update_save_display() -> void:
	var sm = SaveManager.get_instance()
	if sm.has_saved_progress():
		continue_sub_label.text = "clearance: level %02d" % sm.current_unlocked_level
		continue_sub_label.visible = true
	else:
		continue_sub_label.visible = false

func _setup_signals() -> void:
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	settings_back_btn.pressed.connect(_on_settings_back_pressed)
	fullscreen_btn.pressed.connect(_toggle_fullscreen)
	window_size_btn.pressed.connect(_cycle_window_size)
	mute_btn.pressed.connect(_toggle_mute)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	confirm_yes_btn.pressed.connect(_on_confirm_yes_pressed)
	confirm_cancel_btn.pressed.connect(_on_confirm_cancel_pressed)

func _setup_settings_defaults() -> void:
	var sm = SaveManager.get_instance()
	var is_fullscreen = bool(sm.settings.get("fullscreen", true))
	fullscreen_btn.text = "[ FULLSCREEN ]" if is_fullscreen else "[ WINDOWED ]"
	
	# Window size option only visible when windowed
	window_size_row.visible = not is_fullscreen
	var cur_w = int(sm.settings.get("window_width", 1280))
	var cur_h = int(sm.settings.get("window_height", 720))
	window_size_btn.text = "[ %d x %d ]" % [cur_w, cur_h]
	
	var vol = float(sm.settings.get("volume", 100.0))
	volume_slider.value = vol
	volume_val_label.text = "%d%%" % int(vol)
	
	var is_muted = bool(sm.settings.get("mute", false))
	mute_btn.text = "[ MUTED ]" if is_muted else "[ ACTIVE ]"

# Navigation Transitions
func _switch_nav(from_node: Control, to_node: Control) -> void:
	var tween = create_tween()
	tween.tween_property(from_node, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		from_node.visible = false
		to_node.visible = true
		to_node.modulate.a = 0.0
	)
	tween.tween_property(to_node, "modulate:a", 1.0, 0.15)

func _on_continue_pressed() -> void:
	continue_pressed.emit()

func _on_new_game_pressed() -> void:
	var sm = SaveManager.get_instance()
	if sm.has_saved_progress():
		_switch_nav(main_nav, confirm_nav)
	else:
		new_game_pressed.emit()

func _on_confirm_yes_pressed() -> void:
	new_game_pressed.emit()

func _on_confirm_cancel_pressed() -> void:
	_switch_nav(confirm_nav, main_nav)

func _on_settings_pressed() -> void:
	_switch_nav(main_nav, settings_nav)

func _on_settings_back_pressed() -> void:
	_switch_nav(settings_nav, main_nav)

func _on_quit_pressed() -> void:
	get_tree().quit()

# Settings Logic - fully persisted via SaveManager
func _toggle_fullscreen() -> void:
	var sm = SaveManager.get_instance()
	var current_full = bool(sm.settings.get("fullscreen", true))
	var new_full = not current_full
	sm.set_setting("fullscreen", new_full)
	fullscreen_btn.text = "[ FULLSCREEN ]" if new_full else "[ WINDOWED ]"
	window_size_row.visible = not new_full

func _cycle_window_size() -> void:
	var sm = SaveManager.get_instance()
	var available = SaveManager.get_available_window_sizes()
	if available.is_empty():
		return
		
	var cur_w = int(sm.settings.get("window_width", 1280))
	var cur_h = int(sm.settings.get("window_height", 720))
	var cur_vec = Vector2i(cur_w, cur_h)
	
	var current_idx = available.find(cur_vec)
	var next_idx = (current_idx + 1) % available.size()
	var next_size = available[next_idx]
	
	sm.set_setting("window_width", next_size.x)
	sm.set_setting("window_height", next_size.y)
	window_size_btn.text = "[ %d x %d ]" % [next_size.x, next_size.y]

func _on_volume_changed(val: float) -> void:
	volume_val_label.text = "%d%%" % int(val)
	var sm = SaveManager.get_instance()
	sm.set_setting("volume", val)

func _toggle_mute() -> void:
	var sm = SaveManager.get_instance()
	var current_mute = bool(sm.settings.get("mute", false))
	var new_mute = not current_mute
	sm.set_setting("mute", new_mute)
	mute_btn.text = "[ MUTED ]" if new_mute else "[ ACTIVE ]"
