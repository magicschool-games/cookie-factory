extends CharacterBody2D

signal jump_started
signal landed
signal struggle_started
signal struggle_progress(effort: float)

const SPEED = 300.0
const GRID_SIZE := 64.0
const COOKIE_EYES = preload("res://scenes/cookie_eyes.gd")
const OBSTACLE_HOP = preload("res://scenes/obstacle_hop.gd")

@export var is_controlled := false
@export var separate_eyes := false
@export var can_hop_obstacles := false
var hop_bodies: Array[RID] = []
var support_bodies: Array[RID] = []
var bridge_cookie: CharacterBody2D
var eyes
var roll_direction := Vector2.ZERO
var roll_distance := 0.0
var roll_travel := 0.0
var roll_start := Vector2.ZERO
var roll_horizontal := false
var face_flipped := false
var footprint := Vector2.ONE
var axes_swapped := false
var roll_shadow: Polygon2D
var is_launched := false
var launch_pending := false
var is_flinging := false
var fling_elapsed := 0.0
var fling_direction := Vector2.ZERO
var fling_distance := 0.0
var fling_released := false
const FLING_DURATION := 0.36
const FLING_RELEASE := 0.45
var launch_handler: Callable
var movement_blocked_handler: Callable
var obstacle_action_handler: Callable
var is_struggling := false
var struggle_elapsed := 0.0
var struggle_direction := Vector2.ZERO
const STRUGGLE_DURATION := 0.3
var active_launch_target: CharacterBody2D
var launch_input_consumed := false
@onready var resting_scale: Vector2 = $Sprite2D.scale
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Ignore transparent margins and account for either sprite orientation.
	var visible_rect := sprite.texture.get_image().get_used_rect()
	var visible_size := Vector2(visible_rect.size) * resting_scale
	# Flip around the visible cookie center, not transparent sheet padding.
	sprite.region_enabled = true
	sprite.region_rect = Rect2(visible_rect)
	sprite.position = Vector2.ZERO
	axes_swapped = absf(sin(sprite.rotation)) > 0.707
	footprint = Vector2(visible_size.y, visible_size.x) if axes_swapped else visible_size
	position = grid_position(position)
	roll_shadow = Polygon2D.new()
	roll_shadow.name = "RollShadow"
	roll_shadow.z_index = -1
	roll_shadow.color = Color(0.12, 0.06, 0.02, 0.22)
	var outline := PackedVector2Array()
	for i in range(32):
		var angle := TAU * i / 32.0
		outline.append(Vector2(cos(angle), sin(angle)) * footprint * 0.46)
	roll_shadow.polygon = outline
	roll_shadow.visible = false
	add_child(roll_shadow)
	if separate_eyes:
		eyes = COOKIE_EYES.new()
		eyes.name = "Eyes"
		add_child(eyes)
		jump_started.connect(eyes.begin_flip)
		landed.connect(eyes.settle)


func grid_position(value: Vector2) -> Vector2:
	var cell_footprint := (footprint / GRID_SIZE).round().max(Vector2.ONE)
	var offset := Vector2(fmod(cell_footprint.x, 2.0), fmod(cell_footprint.y, 2.0)) * GRID_SIZE * 0.5
	return ((value - offset) / GRID_SIZE).round() * GRID_SIZE + offset


func _cardinal_direction(value: Vector2) -> Vector2:
	if absf(value.x) >= absf(value.y):
		return Vector2(signf(value.x), 0)
	return Vector2(0, signf(value.y))


func toggle_flip_h() -> void:
	if eyes:
		eyes.mirror(true)
	if axes_swapped:
		sprite.flip_v = not sprite.flip_v
	else:
		sprite.flip_h = not sprite.flip_h


func toggle_flip_v() -> void:
	if eyes:
		eyes.mirror(false)
	if axes_swapped:
		sprite.flip_h = not sprite.flip_h
	else:
		sprite.flip_v = not sprite.flip_v


func _physics_process(delta: float) -> void:
	if is_struggling:
		advance_struggle(delta)
		return
	# The wind-up and release finish even if the player switches cookies.
	if is_flinging:
		advance_fling(delta)
		return
	if launch_pending:
		velocity = Vector2.ZERO
		return
	if not is_controlled and not is_launched and roll_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if not is_controlled:
		input_dir = Vector2.ZERO
	input_dir = _cardinal_direction(input_dir)

	# A throw consumes the current movement press. Holding it must not make
	# the launcher walk after the passenger lands.
	if launch_input_consumed and roll_direction == Vector2.ZERO:
		if input_dir == Vector2.ZERO:
			launch_input_consumed = false
		else:
			velocity = Vector2.ZERO
			return
	if is_instance_valid(active_launch_target) and active_launch_target.is_launched:
		velocity = Vector2.ZERO
		return

	if roll_direction == Vector2.ZERO:
		if input_dir == Vector2.ZERO:
			velocity = Vector2.ZERO
			return
		if movement_blocked_handler.is_valid() and movement_blocked_handler.call():
			is_struggling = true
			struggle_elapsed = 0.0
			struggle_direction = input_dir.normalized()
			launch_input_consumed = true
			velocity = Vector2.ZERO
			struggle_started.emit()
			return
		if launch_handler.is_valid() and launch_handler.call(input_dir.normalized()):
			launch_input_consumed = true
			velocity = Vector2.ZERO
			return
		if obstacle_action_handler.is_valid() and obstacle_action_handler.call(input_dir):
			launch_input_consumed = true
			velocity = Vector2.ZERO
			return
		roll_direction = input_dir.normalized()
		roll_horizontal = absf(roll_direction.x) >= absf(roll_direction.y)
		# One flip covers the cookie's extent along its direction of travel.
		roll_distance = maxf(GRID_SIZE, roundf(footprint.dot(roll_direction.abs()) / GRID_SIZE) * GRID_SIZE)
		if can_hop_obstacles:
			if footprint.dot(roll_direction.abs()) > GRID_SIZE + 0.1 or OBSTACLE_HOP.short_axis_has_clear_cell(self, roll_direction, roll_distance):
				_prepare_obstacle_hop(true)
		else:
			_prepare_bridge_crossing()
		roll_travel = 0.0
		roll_start = position
		face_flipped = false
		jump_started.emit()

	# Finish the current flip even when the movement key is released.
	velocity = roll_direction * minf(SPEED, (roll_distance - roll_travel) / delta)
	var before := position
	var collision := move_and_collide(velocity * delta)
	var forward_travel := maxf(0.0, (position - before).dot(roll_direction))
	roll_travel += forward_travel
	var progress := clampf(roll_travel / roll_distance, 0.0, 1.0)
	if progress >= 0.5 and not face_flipped:
		if roll_horizontal:
			toggle_flip_h()
		else:
			toggle_flip_v()
		face_flipped = true
	var angle := progress * PI
	# Keep the near edge planted during the first half, then land beyond it.
	var projected_progress := (1.0 - cos(angle)) * 0.5
	var ground_offset := roll_direction * roll_distance * (projected_progress - progress)
	var lift := sin(angle) * minf(44.0 if is_launched else 28.0, roll_distance * (0.34 if is_launched else 0.22))
	sprite.position = ground_offset + Vector2(0, -lift)
	roll_shadow.position = ground_offset + Vector2(0, 5)
	roll_shadow.scale = Vector2.ONE * (1.0 - sin(angle) * 0.12)
	roll_shadow.visible = true
	# Retain a visible edge at the apex instead of collapsing to one pixel.
	var squash := maxf(0.10, absf(cos(angle)))
	var squash_local_x := roll_horizontal != axes_swapped
	sprite.scale = resting_scale * (Vector2(squash, 1) if squash_local_x else Vector2(1, squash))
	# Finish on a grid anchor. A blocked jump returns to its last fully
	# reached tile instead of leaving the cookie between tiles at the wall.
	if roll_travel >= roll_distance - 0.001 or collision != null or forward_travel < 0.0001:
		var completed_distance := roll_distance if roll_travel >= roll_distance - 0.001 else floorf((roll_travel + 0.001) / GRID_SIZE) * GRID_SIZE
		position = roll_start + roll_direction * completed_distance
		roll_direction = Vector2.ZERO
		is_launched = false
		_clear_obstacle_hop()
		sprite.scale = resting_scale
		sprite.position = Vector2.ZERO
		roll_shadow.visible = false
		velocity = Vector2.ZERO
		landed.emit()


func flip_into_vacated_cell(direction: Vector2) -> void:
	roll_direction = direction
	roll_distance = GRID_SIZE
	roll_horizontal = absf(direction.x) > 0.5
	roll_start = position
	roll_travel = 0.0
	face_flipped = false
	jump_started.emit()


func _prepare_obstacle_hop(allow_landing_on_tile: bool) -> void:
	var hop: Dictionary = OBSTACLE_HOP.plan(self, roll_direction, roll_distance, allow_landing_on_tile)
	if hop.is_empty():
		return
	roll_distance = hop.distance
	hop_bodies.assign(hop.bodies)
	for body in hop_bodies:
		PhysicsServer2D.body_add_collision_exception(get_rid(), body)


func _prepare_bridge_crossing() -> void:
	if not is_instance_valid(bridge_cookie) or bridge_cookie.roll_direction != Vector2.ZERO or bridge_cookie.is_flinging:
		return
	# Only the tiles actually supporting the big cookie become traversable.
	hop_bodies.assign(bridge_cookie.support_bodies)
	for body in hop_bodies:
		PhysicsServer2D.body_add_collision_exception(get_rid(), body)


func _clear_obstacle_hop() -> void:
	var overlaps: Array[RID] = OBSTACLE_HOP.overlapping_bodies(self)
	var retained: Array[RID] = []
	var candidates: Array[RID] = support_bodies.duplicate()
	for body in hop_bodies:
		if body not in candidates:
			candidates.append(body)
	for body in candidates:
		var supported: bool = can_hop_obstacles or (is_instance_valid(bridge_cookie) and body in bridge_cookie.support_bodies)
		if body in overlaps and supported:
			retained.append(body)
		else:
			PhysicsServer2D.body_remove_collision_exception(get_rid(), body)
	support_bodies = retained
	hop_bodies.clear()


func advance_struggle(delta: float) -> void:
	# Rock under the weight without moving the body or changing the stack.
	velocity = Vector2.ZERO
	struggle_elapsed += delta
	var progress := minf(struggle_elapsed / STRUGGLE_DURATION, 1.0)
	var effort := sin(progress * PI) if progress < 1.0 else 0.0
	# Bulge beyond the upper cookie's edges so the trapped cookie is visible.
	sprite.scale = resting_scale * (1.0 + 0.11 * effort)
	sprite.position = struggle_direction * (4.0 * effort)
	struggle_progress.emit(effort)
	if progress >= 1.0:
		is_struggling = false
		sprite.scale = resting_scale
		sprite.position = Vector2.ZERO


func launch_flip(direction: Vector2, distance: float) -> void:
	launch_pending = false
	is_launched = true
	roll_direction = _cardinal_direction(direction)
	roll_horizontal = absf(roll_direction.x) >= absf(roll_direction.y)
	roll_distance = maxf(GRID_SIZE, roundf(distance / GRID_SIZE) * GRID_SIZE)
	_prepare_catapult_flight()
	roll_travel = 0.0
	roll_start = position
	face_flipped = false
	jump_started.emit()


func _prepare_catapult_flight() -> void:
	if not test_move(global_transform, roll_direction * roll_distance) and OBSTACLE_HOP.overlapping_bodies(self).is_empty():
		return
	# Extend a short throw only as needed to land beyond a two-tile obstacle.
	# Existing support under the launcher is excluded from obstacle depth.
	var maximum := maxf(roll_distance, GRID_SIZE * 3.0)
	if is_instance_valid(bridge_cookie):
		var launcher_remaining: float = (bridge_cookie.global_position - global_position).dot(roll_direction)
		launcher_remaining += (bridge_cookie.footprint - footprint).dot(roll_direction.abs()) * 0.5
		maximum += ceilf(maxf(launcher_remaining, 0.0) / GRID_SIZE) * GRID_SIZE
	var candidate := roll_distance
	while candidate <= maximum:
		var flight: Dictionary = OBSTACLE_HOP.plan(self, roll_direction, candidate, false, 2)
		if not flight.is_empty():
			roll_distance = flight.distance
			hop_bodies.assign(flight.bodies)
			for body in hop_bodies:
				PhysicsServer2D.body_add_collision_exception(get_rid(), body)
			return
		candidate += GRID_SIZE


func begin_fling(passenger: CharacterBody2D, direction: Vector2, distance: float) -> void:
	active_launch_target = passenger
	passenger.launch_pending = true
	fling_direction = direction.normalized()
	fling_distance = distance
	fling_elapsed = 0.0
	fling_released = false
	is_flinging = true
	velocity = Vector2.ZERO


func advance_fling(delta: float) -> void:
	velocity = Vector2.ZERO
	fling_elapsed += delta
	var progress := minf(fling_elapsed / FLING_DURATION, 1.0)
	# Rock up around the leading edge, release at the peak, then settle back.
	var tilt := sin(progress * PI) * 1.05
	var squeeze := cos(tilt)
	var horizontal := absf(fling_direction.x) >= absf(fling_direction.y)
	var local_x := horizontal != axes_swapped
	var extent := footprint.dot(fling_direction.abs())
	sprite.scale = resting_scale * (Vector2(squeeze, 1) if local_x else Vector2(1, squeeze))
	sprite.position = fling_direction * extent * 0.5 * (1.0 - squeeze) + Vector2(0, -sin(tilt) * 18.0)
	roll_shadow.position = Vector2(0,5)
	roll_shadow.scale = Vector2.ONE
	roll_shadow.visible = true
	if progress >= FLING_RELEASE and not fling_released:
		fling_released = true
		if is_instance_valid(active_launch_target):
			active_launch_target.launch_flip(fling_direction, fling_distance)
	if progress >= 1.0:
		is_flinging = false
		sprite.position = Vector2.ZERO
		sprite.scale = resting_scale
		roll_shadow.visible = false
