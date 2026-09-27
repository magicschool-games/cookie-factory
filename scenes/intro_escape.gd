extends Node

signal finished

var running := false
var complete := false
var animated_actors: Array[Node2D] = []
var big: Node2D
var small: Node2D
var destination := Vector2.ZERO
var tween: Tween


func _ready() -> void:
	var cast := get_parent().find_child("Characters", true, false)
	big = cast.get_node("BigCookie")
	small = cast.get_node("SmallCookie")
	destination = big.position + Vector2(128, 0)


func play() -> void:
	if running or complete:
		return
	running = true
	animated_actors.assign([big, small])
	big.get_node("Sprite2D").position = Vector2.ZERO
	small.get_node("Sprite2D").position = Vector2.ZERO
	big.get_node("Eyes").set_dialogue_expression("thrilled")
	await _jump_and_fall(big, destination)
	if not is_inside_tree():
		return
	# Hold a clearly visible reaction before the small cookie follows.
	small.get_node("Eyes").set_dialogue_expression("surprised")
	tween = create_tween()
	tween.tween_property(small, "rotation", -0.12, 0.15)
	tween.tween_property(small, "rotation", 0.08, 0.15)
	tween.tween_property(small, "rotation", 0.0, 0.15)
	tween.tween_interval(0.45)
	await tween.finished
	small.get_node("Eyes").set_dialogue_expression("thrilled")
	await _jump_and_fall(small, destination)
	running = false
	complete = true
	finished.emit()


func _jump_and_fall(actor: Node2D, target: Vector2) -> void:
	var start := actor.position
	tween = create_tween()
	tween.tween_method(_jump_pose.bind(actor, start, target), 0.0, 1.0, 0.8)
	await tween.finished
	tween = create_tween().set_parallel(true)
	tween.tween_property(actor, "scale", Vector2.ONE * 0.08, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(actor, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tween.tween_property(actor, "position:y", target.y + 18, 0.75)
	await tween.finished
	actor.hide()


func _jump_pose(progress: float, actor: Node2D, start: Vector2, target: Vector2) -> void:
	actor.position = start.lerp(target, progress) + Vector2(0, -sin(progress * PI) * 80)


func cancel() -> void:
	if tween != null:
		tween.kill()
	running = false


func _exit_tree() -> void:
	cancel()
