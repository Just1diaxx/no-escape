class_name TestIDE
extends Control

signal close_requested

## Standalone interpreter test harness.
## Completely independent of SaveManager / game state.
## Loads res://files/test/test.py and lets you run/edit it freely.

const PythonInterpreter = preload("res://scenes/ide/python_interpreter.gd")
const TEST_FILE := "res://files/test/test.py"

var py_interpreter: PythonInterpreter
var code_editor: CodeEdit
var output_label: RichTextLabel
var problems_label: RichTextLabel
var status_bar: Label
var run_btn: Button
var copy_btn: Button
var tab_output_btn: Button
var tab_problems_btn: Button

var _active_tab := "output"
var _active_errors: Array[Dictionary] = []
var _output_panel: ScrollContainer
var _problems_panel: ScrollContainer
var _problems_list: VBoxContainer

func _ready() -> void:
	py_interpreter = PythonInterpreter.new()
	_build_ui()
	_load_test_file()

# ─── UI BUILD ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Root fills the window
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# ── Title bar ──
	var title_bar := PanelContainer.new()
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.07, 0.08, 0.105, 1.0)
	title_style.content_margin_left = 12
	title_style.content_margin_right = 8
	title_style.content_margin_top = 4
	title_style.content_margin_bottom = 4
	title_bar.add_theme_stylebox_override("panel", title_style)
	root_vbox.add_child(title_bar)

	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	title_bar.add_child(title_hbox)

	var dot := Label.new()
	dot.text = "⬤"
	dot.add_theme_color_override("font_color", Color("#22d3ee"))
	dot.add_theme_font_size_override("font_size", 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_hbox.add_child(dot)

	var title_lbl := Label.new()
	title_lbl.text = "INTERPRETER TEST  ·  test.py"
	title_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_hbox.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(spacer)

	run_btn = Button.new()
	run_btn.text = "▶  Run (Ctrl+Enter)"
	run_btn.add_theme_font_size_override("font_size", 12)
	run_btn.add_theme_color_override("font_color", Color("#34d399"))
	run_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	run_btn.pressed.connect(_on_run_pressed)
	title_hbox.add_child(run_btn)

	var sm = SaveManager.get_instance()
	var min_btn := Button.new()
	min_btn.text = "─"
	min_btn.tooltip_text = "Minimize"
	min_btn.add_theme_font_size_override("font_size", 12)
	min_btn.add_theme_color_override("font_color", Color("#94a3b8"))
	min_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	min_btn.pressed.connect(func(): SaveManager.get_instance().minimize_window())
	title_hbox.add_child(min_btn)

	var max_btn := Button.new()
	max_btn.text = "□"
	max_btn.tooltip_text = "Maximize"
	max_btn.add_theme_font_size_override("font_size", 12)
	max_btn.add_theme_color_override("font_color", Color("#94a3b8"))
	max_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	max_btn.pressed.connect(func(): SaveManager.get_instance().toggle_maximize_window())
	var is_fullscreen = bool(sm.settings.get("fullscreen", true)) if sm else false
	max_btn.visible = not is_fullscreen
	title_hbox.add_child(max_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.tooltip_text = "Close Debug IDE"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color("#94a3b8"))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func():
		_save_test_file()
		if close_requested.get_connections().size() > 0:
			close_requested.emit()
		else:
			get_tree().quit()
	)
	title_hbox.add_child(close_btn)

	# ── Main split: editor (left) | bottom panel (below) ──
	var vsplit := VSplitContainer.new()
	vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsplit.split_offset = 120
	root_vbox.add_child(vsplit)

	# Code editor
	code_editor = CodeEdit.new()
	code_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_editor.gutters_draw_line_numbers = true
	code_editor.add_gutter()
	_apply_editor_theme()
	code_editor.text_changed.connect(_on_code_changed)
	vsplit.add_child(code_editor)

	# ── Bottom panel ──
	var bottom := VBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.custom_minimum_size = Vector2(0, 160)
	bottom.add_theme_constant_override("separation", 0)
	vsplit.add_child(bottom)

	# Bottom tabs row
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 0)
	var tabs_bg := StyleBoxFlat.new()
	tabs_bg.bg_color = Color(0.055, 0.06, 0.085, 1.0)
	var tabs_panel := PanelContainer.new()
	tabs_panel.add_theme_stylebox_override("panel", tabs_bg)
	tabs_panel.add_child(tabs_row)
	bottom.add_child(tabs_panel)

	tab_output_btn = _make_tab_btn("OUTPUT")
	tab_output_btn.pressed.connect(func(): _switch_tab("output"))
	tabs_row.add_child(tab_output_btn)

	tab_problems_btn = _make_tab_btn("PROBLEMS (0)")
	tab_problems_btn.pressed.connect(func(): _switch_tab("problems"))
	tabs_row.add_child(tab_problems_btn)

	copy_btn = Button.new()
	copy_btn.text = "Copy Errors"
	copy_btn.flat = true
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.add_theme_font_size_override("font_size", 11)
	copy_btn.add_theme_color_override("font_color", Color("#64748b"))
	copy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	copy_btn.visible = false
	copy_btn.pressed.connect(_on_copy_errors)
	var copy_spacer := Control.new()
	copy_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(copy_spacer)
	tabs_row.add_child(copy_btn)

	# Output panel
	_output_panel = ScrollContainer.new()
	_output_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_panel.custom_minimum_size = Vector2(0, 120)
	var out_bg := StyleBoxFlat.new()
	out_bg.bg_color = Color(0.04, 0.045, 0.065, 1.0)
	out_bg.content_margin_left = 10
	out_bg.content_margin_top = 8
	out_bg.content_margin_right = 10
	out_bg.content_margin_bottom = 8
	var out_panel_cont := PanelContainer.new()
	out_panel_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out_panel_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out_panel_cont.add_theme_stylebox_override("panel", out_bg)
	_output_panel.add_child(out_panel_cont)
	bottom.add_child(_output_panel)

	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.scroll_following = true
	output_label.add_theme_font_size_override("normal_font_size", 12)
	output_label.add_theme_color_override("default_color", Color("#cbd5e1"))
	out_panel_cont.add_child(output_label)

	# Problems panel
	_problems_panel = ScrollContainer.new()
	_problems_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problems_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_problems_panel.custom_minimum_size = Vector2(0, 120)
	_problems_panel.visible = false
	var prob_bg := StyleBoxFlat.new()
	prob_bg.bg_color = Color(0.04, 0.045, 0.065, 1.0)
	prob_bg.content_margin_left = 10
	prob_bg.content_margin_top = 8
	prob_bg.content_margin_right = 10
	prob_bg.content_margin_bottom = 8
	var prob_cont := PanelContainer.new()
	prob_cont.add_theme_stylebox_override("panel", prob_bg)
	prob_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prob_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_problems_panel.add_child(prob_cont)
	bottom.add_child(_problems_panel)

	_problems_list = VBoxContainer.new()
	_problems_list.add_theme_constant_override("separation", 4)
	prob_cont.add_child(_problems_list)

	# Status bar
	var status_bg := StyleBoxFlat.new()
	status_bg.bg_color = Color(0.06, 0.065, 0.09, 1.0)
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", status_bg)
	root_vbox.add_child(status_panel)

	status_bar = Label.new()
	status_bar.text = "⊗ 0  ⚠ 0  ·  test.py  ·  Python"
	status_bar.add_theme_font_size_override("font_size", 11)
	status_bar.add_theme_color_override("font_color", Color("#64748b"))
	status_panel.add_child(status_bar)

	_switch_tab("output")

func _make_tab_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color("#64748b"))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn

func _apply_editor_theme() -> void:
	var hl := CodeHighlighter.new()
	hl.number_color = Color("#b5cea8")
	hl.symbol_color = Color("#d4d4d4")
	hl.function_color = Color("#dcdcaa")
	hl.member_variable_color = Color("#9cdcfe")
	for kw in ["def", "class", "return", "pass", "lambda", "yield", "raise",
			"import", "from", "as", "global", "nonlocal", "assert", "del",
			"with", "try", "except", "finally", "async", "await", "match", "case"]:
		hl.add_keyword_color(kw, Color("#569cd6"))
	for kw in ["if", "elif", "else", "for", "while", "break", "continue", "in", "is", "not", "and", "or"]:
		hl.add_keyword_color(kw, Color("#c586c0"))
	for bi in ["print", "len", "range", "int", "str", "float", "bool", "list", "dict",
			"set", "tuple", "enumerate", "zip", "sorted", "sum", "min", "max",
			"isinstance", "type", "abs", "all", "any", "reversed", "map", "filter", "round"]:
		hl.add_keyword_color(bi, Color("#4ec9b0"))
	for lit in ["True", "False", "None"]:
		hl.add_keyword_color(lit, Color("#569cd6"))
	hl.add_color_region("#", "", Color("#6a9955"), true)
	hl.add_color_region('"""', '"""', Color("#ce9178"), false)
	hl.add_color_region("'''", "'''", Color("#ce9178"), false)
	hl.add_color_region('"', '"', Color("#ce9178"), false)
	hl.add_color_region("'", "'", Color("#ce9178"), false)
	code_editor.syntax_highlighter = hl
	code_editor.add_theme_color_override("background_color", Color(0.055, 0.06, 0.085, 1.0))
	code_editor.add_theme_color_override("font_color", Color("#d4d4d4"))
	code_editor.add_theme_color_override("caret_color", Color("#aeafad"))
	code_editor.add_theme_color_override("selection_color", Color(0.22, 0.36, 0.6, 0.5))
	code_editor.add_theme_color_override("line_number_color", Color("#6a737d"))
	code_editor.add_theme_font_size_override("font_size", 14)
	code_editor.add_theme_constant_override("line_spacing", 4)

# ─── FILE LOAD ────────────────────────────────────────────────────────────────

func _load_test_file() -> void:
	if FileAccess.file_exists(TEST_FILE):
		code_editor.text = FileAccess.get_file_as_string(TEST_FILE)
	else:
		code_editor.text = "# test.py not found at: " + TEST_FILE + "\nprint('hello world')\n"
	_validate(_get_code())

# ─── LOGIC ────────────────────────────────────────────────────────────────────

func _get_code() -> String:
	return code_editor.text

func _on_code_changed() -> void:
	_validate(_get_code())

func _validate(code: String) -> void:
	# Clear gutter highlights
	for i in range(code_editor.get_line_count()):
		code_editor.set_line_gutter_text(i, 0, "")
		code_editor.set_line_background_color(i, Color(0, 0, 0, 0))

	_active_errors = py_interpreter.validate_python_syntax(code, "test.py")
	_refresh_error_ui()

func _on_run_pressed() -> void:
	run_btn.text = "▶  Running…"
	run_btn.disabled = true
	_switch_tab("output")
	output_label.text = ""
	call_deferred("_do_run")

func _save_test_file() -> void:
	var fa = FileAccess.open(TEST_FILE, FileAccess.WRITE)
	if fa:
		fa.store_string(code_editor.text)
		fa.close()

func _do_run() -> void:
	_save_test_file()
	var code := _get_code()
	var result: Dictionary = py_interpreter.execute(code, TEST_FILE)
	
	var out_text := ""
	if result.get("output", "") != "":
		out_text += result["output"]
	if result.get("error", "") != "":
		out_text += "[color=#ef4444]" + result["error"] + "[/color]"
	if out_text.is_empty():
		out_text = "[color=#64748b](no output)[/color]"
	
	output_label.text = out_text
	run_btn.text = "▶  Run"
	run_btn.disabled = false

func _switch_tab(tab: String) -> void:
	_active_tab = tab
	_output_panel.visible = (tab == "output")
	_problems_panel.visible = (tab == "problems")
	tab_output_btn.add_theme_color_override("font_color",
		Color("#e2e8f0") if tab == "output" else Color("#64748b"))
	tab_problems_btn.add_theme_color_override("font_color",
		Color("#e2e8f0") if tab == "problems" else
		(Color("#f87171") if _active_errors.size() > 0 else Color("#64748b")))

func _refresh_error_ui() -> void:
	var count := _active_errors.size()
	tab_problems_btn.text = "PROBLEMS (%d)" % count
	copy_btn.visible = count > 0

	# Status bar
	if count > 0:
		status_bar.text = "⊗ %d  ⚠ 0  ·  test.py  ·  Python" % count
		status_bar.add_theme_color_override("font_color", Color("#ef4444"))
	else:
		status_bar.text = "⊗ 0  ⚠ 0  ·  test.py  ·  Python"
		status_bar.add_theme_color_override("font_color", Color("#64748b"))

	# Gutter markers
	for err in _active_errors:
		var li: int = int(err.get("line", 1)) - 1
		if li >= 0 and li < code_editor.get_line_count():
			code_editor.set_line_gutter_text(li, 0, "●")
			code_editor.set_line_gutter_item_color(li, 0, Color("#ef4444"))
			code_editor.set_line_background_color(li, Color(0.85, 0.2, 0.2, 0.18))

	# Problems list
	for child in _problems_list.get_children():
		child.queue_free()

	if count == 0:
		var ok := Label.new()
		ok.text = "✓  No problems detected."
		ok.add_theme_color_override("font_color", Color("#34d399"))
		ok.add_theme_font_size_override("font_size", 12)
		_problems_list.add_child(ok)
	else:
		for err in _active_errors:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			var icon := Label.new()
			icon.text = "⊗"
			icon.add_theme_color_override("font_color", Color("#ef4444"))
			icon.add_theme_font_size_override("font_size", 12)
			row.add_child(icon)

			var line_lbl := Label.new()
			line_lbl.text = "Ln %d:" % err["line"]
			line_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
			line_lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(line_lbl)

			var msg := Label.new()
			msg.text = err["message"]
			msg.add_theme_color_override("font_color", Color("#fca5a5"))
			msg.add_theme_font_size_override("font_size", 12)
			msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(msg)

			# Click to jump to line
			var target: int = int(err.get("line", 1)) - 1
			row.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_switch_tab("output")
					code_editor.set_caret_line(target)
					code_editor.set_caret_column(0)
					code_editor.grab_focus()
			)

			_problems_list.add_child(row)

	_switch_tab(_active_tab)  # refresh tab highlight color

func _on_copy_errors() -> void:
	var lines: PackedStringArray = []
	for err in _active_errors:
		lines.append("Line %d: %s" % [err["line"], err["message"]])
	DisplayServer.clipboard_set("\n".join(lines))
	copy_btn.text = "Copied!"
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(copy_btn):
			copy_btn.text = "Copy Errors"
	)

var _dragging_titlebar := false
var _drag_offset := Vector2i.ZERO

func _input(event: InputEvent) -> void:
	var sm = SaveManager.get_instance()
	var is_fullscreen = bool(sm.settings.get("fullscreen", true)) if sm else false

	if not is_fullscreen:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos := DisplayServer.mouse_get_position()
			var win_pos := DisplayServer.window_get_position()
			var local_y := mouse_pos.y - win_pos.y

			if event.pressed and local_y >= 0 and local_y <= 32:
				if sm and sm._is_maximized:
					sm.toggle_maximize_window()
				_dragging_titlebar = true
				_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
			else:
				_dragging_titlebar = false
		elif event is InputEventMouseMotion and _dragging_titlebar:
			var new_pos := DisplayServer.mouse_get_position() - _drag_offset
			DisplayServer.window_set_position(new_pos)

	if event is InputEventKey and event.pressed and not event.echo:
		if ((event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_ENTER) or event.keycode == KEY_F5:
			_on_run_pressed()
			get_viewport().set_input_as_handled()
		elif (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_S:
			_save_test_file()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_save_test_file()
			if close_requested.get_connections().size() > 0:
				close_requested.emit()
				get_viewport().set_input_as_handled()
