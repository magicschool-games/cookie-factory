extends Control


func _enter_tree() -> void:
	# Keep World on the editor canvas so the full tilemap can be edited.
	# At runtime, place it in the gameplay viewport above the hints footer.
	var world := get_node("World")
	var viewport = get_node_or_null("Layout/GameContainer/GameViewport")
	if viewport:
		remove_child(world)
		viewport.add_child(world)
