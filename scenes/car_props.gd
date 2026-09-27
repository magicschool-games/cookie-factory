extends Node

const CAR := Vector2i(2, 8)
const SIGN := Vector2i(4, 10)
const STEPS := 3
const STEP_TIME := 0.22
const SOLID_PROPS = preload("res://scenes/solid_props.gd")
var props: TileMapLayer
var passenger: CharacterBody2D
var moving := false


func _is_tile(cell: Vector2i, atlas: Vector2i) -> bool:
	if props.get_cell_source_id(cell) < 0:
		return false
	var source := props.tile_set.get_source(props.get_cell_source_id(cell)) as TileSetAtlasSource
	return source != null and source.texture.resource_path == "res://assets/kenney_tiny-factory/Tilemap/tilemap_packed.png" and props.get_cell_atlas_coords(cell) == atlas


func try_activate(direction: Vector2) -> bool:
	if moving or direction != Vector2.RIGHT:
		return false
	var cell := props.local_to_map(props.to_local(passenger.global_position + direction * 64.0))
	if not _is_tile(cell, CAR):
		return false
	moving = true
	passenger.launch_pending = true
	_drive.call_deferred(cell)
	return true


func _can_enter(cell: Vector2i, vehicle: TileMapLayer) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62, 62)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, props.to_global(props.map_to_local(cell)))
	query.collision_mask = 3
	for hit in props.get_world_2d().direct_space_state.intersect_shape(query):
		if hit.collider == vehicle:
			continue
		if hit.collider == props and _is_tile(props.get_coords_for_body_rid(hit.rid), SIGN):
			continue
		return false
	var floor := props.get_parent().get_node("FloorTiles") as TileMapLayer
	return floor.get_cell_source_id(floor.local_to_map(floor.to_local(query.transform.origin))) >= 0


func _drive(cell: Vector2i) -> void:
	var source_id := props.get_cell_source_id(cell)
	var alternative := props.get_cell_alternative_tile(cell)
	# A separate layer keeps the car's collision moving with its artwork.
	var vehicle := TileMapLayer.new()
	vehicle.set_script(SOLID_PROPS)
	vehicle.name = "MovingCar"
	vehicle.tile_set = props.tile_set
	vehicle.transform = props.transform
	vehicle.texture_filter = props.texture_filter
	vehicle.z_index = props.z_index
	vehicle.set_cell(cell, source_id, CAR, alternative)
	props.get_parent().add_child(vehicle)
	props.erase_cell(cell)
	props.update_internals()
	vehicle.update_internals()
	var offset := Vector2.ZERO
	for step in range(STEPS):
		var next := cell + Vector2i.RIGHT
		if not _can_enter(next, vehicle):
			break
		if _is_tile(next, SIGN):
			props.erase_cell(next)
			props.update_internals()
		offset += Vector2(props.tile_set.tile_size.x * props.scale.x, 0)
		var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(vehicle, "position", props.position + offset, STEP_TIME)
		await tween.finished
		cell = next
		if step == 0:
			passenger.launch_pending = false
			passenger.flip_into_vacated_cell(Vector2.RIGHT)
	props.set_cell(cell, source_id, CAR, alternative)
	vehicle.collision_enabled = false
	vehicle.queue_free()
	props.update_internals()
	passenger.launch_pending = false
	moving = false
