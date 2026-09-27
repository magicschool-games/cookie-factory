extends Node

@export var idle_enabled := true
@export var idle_interval := Vector2(6, 12)
var idle_retry := 1.0
var separation_enabled := true
var separation_trigger := 384.0
var separation_reset := 256.0
var separation_cooldown := 25.0
var check_interval := 0.5
var small: CharacterBody2D
var big: CharacterBody2D
var manager: Node
var idle_remaining := 10.0
var sample_remaining := 1.0
var separated := false
var separation_ready := 0.0
var flip_starts: Dictionary = {}
var launched: Dictionary = {}


func _ready() -> void:
	manager = get_node("/root/DialogueManager")
	idle_enabled = bool(manager.setting("idle", "enabled", idle_enabled))
	idle_interval.x = maxf(0.5, float(manager.setting("idle", "interval_min", idle_interval.x)))
	idle_interval.y = maxf(idle_interval.x, float(manager.setting("idle", "interval_max", idle_interval.y)))
	idle_retry = maxf(0.5, float(manager.setting("idle", "retry_delay", 1.0)))
	separation_enabled = bool(manager.setting("separation", "enabled", true))
	separation_trigger = maxf(1, float(manager.setting("separation", "trigger_distance", 384.0)))
	separation_reset = clampf(float(manager.setting("separation", "reset_distance", 256.0)), 0, separation_trigger - 1)
	separation_cooldown = maxf(0, float(manager.setting("separation", "cooldown_seconds", 25.0)))
	check_interval = maxf(0.1, float(manager.setting("separation", "check_interval", 0.5)))
	sample_remaining = check_interval
	manager.register_speaker("small_cookie", small)
	manager.register_speaker("big_cookie", big)
	var first_min := maxf(0, float(manager.setting("idle", "first_delay_min", 2.0)))
	var first_max := maxf(first_min, float(manager.setting("idle", "first_delay_max", 4.0)))
	idle_remaining = randf_range(first_min, first_max)
	small.struggle_started.connect(_needs_help)
	for cookie in [small, big]:
		cookie.jump_started.connect(_jump_started.bind(cookie))
		cookie.landed.connect(_landed.bind(cookie))


func _needs_help() -> void:
	manager.request_exchange("needs_big_cookie")


func _jump_started(cookie: CharacterBody2D) -> void:
	flip_starts[cookie] = cookie.position
	launched[cookie] = cookie.is_launched


func _landed(cookie: CharacterBody2D) -> void:
	if not flip_starts.has(cookie):
		return
	var speaker_id := "small_cookie" if cookie == small else "big_cookie"
	if bool(launched.get(cookie, false)):
		manager.request_bark(speaker_id, "after_success")
	elif cookie.position.is_equal_approx(flip_starts[cookie]):
		manager.request_bark(speaker_id, "blocked_by_obstacle")
	flip_starts.erase(cookie)
	launched.erase(cookie)


func _process(delta: float) -> void:
	if not is_instance_valid(small) or not is_instance_valid(big):
		return
	separation_ready = maxf(0, separation_ready - delta)
	sample_remaining -= delta
	if separation_enabled and sample_remaining <= 0:
		sample_remaining = check_interval
		var distance := small.global_position.distance_to(big.global_position)
		if distance <= separation_reset:
			separated = false
		elif distance > separation_trigger and not separated and separation_ready <= 0:
			if manager.request_exchange("distance_large"):
				separated = true
				separation_ready = separation_cooldown
	if not idle_enabled or manager.active:
		return
	idle_remaining -= delta
	if idle_remaining <= 0:
		var speaker_id := "small_cookie" if randf() < 0.5 else "big_cookie"
		if manager.request_bark(speaker_id, "idle"):
			idle_remaining = randf_range(idle_interval.x, idle_interval.y)
		else:
			idle_remaining = idle_retry
