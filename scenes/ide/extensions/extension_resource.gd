class_name ExtensionResource
extends Resource

## Data model for an extension or plugin in the Coder Marketplace.
## Compatible with Godot Resource Serialization and YARD Resource Databases.

@export var id: StringName = &""
@export var title: String = ""
@export var publisher: String = "ksk.tools"
@export_multiline var description: String = ""
@export var price: int = 0
@export var category: String = ""
@export var version: String = "1.0.0"
@export var icon_name: String = "jigsaw_piece"
@export var rating: float = 4.8
@export var downloads: String = "1.2k"

# Theme customizations if category includes theme capabilities
@export var theme_bg_color: Color = Color(0.055, 0.06, 0.085, 1.0)
@export var theme_code_color: Color = Color("#d4d4d4")
@export var theme_accent_color: Color = Color("#38bdf8")
@export var theme_keyword_color: Color = Color("#569cd6")
@export var theme_comment_color: Color = Color("#6a9955")
@export var theme_string_color: Color = Color("#ce9178")

var extension_id: String:
	get: return str(id)
	set(val): id = StringName(val)

var display_name: String:
	get: return title
	set(val): title = val

var price_cents: int:
	get: return price
	set(val): price = val

var theme_editor_bg: Color:
	get: return theme_bg_color
	set(val): theme_bg_color = val

var theme_function_color: Color:
	get: return theme_accent_color
	set(val): theme_accent_color = val
