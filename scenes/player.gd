extends CharacterBody2D

signal jump_started
signal landed

const SPEED = 300.0

@export var is_controlled := false
var roll_direction := Vector2.ZERO
var roll_distance := 0.0
var roll_travel := 0.0
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


func toggle_flip_h() -> void:
	if axes_swapped:
		sprite.flip_v = not sprite.flip_v
	else:
		sprite.flip_h = not sprite.flip_h


func toggle_flip_v() -> void:
	if axes_swapped:
		sprite.flip_h = not sprite.flip_h
	else:
		sprite.flip_v = not sprite.flip_v


func _physics_process(delta: float) -> void:
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

	# A throw consumes the current movement press. Holding it must not make
	# the launcher walk after the passenger lands.
	if launch_input_consumed:
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
		if launch_handler.is_valid() and launch_handler.call(input_dir.normalized()):
			launch_input_consumed = true
			velocity = Vector2.ZERO
			return
		roll_direction = input_dir.normalized()
		roll_horizontal = absf(roll_direction.x) >= absf(roll_direction.y)
		# One flip covers the cookie's extent along its direction of travel.
		roll_distance = footprint.dot(roll_direction.abs())
		roll_travel = 0.0
		face_flipped = false
		jump_started.emit()

	# Finish the current flip even when the movement key is released.
	velocity = roll_direction * minf(SPEED, (roll_distance - roll_travel) / delta)
	var before := position
	move_and_slide()
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
	# Wall contact can still allow sliding; only cancel when actually blocked.
	if roll_travel >= roll_distance - 0.001 or forward_travel < 0.0001:
		roll_direction = Vector2.ZERO
		is_launched = false
		sprite.scale = resting_scale
		sprite.position = Vector2.ZERO
		roll_shadow.visible = false
		velocity = Vector2.ZERO
		landed.emit()


func launch_flip(direction: Vector2, distance: float) -> void:
	launch_pending = false
	is_launched = true
	roll_direction = direction.normalized()
	roll_horizontal = absf(roll_direction.x) >= absf(roll_direction.y)
	roll_distance = distance
	roll_travel = 0.0
	face_flipped = false
	jump_started.emit()


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
