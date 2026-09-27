extends Control
class_name MainMenu

signal game_start_pressed
signal credits_pressed
signal quit_pressed

@export var game_start_button: Button
@export var credits_button: Button
@export var quit_button: Button

func _ready() -> void:
	game_start_pressed.connect(_start_game)
	credits_pressed.connect(_open_credits)
	quit_pressed.connect(_quit_game)

	if game_start_button:
		game_start_button.pressed.connect(game_start_pressed.emit)
		
	if credits_button:
		credits_button.pressed.connect(credits_pressed.emit)
		
	if quit_button:
		quit_button.pressed.connect(quit_pressed.emit)

func _start_game() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/intro_01.tscn")
	if error != OK:
		push_error("Failed to open intro scene: %s" % error_string(error))

func _open_credits() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
	if error != OK:
		push_error("Failed to open credits: " + error_string(error))


func _quit_game() -> void:
	get_tree().quit()
