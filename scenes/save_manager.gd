extends Node
class_name SaveManager

static var _instance: SaveManager = null

const SAVE_PATH: String = "user://save_data.json"

var current_unlocked_level: int = 30
var open_tabs: Array[String] = ["level_30/INTRODUCTION.md", "level_30/task.py"]
var active_file: String = "level_30/INTRODUCTION.md"
var modified_files: Dictionary = {}
var dialogues_shown: Dictionary = {}
var game_stats: Dictionary = {
	"actions_count": 0,
	"tasks_passed": 0
}
var player_money: int = 500
var installed_extensions: Array[String] = []
var active_theme_extension: String = ""
var settings: Dictionary = {
	"fullscreen": true,
	"window_width": 1280,
	"window_height": 720,
	"volume": 100.0,
	"mute": false
}

var _was_maximized_before_minimize: bool = false
var _is_maximized: bool = false
var _saved_window_pos: Vector2i = Vector2i.ZERO

signal state_changed
signal money_changed(new_amount: int)

static func get_instance() -> SaveManager:
	if _instance != null and is_instance_valid(_instance):
		return _instance
		
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var root = (main_loop as SceneTree).root
		if root:
			if root.has_node("SaveManager"):
				_instance = root.get_node("SaveManager") as SaveManager
				return _instance
			else:
				var sm = SaveManager.new()
				sm.name = "SaveManager"
				_instance = sm
				sm.load_game()
				root.add_child.call_deferred(sm)
				return _instance
				
	if _instance == null:
		_instance = SaveManager.new()
		_instance.load_game()
	return _instance

func _enter_tree() -> void:
	if _instance == null or not is_instance_valid(_instance):
		_instance = self

func _ready() -> void:
	if _instance == null or not is_instance_valid(_instance):
		_instance = self
	load_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_restore_borderless_deferred()

func _restore_borderless_deferred() -> void:
	if not is_inside_tree():
		return
	# Wait for the OS window restore animation to finish before re-enabling borderless
	var tree = get_tree()
	if tree:
		await tree.create_timer(0.4).timeout
	if not is_inside_tree():
		return
	var is_full = bool(settings.get("fullscreen", true))
	if not is_full and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		if _was_maximized_before_minimize:
			var screen = DisplayServer.window_get_current_screen()
			var usable = DisplayServer.screen_get_usable_rect(screen)
			DisplayServer.window_set_position(usable.position)
			DisplayServer.window_set_size(usable.size)
			_is_maximized = true
			_was_maximized_before_minimize = false

func minimize_window() -> void:
	var is_full = bool(settings.get("fullscreen", true))
	if is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		return

	_was_maximized_before_minimize = _is_maximized or (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_mode.call_deferred(DisplayServer.WINDOW_MODE_MINIMIZED)

func toggle_maximize_window() -> void:
	var is_full = bool(settings.get("fullscreen", true))
	if is_full:
		return
		
	var screen = DisplayServer.window_get_current_screen()
	var usable = DisplayServer.screen_get_usable_rect(screen)
	
	if _is_maximized or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		# Restore down to normal windowed size
		_is_maximized = false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
		var w = int(settings.get("window_width", 1280))
		var h = int(settings.get("window_height", 720))
		var target_size = Vector2i(w, h)
		
		var pos = _saved_window_pos
		if pos == Vector2i.ZERO or not usable.has_point(pos):
			pos = usable.position + (usable.size - target_size) / 2
			
		DisplayServer.window_set_size(target_size)
		DisplayServer.window_set_position(pos)
	else:
		# Maximize: fill usable monitor area
		_is_maximized = true
		_saved_window_pos = DisplayServer.window_get_position()
		
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_position(usable.position)
		DisplayServer.window_set_size(usable.size)

func save_game() -> void:
	game_stats["actions_count"] = game_stats.get("actions_count", 0) + 1
	var save_dict: Dictionary = {
		"current_unlocked_level": current_unlocked_level,
		"open_tabs": open_tabs,
		"active_file": active_file,
		"modified_files": modified_files,
		"dialogues_shown": dialogues_shown,
		"game_stats": game_stats,
		"player_money": player_money,
		"installed_extensions": installed_extensions,
		"active_theme_extension": active_theme_extension,
		"settings": settings,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var json_string = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_defaults()
		_apply_settings()
		save_game()
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_ensure_defaults()
		_apply_settings()
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		_ensure_defaults()
		_apply_settings()
		return
		
	var data = json.data
	if typeof(data) == TYPE_DICTIONARY:
		current_unlocked_level = int(data.get("current_unlocked_level", 30))
		player_money = int(data.get("player_money", 500))
		var raw_exts = data.get("installed_extensions", [])
		installed_extensions.clear()
		for ex in raw_exts:
			installed_extensions.append(str(ex))
		active_theme_extension = str(data.get("active_theme_extension", ""))
		
		var raw_tabs = data.get("open_tabs", [])
		open_tabs.clear()
		for tab in raw_tabs:
			var tab_str = str(tab)
			# Do not restore checker.py in tabs
			if not tab_str.ends_with("checker.py") and not tab_str.is_empty():
				open_tabs.append(tab_str)
				
		active_file = str(data.get("active_file", ""))
		if active_file.ends_with("checker.py"):
			active_file = ""
			
		modified_files = data.get("modified_files", {})
		dialogues_shown = data.get("dialogues_shown", {})
		game_stats = data.get("game_stats", {"actions_count": 0, "tasks_passed": 0})
		
		var loaded_settings = data.get("settings", {})
		if typeof(loaded_settings) == TYPE_DICTIONARY:
			for k in loaded_settings.keys():
				settings[k] = loaded_settings[k]
		
	_ensure_defaults()
	_apply_settings()
	state_changed.emit()
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	save_game()
	state_changed.emit()

func _apply_settings() -> void:
	# Always borderless — no OS chrome; custom topbar handles windowed title/drag
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	var is_full = bool(settings.get("fullscreen", true))
	if is_full:
		_is_maximized = false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var screen = DisplayServer.window_get_current_screen()
		var usable = DisplayServer.screen_get_usable_rect(screen)
		if _is_maximized:
			DisplayServer.window_set_position(usable.position)
			DisplayServer.window_set_size(usable.size)
		else:
			var w = int(settings.get("window_width", 1280))
			var h = int(settings.get("window_height", 720))
			var target_size = Vector2i(w, h)
			DisplayServer.window_set_size(target_size)
			var pos = usable.position + (usable.size - target_size) / 2
			DisplayServer.window_set_position(pos)
		
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		var is_mute = bool(settings.get("mute", false))
		AudioServer.set_bus_mute(bus_idx, is_mute)
		var vol = float(settings.get("volume", 100.0))
		if vol > 1.0:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol / 100.0))

static func get_available_window_sizes() -> Array[Vector2i]:
	var screen_idx = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(screen_idx)
	
	# Proportional scales relative to the user's native fullscreen resolution
	var fractions = [1.0, 5.0 / 6.0, 3.0 / 4.0, 2.0 / 3.0, 1.0 / 2.0]
	var sizes: Array[Vector2i] = []
	
	for frac in fractions:
		var w = int(round(screen_size.x * frac))
		var h = int(round(screen_size.y * frac))
		# Snap to even dimensions
		w = (w / 2) * 2
		h = (h / 2) * 2
		if w >= 800 and h >= 450 and w <= screen_size.x and h <= screen_size.y:
			var vec = Vector2i(w, h)
			if not sizes.has(vec):
				sizes.append(vec)
				
	if sizes.is_empty():
		sizes.append(Vector2i(1280, 720))
		return sizes
	
	# Remove the first (native/fullscreen) size — it's redundant with Fullscreen mode
	if sizes.size() > 1:
		sizes.remove_at(0)
		
	return sizes



func _ensure_defaults() -> void:
	if open_tabs.is_empty():
		open_tabs = ["level_30/INTRODUCTION.md", "level_30/task.py"]
	if active_file.is_empty() or not open_tabs.has(active_file):
		active_file = open_tabs[0]

func get_file_content(relative_path: String) -> String:
	if modified_files.has(relative_path):
		return str(modified_files[relative_path])
		
	# Try levels subdirectory first, then fallback to base files directory
	var level_path = "res://files/levels/" + relative_path
	if FileAccess.file_exists(level_path):
		return FileAccess.get_file_as_string(level_path)

	var full_res_path = "res://files/" + relative_path
	if FileAccess.file_exists(full_res_path):
		return FileAccess.get_file_as_string(full_res_path)
			
	return ""

func set_file_content(relative_path: String, content: String) -> void:
	if relative_path.is_empty():
		return
	modified_files[relative_path] = content
	save_game()

func has_modified_file(relative_path: String) -> bool:
	return modified_files.has(relative_path)

func set_active_file(file_path: String) -> void:
	active_file = file_path
	save_game()

func set_open_tabs(tabs: Array) -> void:
	open_tabs.clear()
	for t in tabs:
		var tab_str = str(t)
		if not tab_str.ends_with("checker.py") and not tab_str.is_empty():
			open_tabs.append(tab_str)
	save_game()

func add_open_tab(file_path: String) -> void:
	if file_path.is_empty() or file_path.ends_with("checker.py"):
		return
	if not open_tabs.has(file_path):
		open_tabs.append(file_path)
		save_game()

func remove_open_tab(file_path: String) -> void:
	if open_tabs.has(file_path):
		open_tabs.erase(file_path)
		save_game()

func unlock_level(lvl: int) -> void:
	if lvl < current_unlocked_level:
		current_unlocked_level = lvl
		game_stats["tasks_passed"] = game_stats.get("tasks_passed", 0) + 1
		# Grant task completion reward
		add_money(250)
		save_game()

func get_money() -> int:
	return player_money

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	player_money += amount
	save_game()
	money_changed.emit(player_money)
	state_changed.emit()

func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if player_money >= amount:
		player_money -= amount
		save_game()
		money_changed.emit(player_money)
		state_changed.emit()
		return true
	return false

func is_extension_installed(ext_id: String) -> bool:
	return installed_extensions.has(ext_id)

func install_extension(ext_id: String) -> bool:
	if not installed_extensions.has(ext_id):
		installed_extensions.append(ext_id)
		save_game()
		state_changed.emit()
		return true
	return false

func uninstall_extension(ext_id: String) -> void:
	if installed_extensions.has(ext_id):
		installed_extensions.erase(ext_id)
		if active_theme_extension == ext_id:
			active_theme_extension = ""
		save_game()
		state_changed.emit()

func set_active_theme_extension(ext_id: String) -> void:
	active_theme_extension = ext_id
	save_game()
	state_changed.emit()

func is_dialogue_shown(key: String) -> bool:
	return bool(dialogues_shown.get(key, false))

func mark_dialogue_shown(key: String) -> void:
	dialogues_shown[key] = true
	save_game()

func has_saved_progress() -> bool:
	if current_unlocked_level < 30:
		return true
	if not modified_files.is_empty():
		return true
	if game_stats.get("tasks_passed", 0) > 0:
		return true
	return false

func reset_save() -> void:
	current_unlocked_level = 30
	open_tabs = ["level_30/INTRODUCTION.md", "level_30/task.py"]
	active_file = "level_30/INTRODUCTION.md"
	modified_files.clear()
	dialogues_shown.clear()
	game_stats = {"actions_count": 0, "tasks_passed": 0}
	player_money = 500
	installed_extensions.clear()
	active_theme_extension = ""
	save_game()
	money_changed.emit(player_money)
	state_changed.emit()
