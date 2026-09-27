extends Node2D

const SLIDE_DURATION := 0.6
const EYE_COLOR := Color("321407")
enum Mood { NEUTRAL, HAPPY, THRILLED, ANGRY, SURPRISED, BLINK, WORRIED, SKEPTICAL }
const DIALOGUE_MOODS := {
	"neutral": Mood.NEUTRAL, "happy": Mood.HAPPY, "smile": Mood.HAPPY,
	"thrilled": Mood.THRILLED, "angry": Mood.ANGRY, "surprised": Mood.SURPRISED,
	"worried": Mood.WORRIED, "skeptical": Mood.SKEPTICAL,
}
const PATTERNS := {
	Mood.NEUTRAL: ["00000", "01110", "01110", "01110", "01110", "01110", "00000"],
	Mood.HAPPY: ["00000", "00000", "01110", "11011", "10001", "00000", "00000"],
	Mood.THRILLED: ["00000", "00100", "01110", "11111", "01110", "00100", "00000"],
	Mood.ANGRY: ["11000", "01100", "00110", "00000", "01110", "01110", "01110"],
	Mood.SURPRISED: ["01110", "11011", "10001", "10001", "10001", "11011", "01110"],
	Mood.BLINK: ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	Mood.WORRIED: ["00011", "00110", "00000", "01110", "01110", "01110", "00000"],
	Mood.SKEPTICAL: ["00000", "11111", "00000", "01110", "01110", "00000", "00000"],
}

var cookie
var home := Vector2.ZERO
var eye_offset := Vector2.ZERO
var slide_from := Vector2.ZERO
var slide_elapsed := 0.0
var sliding := false
var pixel_size := 1.0
var eye_spacing := 12.0
var expression := Mood.NEUTRAL
var expression_elapsed := 0.0
var expression_remaining := 0.0
var blink_remaining := 3.2
var launched_flip := false
var dialogue_mood := -1


func _ready() -> void:
	cookie = get_parent()
	home = (cookie.footprint * Vector2(0.10, 0.10)).round()
	eye_offset = home
	if cookie.footprint.x > 96.0:
		pixel_size = 2.0
		eye_spacing = 20.0
		blink_remaining = 4.1
	cookie.struggle_started.connect(play_expression.bind(Mood.ANGRY, 0.7))
	queue_redraw()


func begin_flip() -> void:
	# A new jump takes the eyes along from wherever the last slide reached.
	sliding = false
	launched_flip = cookie.is_launched
	play_expression(Mood.HAPPY if cookie.is_launched else Mood.NEUTRAL)


func mirror(horizontal: bool) -> void:
	if horizontal:
		eye_offset.x = -eye_offset.x
	else:
		eye_offset.y = -eye_offset.y
	queue_redraw()


func settle() -> void:
	slide_from = eye_offset
	slide_elapsed = 0.0
	sliding = true
	if launched_flip:
		play_expression(Mood.HAPPY, 0.8)
	else:
		play_expression(Mood.NEUTRAL)
	launched_flip = false


func play_expression(value: Mood, duration: float = 0.0) -> void:
	expression = value
	expression_elapsed = 0.0
	expression_remaining = duration
	queue_redraw()


func set_dialogue_expression(mood_name: String) -> void:
	dialogue_mood = DIALOGUE_MOODS.get(mood_name, Mood.NEUTRAL)
	_advance_expression(0.0)
	queue_redraw()


func clear_dialogue_expression() -> void:
	if dialogue_mood < 0:
		return
	dialogue_mood = -1
	play_expression(Mood.NEUTRAL)
	_advance_expression(0.0)


func _advance_expression(delta: float) -> void:
	expression_elapsed += delta
	var held_expression := -1
	if cookie.is_struggling:
		held_expression = Mood.ANGRY
	elif cookie.is_flinging or cookie.launch_pending or cookie.is_launched:
		held_expression = Mood.HAPPY
	elif is_instance_valid(cookie.active_launch_target) and cookie.active_launch_target.is_launched:
		held_expression = Mood.HAPPY
	if held_expression >= 0:
		if expression != held_expression:
			play_expression(held_expression, 0.5)
		expression_remaining = 0.8
		return
	if dialogue_mood >= 0:
		# Preserve ordinary flip/slide eyes, then resume the speaking mood.
		var wanted: int = Mood.NEUTRAL if cookie.roll_direction != Vector2.ZERO or sliding else dialogue_mood
		if expression != wanted:
			play_expression(wanted)
		return
	if expression_remaining > 0.0:
		expression_remaining = maxf(0.0, expression_remaining - delta)
		if expression_remaining == 0.0:
			play_expression(Mood.NEUTRAL)
	if expression == Mood.NEUTRAL and cookie.roll_direction == Vector2.ZERO and not sliding:
		blink_remaining -= delta
		if blink_remaining <= 0.0:
			play_expression(Mood.BLINK, 0.13)
			blink_remaining = 3.2 if pixel_size == 1.0 else 4.1


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_advance_expression(delta)
	# Follow the body's lift and squash, but keep the eyes independent of
	# Sprite2D's texture flips so they can return to the same corner.
	position = cookie.sprite.position
	var squash: Vector2 = cookie.sprite.scale / cookie.resting_scale
	scale = Vector2(squash.y, squash.x) if cookie.axes_swapped else squash
	if sliding:
		slide_elapsed = minf(slide_elapsed + delta, SLIDE_DURATION)
		var t := slide_elapsed / SLIDE_DURATION
		# A small overshoot gives the landing a soft, playful settle.
		var u := t - 1.0
		var eased := 1.0 + 2.0 * u * u * u + u * u
		eye_offset = slide_from.lerp(home, eased)
		if slide_elapsed >= SLIDE_DURATION:
			eye_offset = home
			sliding = false
	queue_redraw()


func _draw() -> void:
	var pattern: Array = PATTERNS[expression]
	var motion := Vector2.ZERO
	if expression == Mood.HAPPY or expression == Mood.THRILLED:
		motion.y = -absf(sin(expression_elapsed * 12.0)) * pixel_size
	elif expression == Mood.ANGRY:
		motion.x = sin(expression_elapsed * 30.0) * pixel_size
	for side in [-1.0, 1.0]:
		var center := eye_offset + motion + Vector2(side * eye_spacing * 0.5, 0)
		var origin := (center - Vector2(2.5, 3.5) * pixel_size).round()
		for y in range(pattern.size()):
			for x in range(5):
				var column := 4 - x if expression in [Mood.ANGRY, Mood.WORRIED] and side > 0 else x
				if pattern[y][column] == "1":
					var color := EYE_COLOR
					if expression == Mood.THRILLED and x == 2 and y == 3:
						color = Color("fff2b0")
					draw_rect(Rect2(origin + Vector2(x, y) * pixel_size, Vector2.ONE * pixel_size), color)
