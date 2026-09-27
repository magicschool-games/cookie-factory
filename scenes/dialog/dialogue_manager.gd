extends Node

signal dialogue_started(dialogue_id: String)
signal line_started(line: Dictionary)
signal line_finished(line: Dictionary)
signal dialogue_finished(dialogue_id: String, interrupted: bool)

enum Priority { IDLE, CONTEXT, EXCHANGE, CRITICAL, STORY }
const SOURCE := "res://scenes/dialog/dialogues_structured.json"
const CONFIG_PATH := "res://scenes/dialog/dialogue_config.cfg"
const BUBBLE = preload("res://scenes/dialog/dialog_bubble.tscn")

var data: Dictionary = {}
var config: Dictionary = {}
var tuning := ConfigFile.new()
var lines_by_id: Dictionary = {}
var speakers: Dictionary = {}
var bubbles: Dictionary = {}
var last_used: Dictionary = {}
var last_by_speaker: Dictionary = {}
var last_line_id := ""
var clock := 0.0
var next_allowed := 0.0
var active := false
var priority := Priority.IDLE
var conversation_id := ""
var current_line: Dictionary = {}
var queue: Array[Dictionary] = []
var remaining := 0.0
var skippable := false
var rng := RandomNumberGenerator.new()
var voice: AudioStreamPlayer
var voice_fade: Tween
var story_sequence_owner: WeakRef
var screen_bubble: DialogBubble
var advance_hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	voice = AudioStreamPlayer.new()
	add_child(voice)
	var screen_layer := CanvasLayer.new()
	screen_layer.layer = 30
	add_child(screen_layer)
	screen_bubble = BUBBLE.instantiate()
	screen_bubble.screen_narration = true
	screen_layer.add_child(screen_bubble)
	advance_hint = Label.new()
	advance_hint.text = "Enter: next / skip line    Esc: skip story"
	advance_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	advance_hint.add_theme_font_size_override("font_size", 18)
	advance_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	advance_hint.add_theme_constant_override("shadow_offset_x", 2)
	advance_hint.add_theme_constant_override("shadow_offset_y", 2)
	screen_layer.add_child(advance_hint)
	get_viewport().size_changed.connect(_update_advance_hint)
	_update_advance_hint()
	var config_error := tuning.load(CONFIG_PATH)
	if config_error != OK:
		push_warning("Dialogue tuning unavailable; using defaults: " + error_string(config_error))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary:
		push_error("Dialogue source must contain a JSON object: " + SOURCE)
		return
	data = parsed
	var random_data: Dictionary = data.get("random_dialogue", {})
	config = random_data.get("config", {}).duplicate(true)
	for key in ["global_cooldown_seconds", "same_line_cooldown_seconds", "prevent_immediate_repeat", "reply_chance"]:
		if tuning.has_section_key("random", key):
			config[key] = tuning.get_value("random", key)
	config["global_cooldown_seconds"] = maxf(0, float(config.get("global_cooldown_seconds", 8.0)))
	config["same_line_cooldown_seconds"] = maxf(0, float(config.get("same_line_cooldown_seconds", 45.0)))
	config["reply_chance"] = clampf(float(config.get("reply_chance", 0.35)), 0, 1)
	var pools: Dictionary = random_data.get("pools", {})
	for speaker_id: String in pools:
		for entry: Dictionary in pools[speaker_id]:
			var line := entry.duplicate(true)
			line["speaker"] = speaker_id
			lines_by_id[str(line.id)] = line


func setting(section: String, key: String, fallback: Variant) -> Variant:
	return tuning.get_value(section, key, fallback)


func register_speaker(speaker_id: String, node: Node2D) -> void:
	if get_speaker(speaker_id) == node:
		return
	if speakers.has(speaker_id):
		unregister_speaker(speaker_id)
	speakers[speaker_id] = weakref(node)
	# Canvas-space presentation stays readable at either camera's zoom.
	var layer := CanvasLayer.new()
	layer.name = "DialogueOverlay"
	layer.layer = 20
	node.add_child(layer)
	var bubble = BUBBLE.instantiate()
	layer.add_child(bubble)
	bubble.follow_target = node
	bubbles[speaker_id] = bubble
	node.tree_exiting.connect(_speaker_exiting.bind(speaker_id, node.get_instance_id()), CONNECT_ONE_SHOT)


func get_speaker(speaker_id: String) -> Node2D:
	var ref: WeakRef = speakers.get(speaker_id)
	return ref.get_ref() as Node2D if ref != null else null


func _speaker_exiting(speaker_id: String, instance_id: int) -> void:
	var speaker := get_speaker(speaker_id)
	if is_instance_valid(speaker) and speaker.get_instance_id() == instance_id:
		unregister_speaker(speaker_id)


func unregister_speaker(speaker_id: String) -> void:
	stop_dialogue()
	var bubble = bubbles.get(speaker_id)
	if is_instance_valid(bubble):
		bubble.get_parent().queue_free()
	bubbles.erase(speaker_id)
	speakers.erase(speaker_id)


func _eligible(line: Dictionary) -> bool:
	var id := str(line.get("id", ""))
	var speaker_id := str(line.get("speaker", ""))
	if not is_instance_valid(get_speaker(speaker_id)):
		return false
	if float(line.get("weight", 1.0)) <= 0:
		return false
	if clock - float(last_used.get(id, -INF)) < float(config.get("same_line_cooldown_seconds", 45.0)):
		return false
	if config.get("prevent_immediate_repeat", true) and (id == last_line_id or id == last_by_speaker.get(speaker_id, "")):
		return false
	return true


func _weighted(entries: Array) -> Dictionary:
	var total := 0.0
	for entry: Dictionary in entries:
		total += maxf(0.0, float(entry.get("weight", 1.0)))
	if total <= 0:
		return {}
	var draw := rng.randf() * total
	for entry: Dictionary in entries:
		draw -= maxf(0.0, float(entry.get("weight", 1.0)))
		if draw < 0:
			return entry
	return entries.back()


func _context_priority(context: String) -> int:
	if context in ["danger", "near_hazard", "needs_big_cookie"]:
		return Priority.CRITICAL
	return Priority.IDLE if context == "idle" else Priority.CONTEXT


func _can_start(value: int) -> bool:
	if value < Priority.STORY and story_sequence_owner != null and is_instance_valid(story_sequence_owner.get_ref()):
		return false
	if speakers.is_empty():
		return false
	if active:
		# Let the whole conversation (including replies) finish. Movement or
		# puzzle events must never replace a line that is already playing.
		return false
	return value == Priority.STORY or clock >= next_allowed


func request_bark(speaker_id: String, context: String) -> bool:
	var value := _context_priority(context)
	if not _can_start(value):
		return false
	var candidates: Array = []
	for line: Dictionary in lines_by_id.values():
		if line.speaker == speaker_id and context in line.get("contexts", []) and _eligible(line):
			candidates.append(line)
	var selected := _weighted(candidates)
	if selected.is_empty():
		return false
	var sequence: Array[Dictionary] = [selected]
	if rng.randf() < float(selected.get("reply_chance", config.get("reply_chance", 0.35))):
		var replies: Array = []
		for reply_id: String in selected.get("reply_candidates", []):
			var reply: Dictionary = lines_by_id.get(reply_id, {})
			if not reply.is_empty() and reply.speaker != speaker_id and _eligible(reply):
				replies.append(reply)
		var reply := _weighted(replies)
		if not reply.is_empty():
			sequence.append(reply)
	_start(str(selected.id), sequence, value)
	return true


func _exchange_lines(exchange: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in exchange.get("sequence", []):
		var line: Dictionary = lines_by_id.get(id, {})
		if line.is_empty() or not _eligible(line):
			return []
		result.append(line)
	return result


func play_exchange(id: String, value: int = Priority.EXCHANGE) -> bool:
	if not _can_start(value):
		return false
	for exchange: Dictionary in data.get("random_dialogue", {}).get("exchanges", []):
		if exchange.id == id:
			var sequence := _exchange_lines(exchange)
			if sequence.is_empty():
				return false
			_start(id, sequence, value)
			return true
	return false


func request_exchange(context: String) -> bool:
	var value := maxi(Priority.EXCHANGE, _context_priority(context))
	if not _can_start(value):
		return false
	var candidates: Array = []
	for exchange: Dictionary in data.get("random_dialogue", {}).get("exchanges", []):
		if context in exchange.get("contexts", []) and not _exchange_lines(exchange).is_empty():
			candidates.append(exchange)
	var selected := _weighted(candidates)
	return play_exchange(str(selected.id), value) if not selected.is_empty() else false


func play_story(id: String) -> bool:
	var story: Dictionary = data.get("story_dialogue", {}).get(id, {})
	if story.is_empty() or not _can_start(Priority.STORY):
		return false
	var sequence: Array[Dictionary] = []
	sequence.assign(story.get("lines", []))
	if sequence.is_empty():
		return false
	_start(id, sequence, Priority.STORY, bool(story.get("skippable", false)))
	return true


func begin_story_sequence(owner_node: Node) -> void:
	stop_dialogue()
	story_sequence_owner = weakref(owner_node)
	_update_advance_hint()


func end_story_sequence(owner_node: Node) -> void:
	if story_sequence_owner != null and story_sequence_owner.get_ref() == owner_node:
		story_sequence_owner = null
		_update_advance_hint()


func play_line(id: String) -> bool:
	if not _can_start(Priority.STORY):
		return false
	var line: Dictionary = lines_by_id.get(id, {})
	if line.is_empty():
		# Check story lines too
		for story in data.get("story_dialogue", {}).values():
			for l in story.get("lines", []):
				if l.get("id") == id:
					line = l
					break
			if not line.is_empty(): break

	if line.is_empty():
		return false

	var sequence: Array[Dictionary] = [line]
	_start(id, sequence, Priority.STORY, true)
	return true


func _start(id: String, sequence: Array[Dictionary], value: int, allow_skip: bool = false) -> void:
	stop_dialogue()
	active = true
	conversation_id = id
	priority = value as Priority
	skippable = allow_skip
	_update_advance_hint()
	queue.assign(sequence)
	dialogue_started.emit(id)
	_show_next()


func _show_next() -> void:
	if queue.is_empty():
		_finish(false)
		return
	current_line = queue.pop_front()
	var speaker_id := str(current_line.get("speaker", "narrator"))
	var bubble = bubbles.get(speaker_id)
	var actor := get_speaker(speaker_id)
	if speaker_id in ["narrator", "chorus"] or not is_instance_valid(actor) or not actor.is_visible_in_tree():
		actor = null
		bubble = screen_bubble
	if not is_instance_valid(bubble):
		stop_dialogue()
		return
	bubble.follow_target = actor
	var story: Dictionary = data.get("story_dialogue", {}).get(conversation_id, {})
	bubble.center_narration = str(current_line.get("screen_position", story.get("screen_position", "top"))) == "center"
	var characters: Dictionary = data.get("characters", {})
	var display_name := str(characters.get(speaker_id, {}).get("display_name", speaker_id.capitalize()))
	var message := str(current_line.get("text", ""))
	bubble.open_line(message, display_name, priority == Priority.STORY and skippable)
	var minimum := maxf(0.1, float(setting("bubble", "min_duration", 2.5)))
	var maximum := maxf(minimum, float(setting("bubble", "max_duration", 12.0)))
	remaining = clampf(float(setting("bubble", "base_duration", 1.5)) + message.length() * maxf(0, float(setting("bubble", "seconds_per_character", 0.055))), minimum, maximum)
	_reset_voice_fade()
	voice.stop()
	var audio_path := str(current_line.get("audio", ""))
	if not audio_path.is_empty():
		if not audio_path.begins_with("res://"):
			audio_path = "res://" + audio_path
		if ResourceLoader.exists(audio_path):
			var stream := load(audio_path) as AudioStream
			if stream != null:
				voice.stream = stream
				voice.play()
	var id := str(current_line.get("id", ""))
	last_used[id] = clock
	last_line_id = id
	last_by_speaker[speaker_id] = id
	if is_instance_valid(actor):
		var eyes := actor.get_node_or_null("Eyes")
		if eyes != null and eyes.has_method("set_dialogue_expression"):
			eyes.set_dialogue_expression(str(current_line.get("expression", "neutral")))
	line_started.emit(current_line.duplicate(true))


func _process(delta: float) -> void:
	clock += delta
	if not active:
		return
	remaining -= delta
	if remaining > 0.0 or voice.playing:
		return
	if current_line.is_empty():
		_show_next()
	else:
		_end_line()
		if queue.is_empty():
			_finish(false)
		else:
			remaining = maxf(0, float(setting("bubble", "line_gap", 0.35)))


func fade_line_voice(line_id: String, duration: float = 1.1, target_db: float = -30.0) -> void:
	if str(current_line.get("id", "")) != line_id or not voice.playing:
		return
	if voice_fade != null:
		voice_fade.kill()
	voice_fade = create_tween()
	voice_fade.tween_property(voice, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_voice_fade() -> void:
	if voice_fade != null:
		voice_fade.kill()
		voice_fade = null
	voice.volume_db = 0.0


func _end_line() -> void:
	voice.stop()
	_reset_voice_fade()
	voice.stream = null
	screen_bubble.close_dialog()
	var actor := get_speaker(str(current_line.get("speaker", "")))
	if is_instance_valid(actor):
		var eyes := actor.get_node_or_null("Eyes")
		if eyes != null and eyes.has_method("clear_dialogue_expression"):
			eyes.clear_dialogue_expression()
	for bubble in bubbles.values():
		if is_instance_valid(bubble):
			bubble.close_dialog()
	if not current_line.is_empty():
		var ended := current_line
		current_line = {}
		line_finished.emit(ended)


func _finish(interrupted: bool) -> void:
	var ended := conversation_id
	_end_line()
	active = false
	queue.clear()
	conversation_id = ""
	_update_advance_hint()
	next_allowed = clock + float(config.get("global_cooldown_seconds", 8.0))
	dialogue_finished.emit(ended, interrupted)


func stop_dialogue() -> void:
	if active:
		_finish(true)


func skip_line() -> void:
	if active and priority == Priority.STORY and skippable:
		_end_line()
		_show_next()


func _update_advance_hint() -> void:
	if advance_hint == null:
		return
	var in_sequence := story_sequence_owner != null and is_instance_valid(story_sequence_owner.get_ref())
	advance_hint.visible = in_sequence or (active and priority == Priority.STORY and skippable)
	advance_hint.reset_size()
	advance_hint.position = get_viewport().get_visible_rect().size - advance_hint.size - Vector2(24, 20)


func _unhandled_key_input(event: InputEvent) -> void:
	if not active or priority != Priority.STORY or not skippable:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
			skip_line()
		elif event.physical_keycode == KEY_ESCAPE:
			stop_dialogue()
		else:
			return
		get_viewport().set_input_as_handled()
