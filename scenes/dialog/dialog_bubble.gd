extends Node2D
class_name DialogBubble

@export var dialog_container: Control
@export var message_label: Label
var follow_target: Node2D
var _tween: Tween
var pop_scale := 1.0
var bubble_size := Vector2.ZERO
var screen_narration := false

enum DialogPosition { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }


func _ready() -> void:
	hide()
	if screen_narration:
		dialog_container.add_theme_stylebox_override("panel", preload("res://theme/story_panel.tres"))
		dialog_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(_resize_text)


func _resize_text() -> void:
	if visible:
		_fit_text()
		_place_bubble()


func open_line(message: String, _speaker_name: String, _show_skip: bool = false) -> void:
	open_dialog(message)


func open_dialog(message: String, _dialog_pos: DialogPosition = DialogPosition.TOP_RIGHT) -> void:
	if _tween:
		_tween.kill()
	message_label.text = message
	_fit_text()
	show()
	pop_scale = 0.0
	_place_bubble()
	_tween = create_tween()
	_tween.tween_property(self, "pop_scale", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _fit_text() -> void:
	var manager := get_node("/root/DialogueManager")
	if screen_narration:
		var width := minf(760.0, get_viewport_rect().size.x - 48.0)
		var font := message_label.get_theme_font("font")
		var height := ceilf(font.get_multiline_string_size(message_label.text, HORIZONTAL_ALIGNMENT_CENTER, width - 48, 24).y) + 4
		message_label.add_theme_font_size_override("font_size", 24)
		message_label.position = Vector2(24, 20)
		message_label.size = Vector2(width - 48, height)
		bubble_size = Vector2(width, height + 40)
		dialog_container.size = bubble_size
		dialog_container.pivot_offset = Vector2(width * 0.5, 0)
		return
	var width := clampf(float(manager.setting("bubble", "max_width_tiles", 2.75)), 1.5, 2.9) * 64.0
	var max_height := clampf(float(manager.setting("bubble", "max_height_tiles", 2.5)), 1.5, 2.7) * 64.0
	var text_width := width - 24.0
	var font := message_label.get_theme_font("font")
	var font_size := 14
	var text_height := 0.0
	var overhead := 24.0
	while true:
		text_height = ceilf(font.get_multiline_string_size(message_label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size).y) + 2
		if text_height + overhead <= max_height or font_size <= 8:
			break
		font_size -= 1
	message_label.add_theme_font_size_override("font_size", font_size)
	text_height = minf(text_height, max_height - overhead)
	# Explicit rectangles avoid wrapped-label minimum sizes feeding back into
	# a Container and leaving a huge empty panel after a previous long line.
	message_label.position = Vector2(12, 12)
	message_label.size = Vector2(text_width, text_height)
	bubble_size = Vector2(width, overhead + text_height)
	dialog_container.size = bubble_size
	dialog_container.pivot_offset = Vector2(width * 0.5, bubble_size.y)


func _process(_delta: float) -> void:
	if visible:
		_place_bubble()


func _place_bubble() -> void:
	var view_size := get_viewport_rect().size
	# Match world tiles at every camera/window zoom instead of fixed UI pixels.
	var zoom := absf(get_viewport().get_canvas_transform().get_scale().x) if is_instance_valid(follow_target) else 1.0
	zoom = minf(zoom, minf((view_size.x - 24) / bubble_size.x, (view_size.y - 32) / bubble_size.y))
	zoom = maxf(0.01, zoom)
	var size := bubble_size * zoom
	var desired := Vector2((view_size.x - size.x) * 0.5, 24 if screen_narration else 12)
	var tail := $DialogContainer/TailAnchor/Tail as TextureRect
	tail.visible = is_instance_valid(follow_target)
	if is_instance_valid(follow_target):
		var anchor := follow_target.get_global_transform_with_canvas().origin
		var sprite := follow_target.get_node_or_null("Sprite2D") as Sprite2D
		anchor.y -= 40.0 * zoom
		if sprite != null:
			var body_bounds := sprite.get_global_transform_with_canvas() * sprite.get_rect()
			anchor = Vector2(body_bounds.get_center().x, body_bounds.position.y)
		desired = anchor - Vector2(size.x * 0.5, size.y + 14 * zoom)
		desired.x = clampf(desired.x, 12, maxf(12, view_size.x - size.x - 12))
		desired.y = clampf(desired.y, 12, maxf(12, view_size.y - size.y - 14 * zoom))
		tail.position = Vector2(clampf((anchor.x - desired.x) / zoom - 8, 12, bubble_size.x - 28), bubble_size.y - 2)
	# Account for the animation pivot so final placement matches its bounds.
	dialog_container.scale = Vector2.ONE * zoom * pop_scale
	dialog_container.position = desired - dialog_container.pivot_offset * (1.0 - zoom)


func close_dialog() -> void:
	if _tween:
		_tween.kill()
	hide()
