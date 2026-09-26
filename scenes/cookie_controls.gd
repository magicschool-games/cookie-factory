extends Node2D

@onready var cookies: Array[CharacterBody2D] = [$player_big, $player_small]
var active_index := 0
var top_cookie: CharacterBody2D


func _ready() -> void:
	cookies[0].launch_handler = Callable(self, "try_launch_small")
	for cookie in cookies:
		cookie.jump_started.connect(_on_cookie_jump_started.bind(cookie))
		cookie.landed.connect(_on_cookie_landed.bind(cookie))
	get_viewport().size_changed.connect(_fit_cameras_to_level)
	_fit_cameras_to_level()
	select_cookie(0)


func _fit_cameras_to_level() -> void:
	var floor_tiles := get_node_or_null("FloorTiles") as TileMapLayer
	if floor_tiles == null or floor_tiles.get_used_rect().size == Vector2i.ZERO:
		return
	var cells := floor_tiles.get_used_rect()
	var tile_size := Vector2(floor_tiles.tile_set.tile_size)
	var bounds := Rect2(
		floor_tiles.to_global(Vector2(cells.position) * tile_size),
		Vector2(cells.size) * tile_size * floor_tiles.global_scale
	)
	var viewport_size := get_viewport_rect().size
	var fit_zoom := maxf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)
	for cookie in cookies:
		var camera := cookie.get_node("Camera2D") as Camera2D
		camera.limit_left = int(bounds.position.x)
		camera.limit_top = int(bounds.position.y)
		camera.limit_right = int(bounds.end.x)
		camera.limit_bottom = int(bounds.end.y)
		camera.zoom = Vector2.ONE * fit_zoom
		camera.force_update_scroll()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		select_cookie((active_index + 1) % cookies.size())
		get_viewport().set_input_as_handled()


func select_cookie(index: int) -> void:
	active_index = index
	for i in range(cookies.size()):
		cookies[i].is_controlled = i == active_index
		cookies[i].velocity = Vector2.ZERO
	cookies[active_index].get_node("Camera2D").make_current()


func _on_cookie_jump_started(cookie: CharacterBody2D) -> void:
	# Moving either cookie breaks the previous support relationship.
	top_cookie = null
	for other in cookies:
		other.z_index = 3 if other == cookie else 2


func _on_cookie_landed(cookie: CharacterBody2D) -> void:
	var other := cookies[1] if cookie == cookies[0] else cookies[0]
	if other.roll_direction != Vector2.ZERO or other.is_flinging or other.launch_pending:
		return
	var support := Rect2(other.global_position - other.footprint * 0.5, other.footprint)
	if support.has_point(cookie.global_position):
		top_cookie = cookie
		cookie.z_index = 3
		other.z_index = 2


func try_launch_small(direction: Vector2) -> bool:
	var big = cookies[0]
	var small = cookies[1]
	if top_cookie != small or active_index != 0 or not big.is_controlled:
		return false
	if big.roll_direction != Vector2.ZERO or big.is_flinging or small.launch_pending or small.is_launched or small.roll_direction != Vector2.ZERO:
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
	top_cookie = null
	big.begin_fling(small, direction, tiles * 64.0)
	return true
