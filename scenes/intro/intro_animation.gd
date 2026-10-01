extends Node2D
class_name IntroAnimation

signal intro_completed

@onready var camera: Camera2D = $Camera2D
@onready var character: Node2D = $Room/Character
@onready var monitor_glow: PointLight2D = $Room/Desk/Monitor/MonitorGlow
@onready var screen_rect: ColorRect = $Room/Desk/Monitor/ScreenLight
@onready var pc_led: ColorRect = $Room/Desk/PCTower/LED
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skip_label: Label = $CanvasLayer/SkipLabel

var _is_skipping: bool = false

func _ready() -> void:
	# Hide monitor glow initially
	if monitor_glow:
		monitor_glow.energy = 0.0
	if screen_rect:
		screen_rect.color = Color(0.05, 0.05, 0.05, 1.0)
	if pc_led:
		pc_led.color = Color(0.2, 0.2, 0.2, 1.0)
	
	play_intro_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed):
		if not _is_skipping and anim_player.is_playing():
			skip_intro()

func play_intro_sequence() -> void:
	anim_player.play("wake_and_walk")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "wake_and_walk" or anim_name == "zoom_to_monitor":
		intro_completed.emit()

func skip_intro() -> void:
	_is_skipping = true
	anim_player.stop()
	var tween = create_tween()
	tween.tween_property($CanvasLayer/FadeRect, "color:a", 1.0, 0.4)
	tween.tween_callback(func(): intro_completed.emit())
