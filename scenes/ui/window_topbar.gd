extends CanvasLayer

## Custom window chrome for windowed/borderless mode.
## Shown only when Fullscreen is OFF; hidden in fullscreen.

const BAR_HEIGHT := 28

@onready var bar: Panel = $Bar
@onready var title_label: Label = $Bar/TitleLabel
@onready var minimize_btn: Button = $Bar/ButtonsBox/MinimizeButton
@onready var maximize_btn: Button = $Bar/ButtonsBox/MaximizeButton
@onready var close_btn: Button = $Bar/ButtonsBox/CloseButton

var _dragging := false
var _drag_offset := Vector2i.ZERO

func _ready() -> void:
	layer = 99
	_refresh_visibility()
	
	minimize_btn.pressed.connect(_on_minimize)
	maximize_btn.pressed.connect(_on_maximize)
	close_btn.pressed.connect(_on_close)
	
	# Listen for setting changes so we react when the user toggles fullscreen
	var sm = SaveManager.get_instance()
	if sm:
		sm.state_changed.connect(_refresh_visibility)
		
	# Listen for main state changes so we hide generic topbar inside IDE
	var main_node = get_parent()
	if main_node and main_node.has_signal("state_changed"):
		main_node.state_changed.connect(func(_state): _refresh_visibility())

func _refresh_visibility() -> void:
	var sm = SaveManager.get_instance()
	var is_fullscreen = bool(sm.settings.get("fullscreen", true))
	maximize_btn.visible = not is_fullscreen
	
	# Check if we are currently in the IDE screen
	var is_ide := false
	var main_node = get_parent()
	if main_node and "current_state" in main_node:
		if main_node.current_state in [Main.GameState.IDE, Main.GameState.DEBUG_IDE]:
			is_ide = true
			
	# Show generic topbar only when windowed AND not in IDE screen
	var should_show = (not is_fullscreen) and (not is_ide)
	bar.visible = should_show
	
	# Shift the viewport content down only when the generic topbar is active
	var offset_y := BAR_HEIGHT if should_show else 0
	get_viewport().canvas_transform = Transform2D(0, Vector2(0, offset_y))

func _on_minimize() -> void:
	SaveManager.get_instance().minimize_window()

func _on_maximize() -> void:
	SaveManager.get_instance().toggle_maximize_window()

func _on_close() -> void:
	get_tree().quit()

# ─── Drag Logic ───────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not bar.visible:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := DisplayServer.mouse_get_position()
		var win_pos  := DisplayServer.window_get_position()
		var local_y  := mouse_pos.y - win_pos.y
		
		if event.pressed and local_y >= 0 and local_y <= BAR_HEIGHT:
			var sm = SaveManager.get_instance()
			if sm and sm._is_maximized:
				sm.toggle_maximize_window()
			_dragging = true
			_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		else:
			_dragging = false
			
	elif event is InputEventMouseMotion and _dragging:
		var new_pos := DisplayServer.mouse_get_position() - _drag_offset
		DisplayServer.window_set_position(new_pos)
