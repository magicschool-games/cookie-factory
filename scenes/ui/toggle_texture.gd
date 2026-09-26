extends TextureRect

@export var texture_1: Texture2D
@export var texture_2: Texture2D
@export var toogle_time_s: float = 1.0
@export var disable_toggle: bool = false

var _timer: float
var _toggled: bool = false

func _ready() -> void:
	texture = texture_1
	_timer = 0.0
	_toggled = false
	
func _process(delta: float) -> void:
	if disable_toggle:
		return
	_timer += delta
	if _timer >= toogle_time_s:
		_toggled = !_toggled
		self.texture = texture_2 if _toggled else texture_1 
		_timer = 0.0
		
