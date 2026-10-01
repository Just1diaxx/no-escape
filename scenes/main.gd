extends Node
class_name Main

signal state_changed(new_state: GameState)

enum GameState {
	SPLASH,
	MENU,
	INTRO,
	LOGIN,
	DESKTOP,
	IDE,
	DEBUG_IDE
}

var current_state: GameState = GameState.SPLASH:
	set(val):
		current_state = val
		state_changed.emit(current_state)

@onready var scene_container: Node = $SceneContainer
@onready var transition_rect: ColorRect = $CanvasLayer/TransitionRect

var splash_scene_prefab = preload("res://scenes/splash/splash_screen.tscn")
var menu_scene_prefab = preload("res://scenes/menu/main_menu.tscn")
var intro_scene_prefab = preload("res://scenes/intro/intro_animation.tscn")
var login_scene_prefab = preload("res://scenes/login/login_screen.tscn")
var desktop_scene_prefab = preload("res://scenes/desktop/desktop.tscn")
var ide_scene_prefab = preload("res://scenes/ide/ide_screen.tscn")
var test_ide_scene_prefab = preload("res://scenes/ide/test_ide.tscn")
var pause_menu_prefab = preload("res://scenes/ui/pause_menu.tscn")

var current_scene_instance: Node = null
var pause_menu_instance: PauseMenu = null

func _ready() -> void:
	transition_rect.color = Color(0, 0, 0, 1)
	_setup_pause_menu()
	switch_to_splash()

func _setup_pause_menu() -> void:
	var pause_layer = CanvasLayer.new()
	pause_layer.layer = 25
	pause_layer.name = "PauseLayer"
	add_child(pause_layer)
	
	pause_menu_instance = pause_menu_prefab.instantiate()
	pause_layer.add_child(pause_menu_instance)
	pause_menu_instance.back_to_menu_pressed.connect(_on_pause_back_to_menu)

func _on_pause_back_to_menu() -> void:
	switch_to_menu(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if current_state in [GameState.IDE, GameState.DESKTOP, GameState.LOGIN, GameState.INTRO, GameState.DEBUG_IDE]:
			if pause_menu_instance:
				if pause_menu_instance.is_open():
					pause_menu_instance.resume_game()
				else:
					pause_menu_instance.open_menu()
				get_viewport().set_input_as_handled()

func _clear_current_scene() -> void:
	if current_scene_instance and is_instance_valid(current_scene_instance):
		current_scene_instance.queue_free()
		current_scene_instance = null

func switch_to_splash() -> void:
	current_state = GameState.SPLASH
	_clear_current_scene()
	
	var splash = splash_scene_prefab.instantiate()
	splash.splash_finished.connect(_on_splash_finished)
	scene_container.add_child(splash)
	current_scene_instance = splash
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)

func _on_splash_finished() -> void:
	# Splash already faded to black; start background music and reveal the menu
	if has_node("/root/AudioManager"):
		AudioManager.play_bgm(0.8)
	switch_to_menu(false)

func switch_to_menu(fade_out_first: bool = true) -> void:
	current_state = GameState.MENU
	
	if fade_out_first:
		var tween = create_tween()
		tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
		tween.tween_callback(func(): _load_menu_scene())
		tween.tween_property(transition_rect, "color:a", 0.0, 0.2)
	else:
		transition_rect.color.a = 1.0
		_load_menu_scene()
		var tween = create_tween()
		tween.tween_property(transition_rect, "color:a", 0.0, 0.12)

func _load_menu_scene() -> void:
	_clear_current_scene()
	var menu = menu_scene_prefab.instantiate()
	menu.continue_pressed.connect(_on_menu_continue)
	menu.new_game_pressed.connect(_on_menu_new_game)
	scene_container.add_child(menu)
	current_scene_instance = menu

func _on_menu_continue() -> void:
	switch_to_intro()

func _on_menu_new_game() -> void:
	SaveManager.get_instance().reset_save()
	switch_to_intro()

func switch_to_intro() -> void:
	current_state = GameState.INTRO
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.4)
	tween.tween_callback(func():
		_clear_current_scene()
		var intro = intro_scene_prefab.instantiate()
		intro.intro_completed.connect(_on_intro_completed)
		scene_container.add_child(intro)
		current_scene_instance = intro
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.5)

func _on_intro_completed() -> void:
	switch_to_login()

func switch_to_login() -> void:
	current_state = GameState.LOGIN
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.4)
	tween.tween_callback(func():
		_clear_current_scene()
		var login = login_scene_prefab.instantiate()
		login.login_succeeded.connect(_on_login_succeeded)
		scene_container.add_child(login)
		current_scene_instance = login
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.4)

func _on_login_succeeded() -> void:
	switch_to_desktop()

func switch_to_desktop(fade: bool = true) -> void:
	current_state = GameState.DESKTOP
	
	if fade:
		var tween = create_tween()
		tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
		tween.tween_callback(func(): _load_desktop_scene())
		tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
	else:
		_load_desktop_scene()
		transition_rect.color.a = 0.0

func _load_desktop_scene() -> void:
	_clear_current_scene()
	var desktop = desktop_scene_prefab.instantiate()
	desktop.open_coder_requested.connect(_on_desktop_open_coder)
	desktop.open_debug_ide_requested.connect(_on_desktop_open_debug_ide)
	desktop.pause_requested.connect(_on_desktop_pause_requested)
	scene_container.add_child(desktop)
	current_scene_instance = desktop

func _on_desktop_open_coder() -> void:
	switch_to_ide()

func _on_desktop_open_debug_ide() -> void:
	switch_to_debug_ide()

func _on_desktop_pause_requested() -> void:
	if pause_menu_instance:
		if pause_menu_instance.is_open():
			pause_menu_instance.resume_game()
		else:
			pause_menu_instance.open_menu()

func switch_to_ide() -> void:
	current_state = GameState.IDE
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		_clear_current_scene()
		var ide = ide_scene_prefab.instantiate()
		if ide.has_signal("close_requested"):
			ide.close_requested.connect(func(): switch_to_desktop())
		scene_container.add_child(ide)
		current_scene_instance = ide
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)

func switch_to_debug_ide() -> void:
	current_state = GameState.DEBUG_IDE
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		_clear_current_scene()
		var dbg = test_ide_scene_prefab.instantiate()
		if dbg.has_signal("close_requested"):
			dbg.close_requested.connect(func(): switch_to_desktop())
		scene_container.add_child(dbg)
		current_scene_instance = dbg
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
