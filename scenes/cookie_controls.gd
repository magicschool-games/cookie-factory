extends Node2D

@onready var cookies: Array[CharacterBody2D] = [$player_big, $player_small]
var active_index := 0


func _ready() -> void:
	cookies[0].launch_handler = Callable(self, "try_launch_small")
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


func try_launch_small(direction: Vector2) -> bool:
	var big = cookies[0]
	var small = cookies[1]
	if active_index != 0 or big.is_flinging or small.launch_pending or small.is_launched or small.roll_direction != Vector2.ZERO:
		return false
	# The passenger's center must be over the big cookie, not merely touching it.
	var support := Rect2(big.global_position - big.footprint * 0.5, big.footprint)
	if not support.has_point(small.global_position):
		return false
	# The leading edge is the pivot: the back half has the longer lever arm.
	var offset: float = (small.global_position - big.global_position).dot(direction.normalized())
	var tiles := 2.0
	if offset < -1.0:
		tiles = 3.0
	elif offset > 1.0:
		tiles = 1.0
	big.begin_fling(small, direction, tiles * 64.0)
	return true
