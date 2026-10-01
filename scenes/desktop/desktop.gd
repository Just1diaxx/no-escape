class_name DesktopScreen
extends Control

## Cyberpunk OS Desktop Environment for No ESCape.
## Provides application launchers for Coder (IDE), Documents, and Debug IDE.

signal open_coder_requested
signal open_debug_ide_requested
signal pause_requested

const ICON_CODER = preload("res://addons/at-icons/control/laptop.svg")
const ICON_DOCS = preload("res://addons/at-icons/control/folder_open.svg")
const ICON_DEBUG = preload("res://addons/at-icons/control/bug.svg")
const ICON_FILE_DOC = preload("res://addons/at-icons/control/file_document.svg")
const ICON_FILE_TXT = preload("res://addons/at-icons/control/file.svg")
const ICON_MENU = preload("res://addons/at-icons/control/grid_coarse.svg")

const DOCS_PATH := "res://files/Documents/"

# UI References
var clock_label: Label
var clearance_label: Label
var money_label: Label
var docs_window: PanelContainer
var docs_file_list: VBoxContainer
var docs_viewer: RichTextLabel
var docs_path_label: Label
var active_doc_file := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_update_clearance()
	_update_money()
	_update_clock()
	
	if has_node("/root/AudioManager") and not AudioManager.is_bgm_playing():
		AudioManager.play_bgm(0.8)
	
	var sm = SaveManager.get_instance()
	if sm:
		sm.money_changed.connect(func(_amt): _update_money())
		sm.state_changed.connect(_update_money)
	
	# Clock update timer
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_clock)
	add_child(timer)

func _build_ui() -> void:
	# ── 1. Wallpaper Background ──
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.055, 0.08, 1.0)
	add_child(bg)

	# Decorative system watermark & grid lines
	var watermark_box := CenterContainer.new()
	watermark_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	watermark_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(watermark_box)

	var watermark_vbox := VBoxContainer.new()
	watermark_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	watermark_vbox.add_theme_constant_override("separation", 6)
	watermark_vbox.modulate = Color(1.0, 1.0, 1.0, 0.05)
	watermark_box.add_child(watermark_vbox)

	var wm_title := Label.new()
	wm_title.text = "KOMMANDO SPEZIALKRÄFTE"
	wm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wm_title.add_theme_font_size_override("font_size", 32)
	watermark_vbox.add_child(wm_title)

	var wm_sub := Label.new()
	wm_sub.text = "SECURE WORKSTATION // NODE_042"
	wm_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wm_sub.add_theme_font_size_override("font_size", 16)
	watermark_vbox.add_child(wm_sub)

	# ── 2. Desktop Icon Area ──
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var icons_container := HBoxContainer.new()
	icons_container.add_theme_constant_override("separation", 28)
	margin.add_child(icons_container)

	# App Icons Column
	var app_column := VBoxContainer.new()
	app_column.add_theme_constant_override("separation", 24)
	icons_container.add_child(app_column)

	# 1) Coder Icon
	var coder_icon = _create_desktop_icon("Coder", "IDE // Levels", ICON_CODER, Color("#38bdf8"), func():
		open_coder_requested.emit()
	)
	app_column.add_child(coder_icon)

	# 2) Documents Icon
	var docs_icon = _create_desktop_icon("Documents", "File Archive", ICON_DOCS, Color("#34d399"), func():
		_open_documents_window()
	)
	app_column.add_child(docs_icon)

	# 3) Debug IDE Icon
	var debug_icon = _create_desktop_icon("Debug IDE", "Harness // test.py", ICON_DEBUG, Color("#f59e0b"), func():
		open_debug_ide_requested.emit()
	)
	app_column.add_child(debug_icon)

	# ── 3. Documents Floating Window ──
	_build_documents_window()

	# ── 4. Taskbar (Bottom) ──
	_build_taskbar()

func _create_desktop_icon(app_name: String, app_sub: String, icon_texture: Texture2D, accent_color: Color, on_activate: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 106)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.16, 0.4)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.28, 0.4, 0.3)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 10
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 8

	var hover_style := panel_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.12, 0.18, 0.28, 0.75)
	hover_style.border_color = accent_color

	btn.add_theme_stylebox_override("normal", panel_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_texture
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = accent_color
	vbox.add_child(icon_rect)

	var label := Label.new()
	label.text = app_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#e2e8f0"))
	vbox.add_child(label)

	var sub_label := Label.new()
	sub_label.text = app_sub
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 9)
	sub_label.add_theme_color_override("font_color", Color("#64748b"))
	vbox.add_child(sub_label)

	btn.pressed.connect(on_activate)
	return btn

func _build_taskbar() -> void:
	var taskbar := PanelContainer.new()
	taskbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -38
	taskbar.offset_bottom = 0
	
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	tb_style.border_width_top = 1
	tb_style.border_color = Color(0.18, 0.22, 0.32, 1.0)
	tb_style.content_margin_left = 12
	tb_style.content_margin_right = 16
	tb_style.content_margin_top = 4
	tb_style.content_margin_bottom = 4
	taskbar.add_theme_stylebox_override("panel", tb_style)
	add_child(taskbar)

	var tb_hbox := HBoxContainer.new()
	tb_hbox.add_theme_constant_override("separation", 14)
	taskbar.add_child(tb_hbox)

	# KSK System Menu / Start Button
	var start_btn := Button.new()
	start_btn.text = " ⬢ KSK NODE "
	start_btn.flat = true
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_btn.add_theme_font_size_override("font_size", 12)
	start_btn.add_theme_color_override("font_color", Color("#38bdf8"))
	start_btn.pressed.connect(func(): pause_requested.emit())
	tb_hbox.add_child(start_btn)

	var div1 := VSeparator.new()
	tb_hbox.add_child(div1)

	# Quick launch buttons
	var q_coder := Button.new()
	q_coder.text = "Coder"
	q_coder.flat = true
	q_coder.focus_mode = Control.FOCUS_NONE
	q_coder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	q_coder.add_theme_font_size_override("font_size", 11)
	q_coder.add_theme_color_override("font_color", Color("#94a3b8"))
	q_coder.pressed.connect(func(): open_coder_requested.emit())
	tb_hbox.add_child(q_coder)

	var q_docs := Button.new()
	q_docs.text = "Documents"
	q_docs.flat = true
	q_docs.focus_mode = Control.FOCUS_NONE
	q_docs.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	q_docs.add_theme_font_size_override("font_size", 11)
	q_docs.add_theme_color_override("font_color", Color("#94a3b8"))
	q_docs.pressed.connect(func(): _open_documents_window())
	tb_hbox.add_child(q_docs)

	var q_dbg := Button.new()
	q_dbg.text = "Debug IDE"
	q_dbg.flat = true
	q_dbg.focus_mode = Control.FOCUS_NONE
	q_dbg.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	q_dbg.add_theme_font_size_override("font_size", 11)
	q_dbg.add_theme_color_override("font_color", Color("#94a3b8"))
	q_dbg.pressed.connect(func(): open_debug_ide_requested.emit())
	tb_hbox.add_child(q_dbg)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer)

	# Money Counter Widget (€)
	money_label = Label.new()
	money_label.text = "[€ %d]" % (SaveManager.get_instance().player_money if SaveManager.get_instance() else 500)
	money_label.add_theme_font_size_override("font_size", 11)
	money_label.add_theme_color_override("font_color", Color("#34d399"))
	money_label.tooltip_text = "Player Credits / Operating Funds"
	tb_hbox.add_child(money_label)

	var div_m := VSeparator.new()
	tb_hbox.add_child(div_m)

	# Clearance Badge
	clearance_label = Label.new()
	clearance_label.text = "[CLR: SUB-LEVEL 30]"
	clearance_label.add_theme_font_size_override("font_size", 11)
	clearance_label.add_theme_color_override("font_color", Color("#38bdf8"))
	tb_hbox.add_child(clearance_label)

	var user_lbl := Label.new()
	user_lbl.text = "op@escape-node"
	user_lbl.add_theme_font_size_override("font_size", 11)
	user_lbl.add_theme_color_override("font_color", Color("#64748b"))
	tb_hbox.add_child(user_lbl)

	var div2 := VSeparator.new()
	tb_hbox.add_child(div2)

	# System Clock
	clock_label = Label.new()
	clock_label.text = "00:00:00"
	clock_label.add_theme_font_size_override("font_size", 11)
	clock_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	tb_hbox.add_child(clock_label)

func _update_clearance() -> void:
	var sm = SaveManager.get_instance()
	if clearance_label and sm:
		clearance_label.text = "[CLR: SUB-LEVEL %02d]" % sm.current_unlocked_level

func _update_money() -> void:
	var sm = SaveManager.get_instance()
	if money_label and sm:
		money_label.text = "[€ %d]" % sm.player_money

func _update_clock() -> void:
	if clock_label:
		var dt = Time.get_time_dict_from_system()
		clock_label.text = "%02d:%02d:%02d" % [dt.hour, dt.minute, dt.second]

# ─── DOCUMENTS WINDOW ──────────────────────────────────────────────────────────

func _build_documents_window() -> void:
	docs_window = PanelContainer.new()
	docs_window.visible = false
	
	# Center positioned window
	docs_window.set_anchors_preset(Control.PRESET_CENTER)
	docs_window.offset_left = -380
	docs_window.offset_right = 380
	docs_window.offset_top = -240
	docs_window.offset_bottom = 240
	
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.07, 0.08, 0.115, 0.98)
	win_style.border_width_left = 1
	win_style.border_width_top = 1
	win_style.border_width_right = 1
	win_style.border_width_bottom = 1
	win_style.border_color = Color(0.24, 0.32, 0.46, 0.7)
	win_style.corner_radius_top_left = 8
	win_style.corner_radius_top_right = 8
	win_style.corner_radius_bottom_right = 8
	win_style.corner_radius_bottom_left = 8
	win_style.shadow_size = 16
	win_style.shadow_color = Color(0, 0, 0, 0.6)
	docs_window.add_theme_stylebox_override("panel", win_style)
	add_child(docs_window)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	docs_window.add_child(root_vbox)

	# Window Titlebar
	var titlebar := PanelContainer.new()
	var tb_style := StyleBoxFlat.new()
	tb_style.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	tb_style.corner_radius_top_left = 8
	tb_style.corner_radius_top_right = 8
	tb_style.content_margin_left = 12
	tb_style.content_margin_right = 10
	tb_style.content_margin_top = 6
	tb_style.content_margin_bottom = 6
	titlebar.add_theme_stylebox_override("panel", tb_style)
	root_vbox.add_child(titlebar)

	var tb_hbox := HBoxContainer.new()
	tb_hbox.add_theme_constant_override("separation", 8)
	titlebar.add_child(tb_hbox)

	var doc_ico := TextureRect.new()
	doc_ico.texture = ICON_DOCS
	doc_ico.custom_minimum_size = Vector2(16, 16)
	doc_ico.modulate = Color("#34d399")
	doc_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	doc_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tb_hbox.add_child(doc_ico)

	var win_title := Label.new()
	win_title.text = "DOCUMENTS ARCHIVE  ·  /files/Documents"
	win_title.add_theme_font_size_override("font_size", 12)
	win_title.add_theme_color_override("font_color", Color("#cbd5e1"))
	tb_hbox.add_child(win_title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color("#64748b"))
	close_btn.add_theme_color_override("font_hover_color", Color("#ef4444"))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func(): docs_window.visible = false)
	tb_hbox.add_child(close_btn)

	# Main Split: File List (Left) | Viewer (Right)
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.split_offset = 200
	root_vbox.add_child(hsplit)

	# Left sidebar: File List
	var left_panel := ScrollContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	var left_bg := StyleBoxFlat.new()
	left_bg.bg_color = Color(0.04, 0.048, 0.07, 1.0)
	left_bg.content_margin_left = 6
	left_bg.content_margin_top = 8
	left_bg.content_margin_right = 6
	left_bg.content_margin_bottom = 8
	var left_cont := PanelContainer.new()
	left_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_cont.add_theme_stylebox_override("panel", left_bg)
	left_panel.add_child(left_cont)
	hsplit.add_child(left_panel)

	docs_file_list = VBoxContainer.new()
	docs_file_list.add_theme_constant_override("separation", 4)
	left_cont.add_child(docs_file_list)

	# Right area: Document Viewer
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_bg := StyleBoxFlat.new()
	right_bg.bg_color = Color(0.055, 0.065, 0.09, 1.0)
	right_bg.content_margin_left = 16
	right_bg.content_margin_top = 14
	right_bg.content_margin_right = 16
	right_bg.content_margin_bottom = 14
	right_panel.add_theme_stylebox_override("panel", right_bg)
	hsplit.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	docs_path_label = Label.new()
	docs_path_label.text = "Select a document to read"
	docs_path_label.add_theme_font_size_override("font_size", 11)
	docs_path_label.add_theme_color_override("font_color", Color("#64748b"))
	right_vbox.add_child(docs_path_label)

	var sep := HSeparator.new()
	right_vbox.add_child(sep)

	docs_viewer = RichTextLabel.new()
	docs_viewer.bbcode_enabled = true
	docs_viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	docs_viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	docs_viewer.scroll_following = false
	docs_viewer.selection_enabled = true
	docs_viewer.add_theme_font_size_override("normal_font_size", 13)
	docs_viewer.add_theme_color_override("default_color", Color("#cbd5e1"))
	right_vbox.add_child(docs_viewer)

func _open_documents_window() -> void:
	docs_window.visible = true
	_refresh_documents_list()

func _refresh_documents_list() -> void:
	for child in docs_file_list.get_children():
		child.queue_free()

	var dir = DirAccess.open(DOCS_PATH)
	var found_files: Array[String] = []

	if dir:
		dir.list_dir_begin()
		var fn = dir.get_next()
		while fn != "":
			if not dir.current_is_dir() and not fn.begins_with(".") and not fn.ends_with(".import") and not fn.ends_with(".uid"):
				found_files.append(fn)
			fn = dir.get_next()
		dir.list_dir_end()

	found_files.sort()

	if found_files.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No files found"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color("#64748b"))
		docs_file_list.add_child(empty_lbl)
		return

	for fn in found_files:
		var item_btn := Button.new()
		item_btn.text = "  " + fn
		item_btn.icon = ICON_FILE_DOC if fn.ends_with(".md") else ICON_FILE_TXT
		item_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.expand_icon = true
		item_btn.custom_minimum_size = Vector2(0, 30)
		item_btn.flat = true
		item_btn.focus_mode = Control.FOCUS_NONE
		item_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item_btn.add_theme_font_size_override("font_size", 11)
		
		var is_sel = (fn == active_doc_file)
		item_btn.add_theme_color_override("font_color", Color("#38bdf8") if is_sel else Color("#cbd5e1"))
		
		var target_name = fn
		item_btn.pressed.connect(func(): _display_document(target_name))
		docs_file_list.add_child(item_btn)

	# Auto-open first document if none active
	if active_doc_file.is_empty() and not found_files.is_empty():
		_display_document(found_files[0])
	elif not active_doc_file.is_empty():
		_display_document(active_doc_file)

func _display_document(filename: String) -> void:
	active_doc_file = filename
	var full_p = DOCS_PATH + filename
	if not FileAccess.file_exists(full_p):
		docs_viewer.text = "[color=#ef4444]File not found: %s[/color]" % full_p
		return

	var raw_content = FileAccess.get_file_as_string(full_p)
	docs_path_label.text = "/files/Documents/%s  ·  %d bytes" % [filename, raw_content.length()]

	if filename.ends_with(".md"):
		docs_viewer.text = _parse_markdown(raw_content)
	else:
		docs_viewer.text = raw_content

func _parse_markdown(md: String) -> String:
	var lines = md.split("\n")
	var result_lines: PackedStringArray = []
	var in_code_block = false
	var code_block_lines: PackedStringArray = []

	for line in lines:
		if line.strip_edges().begins_with("```"):
			if in_code_block:
				var block_text = "\n".join(code_block_lines)
				result_lines.append("[bgcolor=#090a0f][color=#38bdf8][code]" + block_text + "[/code][/color][/bgcolor]\n")
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
			result_lines.append("\n[font_size=17][color=#38bdf8][b]" + content + "[/b][/color][/font_size]")
		elif trimmed.begins_with("## "):
			var content = trimmed.substr(3).strip_edges()
			result_lines.append("\n[font_size=14][color=#34d399][b]" + content + "[/b][/color][/font_size]")
		elif trimmed.begins_with("### "):
			var content = trimmed.substr(4).strip_edges()
			result_lines.append("\n[font_size=12][color=#f59e0b][b]" + content + "[/b][/color][/font_size]")
		elif trimmed.begins_with("---"):
			result_lines.append("[color=#334155]────────────────────────────────────────────────[/color]")
		elif trimmed.begins_with("- "):
			var content = trimmed.substr(2).strip_edges()
			result_lines.append("  [color=#38bdf8]•[/color] " + _format_inline(content))
		else:
			result_lines.append(_format_inline(line))

	return "\n".join(result_lines)

func _format_inline(text: String) -> String:
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*(.*?)\\*\\*")
	text = bold_regex.sub(text, "[b][color=#f8fafc]$1[/color][/b]", true)

	var inline_code = RegEx.new()
	inline_code.compile("`([^`]+)`")
	text = inline_code.sub(text, "[color=#38bdf8][bgcolor=#0d1525] $1 [/bgcolor][/color]", true)
	return text

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if docs_window.visible:
				docs_window.visible = false
				get_viewport().set_input_as_handled()
			else:
				pause_requested.emit()
				get_viewport().set_input_as_handled()
