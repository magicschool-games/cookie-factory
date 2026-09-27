extends Node
class_name CutsceneController

@export_file("*.tscn") var next_scene := ""
@export var is_final_intro := false
@export var player_node: NodePath
@export var animate_cast := true
@export var exit_story := ""

var anim_player: AnimationPlayer
var skipping := false
var waiting_line := ""
var manager: Node
var characters: Node2D
var camera: Camera2D
var actors: Array[Node2D] = []
var motion_time := 0.0
var finishing := false
var played_lines: Dictionary = {}
var pending_lines: Array[String] = []
var timeline_finished := false
var escape_sequence: Node


func _ready() -> void:
	# Both intro layouts are supported, including World reparenting into a viewport.
	characters = get_parent().find_child("Characters", true, false) as Node2D
	anim_player = get_parent().get_node_or_null("CutsceneAnimationPlayer") as AnimationPlayer
	if anim_player == null:
		anim_player = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer
	manager = get_node("/root/DialogueManager")
	escape_sequence = get_parent().get_node_or_null("IntroEscape")
	if escape_sequence != null:
		escape_sequence.finished.connect(_resume_animation)
	manager.dialogue_finished.connect(_on_dialogue_finished)
	if characters != null:
		for child in characters.get_children():
			if not child is Node2D:
				continue
			child.set_physics_process(false)
			child.set_process_input(false)
			if child.visible and child.process_mode != Node.PROCESS_MODE_DISABLED:
				actors.append(child)
				manager.register_speaker(String(child.name).to_snake_case(), child)
		# A single stage camera keeps the whole cast visible; actor cameras must not compete.
		for actor_camera in characters.get_parent().find_children("*", "Camera2D", true, false):
			actor_camera.enabled = false
		camera = Camera2D.new()
		camera.name = "CutsceneCamera"
		characters.get_parent().add_child(camera)
		_frame_cast()
		characters.get_viewport().size_changed.connect(_frame_cast)
	manager.begin_story_sequence(self)
	if anim_player != null and anim_player.has_animation("intro"):
		anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play("intro")
	else:
		push_error("Intro is missing its intro animation")


func _frame_cast() -> void:
	if actors.is_empty() or camera == null:
		return
	var bounds := Rect2(actors[0].global_position, Vector2.ZERO)
	for actor in actors:
		bounds = bounds.expand(actor.global_position)
	if is_final_intro:
		bounds = bounds.expand(characters.get_node("BigCookie").global_position + Vector2(128, 0))
	bounds = bounds.grow(192)
	var view_size := characters.get_viewport_rect().size
	camera.global_position = bounds.get_center()
	camera.zoom = Vector2.ONE * minf(2.0, minf(view_size.x / bounds.size.x, view_size.y / bounds.size.y))
	camera.make_current()
	camera.force_update_scroll()


func _process(delta: float) -> void:
	if not animate_cast or finishing:
		return
	motion_time += delta
	var singing: bool = manager.active and str(manager.current_line.get("speaker", "")) == "chorus"
	for index in range(actors.size()):
		if escape_sequence != null and actors[index] in escape_sequence.animated_actors:
			continue
		var sprite := actors[index].get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			var phase := motion_time * (6.0 if singing else 3.0) + index * 0.8
			sprite.position.y = -absf(sin(phase)) * (9.0 if singing else 3.0)


func _input(event: InputEvent) -> void:
	if finishing or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE, KEY_ENTER:
			manager.skip_line()
		KEY_ESCAPE:
			skip_cutscene()
		_:
			return
	get_viewport().set_input_as_handled()


func skip_cutscene() -> void:
	if finishing:
		return
	skipping = true
	_finish_cutscene()


func say(line_id: String) -> void:
	if finishing or played_lines.has(line_id) or line_id in pending_lines:
		return
	if not waiting_line.is_empty():
		pending_lines.append(line_id)
		return
	waiting_line = line_id
	# Resuming exactly on a method key can invoke that key again.
	played_lines[line_id] = true
	anim_player.pause()
	if not manager.play_line(line_id):
		push_warning("Intro line unavailable: " + line_id)
		waiting_line = ""
		_resume_animation.call_deferred()
	elif line_id == "story_02_007" and escape_sequence != null:
		# Start the escape with the voice, not after dialogue playback ends.
		escape_sequence.play()


func _on_dialogue_finished(id: String, _interrupted: bool) -> void:
	if finishing or id != waiting_line:
		return
	waiting_line = ""
	# Resume only after the dialogue manager has completed its state cleanup.
	_resume_animation.call_deferred()


func _resume_animation() -> void:
	if escape_sequence != null and escape_sequence.running:
		return
	if not finishing and waiting_line.is_empty() and anim_player != null:
		if not pending_lines.is_empty():
			say(pending_lines.pop_front())
			return
		if timeline_finished:
			_finish_cutscene()
			return
		anim_player.play()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"intro":
		timeline_finished = true
		# Method-track callbacks may still be deferred from the final frame.
		_complete_timeline.call_deferred()


func _complete_timeline() -> void:
	if escape_sequence != null and escape_sequence.running:
		return
	if not finishing and waiting_line.is_empty() and pending_lines.is_empty():
		_finish_cutscene()


func _finish_cutscene() -> void:
	if finishing:
		return
	finishing = true
	if escape_sequence != null:
		escape_sequence.cancel()
	manager.stop_dialogue()
	manager.end_story_sequence(self)
	if anim_player != null:
		anim_player.stop()
	if not next_scene.is_empty():
		_play_exit_story.call_deferred()
	elif is_final_intro:
		if not player_node.is_empty():
			var player := get_node_or_null(player_node)
			if player != null:
				player.set_physics_process(true)
				player.set_process_input(true)
		queue_free()


func _play_exit_story() -> void:
	if not exit_story.is_empty():
		# Retain Intro 1's stage behind the off-screen story beat.
		if characters != null:
			characters.hide()
			characters.get_parent().modulate = Color(0.65, 0.65, 0.65, 1)
		if manager.play_story(exit_story):
			await manager.dialogue_finished
	_change_scene()


func _change_scene() -> void:
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("Failed to load scene after intro: " + error_string(error))


func _exit_tree() -> void:
	if is_instance_valid(manager):
		manager.end_story_sequence(self)
