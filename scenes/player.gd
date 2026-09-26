extends CharacterBody2D

const SPEED = 300.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

func toggle_flip_h():
	sprite.flip_h = not sprite.flip_h

func toggle_flip_v():
	sprite.flip_v = not sprite.flip_v

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1

	velocity = input_dir.normalized() * SPEED
	
	# If we are moving and no flip animation is currently playing
	if input_dir != Vector2.ZERO and anim_player and not anim_player.is_playing():
		# Play the correct animation based on direction
		if input_dir.x != 0:
			anim_player.play("flip_horizontal")
		else:
			anim_player.play("flip_vertical")
			
	move_and_slide()
