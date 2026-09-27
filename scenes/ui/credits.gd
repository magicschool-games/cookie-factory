extends Control

var leaving := false

func _ready() -> void:
	resized.connect(_fit_card)
	_fit_card()
	$Margin/Center/Card/Padding/Content/Back.pressed.connect(_back)
	$Margin/Center/Card/Padding/Content/Back.grab_focus()
	var card := $Margin/Center/Card as Control
	card.modulate.a = 0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.45)

func _fit_card() -> void:
	$Margin/Center/Card.custom_minimum_size = Vector2(minf(880, maxf(320, size.x - 64)), maxf(420, size.y - 64))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	if leaving:
		return
	leaving = true
	var error := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if error != OK:
		leaving = false
		push_error("Could not return to menu: " + error_string(error))
