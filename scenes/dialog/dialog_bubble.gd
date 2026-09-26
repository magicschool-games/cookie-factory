extends Node2D
class_name DialogBubble

@export var dialog_container: Container
@export var message_label: Label

var _tween: Tween

enum DialogPosition {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT
}

func _ready() -> void:
	hide()

func open_dialog(message: String, dialog_pos: DialogPosition = DialogPosition.BOTTOM_RIGHT):
	if _tween:
		_tween.kill()
		
	message_label.text = message
	match dialog_pos:
		DialogPosition.TOP_LEFT:
			dialog_container.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		DialogPosition.TOP_RIGHT:
			dialog_container.anchors_preset = Control.PRESET_BOTTOM_LEFT
		DialogPosition.BOTTOM_LEFT:
			dialog_container.anchors_preset = Control.PRESET_TOP_RIGHT
		DialogPosition.BOTTOM_RIGHT:
			dialog_container.anchors_preset = Control.PRESET_TOP_LEFT
	
	dialog_container.offset_bottom = 0
	dialog_container.offset_left = 0
	dialog_container.offset_right = 0
	dialog_container.offset_top = 0
	
	self.show()
	dialog_container.scale = Vector2(0, 0)
	
	_tween = create_tween()
	_tween.tween_property(dialog_container, "scale", Vector2(1, 1), 0.2)

func close_dialog():
	self.hide()
