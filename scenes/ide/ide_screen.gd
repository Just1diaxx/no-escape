extends Control
class_name IDEScreen

const PythonInterpreter = preload("res://scenes/ide/python_interpreter.gd")

# Vector SVG icon assets
const ICON_FOLDER = preload("res://addons/at-icons/control/folder.svg")
const ICON_FOLDER_OPEN = preload("res://addons/at-icons/control/folder_open.svg")
const ICON_FOLDER_LOCK = preload("res://addons/at-icons/control/folder_lock.svg")
const ICON_FILE_CODE = preload("res://addons/at-icons/control/file_code.svg")
const ICON_FILE_DOC = preload("res://addons/at-icons/control/file_document.svg")
const ICON_FILE_TERM = preload("res://addons/at-icons/control/file_terminal.svg")
const ICON_FILE_DEFAULT = preload("res://addons/at-icons/control/file.svg")
const ICON_CROSS = preload("res://addons/at-icons/control/cross.svg")
const ICON_CHECK = preload("res://addons/at-icons/control/checkmark.svg")
const ICON_PLAY = preload("res://addons/at-icons/control/play.svg")

signal close_requested

# System levels configuration
const FILES_BASE_PATH: String = "res://files/levels/"

# Internal state
var active_syntax_errors: Array[Dictionary] = []

# Highlighters
var py_highlighter: CodeHighlighter = null
var md_highlighter: CodeHighlighter = null
var doc_hover_panel: PanelContainer = null
var doc_hover_title: RichTextLabel = null
var doc_hover_body: RichTextLabel = null
var doc_hover_timer: Timer = null
var _last_hover_word: String = ""
var _last_hover_receiver: String = ""
var _last_hover_pos: Vector2 = Vector2.ZERO
var _panel_hovered: bool = false

@onready var file_list_container: VBoxContainer = %FileListContainer
@onready var tabs_container: HBoxContainer = %TabsContainer
@onready var breadcrumbs_label: Label = %BreadcrumbsLabel
@onready var code_editor: CodeEdit = %CodeEditor
@onready var markdown_viewer: RichTextLabel = %MarkdownViewer
@onready var empty_placeholder: CenterContainer = %EmptyPlaceholder
@onready var run_button: Button = %RunButton
@onready var status_file_type: Label = %StatusFileType
@onready var status_cursor_pos: Label = %StatusCursorPos
@onready var errors_warnings_label: Label = %ErrorsWarnings
@onready var escape_status_label: Label = %EscapeStatus
@onready var workspace_badge: Label = %WorkspaceBadge
@onready var prompt_label: Label = %PromptLabel
@onready var terminal_output: RichTextLabel = %TerminalOutput
@onready var terminal_input: LineEdit = %TerminalInput
@onready var terminal_view: VBoxContainer = %TerminalView
@onready var problems_view: ScrollContainer = %ProblemsView
@onready var problems_list: VBoxContainer = %ProblemsList
@onready var tab_term_btn: Button = %TabTermBtn
@onready var tab_problems_btn: Button = %TabProblemsBtn
@onready var tab_output_btn: Button = %TabOutputBtn
@onready var output_view: ScrollContainer = %OutputView
@onready var output_label: RichTextLabel = %OutputLabel
@onready var minimize_button: Button = %MinimizeButton
@onready var maximize_button: Button = %MaximizeButton
@onready var close_button: Button = %CloseButton
@onready var money_badge: Label = %MoneyBadge
@onready var explorer_icon: Button = %ExplorerIcon
@onready var extensions_icon: Button = %ExtensionsIcon
@onready var explorer_view: VBoxContainer = %ExplorerView
@onready var extensions_view: VBoxContainer = %ExtensionsView
@onready var extension_search_input: LineEdit = %ExtensionSearchInput
@onready var extensions_list_container: VBoxContainer = %ExtensionsListContainer

func _ready() -> void:
	_setup_syntax_highlighters()
	_setup_editor()
	_setup_doc_hover()
	_setup_file_tree()
	_setup_terminal()
	_setup_bottom_panel_tabs()
	_setup_activity_bar()
	_update_workspace_badge()
	_update_money_badge()
	_apply_active_theme()
	
	var sm = SaveManager.get_instance()
	var cur_lvl = sm.current_unlocked_level
	var dialogue_key = "level_%02d_intro" % cur_lvl
	var is_intro_done = sm.is_dialogue_shown(dialogue_key)
	
	if not is_intro_done:
		var pending = _get_transfer_files_from_config(cur_lvl)
		var valid_tabs: Array[String] = []
		for t in sm.open_tabs:
			var fname = t.get_file()
			if not pending.has(fname) and fname != "config.yml" and fname != "checker.py":
				valid_tabs.append(t)
		sm.open_tabs = valid_tabs
		if not sm.open_tabs.has(sm.active_file):
			sm.active_file = sm.open_tabs[0] if not sm.open_tabs.is_empty() else ""
			
	if not sm.open_tabs.is_empty():
		var target_file = sm.active_file
		if target_file.is_empty() or not sm.open_tabs.has(target_file):
			target_file = sm.open_tabs[0]
		open_file(target_file)
	else:
		_rebuild_tabs()
		_display_active_file()
	
	# Wire up titlebar window controls
	minimize_button.pressed.connect(func(): SaveManager.get_instance().minimize_window())
	maximize_button.pressed.connect(func(): SaveManager.get_instance().toggle_maximize_window())
	close_button.pressed.connect(_on_close_pressed)
	
	var settings_icon = find_child("SettingsIcon", true, false)
	if settings_icon:
		settings_icon.pressed.connect(_trigger_pause_menu)
	
	_update_maximize_button_state()
	sm.state_changed.connect(_update_maximize_button_state)
	sm.money_changed.connect(func(_amt): _update_money_badge())
	sm.state_changed.connect(_update_money_badge)
	
	# Check and trigger level dialogue
	call_deferred("_check_and_trigger_dialogue", sm.current_unlocked_level)

func _update_workspace_badge() -> void:
	var sm = SaveManager.get_instance()
	var cur_lvl = sm.current_unlocked_level
	if workspace_badge:
		workspace_badge.text = "[node_042 // clearance: sub-level %02d]" % cur_lvl
	if prompt_label:
		prompt_label.text = "op@escape-node[%02d]:~$ " % cur_lvl

func _update_maximize_button_state() -> void:
	var sm = SaveManager.get_instance()
	var is_full = bool(sm.settings.get("fullscreen", true))
	maximize_button.visible = not is_full

var _dragging_titlebar := false
var _drag_offset := Vector2i.ZERO

func _on_close_pressed() -> void:
	SaveManager.get_instance().save_game()
	if close_requested.get_connections().size() > 0:
		close_requested.emit()
	else:
		get_tree().quit()

func _input(event: InputEvent) -> void:
	var sm = SaveManager.get_instance()
	var is_fullscreen = bool(sm.settings.get("fullscreen", true))
	if is_fullscreen:
		_dragging_titlebar = false
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := DisplayServer.mouse_get_position()
		var win_pos := DisplayServer.window_get_position()
		var local_y := mouse_pos.y - win_pos.y
		
		if event.pressed and local_y >= 0 and local_y <= 34:
			if sm and sm._is_maximized:
				sm.toggle_maximize_window()
			_dragging_titlebar = true
			_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		else:
			_dragging_titlebar = false
			
	elif event is InputEventMouseMotion and _dragging_titlebar:
		var new_pos := DisplayServer.mouse_get_position() - _drag_offset
		DisplayServer.window_set_position(new_pos)

func _get_config_data(level_num: int) -> Dictionary:
	var config_path = FILES_BASE_PATH + ("level_%02d/config.yml" % level_num)
	var data = {
		"files_to_transfer": [] as Array[String],
		"file_sizes": {} as Dictionary
	}
	if not FileAccess.file_exists(config_path):
		return data
		
	var content = FileAccess.get_file_as_string(config_path)
	var lines = content.split("\n")
	var current_section = ""
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("files_to_transfer:"):
			current_section = "files_to_transfer"
			continue
		elif trimmed.begins_with("file_sizes:"):
			current_section = "file_sizes"
			continue
		elif not line.begins_with(" ") and not line.begins_with("\t") and trimmed.ends_with(":"):
			current_section = ""
			continue
			
		if current_section == "files_to_transfer":
			if trimmed.begins_with("-"):
				var fname = trimmed.substr(1).strip_edges()
				fname = fname.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
				if not fname.is_empty():
					data["files_to_transfer"].append(fname)
		elif current_section == "file_sizes":
			var colon_idx = trimmed.find(":")
			if colon_idx != -1:
				var k = trimmed.substr(0, colon_idx).strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
				var v = trimmed.substr(colon_idx + 1).strip_edges().to_float()
				data["file_sizes"][k] = v
	return data

func _get_transfer_files_from_config(level_num: int) -> Array[String]:
	var data = _get_config_data(level_num)
	return data["files_to_transfer"]

func _animate_file_transfer(fname: String, duration_sec: float) -> void:
	var total_bar_len: int = 18
	var steps: int = int(clamp(duration_sec * 30.0, 10, 60))
	var step_delay: float = duration_sec / float(steps)
	var formatted_fname = fname.rpad(16, " ")
	
	for s in range(steps + 1):
		var progress: float = float(s) / float(steps)
		var percent: int = int(round(progress * 100.0))
		var filled_count: int = int(round(progress * total_bar_len))
		var empty_count: int = total_bar_len - filled_count
		var bar_str = "━".repeat(filled_count) + "─".repeat(empty_count)
		var current_line = "  [color=#64748b]recv:[/color] [color=#e2e8f0]%s[/color] [color=#38bdf8][%s][/color] [color=#34d399]%3d%%[/color]" % [formatted_fname, bar_str, percent]
		
		terminal_output.text = _terminal_raw_text + current_line + "\n"
		if s < steps:
			await get_tree().create_timer(step_delay).timeout
			
	var final_bar = "━".repeat(total_bar_len)
	var final_line = "  [color=#64748b]recv:[/color] [color=#e2e8f0]%s[/color] [color=#34d399][%s][/color] [color=#34d399]100%% [OK][/color]" % [formatted_fname, final_bar]
	_print_terminal_line(final_line)

func _check_and_trigger_dialogue(level_num: int) -> void:
	await get_tree().create_timer(0.35).timeout
	var sm = SaveManager.get_instance()
	var dialogue_key = "level_%02d_intro" % level_num
	
	if sm.is_dialogue_shown(dialogue_key):
		return
		
	var dialogue_rel_path = "level_%02d/dialogues/intro.dialogue" % level_num
	var full_path = FILES_BASE_PATH + dialogue_rel_path
	
	if not FileAccess.file_exists(full_path) and level_num == 30:
		full_path = "res://dialogue/townley_intro.dialogue"
		
	var resource: Resource = null
	if FileAccess.file_exists(full_path):
		if ResourceLoader.exists(full_path):
			resource = load(full_path)
			
		if not resource:
			var text = FileAccess.get_file_as_string(full_path)
			if not text.is_empty():
				resource = DialogueManager.create_resource_from_text(text)
			
	# Show dialogue cue if exists
	if resource:
		DialogueManager.show_dialogue_balloon(resource, "start")
		await DialogueManager.dialogue_ended
	
	# Dynamically perform file transfer from config.yml if specified
	var config_data = _get_config_data(level_num)
	var transfer_files: Array[String] = config_data["files_to_transfer"]
	if not transfer_files.is_empty():
		await get_tree().create_timer(0.4).timeout
		_switch_bottom_tab("terminal")
		var header_msg = "\n[color=#38bdf8]── [DATA TRANSFER: SUB-LEVEL %02d INCOMING STREAM] ──[/color]" % level_num
		if level_num == 30:
			header_msg = "\n[color=#38bdf8]── [SECURE PACKET STREAM: TOWNLEY @ SUB-LEVEL 30] ──[/color]"
		_print_terminal_line(header_msg)
		
		for f in transfer_files:
			var size_val: float = config_data["file_sizes"].get(f, 500.0)
			var duration_sec: float = size_val / 1000.0
			await _animate_file_transfer(f, duration_sec)
			
		await get_tree().create_timer(0.3).timeout
		_print_terminal_line("[color=#34d399]✔ Transfer complete. %d file(s) synchronized to workspace.[/color]\n" % transfer_files.size())
		await get_tree().create_timer(0.4).timeout
		
		sm.mark_dialogue_shown(dialogue_key)
		_setup_file_tree()
		for f in transfer_files:
			var rel_f = "level_%02d/%s" % [level_num, f]
			sm.add_open_tab(rel_f)
		if not transfer_files.is_empty():
			open_file("level_%02d/%s" % [level_num, transfer_files[0]])
			
		if resource:
			var raw_text = FileAccess.get_file_as_string(full_path)
			if raw_text.contains("~ received"):
				DialogueManager.show_dialogue_balloon(resource, "received")
				await DialogueManager.dialogue_ended
	else:
		sm.mark_dialogue_shown(dialogue_key)
		_setup_file_tree()

	sm.save_game()

func _setup_syntax_highlighters() -> void:
	# Modern VS Code / Obsidian Dark Python Highlighter
	py_highlighter = CodeHighlighter.new()
	py_highlighter.number_color = Color("#b5cea8")
	py_highlighter.symbol_color = Color("#d4d4d4")
	py_highlighter.function_color = Color("#dcdcaa")
	py_highlighter.member_variable_color = Color("#9cdcfe")
	
	var keywords = [
		"def", "class", "return", "pass", "lambda", "yield", "raise",
		"import", "from", "as", "global", "nonlocal", "assert", "del",
		"with", "try", "except", "finally", "async", "await"
	]
	for kw in keywords:
		py_highlighter.add_keyword_color(kw, Color("#569cd6"))
		
	var control_flow = [
		"if", "elif", "else", "for", "while", "break", "continue", "in", "is", "not", "and", "or"
	]
	for kw in control_flow:
		py_highlighter.add_keyword_color(kw, Color("#c586c0"))
		
	var builtins = [
		"print", "len", "range", "int", "str", "float", "bool", "list", "dict",
		"set", "tuple", "enumerate", "zip", "sorted", "sum", "min", "max", "isinstance", "type",
		"abs", "all", "any", "reversed", "map", "filter", "round"
	]
	for bi in builtins:
		py_highlighter.add_keyword_color(bi, Color("#4ec9b0"))
		
	var literals = ["True", "False", "None"]
	for lit in literals:
		py_highlighter.add_keyword_color(lit, Color("#569cd6"))
		
	py_highlighter.add_color_region("#", "", Color("#6a9955"), true)
	py_highlighter.add_color_region('"""', '"""', Color("#ce9178"), false)
	py_highlighter.add_color_region("'''", "'''", Color("#ce9178"), false)
	py_highlighter.add_color_region('"', '"', Color("#ce9178"), false)
	py_highlighter.add_color_region("'", "'", Color("#ce9178"), false)
	
	# Markdown Highlighter
	md_highlighter = CodeHighlighter.new()
	md_highlighter.number_color = Color("#b5cea8")
	md_highlighter.symbol_color = Color("#d4d4d4")
	md_highlighter.add_color_region("#", "", Color("#569cd6"), true)
	md_highlighter.add_color_region("`", "`", Color("#ce9178"), false)
	md_highlighter.add_color_region("**", "**", Color("#4ec9b0"), false)

var py_interpreter: PythonInterpreter = PythonInterpreter.new()

func _setup_editor() -> void:
	code_editor.text_changed.connect(_on_editor_text_changed)
	code_editor.caret_changed.connect(_on_editor_caret_changed)
	code_editor.code_completion_enabled = true
	
	# Auto complete triggers
	var prefixes: Array[String] = [".", "_"]
	for i in range(26):
		prefixes.append(char(97 + i))
		prefixes.append(char(65 + i))
	code_editor.code_completion_prefixes = PackedStringArray(prefixes)
	
	# Error indicator gutter
	code_editor.add_gutter(0)
	code_editor.set_gutter_name(0, "errors")
	code_editor.set_gutter_type(0, CodeEdit.GUTTER_TYPE_STRING)
	code_editor.set_gutter_width(0, 16)
	code_editor.set_gutter_draw(0, true)
	
	code_editor.code_completion_requested.connect(_on_code_completion_requested)
	code_editor.gui_input.connect(_on_editor_gui_input)
	code_editor.mouse_exited.connect(func():
		_last_hover_word = ""
		if doc_hover_timer:
			doc_hover_timer.stop()
		_hide_doc_hover()
	)
	run_button.pressed.connect(func(): _execute_task_file())
	
	errors_warnings_label.mouse_filter = Control.MOUSE_FILTER_STOP
	errors_warnings_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	errors_warnings_label.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_switch_bottom_tab("problems")
	)

func _on_code_completion_requested() -> void:
	var sm = SaveManager.get_instance()
	if not sm.active_file.ends_with(".py"):
		return
		
	var items = PythonInterpreter.get_intellisense_completions(code_editor.text)
	for item in items:
		code_editor.add_code_completion_option(
			item["kind"],
			item["text"],
			item["text"],
			item["color"]
		)
	code_editor.update_code_completion_options(true)

var standalone_pause_menu: PauseMenu = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_trigger_pause_menu()
		get_viewport().set_input_as_handled()

func _trigger_pause_menu() -> void:
	var pm: PauseMenu = get_tree().root.find_child("PauseMenu", true, false) as PauseMenu
	if pm:
		if pm.is_open():
			pm.resume_game()
		else:
			pm.open_menu()
	else:
		if not standalone_pause_menu:
			var pl = CanvasLayer.new()
			pl.layer = 25
			add_child(pl)
			standalone_pause_menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
			pl.add_child(standalone_pause_menu)
			standalone_pause_menu.back_to_menu_pressed.connect(func():
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			)
		if standalone_pause_menu.is_open():
			standalone_pause_menu.resume_game()
		else:
			standalone_pause_menu.open_menu()

func _on_editor_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_editor_mouse_motion(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_hide_doc_hover()
	elif event is InputEventKey:
		_hide_doc_hover()
		if event.pressed:
			if event.ctrl_pressed and event.keycode == KEY_ENTER:
				_execute_task_file()
				code_editor.accept_event()
			elif event.ctrl_pressed and event.keycode == KEY_SPACE:
				code_editor.request_code_completion(true)
				code_editor.accept_event()
			elif event.keycode == KEY_ESCAPE:
				_trigger_pause_menu()
				code_editor.accept_event()

func _on_editor_text_changed() -> void:
	_hide_doc_hover()
	var sm = SaveManager.get_instance()
	var active_f = sm.active_file
	if active_f.is_empty():
		return
		
	sm.set_file_content(active_f, code_editor.text)
	
	if active_f.ends_with(".py"):
		_validate_python_syntax(code_editor.text)
		
		# Auto-trigger IntelliSense while typing
		var line_idx = code_editor.get_caret_line()
		var col_idx = code_editor.get_caret_column()
		var line_text = code_editor.get_line(line_idx)
		if col_idx > 0 and col_idx <= line_text.length():
			var last_char = line_text[col_idx - 1]
			if (last_char >= 'a' and last_char <= 'z') or (last_char >= 'A' and last_char <= 'Z') or last_char == '.' or last_char == '_':
				code_editor.request_code_completion(true)
	else:
		_clear_errors()

func _on_editor_caret_changed() -> void:
	_hide_doc_hover()
	var line = code_editor.get_caret_line() + 1
	var col = code_editor.get_caret_column() + 1
	status_cursor_pos.text = "Ln %d, Col %d" % [line, col]
	
	# Display contextual error message on status bar if caret is on an error line
	var current_line_err = ""
	for err in active_syntax_errors:
		if err.get("line", -1) == line:
			current_line_err = err.get("message", "")
			break
			
	if not current_line_err.is_empty():
		errors_warnings_label.text = "⊗ " + current_line_err
		errors_warnings_label.add_theme_color_override("font_color", Color("#ef4444"))
	elif active_syntax_errors.size() > 0:
		errors_warnings_label.text = "⊗ %d  ⚠ 0" % active_syntax_errors.size()
		errors_warnings_label.add_theme_color_override("font_color", Color("#ef4444"))
	else:
		errors_warnings_label.text = "⊗ 0  ⚠ 0"
		errors_warnings_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))

# ----------------- Real-Time Error Tracker -----------------
func _validate_python_syntax(code: String) -> void:
	active_syntax_errors.clear()
	
	for i in range(code_editor.get_line_count()):
		code_editor.set_line_gutter_text(i, 0, "")
		code_editor.set_line_background_color(i, Color(0, 0, 0, 0))
		
	var sm = SaveManager.get_instance()
	var cur_active = sm.active_file.get_file()
	
	active_syntax_errors = py_interpreter.validate_python_syntax(code, cur_active)
	_update_error_ui()

func _clear_errors() -> void:
	active_syntax_errors.clear()
	for i in range(code_editor.get_line_count()):
		code_editor.set_line_gutter_text(i, 0, "")
		code_editor.set_line_background_color(i, Color(0, 0, 0, 0))
	_update_error_ui()

func _update_error_ui() -> void:
	var count = active_syntax_errors.size()
	tab_problems_btn.text = "PROBLEMS (%d)" % count
	
	for i in range(code_editor.get_line_count()):
		code_editor.set_line_gutter_text(i, 0, "")
		code_editor.set_line_background_color(i, Color(0, 0, 0, 0))
		
	if count > 0:
		tab_problems_btn.add_theme_color_override("font_color", Color("#f87171"))
		errors_warnings_label.text = "⊗ %d  ⚠ 0" % count
		errors_warnings_label.add_theme_color_override("font_color", Color("#ef4444"))
		
		for err in active_syntax_errors:
			var l_idx = err["line"] - 1
			if l_idx >= 0 and l_idx < code_editor.get_line_count():
				code_editor.set_line_gutter_text(l_idx, 0, "●")
				code_editor.set_line_gutter_item_color(l_idx, 0, Color("#ef4444"))
				code_editor.set_line_background_color(l_idx, Color(0.85, 0.2, 0.2, 0.22))
	else:
		tab_problems_btn.add_theme_color_override("font_color", Color(0.55, 0.6, 0.72, 1))
		errors_warnings_label.text = "⊗ 0  ⚠ 0"
		errors_warnings_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.8))
		
	for child in problems_list.get_children():
		child.queue_free()
		
	if count == 0:
		var ok_card = PanelContainer.new()
		var ok_style = StyleBoxFlat.new()
		ok_style.bg_color = Color(0.04, 0.12, 0.08, 0.4)
		ok_style.border_width_left = 1
		ok_style.border_width_top = 1
		ok_style.border_width_right = 1
		ok_style.border_width_bottom = 1
		ok_style.border_color = Color(0.1, 0.4, 0.25, 0.5)
		ok_style.corner_radius_top_left = 4
		ok_style.corner_radius_top_right = 4
		ok_style.corner_radius_bottom_right = 4
		ok_style.corner_radius_bottom_left = 4
		ok_style.content_margin_left = 10
		ok_style.content_margin_top = 6
		ok_style.content_margin_right = 10
		ok_style.content_margin_bottom = 6
		ok_card.add_theme_stylebox_override("panel", ok_style)
		
		var ok_hbox = HBoxContainer.new()
		ok_hbox.add_theme_constant_override("separation", 8)
		
		var ok_icon = TextureRect.new()
		ok_icon.texture = ICON_CHECK
		ok_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ok_icon.custom_minimum_size = Vector2(14, 14)
		ok_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ok_icon.modulate = Color("#34d399")
		ok_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ok_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ok_hbox.add_child(ok_icon)
		
		var ok_label = Label.new()
		ok_label.text = "No problems detected in active workspace files."
		ok_label.add_theme_color_override("font_color", Color("#34d399"))
		ok_label.add_theme_font_size_override("font_size", 11)
		ok_hbox.add_child(ok_label)
		
		ok_card.add_child(ok_hbox)
		problems_list.add_child(ok_card)
	else:
		var copy_hbox = HBoxContainer.new()
		copy_hbox.alignment = BoxContainer.ALIGNMENT_END
		
		var copy_btn = Button.new()
		copy_btn.text = "Copy Errors"
		copy_btn.add_theme_font_size_override("font_size", 11)
		copy_btn.add_theme_color_override("font_color", Color("#94a3b8"))
		copy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		copy_btn.pressed.connect(func():
			var err_texts = []
			for err in active_syntax_errors:
				err_texts.append("Line %d: %s" % [err["line"], err["message"]])
			DisplayServer.clipboard_set("\\n".join(err_texts))
			copy_btn.text = "Copied!"
			var t = get_tree().create_timer(2.0)
			t.timeout.connect(func():
				if is_instance_valid(copy_btn):
					copy_btn.text = "Copy Errors"
			)
		)
		copy_hbox.add_child(copy_btn)
		problems_list.add_child(copy_hbox)

		for err in active_syntax_errors:
			var card = PanelContainer.new()
			var card_style = StyleBoxFlat.new()
			card_style.bg_color = Color(0.15, 0.05, 0.07, 0.6)
			card_style.border_width_left = 1
			card_style.border_width_top = 1
			card_style.border_width_right = 1
			card_style.border_width_bottom = 1
			card_style.border_color = Color(0.6, 0.2, 0.25, 0.6)
			card_style.corner_radius_top_left = 4
			card_style.corner_radius_top_right = 4
			card_style.corner_radius_bottom_right = 4
			card_style.corner_radius_bottom_left = 4
			card_style.content_margin_left = 10
			card_style.content_margin_top = 6
			card_style.content_margin_right = 10
			card_style.content_margin_bottom = 6
			card.add_theme_stylebox_override("panel", card_style)
			
			var card_btn = Button.new()
			card_btn.flat = true
			card_btn.focus_mode = FOCUS_NONE
			card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			var chbox = HBoxContainer.new()
			chbox.add_theme_constant_override("separation", 8)
			
			var err_icon = TextureRect.new()
			err_icon.texture = ICON_CROSS
			err_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			err_icon.custom_minimum_size = Vector2(13, 13)
			err_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			err_icon.modulate = Color("#ef4444")
			err_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			err_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chbox.add_child(err_icon)
			
			var file_badge = Label.new()
			file_badge.text = "[%s]" % err["file"]
			file_badge.add_theme_color_override("font_color", Color("#94a3b8"))
			file_badge.add_theme_font_size_override("font_size", 11)
			chbox.add_child(file_badge)
			
			var line_badge = Label.new()
			line_badge.text = "Ln %d:" % err["line"]
			line_badge.add_theme_color_override("font_color", Color("#f59e0b"))
			line_badge.add_theme_font_size_override("font_size", 11)
			chbox.add_child(line_badge)
			
			var msg_label = Label.new()
			msg_label.text = err["message"]
			msg_label.add_theme_color_override("font_color", Color("#fca5a5"))
			msg_label.add_theme_font_size_override("font_size", 12)
			chbox.add_child(msg_label)
			
			card.add_child(chbox)
			
			var target_line = err["line"] - 1
			card.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					code_editor.set_caret_line(target_line)
					code_editor.set_caret_column(0)
					code_editor.grab_focus()
			)
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			problems_list.add_child(card)
			
	_on_editor_caret_changed()

# ----------------- Dynamic Explorer & Levels Adaptor -----------------
func _get_file_icon_texture(filename: String) -> Texture2D:
	if filename.ends_with(".py"):
		return ICON_FILE_CODE
	elif filename.ends_with(".md"):
		return ICON_FILE_DOC
	elif filename.ends_with(".sh") or filename.ends_with(".bash"):
		return ICON_FILE_TERM
	return ICON_FILE_DEFAULT

func _get_file_icon_color(filename: String) -> Color:
	if filename.ends_with(".py"):
		return Color("#38bdf8")
	elif filename.ends_with(".md"):
		return Color("#94a3b8")
	elif filename.ends_with(".json") or filename.ends_with(".yml"):
		return Color("#e5c07b")
	return Color("#64748b")

func _setup_file_tree() -> void:
	for child in file_list_container.get_children():
		child.queue_free()
		
	var sm = SaveManager.get_instance()
	var unlocked_lvl = sm.current_unlocked_level
	_update_workspace_badge()
	
	for i in range(0, 31):
		var folder_name = "level_%02d" % i
		var is_unlocked = (i >= unlocked_lvl)
		var is_current = (i == unlocked_lvl)
		
		var folder_panel = PanelContainer.new()
		var f_style = StyleBoxFlat.new()
		f_style.bg_color = Color(0.08, 0.1, 0.14, 0.4) if is_current else Color(0, 0, 0, 0)
		f_style.corner_radius_top_left = 4
		f_style.corner_radius_top_right = 4
		f_style.corner_radius_bottom_right = 4
		f_style.corner_radius_bottom_left = 4
		f_style.content_margin_left = 6
		f_style.content_margin_right = 6
		f_style.content_margin_top = 3
		f_style.content_margin_bottom = 3
		folder_panel.add_theme_stylebox_override("panel", f_style)
		
		var fhbox = HBoxContainer.new()
		fhbox.add_theme_constant_override("separation", 6)
		
		var f_icon = TextureRect.new()
		f_icon.texture = (ICON_FOLDER_OPEN if is_unlocked else ICON_FOLDER_LOCK)
		f_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		f_icon.custom_minimum_size = Vector2(14, 14)
		f_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f_icon.modulate = (Color("#e2e8f0") if is_current else (Color("#94a3b8") if is_unlocked else Color("#475569")))
		f_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		f_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fhbox.add_child(f_icon)
		
		var f_label = Label.new()
		f_label.text = folder_name
		f_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f_label.add_theme_font_size_override("font_size", 12)
		f_label.add_theme_color_override("font_color", Color("#ffffff") if is_current else (Color("#cbd5e1") if is_unlocked else Color("#475569")))
		fhbox.add_child(f_label)
		
		if is_current:
			var act_badge = Label.new()
			act_badge.text = "[ACTIVE]"
			act_badge.add_theme_font_size_override("font_size", 9)
			act_badge.add_theme_color_override("font_color", Color("#34d399"))
			fhbox.add_child(act_badge)
		elif not is_unlocked:
			var lock_badge = Label.new()
			lock_badge.text = "[LOCKED]"
			lock_badge.add_theme_font_size_override("font_size", 9)
			lock_badge.add_theme_color_override("font_color", Color("#475569"))
			fhbox.add_child(lock_badge)
			
		folder_panel.add_child(fhbox)
		folder_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		folder_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var lvl_num = i
		var f_name_str = folder_name
		folder_panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_folder_clicked(lvl_num, f_name_str)
		)
		
		file_list_container.add_child(folder_panel)
		
		if is_unlocked:
			var dir_path = FILES_BASE_PATH + folder_name
			var dir = DirAccess.open(dir_path)
			var found_files: Array[String] = []
			var dialogue_key = "level_%02d_intro" % i
			var is_lvl_transferred = sm.is_dialogue_shown(dialogue_key)
			var pending_transfers: Array[String] = []
			if not is_lvl_transferred:
				pending_transfers = _get_transfer_files_from_config(i)
			
			if dir:
				dir.list_dir_begin()
				var fname = dir.get_next()
				while fname != "":
					if not dir.current_is_dir() and not fname.begins_with(".") and not fname.ends_with(".import") and not fname.ends_with(".uid") and fname != "checker.py" and fname != "config.yml" and not fname.ends_with(".dialogue"):
						if is_lvl_transferred or not pending_transfers.has(fname):
							found_files.append(fname)
					fname = dir.get_next()
				dir.list_dir_end()
				
			found_files.sort()
			
			if found_files.is_empty():
				var empty_hint = Label.new()
				empty_hint.text = "     (No decrypted files yet)"
				empty_hint.add_theme_color_override("font_color", Color(0.4, 0.55, 0.45))
				empty_hint.add_theme_font_size_override("font_size", 10)
				file_list_container.add_child(empty_hint)
			else:
				for filename in found_files:
					var file_rel_path = "%s/%s" % [folder_name, filename]
					var is_active_f = (file_rel_path == sm.active_file)
					
					var file_panel = PanelContainer.new()
					var file_style = StyleBoxFlat.new()
					if is_active_f:
						file_style.bg_color = Color(0.12, 0.16, 0.24, 0.9)
						file_style.border_width_left = 2
						file_style.border_color = Color(0.22, 0.74, 0.97, 1.0)
					else:
						file_style.bg_color = Color(0, 0, 0, 0)
					file_style.corner_radius_top_right = 4
					file_style.corner_radius_bottom_right = 4
					file_style.content_margin_left = 18
					file_style.content_margin_right = 6
					file_style.content_margin_top = 3
					file_style.content_margin_bottom = 3
					file_panel.add_theme_stylebox_override("panel", file_style)
					
					var file_hbox = HBoxContainer.new()
					file_hbox.add_theme_constant_override("separation", 6)
					
					var ficon = TextureRect.new()
					ficon.texture = _get_file_icon_texture(filename)
					ficon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					ficon.custom_minimum_size = Vector2(14, 14)
					ficon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					ficon.modulate = _get_file_icon_color(filename)
					ficon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					ficon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					file_hbox.add_child(ficon)
					
					var file_label = Label.new()
					file_label.text = filename
					file_label.add_theme_font_size_override("font_size", 12)
					if is_active_f:
						file_label.add_theme_color_override("font_color", Color("#ffffff"))
					else:
						file_label.add_theme_color_override("font_color", Color("#cbd5e1"))
					file_hbox.add_child(file_label)
					
					file_panel.add_child(file_hbox)
					file_panel.mouse_filter = Control.MOUSE_FILTER_STOP
					file_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					
					var target_to_open = file_rel_path
					file_panel.gui_input.connect(func(ev: InputEvent):
						if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
							open_file(target_to_open)
					)
					
					file_list_container.add_child(file_panel)

func _get_file_lang(filename: String) -> String:
	if filename.ends_with(".py"):
		return "Python 3.10"
	elif filename.ends_with(".md"):
		return "Markdown"
	elif filename.ends_with(".txt"):
		return "Plain Text"
	elif filename.ends_with(".json"):
		return "JSON"
	return "Plain Text"

func _on_folder_clicked(lvl_num: int, folder_name: String) -> void:
	var sm = SaveManager.get_instance()
	var cur_unlocked = sm.current_unlocked_level
	if lvl_num < cur_unlocked:
		_print_terminal_line("[color=#ef4444][ACCESS DENIED] Folder '%s' requires higher clearance.[/color]" % folder_name)
		_print_terminal_line("[color=#64748b]Solve and verify task.py in level_%02d to elevate clearance.[/color]" % cur_unlocked)
	else:
		_print_terminal_line("[color=#38bdf8][WORKSPACE] Focused directory: %s[/color]" % folder_name)

# ----------------- File Tabs & Save State -----------------
func open_file(relative_path: String) -> void:
	if relative_path.is_empty():
		return
	var base_fn = relative_path.get_file()
	if base_fn == "checker.py" or base_fn == "config.yml":
		_print_terminal_line("[color=#ef4444][ACCESS DENIED] %s is an internal system module and cannot be opened.[/color]" % base_fn)
		return
		
	var sm = SaveManager.get_instance()
	sm.add_open_tab(relative_path)
	sm.set_active_file(relative_path)
	_rebuild_tabs()
	_display_active_file()
	_setup_file_tree()

func close_file(relative_path: String) -> void:
	var sm = SaveManager.get_instance()
	sm.remove_open_tab(relative_path)
	
	if sm.active_file == relative_path:
		if not sm.open_tabs.is_empty():
			sm.set_active_file(sm.open_tabs[0])
		else:
			sm.set_active_file("")
			
	_rebuild_tabs()
	_display_active_file()
	_setup_file_tree()

func _rebuild_tabs() -> void:
	for child in tabs_container.get_children():
		child.queue_free()
		
	var sm = SaveManager.get_instance()
	var active_f = sm.active_file
	
	for rel_path in sm.open_tabs:
		var is_active = (rel_path == active_f)
		var filename = rel_path.get_file()
		
		var tab_panel = PanelContainer.new()
		var tab_style = StyleBoxFlat.new()
		if is_active:
			tab_style.bg_color = Color(0.07, 0.078, 0.11, 1.0)
			tab_style.border_width_top = 2
			tab_style.border_color = Color(0.22, 0.74, 0.97, 1.0)
		else:
			tab_style.bg_color = Color(0.045, 0.05, 0.07, 1.0)
			tab_style.border_width_top = 0
		tab_style.corner_radius_top_left = 4
		tab_style.corner_radius_top_right = 4
		tab_style.content_margin_left = 10
		tab_style.content_margin_right = 6
		tab_style.content_margin_top = 4
		tab_style.content_margin_bottom = 4
		tab_panel.add_theme_stylebox_override("panel", tab_style)
		
		var tab_hbox = HBoxContainer.new()
		tab_hbox.add_theme_constant_override("separation", 6)
		
		var tab_icon = TextureRect.new()
		tab_icon.texture = _get_file_icon_texture(filename)
		tab_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tab_icon.custom_minimum_size = Vector2(13, 13)
		tab_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tab_icon.modulate = _get_file_icon_color(filename)
		tab_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tab_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tab_hbox.add_child(tab_icon)
		
		var tab_title_btn = Button.new()
		tab_title_btn.text = filename
		tab_title_btn.flat = true
		tab_title_btn.focus_mode = FOCUS_NONE
		tab_title_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab_title_btn.add_theme_font_size_override("font_size", 12)
		if is_active:
			tab_title_btn.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			tab_title_btn.add_theme_color_override("font_color", Color(0.55, 0.6, 0.72))
			tab_title_btn.add_theme_color_override("font_hover_color", Color(0.9, 0.93, 0.98))
			
		var this_file = rel_path
		tab_title_btn.pressed.connect(func():
			sm.set_active_file(this_file)
			_rebuild_tabs()
			_display_active_file()
			_setup_file_tree()
		)
		tab_hbox.add_child(tab_title_btn)
		
		var close_btn = Button.new()
		close_btn.text = "✕"
		close_btn.flat = true
		close_btn.focus_mode = FOCUS_NONE
		close_btn.custom_minimum_size = Vector2(16, 16)
		close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close_btn.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
		close_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.35, 0.35))
		close_btn.add_theme_font_size_override("font_size", 10)
		close_btn.tooltip_text = "Close tab"
		close_btn.pressed.connect(func(): close_file(this_file))
		tab_hbox.add_child(close_btn)
		
		tab_panel.add_child(tab_hbox)
		tabs_container.add_child(tab_panel)

func _display_active_file() -> void:
	var sm = SaveManager.get_instance()
	var active_f = sm.active_file
	if active_f.is_empty():
		code_editor.visible = false
		markdown_viewer.visible = false
		empty_placeholder.visible = true
		breadcrumbs_label.text = "workspace  ›  (no active file)"
		status_file_type.text = "Plain Text"
		status_cursor_pos.text = "--"
		_clear_errors()
		return
		
	var content = sm.get_file_content(active_f)
	if content.is_empty():
		var full_res = FILES_BASE_PATH + active_f
		if FileAccess.file_exists(full_res):
			content = FileAccess.get_file_as_string(full_res)
			sm.set_file_content(active_f, content)
			
	var lang = _get_file_lang(active_f.get_file())
	breadcrumbs_label.text = "workspace  ›  " + active_f.replace("/", "  ›  ")
	status_file_type.text = lang
	
	empty_placeholder.visible = false
	
	if lang == "Markdown":
		code_editor.visible = false
		markdown_viewer.visible = true
		markdown_viewer.text = _parse_markdown_to_bbcode(content)
	else:
		markdown_viewer.visible = false
		code_editor.visible = true
		code_editor.text = content
		if active_f.ends_with(".py"):
			code_editor.syntax_highlighter = py_highlighter
		else:
			code_editor.syntax_highlighter = null
	status_cursor_pos.text = "Ln 1, Col 1"
	
	if active_f.ends_with(".py"):
		_validate_python_syntax(code_editor.text)
	else:
		_clear_errors()

# ----------------- Bottom Panel Tabs -----------------
func _setup_bottom_panel_tabs() -> void:
	tab_term_btn.pressed.connect(func(): _switch_bottom_tab("terminal"))
	tab_problems_btn.pressed.connect(func(): _switch_bottom_tab("problems"))
	tab_output_btn.pressed.connect(func(): _switch_bottom_tab("output"))

func _switch_bottom_tab(tab_name: String) -> void:
	terminal_view.visible = (tab_name == "terminal")
	problems_view.visible = (tab_name == "problems")
	output_view.visible = (tab_name == "output")
	
	tab_term_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1) if tab_name == "terminal" else Color(0.55, 0.6, 0.72, 1))
	tab_problems_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1) if tab_name == "problems" else (Color("#f87171") if active_syntax_errors.size() > 0 else Color(0.55, 0.6, 0.72, 1)))
	tab_output_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1) if tab_name == "output" else Color(0.55, 0.6, 0.72, 1))

# ----------------- Terminal & Commands -----------------
func _setup_terminal() -> void:
	terminal_input.text_submitted.connect(_on_terminal_command)
	_print_terminal_line("[color=#38bdf8]── No ESCape Integrated Command Interface [Version 4.22] ──[/color]")
	_print_terminal_line("[color=#64748b]Node connection established: [color=#93c5fd]gateway.internal.net[/color][/color]")
	_print_terminal_line("[color=#64748b]Type '[b][color=#cbd5e1]help[/color][/b]' for command manual, or press '[b][color=#34d399]Run Script[/color][/b]' to test task.py.[/color]\n")

var _terminal_raw_text: String = ""

func _print_terminal_line(text: String) -> void:
	_terminal_raw_text += text + "\n"
	terminal_output.text = _terminal_raw_text

func _on_terminal_command(cmd: String) -> void:
	cmd = cmd.strip_edges()
	terminal_input.text = ""
	if cmd.is_empty():
		return
		
	var sm = SaveManager.get_instance()
	var cur_lvl = sm.current_unlocked_level
	_print_terminal_line("[color=#38bdf8]op@escape-node[%02d][/color]:[color=#ce9178]~$[/color] %s" % [cur_lvl, cmd])
	
	sm.save_game()
	
	var parts = cmd.split(" ", false)
	var main_cmd = parts[0].to_lower()
	
	match main_cmd:
		"help":
			_print_terminal_line("[color=#dcdcaa]Available terminal routines:[/color]")
			_print_terminal_line("  [b][color=#38bdf8]ls[/color][/b]               - List files in current level directory")
			_print_terminal_line("  [b][color=#38bdf8]cat <file>[/color][/b]        - Display file contents in terminal")
			_print_terminal_line("  [b][color=#38bdf8]run task.py[/color][/b]       - Execute automated test suite for current clearance")
			_print_terminal_line("  [b][color=#38bdf8]python task.py[/color][/b]    - Alias for run task.py")
			_print_terminal_line("  [b][color=#38bdf8]status[/color][/b]           - Inspect security clearance and session telemetry")
			_print_terminal_line("  [b][color=#38bdf8]clear[/color][/b]            - Wipe terminal buffer")
		"ls":
			var cur_lvl_folder = "level_%02d" % cur_lvl
			var dir_path = FILES_BASE_PATH + cur_lvl_folder
			var dir = DirAccess.open(dir_path)
			var files_list: Array[String] = []
			var dialogue_key = "level_%02d_intro" % cur_lvl
			var is_lvl_transferred = sm.is_dialogue_shown(dialogue_key)
			var pending_transfers: Array[String] = []
			if not is_lvl_transferred:
				pending_transfers = _get_transfer_files_from_config(cur_lvl)
				
			if dir:
				dir.list_dir_begin()
				var fn = dir.get_next()
				while fn != "":
					if not dir.current_is_dir() and not fn.begins_with(".") and not fn.ends_with(".import") and not fn.ends_with(".uid") and fn != "checker.py" and fn != "config.yml" and not fn.ends_with(".dialogue"):
						if is_lvl_transferred or not pending_transfers.has(fn):
							files_list.append(fn)
					fn = dir.get_next()
				dir.list_dir_end()
			files_list.sort()
			_print_terminal_line("[color=#9cdcfe]" + "  ".join(PackedStringArray(files_list)) + "[/color]")
		"cat":
			if parts.size() < 2:
				_print_terminal_line("[color=#ef4444]Usage: cat <filename>[/color]")
			elif parts[1] == "checker.py" or parts[1] == "config.yml":
				_print_terminal_line("[color=#ef4444][ACCESS DENIED] %s is an internal system module.[/color]" % parts[1])
			else:
				var fname = parts[1]
				var cur_lvl_folder = "level_%02d" % cur_lvl
				var rel_p = "%s/%s" % [cur_lvl_folder, fname]
				var content = sm.get_file_content(rel_p)
				if content.is_empty():
					var full_p = FILES_BASE_PATH + rel_p
					if FileAccess.file_exists(full_p):
						content = FileAccess.get_file_as_string(full_p)
				if not content.is_empty():
					_print_terminal_line(content)
				else:
					_print_terminal_line("[color=#ef4444]cat: %s: No such file or directory[/color]" % fname)
		"status":
			_print_terminal_line("[color=#f59e0b]── SECURITY CLEARANCE MONITOR ──[/color]")
			_print_terminal_line("  Current Clearance: [color=#ef4444]Sub-Level %02d[/color]" % cur_lvl)
			_print_terminal_line("  Target Node: [color=#34d399]level_00 (Core Server Gateway)[/color]")
			_print_terminal_line("  Monitoring Supervisor: George TOWNLEY")
			_print_terminal_line("  Total Actions Logged: %d" % sm.game_stats.get("actions_count", 0))
		"run", "python":
			_execute_task_file()
		"clear":
			_terminal_raw_text = ""
			terminal_output.text = ""
		_:
			_print_terminal_line("[color=#ef4444]Command not recognized: '%s'. Type 'help' for manual.[/color]" % main_cmd)

# ----------------- Python Evaluator & Test Runner -----------------
func _print_output_line(text: String) -> void:
	output_label.append_text(text + "\n")

func _execute_task_file() -> void:
	_switch_bottom_tab("output")
	output_label.text = ""
	var sm = SaveManager.get_instance()
	var cur_lvl = sm.current_unlocked_level
	var task_file_key = "level_%02d/task.py" % cur_lvl
	
	_print_output_line("[color=#38bdf8]┌────────────────────────────────────────────────────────────┐[/color]")
	_print_output_line("[color=#38bdf8]│[/color] [color=#e2e8f0]EXEC: python %s[/color]" % task_file_key)
	_print_output_line("[color=#38bdf8]│[/color] [color=#64748b]Suite: Sub-Level %02d Verification Suite[/color]" % cur_lvl)
	_print_output_line("[color=#38bdf8]└────────────────────────────────────────────────────────────┘[/color]")
	
	var code = sm.get_file_content(task_file_key)
	if code.is_empty():
		var full_res_path = FILES_BASE_PATH + task_file_key
		if FileAccess.file_exists(full_res_path):
			code = FileAccess.get_file_as_string(full_res_path)
			
	if code.is_empty():
		_print_output_line("[color=#ef4444]ERROR: %s not found in workspace.[/color]" % task_file_key)
		return
		
	if active_syntax_errors.size() > 0 and sm.active_file == task_file_key:
		_print_output_line("[color=#ef4444]SyntaxError: Cannot run %s due to active syntax errors![/color]" % task_file_key.get_file())
		for err in active_syntax_errors:
			_print_output_line("  [color=#fca5a5]Line %d: %s[/color]" % [err["line"], err["message"]])
		_print_output_line("[color=#f59e0b]Switch to the PROBLEMS tab below to inspect and correct.[/color]")
		return
		
	var checker_rel_path = "level_%02d/checker.py" % cur_lvl
	var full_checker_path = FILES_BASE_PATH + checker_rel_path
	var checker_info = _load_checker_info(full_checker_path)
	var func_name = checker_info.get("func_name", "")
	var test_cases = checker_info.get("test_cases", [])
	
	if func_name.is_empty():
		var def_idx = code.find("def ")
		if def_idx != -1:
			var paren_idx = code.find("(", def_idx)
			if paren_idx != -1:
				func_name = code.substr(def_idx + 4, paren_idx - (def_idx + 4)).strip_edges()
				
	if test_cases.is_empty():
		_print_terminal_line("[color=#ef4444]ERROR: No test cases found for Sub-Level %02d.[/color]" % cur_lvl)
		return
		
	var all_passed = true
	var pass_count = 0
	
	for idx in range(test_cases.size()):
		var tc = test_cases[idx]
		var call_res = py_interpreter.call_function(code, func_name, tc.get("args", []))
		
		if call_res.get("status") != "ok":
			_print_output_line("  [color=#ef4444][✖ FAIL][/color] [color=#e2e8f0]Test %d:[/color] [color=#f87171]%s[/color]" % [idx + 1, tc.get("desc", "")])
			_print_output_line("        [color=#fca5a5]RuntimeError: %s[/color]" % call_res.get("error_msg", "Execution error"))
			all_passed = false
			break
			
		var result = call_res.get("value")
		if result == tc["expected"]:
			_print_output_line("  [color=#34d399][✔ PASS][/color] [color=#e2e8f0]Test %d:[/color] [color=#94a3b8]%s[/color]" % [idx + 1, tc.get("desc", "")])
			pass_count += 1
		else:
			_print_output_line("  [color=#ef4444][✖ FAIL][/color] [color=#e2e8f0]Test %d:[/color] [color=#f87171]%s[/color]" % [idx + 1, tc.get("desc", "")])
			_print_output_line("        [color=#94a3b8]Expected:[/color] [color=#34d399]%s[/color]   [color=#94a3b8]Received:[/color] [color=#ef4444]%s[/color]" % [str(tc["expected"]), str(result)])
			all_passed = false
			break
			
	if all_passed:
		_print_output_line("\n[color=#34d399]════════════════════════════════════════════════════════════[/color]")
		_print_output_line("[color=#34d399][✔] ALL %d/%d VALIDATION TESTS PASSED[/color]" % [pass_count, test_cases.size()])
		_print_output_line("[color=#38bdf8][+] SUB-LEVEL %02d NETWORK SECURITY FILTER BYPASSED[/color]" % cur_lvl)
		
		var next_lvl = cur_lvl - 1
		if next_lvl >= 0:
			sm.unlock_level(next_lvl)
			_print_output_line("[color=#dcdcaa][+] ESCALATING CLEARANCE TO SUB-LEVEL %02d...[/color]" % next_lvl)
			_print_output_line("[color=#34d399][+] ACCESS GRANTED: Directory 'level_%02d' is unlocked[/color]" % next_lvl)
			_setup_file_tree()
			call_deferred("_check_and_trigger_dialogue", next_lvl)
			
		_print_output_line("[color=#34d399]════════════════════════════════════════════════════════════[/color]")
	else:
		_print_output_line("\n[color=#ef4444]════════════════════════════════════════════════════════════[/color]")
		_print_output_line("[color=#ef4444][✖] VERIFICATION FAILED (%d/%d tests passed)[/color]" % [pass_count, test_cases.size()])
		_print_output_line("[color=#94a3b8]    Read INTRODUCTION.md for specifications and modify %s.[/color]" % task_file_key.get_file())
		_print_output_line("[color=#ef4444]════════════════════════════════════════════════════════════[/color]")
		
	sm.save_game()

func _load_checker_info(checker_path: String) -> Dictionary:
	var info: Dictionary = {
		"func_name": "",
		"test_cases": []
	}
	if not FileAccess.file_exists(checker_path):
		return info
		
	var content = FileAccess.get_file_as_string(checker_path)
	if content.is_empty():
		return info
		
	var import_idx = content.find("from task import ")
	if import_idx != -1:
		var line_end = content.find("\n", import_idx)
		if line_end == -1:
			line_end = content.length()
		var import_line = content.substr(import_idx + 17, line_end - (import_idx + 17)).strip_edges()
		info["func_name"] = import_line.split(",")[0].split(" ")[0].strip_edges()
		
	var test_block = _extract_test_cases_block(content)
	if not test_block.is_empty():
		var tuples = _extract_tuples_from_block(test_block)
		for t_str in tuples:
			var parsed_tc = py_interpreter.parse_test_case(t_str)
			if not parsed_tc.is_empty():
				info["test_cases"].append(parsed_tc)
				
	return info

func _extract_test_cases_block(content: String) -> String:
	var start_idx = content.find("test_cases = [")
	if start_idx == -1:
		start_idx = content.find("test_cases=[")
	if start_idx == -1:
		return ""
	var open_bracket = content.find("[", start_idx)
	if open_bracket == -1:
		return ""
		
	var depth = 0
	var in_str = false
	var str_char = ""
	for i in range(open_bracket, content.length()):
		var ch = content[i]
		if not in_str:
			if ch == '"' or ch == "'":
				in_str = true
				str_char = ch
			elif ch == "[":
				depth += 1
			elif ch == "]":
				depth -= 1
				if depth == 0:
					return content.substr(open_bracket + 1, i - open_bracket - 1)
		else:
			if ch == str_char and (i == 0 or content[i - 1] != "\\"):
				in_str = false
	return ""

func _extract_tuples_from_block(block: String) -> Array[String]:
	var tuples: Array[String] = []
	var depth = 0
	var in_str = false
	var str_char = ""
	var current_tuple = ""
	for i in range(block.length()):
		var ch = block[i]
		if not in_str:
			if ch == '"' or ch == "'":
				in_str = true
				str_char = ch
				if depth > 0:
					current_tuple += ch
			elif ch == "(":
				depth += 1
				if depth == 1:
					current_tuple = "("
				else:
					current_tuple += ch
			elif ch == ")":
				depth -= 1
				if depth >= 0:
					current_tuple += ch
				if depth == 0 and not current_tuple.is_empty():
					tuples.append(current_tuple)
					current_tuple = ""
			else:
				if depth > 0:
					current_tuple += ch
		else:
			if depth > 0:
				current_tuple += ch
			if ch == str_char and (i == 0 or block[i - 1] != "\\"):
				in_str = false
	return tuples

func _parse_markdown_to_bbcode(md: String) -> String:
	var lines = md.split("\n")
	var result_lines: PackedStringArray = []
	var in_code_block = false
	var code_block_lines: PackedStringArray = []
	
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*(.*?)\\*\\*")
	
	var inline_code_regex = RegEx.new()
	inline_code_regex.compile("`([^`]+)`")
	
	for line in lines:
		if line.strip_edges().begins_with("```"):
			if in_code_block:
				var block_text = "\n".join(code_block_lines)
				result_lines.append("[bgcolor=#090a0f][color=#dcdcaa][code]" + block_text + "[/code][/color][/bgcolor]\n")
				code_block_lines.clear()
				in_code_block = false
			else:
				in_code_block = true
				code_block_lines.clear()
			continue
			
		if in_code_block:
			code_block_lines.append(line)
			continue
			
		var trimmed = line.strip_edges()
		
		# Headers
		if trimmed.begins_with("# "):
			var content = trimmed.substr(2).strip_edges()
			result_lines.append("[font_size=18][color=#38bdf8][b]" + content + "[/b][/color][/font_size]")
			result_lines.append("[color=#1e293b]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n")
			continue
		elif trimmed.begins_with("## "):
			var content = trimmed.substr(3).strip_edges()
			result_lines.append("[font_size=15][color=#60a5fa][b]" + content + "[/b][/color][/font_size]\n")
			continue
		elif trimmed.begins_with("### "):
			var content = trimmed.substr(4).strip_edges()
			result_lines.append("[font_size=13][color=#93c5fd][b]" + content + "[/b][/color][/font_size]\n")
			continue
		elif trimmed.begins_with("#### "):
			var content = trimmed.substr(5).strip_edges()
			result_lines.append("[font_size=12][b]" + content + "[/b][/font_size]\n")
			continue
			
		# Callout quote alerts
		if trimmed.begins_with("> [!NOTE]"):
			result_lines.append("[color=#38bdf8][b]ℹ NOTE:[/b][/color]")
			continue
		elif trimmed.begins_with("> [!TIP]"):
			result_lines.append("[color=#34d399][b]💡 TIP:[/b][/color]")
			continue
		elif trimmed.begins_with("> [!IMPORTANT]"):
			result_lines.append("[color=#f59e0b][b]⚠ IMPORTANT:[/b][/color]")
			continue
		elif trimmed.begins_with("> [!WARNING]") or trimmed.begins_with("> [!CAUTION]"):
			result_lines.append("[color=#ef4444][b]⛔ WARNING:[/b][/color]")
			continue
			
		# Horizontal Rule
		if trimmed == "---" or trimmed == "***" or trimmed == "___":
			result_lines.append("[color=#1e293b]────────────────────────────────────────────────────────────[/color]")
			continue
			
		# Unordered list items
		var list_line = line
		if list_line.strip_edges().begins_with("- "):
			var indent_len = list_line.find("- ")
			var indent = " ".repeat(indent_len)
			list_line = indent + "[color=#38bdf8]•[/color] " + list_line.strip_edges().substr(2)
		elif list_line.strip_edges().begins_with("* "):
			var indent_len = list_line.find("* ")
			var indent = " ".repeat(indent_len)
			list_line = indent + "[color=#38bdf8]•[/color] " + list_line.strip_edges().substr(2)
			
		# Inline bold & code
		list_line = bold_regex.sub(list_line, "[b]$1[/b]", true)
		list_line = inline_code_regex.sub(list_line, "[bgcolor=#161a24][color=#fbbf24] $1 [/color][/bgcolor]", true)
		
		result_lines.append(list_line)
		
	if in_code_block and not code_block_lines.is_empty():
		var block_text = "\n".join(code_block_lines)
		result_lines.append("[bgcolor=#090a0f][color=#dcdcaa][code]" + block_text + "[/code][/color][/bgcolor]\n")
		
	return "\n".join(result_lines)


# -----------------------------------------------------------------------------
# Documentation & Docstring Hover Tooltip System (VS Code Doctype View)
# -----------------------------------------------------------------------------

func _setup_doc_hover() -> void:
	doc_hover_timer = Timer.new()
	doc_hover_timer.one_shot = true
	doc_hover_timer.wait_time = 0.35
	doc_hover_timer.timeout.connect(_on_doc_hover_timeout)
	add_child(doc_hover_timer)
	
	# Outer Panel Container (VS Code dark card #252526 with #454545 border & shadow)
	doc_hover_panel = PanelContainer.new()
	doc_hover_panel.name = "DocHoverPanel"
	doc_hover_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	doc_hover_panel.top_level = true
	doc_hover_panel.z_index = 120
	doc_hover_panel.visible = false
	doc_hover_panel.mouse_entered.connect(func(): _panel_hovered = true)
	doc_hover_panel.mouse_exited.connect(func():
		_panel_hovered = false
		_hide_doc_hover()
	)
	
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color("#252526")
	outer_style.border_color = Color("#454545")
	outer_style.set_border_width_all(1)
	outer_style.set_corner_radius_all(5)
	outer_style.content_margin_left = 0
	outer_style.content_margin_right = 0
	outer_style.content_margin_top = 0
	outer_style.content_margin_bottom = 0
	outer_style.shadow_color = Color(0, 0, 0, 0.5)
	outer_style.shadow_size = 8
	doc_hover_panel.add_theme_stylebox_override("panel", outer_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	doc_hover_panel.add_child(main_vbox)
	
	# Header Code Block Container (#1e1e1e dark code box)
	var header_box = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color("#1e1e1e")
	header_style.set_corner_radius_all(3)
	header_style.content_margin_left = 10
	header_style.content_margin_right = 10
	header_style.content_margin_top = 8
	header_style.content_margin_bottom = 8
	header_box.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_box)
	
	doc_hover_title = RichTextLabel.new()
	doc_hover_title.bbcode_enabled = true
	doc_hover_title.fit_content = true
	doc_hover_title.scroll_active = false
	doc_hover_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doc_hover_title.custom_minimum_size = Vector2(300, 0)
	header_box.add_child(doc_hover_title)
	
	# Separator Line (#383838)
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color("#3c3c3c")
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep)
	
	# Body Documentation Container
	var body_box = MarginContainer.new()
	body_box.add_theme_constant_override("margin_left", 12)
	body_box.add_theme_constant_override("margin_right", 12)
	body_box.add_theme_constant_override("margin_top", 8)
	body_box.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(body_box)
	
	doc_hover_body = RichTextLabel.new()
	doc_hover_body.bbcode_enabled = true
	doc_hover_body.fit_content = true
	doc_hover_body.scroll_active = false
	doc_hover_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doc_hover_body.custom_minimum_size = Vector2(300, 0)
	doc_hover_body.add_theme_color_override("default_color", Color("#cccccc"))
	body_box.add_child(doc_hover_body)
	
	add_child(doc_hover_panel)

func _handle_editor_mouse_motion(local_mouse_pos: Vector2) -> void:
	# Don't interfere while the user is reading the hover panel
	if _panel_hovered:
		return
	var sm = SaveManager.get_instance()
	if not sm.active_file.ends_with(".py"):
		_hide_doc_hover()
		return
		
	var ident_info = _get_identifier_at_pos(local_mouse_pos)
	if ident_info.is_empty():
		if not _last_hover_word.is_empty():
			_last_hover_word = ""
			_last_hover_receiver = ""
			if doc_hover_timer:
				doc_hover_timer.stop()
			_hide_doc_hover()
		return
		
	var word: String = ident_info.get("word", "")
	var receiver: String = ident_info.get("receiver", "")
	if word.is_valid_int() or word.is_valid_float():
		if not _last_hover_word.is_empty():
			_last_hover_word = ""
			_last_hover_receiver = ""
			if doc_hover_timer:
				doc_hover_timer.stop()
			_hide_doc_hover()
		return
		
	var global_mpos = code_editor.global_position + local_mouse_pos
	if word != _last_hover_word or receiver != _last_hover_receiver:
		_last_hover_word = word
		_last_hover_receiver = receiver
		_last_hover_pos = global_mpos
		_hide_doc_hover()
		if doc_hover_timer:
			doc_hover_timer.start(0.35)
	else:
		_last_hover_pos = global_mpos

func _on_doc_hover_timeout() -> void:
	if _last_hover_word.is_empty():
		_hide_doc_hover()
		return
		
	var sm = SaveManager.get_instance()
	if not sm.active_file.ends_with(".py"):
		return
		
	var doc = PythonInterpreter.get_symbol_doc(_last_hover_word, code_editor.text, _last_hover_receiver)
	if not doc.get("found", false):
		_hide_doc_hover()
		return
		
	var sig: String = doc.get("signature", _last_hover_word)
	var kind: String = doc.get("kind", "function")
	var docstring: String = doc.get("docstring", "")
	
	# Build VS Code style signature block
	var title_bb = ""
	var kind_color = "#569cd6"
	if kind == "class":
		kind_color = "#4ec9b0"
	elif kind == "method":
		kind_color = "#4ec9b0"
	elif kind == "variable":
		kind_color = "#9cdcfe"
		
	var clean_sig = sig
	if not clean_sig.begins_with("("):
		clean_sig = "(%s) %s" % [kind, sig]
		
	# Color syntax in signature
	var color_sig = clean_sig
	color_sig = color_sig.replace("(function)", "[color=#569cd6](function)[/color]")
	color_sig = color_sig.replace("(method)", "[color=#4ec9b0](method)[/color]")
	color_sig = color_sig.replace("(class)", "[color=#4ec9b0](class)[/color]")
	color_sig = color_sig.replace("(parameter)", "[color=#9cdcfe](parameter)[/color]")
	color_sig = color_sig.replace("def ", "[color=#569cd6]def [/color]")
	color_sig = color_sig.replace("class ", "[color=#569cd6]class [/color]")
	color_sig = color_sig.replace("->", "[color=#569cd6]->[/color]")
	
	doc_hover_title.text = color_sig
	
	if docstring.is_empty():
		doc_hover_body.text = "[i][color=#808080]No documentation provided.[/color][/i]"
	else:
		var lines = docstring.split("\n")
		var clean_lines: Array[String] = []
		for l in lines:
			var trimmed_l = l.strip_edges(false, true)
			# Bullet points
			if trimmed_l.begins_with("- ") or trimmed_l.begins_with("* "):
				clean_lines.append("[color=#808080]•[/color] " + trimmed_l.substr(2))
			# Headers like Rules:, Args:, Returns:
			elif trimmed_l.begins_with("Rules:") or trimmed_l.begins_with("Args:") or trimmed_l.begins_with("Returns:") or trimmed_l.begins_with("Invariant:"):
				clean_lines.append("[b][color=#569cd6]%s[/color][/b]" % trimmed_l)
			else:
				# Format inline code `foo` with VS Code string color
				var line_formatted = trimmed_l
				while "`" in line_formatted:
					var first_q = line_formatted.find("`")
					var second_q = line_formatted.find("`", first_q + 1)
					if second_q != -1:
						var code_span = line_formatted.substr(first_q + 1, second_q - first_q - 1)
						line_formatted = line_formatted.substr(0, first_q) + "[bgcolor=#1e1e1e][color=#ce9178] " + code_span + " [/color][/bgcolor]" + line_formatted.substr(second_q + 1)
					else:
						break
				clean_lines.append(line_formatted)
			doc_hover_body.text = "\n".join(clean_lines)
		
	doc_hover_panel.reset_size()
	var panel_size = doc_hover_panel.get_combined_minimum_size()
	var vp_size = get_viewport_rect().size
	
	var target_x = _last_hover_pos.x + 10
	var target_y = _last_hover_pos.y + 20
	
	if target_y + panel_size.y > vp_size.y - 15:
		target_y = _last_hover_pos.y - panel_size.y - 10
	if target_x + panel_size.x > vp_size.x - 15:
		target_x = vp_size.x - panel_size.x - 15
	if target_x < 15: target_x = 15
	if target_y < 15: target_y = 15
	
	doc_hover_panel.global_position = Vector2(target_x, target_y)
	doc_hover_panel.visible = true

func _hide_doc_hover() -> void:
	if _panel_hovered:
		return
	if doc_hover_panel and doc_hover_panel.visible:
		doc_hover_panel.visible = false

func _get_identifier_at_pos(local_mouse_pos: Vector2) -> Dictionary:
	var lc = code_editor.get_line_column_at_pos(Vector2i(local_mouse_pos))
	var col = lc.x
	var line_idx = lc.y
	if line_idx < 0 or line_idx >= code_editor.get_line_count():
		return {}
	var line_text = code_editor.get_line(line_idx)
	if line_text.is_empty():
		return {}
	if col < 0: col = 0
	if col >= line_text.length():
		if col > 0 and col == line_text.length():
			col -= 1
		else:
			return {}
	var c = line_text[col]
	if not _is_ident_char(c):
		if col > 0 and _is_ident_char(line_text[col - 1]):
			col -= 1
			c = line_text[col]
		else:
			return {}
	var start_col = col
	while start_col > 0 and _is_ident_char(line_text[start_col - 1]):
		start_col -= 1
	var end_col = col
	while end_col < line_text.length() and _is_ident_char(line_text[end_col]):
		end_col += 1
	var word = line_text.substr(start_col, end_col - start_col)
	
	# Check if preceded by receiver.dot (e.g. packet.get or obj.method)
	var receiver = ""
	if start_col > 0 and line_text[start_col - 1] == '.':
		var r_end = start_col - 1
		var r_start = r_end
		while r_start > 0 and _is_ident_char(line_text[r_start - 1]):
			r_start -= 1
		if r_end > r_start:
			receiver = line_text.substr(r_start, r_end - r_start)
			
	return {"word": word, "receiver": receiver, "line": line_idx, "col": col}

func _is_ident_char(c: String) -> bool:
	if c.is_empty():
		return false
	var code = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95

# ----------------- Activity Bar & Extension Marketplace -----------------
var _active_sidebar_view: String = "explorer"

func _setup_activity_bar() -> void:
	if explorer_icon:
		explorer_icon.pressed.connect(func(): _switch_sidebar_view("explorer"))
	if extensions_icon:
		extensions_icon.pressed.connect(func(): _switch_sidebar_view("extensions"))
	if extension_search_input:
		extension_search_input.text_changed.connect(func(_new_text): _render_marketplace_extensions())
	_switch_sidebar_view("explorer")

func _set_activity_btn_active(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		btn.add_theme_color_override("icon_normal_color", Color(0.22, 0.74, 0.97, 1.0))
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		sb.border_width_left = 2
		sb.border_color = Color(0.22, 0.74, 0.97, 1.0)
		sb.corner_radius_top_left = 2
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", sb)
	else:
		btn.add_theme_color_override("icon_normal_color", Color(0.48, 0.54, 0.65, 1.0))
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

func _switch_sidebar_view(view_name: String) -> void:
	_active_sidebar_view = view_name
	if explorer_view:
		explorer_view.visible = (view_name == "explorer")
	if extensions_view:
		extensions_view.visible = (view_name == "extensions")
		if view_name == "extensions":
			_render_marketplace_extensions()
	if explorer_icon:
		_set_activity_btn_active(explorer_icon, view_name == "explorer")
	if extensions_icon:
		_set_activity_btn_active(extensions_icon, view_name == "extensions")

func _update_money_badge() -> void:
	if money_badge:
		var sm = SaveManager.get_instance()
		money_badge.text = "[€ %d]" % sm.get_money()

func _render_marketplace_extensions() -> void:
	if extensions_list_container == null:
		return
	for child in extensions_list_container.get_children():
		child.queue_free()
		
	var search_text = ""
	if extension_search_input:
		search_text = extension_search_input.text.strip_edges()
		
	var exts: Array[ExtensionResource] = []
	if search_text.is_empty():
		exts = ExtensionDatabase.get_all_extensions()
	else:
		exts = ExtensionDatabase.search_extensions(search_text)
		
	var sm = SaveManager.get_instance()
	for ext in exts:
		var card = _create_extension_card(ext, sm)
		extensions_list_container.add_child(card)

func _create_extension_card(ext: ExtensionResource, sm: SaveManager) -> PanelContainer:
	var card = PanelContainer.new()
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.09, 0.12, 1.0)
	card_sb.border_width_left = 1
	card_sb.border_width_top = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 1
	card_sb.border_color = Color(0.16, 0.18, 0.24, 1.0)
	card_sb.corner_radius_top_left = 5
	card_sb.corner_radius_top_right = 5
	card_sb.corner_radius_bottom_right = 5
	card_sb.corner_radius_bottom_left = 5
	card.add_theme_stylebox_override("panel", card_sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Top row: Name & Category badge
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)
	
	var name_lbl = Label.new()
	name_lbl.text = ext.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	top_row.add_child(name_lbl)
	
	if not ext.category.is_empty():
		var cat_lbl = Label.new()
		cat_lbl.text = "[%s]" % ext.category
		cat_lbl.add_theme_font_size_override("font_size", 9)
		cat_lbl.add_theme_color_override("font_color", Color(0.48, 0.56, 0.7, 1.0))
		top_row.add_child(cat_lbl)
		
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = ext.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8, 1.0))
	vbox.add_child(desc_lbl)
	
	# Bottom row: Price / Status and Action Button
	var bot_row = HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bot_row)
	
	var is_installed = sm.is_extension_installed(ext.extension_id)
	var is_theme = ext.category.to_lower().contains("theme")
	var is_active_theme = (sm.active_theme_extension == ext.extension_id)
	
	var price_status_lbl = Label.new()
	price_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_status_lbl.add_theme_font_size_override("font_size", 11)
	if is_installed:
		if is_active_theme:
			price_status_lbl.text = "● Active Theme"
			price_status_lbl.add_theme_color_override("font_color", Color(0.22, 0.74, 0.97, 1.0))
		else:
			price_status_lbl.text = "✓ Installed"
			price_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.83, 0.6, 1.0))
	else:
		price_status_lbl.text = "€ %d" % ext.price_cents
		price_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.83, 0.6, 1.0))
	bot_row.add_child(price_status_lbl)
	
	var action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(60, 22)
	action_btn.focus_mode = Control.FOCUS_NONE
	action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_btn.add_theme_font_size_override("font_size", 10)
	
	var btn_sb = StyleBoxFlat.new()
	btn_sb.corner_radius_top_left = 3
	btn_sb.corner_radius_top_right = 3
	btn_sb.corner_radius_bottom_right = 3
	btn_sb.corner_radius_bottom_left = 3
	btn_sb.content_margin_left = 8
	btn_sb.content_margin_right = 8
	btn_sb.content_margin_top = 2
	btn_sb.content_margin_bottom = 2
	
	if not is_installed:
		action_btn.text = "Buy (€ %d)" % ext.price_cents
		btn_sb.bg_color = Color(0.04, 0.36, 0.26, 0.95)
		action_btn.add_theme_stylebox_override("normal", btn_sb)
		action_btn.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95, 1.0))
		action_btn.pressed.connect(func(): _buy_or_install_extension(ext))
	else:
		if is_theme:
			if is_active_theme:
				action_btn.text = "Disable"
				btn_sb.bg_color = Color(0.25, 0.15, 0.15, 0.95)
				action_btn.add_theme_stylebox_override("normal", btn_sb)
				action_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7, 1.0))
				action_btn.pressed.connect(func():
					sm.set_active_theme_extension("")
					_apply_active_theme()
					_render_marketplace_extensions()
				)
			else:
				action_btn.text = "Apply"
				btn_sb.bg_color = Color(0.12, 0.25, 0.45, 0.95)
				action_btn.add_theme_stylebox_override("normal", btn_sb)
				action_btn.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0, 1.0))
				action_btn.pressed.connect(func():
					sm.set_active_theme_extension(ext.extension_id)
					_apply_active_theme()
					_render_marketplace_extensions()
				)
		else:
			action_btn.text = "Installed"
			action_btn.disabled = true
			btn_sb.bg_color = Color(0.15, 0.17, 0.22, 0.8)
			action_btn.add_theme_stylebox_override("normal", btn_sb)
			action_btn.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
			
	bot_row.add_child(action_btn)
	return card

func _buy_or_install_extension(ext: ExtensionResource) -> void:
	var sm = SaveManager.get_instance()
	if sm.get_money() < ext.price_cents:
		_print_terminal_line("[color=#f87171]✘ Transaction failed: Insufficient funds. Required: €%d, Available: €%d[/color]" % [ext.price_cents, sm.get_money()])
		return
		
	if sm.spend_money(ext.price_cents):
		sm.install_extension(ext.extension_id)
		_print_terminal_line("[color=#34d399]✔ Successfully purchased and installed %s for €%d.[/color]" % [ext.display_name, ext.price_cents])
		if ext.category.to_lower().contains("theme"):
			sm.set_active_theme_extension(ext.extension_id)
			_apply_active_theme()
		_update_money_badge()
		_render_marketplace_extensions()

func _apply_active_theme() -> void:
	var sm = SaveManager.get_instance()
	var active_ext_id = sm.active_theme_extension
	if active_ext_id.is_empty():
		_setup_syntax_highlighters()
		if code_editor:
			var default_sb = StyleBoxFlat.new()
			default_sb.bg_color = Color(0.07, 0.078, 0.11, 1.0)
			code_editor.add_theme_stylebox_override("normal", default_sb)
			code_editor.add_theme_stylebox_override("focus", default_sb)
			if sm.active_file.ends_with(".py"):
				code_editor.syntax_highlighter = py_highlighter
		return
		
	var ext = ExtensionDatabase.get_extension(active_ext_id)
	if ext == null:
		return
		
	if code_editor and ext.theme_editor_bg != Color.BLACK:
		var sb = StyleBoxFlat.new()
		sb.bg_color = ext.theme_editor_bg
		code_editor.add_theme_stylebox_override("normal", sb)
		code_editor.add_theme_stylebox_override("focus", sb)
		
	if py_highlighter:
		if ext.theme_keyword_color != Color.BLACK:
			py_highlighter.clear_keyword_colors()
			var keywords = [
				"def", "class", "return", "pass", "lambda", "yield", "raise",
				"import", "from", "as", "global", "nonlocal", "assert", "del",
				"with", "try", "except", "finally", "async", "await"
			]
			for kw in keywords:
				py_highlighter.add_keyword_color(kw, ext.theme_keyword_color)
				
			var control_flow = [
				"if", "elif", "else", "for", "while", "break", "continue", "in", "is", "not", "and", "or"
			]
			for kw in control_flow:
				py_highlighter.add_keyword_color(kw, ext.theme_keyword_color)
				
		if ext.theme_function_color != Color.BLACK:
			py_highlighter.function_color = ext.theme_function_color
			
		if ext.theme_string_color != Color.BLACK:
			py_highlighter.clear_color_regions()
			py_highlighter.add_color_region("#", "", Color("#6a9955"), true)
			py_highlighter.add_color_region('"""', '"""', ext.theme_string_color, false)
			py_highlighter.add_color_region("'''", "'''", ext.theme_string_color, false)
			py_highlighter.add_color_region('"', '"', ext.theme_string_color, false)
			py_highlighter.add_color_region("'", "'", ext.theme_string_color, false)
			
	if code_editor and sm.active_file.ends_with(".py"):
		code_editor.syntax_highlighter = py_highlighter
