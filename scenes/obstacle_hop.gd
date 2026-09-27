extends RefCounted


static func short_axis_has_clear_cell(cookie: CharacterBody2D, direction: Vector2, distance: float) -> bool:
	# Check each of the two destination cells separately. The cookie may
	# straddle one obstacle, but cannot land across two blocked cells.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62, 62)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = cookie.collision_mask
	query.exclude = [cookie.get_rid()]
	var across := Vector2(-direction.y, direction.x)
	var destination := cookie.global_position + direction * distance
	var space := cookie.get_world_2d().direct_space_state
	for side in [-1.0, 1.0]:
		query.transform = Transform2D(0, destination + across * (32.0 * side))
		if space.intersect_shape(query).is_empty():
			return true
	return false


static func plan(cookie: CharacterBody2D, direction: Vector2, distance: float, allow_landing_on_tile: bool, max_obstacle_tiles: int = 1) -> Dictionary:
	# Keep diagonal corner collisions intact; hops cross one row or column.
	if absf(direction.x) > 0.01 and absf(direction.y) > 0.01:
		return {}
	var shape_node := cookie.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.collision_mask = cookie.collision_mask
	query.exclude = [cookie.get_rid()]
	var space := cookie.get_world_2d().direct_space_state
	var hop_distance := distance
	query.transform = shape_node.global_transform
	query.transform.origin += direction * hop_distance
	if not allow_landing_on_tile and not space.intersect_shape(query).is_empty():
		return {}
	var ignored: Array[RID] = []
	var near_edge := INF
	var far_edge := -INF
	var tile_depth := 0.0
	var steps := ceili(hop_distance / 4.0)
	for step in range(steps + 1):
		query.transform = shape_node.global_transform
		query.transform.origin += direction * minf(step * 4.0, hop_distance)
		var hits := space.intersect_shape(query, 64)
		if hits.size() == 64:
			return {}
		for hit in hits:
			var layer := hit.collider as TileMapLayer
			if layer == null or layer.name == "Boundary" or layer.physics_quadrant_size != 1:
				return {}
			var rid: RID = hit.rid
			if rid in ignored:
				continue
			var launcher_support: bool = cookie.is_launched and is_instance_valid(cookie.bridge_cookie) and rid in cookie.bridge_cookie.support_bodies
			if rid in cookie.support_bodies or launcher_support:
				# Leaving an already-supported tile must not make the next
				# single obstacle count as a two-tile-thick wall.
				ignored.append(rid)
				continue
			var cell := layer.get_coords_for_body_rid(rid)
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null:
				return {}
			var cells := source.get_tile_size_in_atlas(layer.get_cell_atlas_coords(cell))
			if max_obstacle_tiles == 1 and cells != Vector2i.ONE:
				return {}
			var size := Vector2(layer.tile_set.tile_size) * layer.global_scale.abs()
			var depth := (size * Vector2(cells)).dot(direction.abs())
			var data := layer.get_cell_tile_data(cell)
			var center := layer.to_global(layer.map_to_local(cell) - Vector2(data.texture_origin)).dot(direction)
			near_edge = minf(near_edge, center - depth * 0.5)
			far_edge = maxf(far_edge, center + depth * 0.5)
			tile_depth = maxf(tile_depth, size.dot(direction.abs()))
			ignored.append(rid)
	# Walking hops cross one tile; catapult flights can cross two.
	if ignored.is_empty() or far_edge - near_edge > tile_depth * max_obstacle_tiles + 0.1:
		return {}
	return {"distance": hop_distance, "bodies": ignored}


static func overlapping_bodies(cookie: CharacterBody2D) -> Array[RID]:
	var shape_node := cookie.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = cookie.collision_mask
	query.exclude = [cookie.get_rid()]
	var bodies: Array[RID] = []
	for hit in cookie.get_world_2d().direct_space_state.intersect_shape(query, 64):
		bodies.append(hit.rid)
	return bodies
