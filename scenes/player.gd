extends CharacterBody2D

const SPEED = 300.0

@export var is_controlled := false
var roll_direction := Vector2.ZERO
var roll_distance := 0.0
var roll_travel := 0.0
var roll_horizontal := false
var face_flipped := false
var footprint := Vector2.ONE
@onready var resting_scale: Vector2 = $Sprite2D.scale
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Ignore transparent margins and account for the upright sprite's rotation.
	var visible_size := Vector2(sprite.texture.get_image().get_used_rect().size) * resting_scale
	footprint = Vector2(visible_size.y, visible_size.x)


func toggle_flip_h() -> void:
	sprite.flip_v = not sprite.flip_v


func toggle_flip_v() -> void:
	sprite.flip_h = not sprite.flip_h


func _physics_process(delta: float) -> void:
	if not is_controlled:
		velocity = Vector2.ZERO
		return
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1

	if roll_direction == Vector2.ZERO:
		if input_dir == Vector2.ZERO:
			velocity = Vector2.ZERO
			return
		roll_direction = input_dir.normalized()
		roll_horizontal = absf(roll_direction.x) >= absf(roll_direction.y)
		# One flip covers the cookie's extent along its direction of travel.
		roll_distance = footprint.dot(roll_direction.abs())
		roll_travel = 0.0
		face_flipped = false

	# Finish the current flip even when the movement key is released.
	velocity = roll_direction * minf(SPEED, (roll_distance - roll_travel) / delta)
	var before := position
	move_and_slide()
	var forward_travel := maxf(0.0, (position - before).dot(roll_direction))
	roll_travel += forward_travel
	var progress := clampf(roll_travel / roll_distance, 0.0, 1.0)
	if progress >= 0.45 and not face_flipped:
		if roll_horizontal:
			toggle_flip_h()
		else:
			toggle_flip_v()
		face_flipped = true
	var squash := maxf(0.01, absf(cos(progress * PI)))
	sprite.scale = resting_scale * (Vector2(1, squash) if roll_horizontal else Vector2(squash, 1))
	# Wall contact can still allow sliding; only cancel when actually blocked.
	if roll_travel >= roll_distance - 0.001 or forward_travel < 0.0001:
		roll_direction = Vector2.ZERO
		sprite.scale = resting_scale
		velocity = Vector2.ZERO
