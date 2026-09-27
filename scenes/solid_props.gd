@tool
extends TileMapLayer


func _ready() -> void:
	collision_enabled = true
	physics_quadrant_size = 1
	if tile_set == null:
		return
	if tile_set.get_physics_layers_count() == 0:
		# Keep this layer's collision settings separate from shared floor data.
		tile_set = tile_set.duplicate(true)
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 1)
	notify_runtime_tile_data_update()


func _use_tile_data_runtime_update(_coords: Vector2i) -> bool:
	return tile_set != null and tile_set.get_physics_layers_count() > 0


func _tile_data_runtime_update(coords: Vector2i, data: TileData) -> void:
	if data.get_collision_polygons_count(0) > 0:
		return
	var source := tile_set.get_source(get_cell_source_id(coords)) as TileSetAtlasSource
	if source == null:
		return
	var size := Vector2(source.get_tile_size_in_atlas(get_cell_atlas_coords(coords)) * source.texture_region_size)
	var center := -Vector2(data.texture_origin)
	var start := center - size * 0.5
	var end := center + size * 0.5
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		start, Vector2(end.x, start.y), end, Vector2(start.x, end.y)
	]))
