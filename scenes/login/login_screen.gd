extends Control
class_name LoginScreen

signal login_succeeded

const USERNAME_MAX_DOTS: int = 8
const PASSWORD_MAX_DOTS: int = 14
const DOT_CHAR: String = "•"

@onready var username_value_label: Label = %UsernameValue
@onready var password_value_label: Label = %PasswordValue
@onready var username_container: PanelContainer = %UsernameContainer
@onready var password_container: PanelContainer = %PasswordContainer
@onready var login_button: Button = %LoginButton
@onready var error_label: Label = %ErrorLabel
@onready var card_panel: PanelContainer = %CardPanel
@onready var hint_label: Label = %HintLabel
@onready var clock_label: Label = %ClockLabel
@onready var progress_bar: ProgressBar = %ProgressBar

var username_dots: int = 0
var password_dots: int = 0
var _shake_tween: Tween
var _fade_tween: Tween

func _ready() -> void:
	login_button.pressed.connect(_on_login_pressed)
	_update_ui()
	_update_clock()
	
	# Start clock timer
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_clock)
	timer.autostart = true
	add_child(timer)

func _update_clock() -> void:
	var time_dict = Time.get_time_dict_from_system()
	if clock_label:
		clock_label.text = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
		
	# Ignore control / navigation keys for typing
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_on_login_pressed()
		return
	elif event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_CAPSLOCK, KEY_ESCAPE, KEY_TAB]:
		return
		
	# Any random key pressed advances the dots
	_advance_fake_typing()

func _advance_fake_typing() -> void:
	if username_dots < USERNAME_MAX_DOTS:
		username_dots += 1
		_pulse_field(username_container)
	elif password_dots < PASSWORD_MAX_DOTS:
		password_dots += 1
		_pulse_field(password_container)
		
	_update_ui()

func _update_ui() -> void:
	# Username display
	if username_dots == 0:
		username_value_label.text = ""
		username_value_label.get_parent().get_node("Placeholder").visible = true
	else:
		username_value_label.text = DOT_CHAR.repeat(username_dots)
		username_value_label.get_parent().get_node("Placeholder").visible = false
		
	# Password display
	if password_dots == 0:
		password_value_label.text = ""
		password_value_label.get_parent().get_node("Placeholder").visible = true
	else:
		password_value_label.text = DOT_CHAR.repeat(password_dots)
		password_value_label.get_parent().get_node("Placeholder").visible = false
		
	# Highlight active field
	if username_dots < USERNAME_MAX_DOTS:
		_highlight_container(username_container, true)
		_highlight_container(password_container, false)
		hint_label.text = "Type on keyboard to input Username... (%d/%d)" % [username_dots, USERNAME_MAX_DOTS]
	elif password_dots < PASSWORD_MAX_DOTS:
		_highlight_container(username_container, false)
		_highlight_container(password_container, true)
		hint_label.text = "Type on keyboard to input Password... (%d/%d)" % [password_dots, PASSWORD_MAX_DOTS]
	else:
		_highlight_container(username_container, false)
		_highlight_container(password_container, false)
		hint_label.text = "✓ Credentials entered. Click LOGIN or press Enter."
		
	# Progress bar
	var total_typed = username_dots + password_dots
	var total_required = USERNAME_MAX_DOTS + PASSWORD_MAX_DOTS
	progress_bar.value = (float(total_typed) / float(total_required)) * 100.0

func _highlight_container(container: PanelContainer, active: bool) -> void:
	var sb: StyleBoxFlat = container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if active:
		sb.border_color = Color(0.0, 0.47, 0.8, 1.0) # VS Code Blue
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	else:
		sb.border_color = Color(0.2, 0.25, 0.32, 1.0)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
	container.add_theme_stylebox_override("panel", sb)

func _pulse_field(container: PanelContainer) -> void:
	var tween = create_tween()
	tween.tween_property(container, "scale", Vector2(1.02, 1.02), 0.04)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.04)

func is_typing_complete() -> bool:
	return username_dots >= USERNAME_MAX_DOTS and password_dots >= PASSWORD_MAX_DOTS

func _on_login_pressed() -> void:
	if not is_typing_complete():
		_show_error("⚠️ Incorrect credentials. Sequence incomplete.")
	else:
		_login_success()

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true
	error_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	
	# Shake effect
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		
	var orig_pos = card_panel.position
	_shake_tween = create_tween()
	_shake_tween.tween_property(card_panel, "position:x", orig_pos.x - 14, 0.04)
	_shake_tween.tween_property(card_panel, "position:x", orig_pos.x + 14, 0.04)
	_shake_tween.tween_property(card_panel, "position:x", orig_pos.x - 8, 0.04)
	_shake_tween.tween_property(card_panel, "position:x", orig_pos.x + 8, 0.04)
	_shake_tween.tween_property(card_panel, "position:x", orig_pos.x, 0.04)

func _login_success() -> void:
	error_label.visible = true
	error_label.text = "✓ Access granted. Initializing environment..."
	error_label.modulate = Color(0.2, 0.9, 0.4, 1.0)
	login_button.disabled = true
	
	var tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func(): login_succeeded.emit())
