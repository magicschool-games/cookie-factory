extends Control
class_name MainMenu

signal game_start_pressed
signal credits_pressed
signal quit_pressed

@export var game_start_button: Button
@export var credits_button: Button
@export var quit_button: Button

func _ready() -> void:
	if game_start_button:
		game_start_button.pressed.connect(game_start_pressed.emit)
		
	if credits_button:
		credits_button.pressed.connect(credits_pressed.emit)
		
	if quit_button:
		quit_button.pressed.connect(quit_pressed.emit)
