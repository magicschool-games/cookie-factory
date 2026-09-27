extends Control


func _enter_tree() -> void:
	# Keep World on the editor canvas so the full tilemap can be edited.
	# At runtime, place it in the gameplay viewport above the hints footer.
	var world := get_node("World")
	remove_child(world)
	get_node("Layout/GameContainer/GameViewport").add_child(world)
