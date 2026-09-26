extends Node2D

## Compact rooms progress to the right; room zero is the starting base.
const CELL_SIZE := 64
const ROOM_SIZE := Vector2i(24, 12)
const BASE_SPAWN := Vector2(192, 384)

var area_index := 0
@onready var player: CharacterBody2D = $Player
@onready var boundary: TileMapLayer = $Boundary
@onready var area_title: Label = $AreaTitle
@onready var entrance_label: Label = $EntranceLabel


func _ready() -> void:
	player.position = BASE_SPAWN
	update_area()


func _physics_process(_delta: float) -> void:
	# Cross the outer edge through the wall opening before changing rooms.
	if player.position.x >= ROOM_SIZE.x * CELL_SIZE:
		enter_area(area_index + 1, false)
	elif area_index > 0 and player.position.x < 0:
		enter_area(area_index - 1, true)


func enter_area(index: int, from_right: bool) -> void:
	area_index = maxi(index, 0)
	player.position = Vector2(
		(ROOM_SIZE.x - 2) * CELL_SIZE if from_right else 2 * CELL_SIZE,
		clampf(player.position.y, 4.5 * CELL_SIZE, 7.5 * CELL_SIZE)
	)
	player.velocity = Vector2.ZERO
	update_area()
	$Player/Camera2D.reset_smoothing()


func update_area() -> void:
	area_title.text = "BASE" if area_index == 0 else "FACTORY — AREA %d" % area_index
	entrance_label.text = "START" if area_index == 0 else "← PREVIOUS AREA"
	$BasePad.visible = area_index == 0
	for y in range(4, 8):
		if area_index == 0:
			boundary.set_cell(Vector2i(0, y), 0, Vector2i.ZERO, TileSetAtlasSource.TRANSFORM_TRANSPOSE)
		else:
			boundary.erase_cell(Vector2i(0, y))
