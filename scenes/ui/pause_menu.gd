extends Control
class_name PauseMenu

signal resumed
signal back_to_menu_pressed

@onready var backdrop: ColorRect = %Backdrop
@onready var dialog_panel: PanelContainer = %DialogPanel
@onready var clearance_label: Label = %ClearanceLabel

# Nav areas
@onready var main_nav: VBoxContainer = %MainNav
@onready var settings_nav: VBoxContainer = %SettingsNav

# Main Nav Buttons
@onready var continue_btn: Button = %ContinueButton
@onready var settings_btn: Button = %SettingsButton
@onready var back_to_menu_btn: Button = %BackToMenuButton

# Settings Controls
@onready var fullscreen_btn: Button = %FullscreenButton
@onready var window_size_row: HBoxContainer = %WindowSizeRow
@onready var window_size_btn: Button = %WindowSizeButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_val_label: Label = %VolumeValueLabel
@onready var mute_btn: Button = %MuteButton
@onready var settings_back_btn: Button = %SettingsBackButton

var _original_btn_texts: Dictionary = {}
var _is_open: bool = false
var _is_in_settings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_setup_button_hover_effects()
	_setup_signals()

func is_open() -> bool:
	return _is_open

func _setup_button_hover_effects() -> void:
	var buttons = [continue_btn, settings_btn, back_to_menu_btn, settings_back_btn]
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

func _setup_signals() -> void:
	continue_btn.pressed.connect(resume_game)
	settings_btn.pressed.connect(_on_settings_pressed)
	back_to_menu_btn.pressed.connect(_on_back_to_menu_pressed)
	
	settings_back_btn.pressed.connect(_on_settings_back_pressed)
	fullscreen_btn.pressed.connect(_toggle_fullscreen)
	window_size_btn.pressed.connect(_cycle_window_size)
	mute_btn.pressed.connect(_toggle_mute)
	volume_slider.value_changed.connect(_on_volume_changed)

func open_menu() -> void:
	if _is_open:
		return
	_is_open = true
	_is_in_settings = false
	
	var sm = SaveManager.get_instance()
	clearance_label.text = "SUB-LEVEL %02d // OPERATOR TERMINAL" % sm.current_unlocked_level
	_setup_settings_defaults()
	
	main_nav.visible = true
	main_nav.modulate.a = 1.0
	settings_nav.visible = false
	settings_nav.modulate.a = 0.0
	
	visible = true
	backdrop.modulate.a = 0.0
	dialog_panel.modulate.a = 0.0
	dialog_panel.pivot_offset = dialog_panel.size / 2.0
	dialog_panel.scale = Vector2(0.95, 0.95)
	
	get_tree().paused = true
	
	var tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.2)
	tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(dialog_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func resume_game() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_in_settings = false
	
	var tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(backdrop, "modulate:a", 0.0, 0.15)
	tween.tween_property(dialog_panel, "modulate:a", 0.0, 0.15)
	tween.tween_property(dialog_panel, "scale", Vector2(0.95, 0.95), 0.15)
	tween.chain().tween_callback(func():
		visible = false
		get_tree().paused = false
		resumed.emit()
	)

func _on_settings_pressed() -> void:
	_is_in_settings = true
	_switch_nav(main_nav, settings_nav)

func _on_settings_back_pressed() -> void:
	_is_in_settings = false
	_switch_nav(settings_nav, main_nav)

func _switch_nav(from_node: Control, to_node: Control) -> void:
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(from_node, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func():
		from_node.visible = false
		to_node.visible = true
		to_node.modulate.a = 0.0
	)
	tween.tween_property(to_node, "modulate:a", 1.0, 0.12)

func _on_back_to_menu_pressed() -> void:
	_is_open = false
	_is_in_settings = false
	visible = false
	get_tree().paused = false
	SaveManager.get_instance().save_game()
	back_to_menu_pressed.emit()

# Settings Logic
func _setup_settings_defaults() -> void:
	var sm = SaveManager.get_instance()
	var is_fullscreen = bool(sm.settings.get("fullscreen", true))
	fullscreen_btn.text = "[ FULLSCREEN ]" if is_fullscreen else "[ WINDOWED ]"
	window_size_row.visible = not is_fullscreen
	
	var cur_w = int(sm.settings.get("window_width", 1280))
	var cur_h = int(sm.settings.get("window_height", 720))
	window_size_btn.text = "[ %d x %d ]" % [cur_w, cur_h]
	
	var vol = float(sm.settings.get("volume", 100.0))
	volume_slider.value = vol
	volume_val_label.text = "%d%%" % int(vol)
	
	var is_muted = bool(sm.settings.get("mute", false))
	mute_btn.text = "[ MUTED ]" if is_muted else "[ ACTIVE ]"

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

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _is_in_settings:
			_on_settings_back_pressed()
		else:
			resume_game()
