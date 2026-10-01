class_name ExtensionDatabase
extends RefCounted

## Database service managing all available Extension Marketplace items.
## Persists and retrieves ExtensionResource objects from res://data/extensions/
## fully compatible with Godot's resource system and YARD registries.

const EXTENSIONS_DIR: String = "res://data/extensions/"

static var _cached_extensions: Array[ExtensionResource] = []

static func get_all_extensions() -> Array[ExtensionResource]:
	if not _cached_extensions.is_empty():
		return _cached_extensions
		
	_ensure_database_directory()
	_load_or_create_database()
	return _cached_extensions

static func get_extension_by_id(ext_id: String) -> ExtensionResource:
	var list = get_all_extensions()
	for ext in list:
		if str(ext.id) == ext_id:
			return ext
	return null

static func get_extension(ext_id: String) -> ExtensionResource:
	return get_extension_by_id(ext_id)

static func search_extensions(query: String, cat: String = "") -> Array[ExtensionResource]:
	return search(query, cat)

static func filter_by_category(cat: String) -> Array[ExtensionResource]:
	var all = get_all_extensions()
	if cat.is_empty() or cat.to_lower() == "all":
		return all
	var filtered: Array[ExtensionResource] = []
	for ext in all:
		if ext.category.to_lower() == cat.to_lower():
			filtered.append(ext)
	return filtered

static func search(query: String, cat: String = "") -> Array[ExtensionResource]:
	var base_list = filter_by_category(cat)
	var q = query.strip_edges().to_lower()
	if q.is_empty():
		return base_list
	var matched: Array[ExtensionResource] = []
	for ext in base_list:
		if ext.title.to_lower().contains(q) or ext.description.to_lower().contains(q) or ext.publisher.to_lower().contains(q):
			matched.append(ext)
	return matched

static func _ensure_database_directory() -> void:
	if not DirAccess.dir_exists_absolute(EXTENSIONS_DIR):
		DirAccess.make_dir_recursive_absolute(EXTENSIONS_DIR)

static func _load_or_create_database() -> void:
	_cached_extensions.clear()
	
	# Initial seed items if database directory is empty
	var definitions = _get_default_extension_definitions()
	for d in definitions:
		var file_path = EXTENSIONS_DIR + str(d["id"]) + ".tres"
		var res: ExtensionResource = null
		
		if ResourceLoader.exists(file_path):
			var loaded = ResourceLoader.load(file_path)
			if loaded is ExtensionResource:
				res = loaded
				
		if res == null:
			res = ExtensionResource.new()
			res.id = d["id"]
			res.title = d["title"]
			res.publisher = d["publisher"]
			res.description = d["description"]
			res.price = d["price"]
			res.category = d["category"]
			res.version = d["version"]
			res.icon_name = d["icon_name"]
			res.rating = d["rating"]
			res.downloads = d["downloads"]
			if d.has("theme_bg_color"):
				res.theme_bg_color = d["theme_bg_color"]
				res.theme_code_color = d["theme_code_color"]
				res.theme_accent_color = d["theme_accent_color"]
				res.theme_keyword_color = d["theme_keyword_color"]
				res.theme_comment_color = d["theme_comment_color"]
				res.theme_string_color = d["theme_string_color"]
			ResourceSaver.save(res, file_path)
			
		_cached_extensions.append(res)

static func _get_default_extension_definitions() -> Array[Dictionary]:
	return [
		{
			"id": &"ext_core_starter",
			"title": "Cyber Hacker Core",
			"publisher": "ksk.os",
			"description": "Standard-issue workstation suite. Includes basic autocomplete, shell shortcuts, and status diagnostics.",
			"price": 0,
			"category": "Starter Pack",
			"version": "1.0.0",
			"icon_name": "circuit_board",
			"rating": 5.0,
			"downloads": "10.4k"
		},
		{
			"id": &"theme_matrix_green",
			"title": "Matrix Cyber-Green Theme",
			"publisher": "zion.net",
			"description": "Emerald phosphor syntax highlight on deep obsidian. Classic monochrome hacker aesthetic.",
			"price": 150,
			"category": "Theme",
			"version": "2.4.1",
			"icon_name": "palette",
			"rating": 4.9,
			"downloads": "8.7k",
			"theme_bg_color": Color(0.015, 0.04, 0.025, 1.0),
			"theme_code_color": Color("#86efac"),
			"theme_accent_color": Color("#22c55e"),
			"theme_keyword_color": Color("#4ade80"),
			"theme_comment_color": Color("#166534"),
			"theme_string_color": Color("#a7f3d0")
		},
		{
			"id": &"theme_dracula_night",
			"title": "Dracula Synthwave Theme",
			"publisher": "vampire.io",
			"description": "Vibrant violet and neon magenta dark theme optimized for late-night tactical debugging sessions.",
			"price": 120,
			"category": "Theme",
			"version": "1.8.0",
			"icon_name": "palette",
			"rating": 4.8,
			"downloads": "6.2k",
			"theme_bg_color": Color(0.065, 0.05, 0.09, 1.0),
			"theme_code_color": Color("#f8fafc"),
			"theme_accent_color": Color("#ec4899"),
			"theme_keyword_color": Color("#a855f7"),
			"theme_comment_color": Color("#64748b"),
			"theme_string_color": Color("#f472b6")
		},
		{
			"id": &"theme_amber_crt",
			"title": "Amber CRT Phosphor Theme",
			"publisher": "retro.hardware",
			"description": "Warm retro amber terminal glow recreating 1980s military mainframe consoles.",
			"price": 180,
			"category": "Theme",
			"version": "1.2.0",
			"icon_name": "palette",
			"rating": 4.7,
			"downloads": "4.1k",
			"theme_bg_color": Color(0.06, 0.045, 0.02, 1.0),
			"theme_code_color": Color("#fde68a"),
			"theme_accent_color": Color("#f59e0b"),
			"theme_keyword_color": Color("#fbbf24"),
			"theme_comment_color": Color("#78350f"),
			"theme_string_color": Color("#fef08a")
		},
		{
			"id": &"ext_ai_copilot",
			"title": "KSK Neural Co-pilot",
			"publisher": "cyberdyne.ai",
			"description": "Real-time AI suggestions, autonomous docstring synthesis, and logic refactoring assistant.",
			"price": 250,
			"category": "AI Tools",
			"version": "3.1.0",
			"icon_name": "bot",
			"rating": 4.9,
			"downloads": "12.3k"
		},
		{
			"id": &"ext_turboterm",
			"title": "Turbo Terminal Visualizer",
			"publisher": "telemetry.systems",
			"description": "High-throughput terminal emulator buffer with ANSI formatting and memory-mapped scrolling.",
			"price": 80,
			"category": "Terminal",
			"version": "1.5.2",
			"icon_name": "file_terminal",
			"rating": 4.6,
			"downloads": "3.9k"
		},
		{
			"id": &"ext_git_matrix",
			"title": "Git Matrix Visualizer",
			"publisher": "version.control",
			"description": "Interactive DAG commit visualizer, visual merge conflict resolver, and signature verifier.",
			"price": 200,
			"category": "Productivity",
			"version": "2.0.4",
			"icon_name": "git_branch",
			"rating": 4.8,
			"downloads": "7.5k"
		},
		{
			"id": &"ext_quantum_linter",
			"title": "Quantum Static Linter",
			"publisher": "compiler.corp",
			"description": "Deep AST static inspection detecting edge-case runtime exceptions and type discrepancies.",
			"price": 100,
			"category": "Productivity",
			"version": "1.1.0",
			"icon_name": "bug",
			"rating": 4.7,
			"downloads": "5.3k"
		},
		{
			"id": &"ext_hex_dump",
			"title": "Hex-Dump Memory Map",
			"publisher": "lowlevel.org",
			"description": "Byte-by-byte memory visualizer with pointer disassembly for low-level node diagnostics.",
			"price": 300,
			"category": "Debugger",
			"version": "4.0.0",
			"icon_name": "database",
			"rating": 5.0,
			"downloads": "1.8k"
		}
	]
