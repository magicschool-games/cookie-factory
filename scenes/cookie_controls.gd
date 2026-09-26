extends Node2D

@onready var cookies: Array[CharacterBody2D] = [$player_big, $player_small]
var active_index := 0


func _ready() -> void:
	select_cookie(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		select_cookie((active_index + 1) % cookies.size())
		get_viewport().set_input_as_handled()


func select_cookie(index: int) -> void:
	active_index = index
	for i in range(cookies.size()):
		cookies[i].is_controlled = i == active_index
		cookies[i].velocity = Vector2.ZERO
	cookies[active_index].get_node("Camera2D").make_current()
