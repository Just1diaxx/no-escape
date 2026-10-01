extends Control
class_name SplashScreen

signal splash_finished

@onready var content_vbox: VBoxContainer = %ContentVBox
@onready var title_label: RichTextLabel = %TitleLabel
@onready var divider: ColorRect = %Divider
@onready var credits_container: HBoxContainer = %CreditsContainer
@onready var heart_label: Label = %HeartLabel
@onready var vignette: ColorRect = %Vignette

var _finished: bool = false

func _ready() -> void:
	content_vbox.modulate.a = 0.0
	credits_container.modulate.a = 0.0
	divider.scale.x = 0.0
	divider.pivot_offset = Vector2(divider.custom_minimum_size.x * 0.5, 1.0)
	heart_label.pivot_offset = Vector2(8, 10)
	
	_play_cinematic_sequence()

# STRICTLY NON-SKIPPABLE: Consume all input without skipping
func _unhandled_input(_event: InputEvent) -> void:
	pass

func _unhandled_key_input(_event: InputEvent) -> void:
	pass

func _play_cinematic_sequence() -> void:
	var tween = create_tween()
	
	# Initial silence and darkness (0.6s)
	tween.tween_interval(0.6)
	
	# 1. Reveal Title and expand subtle divider line (1.4s)
	tween.tween_property(content_vbox, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(divider, "scale:x", 1.0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Brief pause (0.4s)
	tween.tween_interval(0.4)
	
	# 2. Reveal author credit (0.9s)
	tween.tween_property(credits_container, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Breath before the heart bump (0.3s)
	tween.tween_interval(0.3)
	
	# 3. First heart bump
	tween.tween_callback(func(): _pulse_heart())
	tween.tween_interval(0.35)
	
	# 4. Fade to black immediately after the bump (0.4s)
	tween.tween_property(content_vbox, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(vignette, "color:a", 1.0, 0.4)
	
	# 5. Complete and notify immediately - zero dead gap
	tween.tween_callback(func():
		if not _finished:
			_finished = true
			splash_finished.emit()
	)

func _pulse_heart() -> void:
	var ht = create_tween()
	ht.tween_property(heart_label, "scale", Vector2(1.35, 1.35), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ht.tween_property(heart_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
