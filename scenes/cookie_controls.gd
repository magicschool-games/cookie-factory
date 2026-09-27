extends Node2D

@export_file("*.tscn") var next_scene := ""
@export var exit_region := Rect2()
@export_file("*.tscn") var previous_scene := ""
@export var return_region := Rect2()
@export var previous_scene_spawns: Array[Vector2] = []
static var pending_spawns: Array[Vector2] = []
var level_completed := false
var forward_armed := true
var return_armed := true

@onready var cookies: Array[CharacterBody2D] = [$player_big, $player_small]
var active_index := 0
var top_cookie: CharacterBody2D


func _ready() -> void:
	if pending_spawns.size() == cookies.size():
		for i in range(cookies.size()):
			cookies[i].position = cookies[i].grid_position(pending_spawns[i])
	pending_spawns.clear()
	forward_armed = not _any_cookie_in_region(exit_region)
	return_armed = not _any_cookie_in_region(return_region)
	_ensure_bakery_collisions()
	# Separate tile bodies let jumps ignore only the obstacle being cleared.
	for child in get_children():
		if child is TileMapLayer:
			child.physics_quadrant_size = 1
	cookies[0].can_hop_obstacles = true
	cookies[1].bridge_cookie = cookies[0]
	var cars := preload("res://scenes/car_props.gd").new()
	cars.props = $Props
	cars.passenger = cookies[1]
	add_child(cars)
	cookies[1].obstacle_action_handler = cars.try_activate
	cookies[0].launch_handler = Callable(self, "try_launch_small")
	cookies[1].movement_blocked_handler = Callable(self, "is_small_pinned")
	cookies[1].struggle_progress.connect(_lift_top_cookie)
	for cookie in cookies:
		cookie.jump_started.connect(_on_cookie_jump_started.bind(cookie))
		cookie.landed.connect(_on_cookie_landed.bind(cookie))
	get_viewport().size_changed.connect(_fit_cameras_to_level)
	_fit_cameras_to_level()
	select_cookie(0)
	var dialogue_context := preload("res://scenes/dialog/dialogue_context.gd").new()
	dialogue_context.name = "DialogueContext"
	dialogue_context.small = cookies[1]
	dialogue_context.big = cookies[0]
	add_child(dialogue_context)
	set_physics_process(not next_scene.is_empty() or not previous_scene.is_empty())


func _ensure_bakery_collisions() -> void:
	# External atlas saves can lose TileData physics when detached from a
	# TileSet. Restore missing bakery shapes before the first physics frame.
	var checked: Array[TileSet] = []
	for child in get_children():
		if not child is TileMapLayer or child.tile_set == null:
			continue
		var tiles: TileSet = child.tile_set
		if tiles in checked:
			continue
		checked.append(tiles)
		for source_index in range(tiles.get_source_count()):
			var source := tiles.get_source(tiles.get_source_id(source_index)) as TileSetAtlasSource
			if source == null or source.texture == null or source.texture.resource_path != "res://assets/bakery/bakery_tiles.png":
				continue
			if tiles.get_physics_layers_count() == 0:
				tiles.add_physics_layer()
				tiles.set_physics_layer_collision_layer(0, 1)
			for tile_index in range(source.get_tiles_count()):
				var coords := source.get_tile_id(tile_index)
				var data := source.get_tile_data(coords, 0)
				if data.get_collision_polygons_count(0) > 0:
					continue
				var end := Vector2(source.get_tile_size_in_atlas(coords) * source.texture_region_size) - Vector2(8, 8)
				data.set_collision_polygons_count(0, 1)
				data.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(end.x, -8), end, Vector2(-8, end.y)
				]))


func _physics_process(_delta: float) -> void:
	if level_completed:
		return
	# An arrival inside an exit must leave it before that exit can fire again.
	if not forward_armed:
		forward_armed = not _any_cookie_in_region(exit_region)
	if not return_armed:
		return_armed = not _any_cookie_in_region(return_region)
	if forward_armed and not next_scene.is_empty() and _all_cookies_in_region(exit_region):
		level_completed = true
		_change_level.call_deferred(next_scene, [])
	elif return_armed and not previous_scene.is_empty() and _all_cookies_in_region(return_region):
		level_completed = true
		_change_level.call_deferred(previous_scene, previous_scene_spawns)


func _any_cookie_in_region(region: Rect2) -> bool:
	if not region.has_area():
		return false
	for cookie in cookies:
		if region.intersects(Rect2(cookie.position - cookie.footprint * 0.5, cookie.footprint)):
			return true
	return false


func _all_cookies_in_region(region: Rect2) -> bool:
	if not region.has_area():
		return false
	for cookie in cookies:
		var cookie_bounds := Rect2(cookie.position - cookie.footprint * 0.5, cookie.footprint)
		if not region.intersects(cookie_bounds):
			return false
	return true


func _change_level(path: String, spawn_positions: Array) -> void:
	pending_spawns.assign(spawn_positions)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		pending_spawns.clear()
		push_error("Failed to load next level: %s" % error_string(error))
		set_physics_process(false)


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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		if not level_completed:
			level_completed = true
			_restart_level.call_deferred()
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		select_cookie((active_index + 1) % cookies.size())
		get_viewport().set_input_as_handled()


func _restart_level() -> void:
	pending_spawns.clear()
	var error := get_tree().reload_current_scene()
	if error != OK:
		level_completed = false
		push_error("Failed to restart level: %s" % error_string(error))


func select_cookie(index: int) -> void:
	active_index = index
	for i in range(cookies.size()):
		cookies[i].is_controlled = i == active_index
		cookies[i].velocity = Vector2.ZERO
	cookies[active_index].get_node("Camera2D").make_current()


func _on_cookie_jump_started(cookie: CharacterBody2D) -> void:
	# Moving either cookie breaks the previous support relationship.
	if top_cookie == cookies[0]:
		cookies[0].sprite.position = Vector2.ZERO
	top_cookie = null
	for other in cookies:
		other.z_index = 3 if other == cookie else 2


func _on_cookie_landed(cookie: CharacterBody2D) -> void:
	var other := cookies[1] if cookie == cookies[0] else cookies[0]
	if other.roll_direction != Vector2.ZERO or other.is_flinging or other.launch_pending:
		return
	# Either half of the big cookie can cover the small cookie. Testing the
	# big cookie's center against the small one's footprint misses offset landings.
	var big := cookies[0]
	var small := cookies[1]
	var support := Rect2(big.global_position - big.footprint * 0.5, big.footprint)
	if support.has_point(small.global_position):
		top_cookie = cookie
		cookie.z_index = 3
		other.z_index = 2


func is_small_pinned() -> bool:
	return top_cookie == cookies[0]


func _lift_top_cookie(effort: float) -> void:
	if is_small_pinned():
		# Visual lift only: the stack and collision bodies remain stationary.
		cookies[0].sprite.position = Vector2(0, -3.0 * effort)


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
