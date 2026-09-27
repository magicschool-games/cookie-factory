extends SceneTree

func _initialize() -> void:
	var source := Image.load_from_file("res://assets/bakery/source.png")
	var atlas := Image.create(128, 112, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var entries: Array = []
	var columns := [39, 213, 388, 562, 734, 908, 1082, 1257]
	for row in range(2):
		for col in range(8):
			var name := ("floor_crack_%02d" if row == 0 else "floor_hole_%02d") % (col + 1)
			entries.append({"name": name, "rect": Rect2i(columns[col], 357 if row == 0 else 577, 152, 176 if row == 0 else 195), "coords": Vector2i(col, row), "cells": Vector2i.ONE, "floor": true})
	entries.append({"name": "floor_butter_puddle", "rect": Rect2i(40, 823, 211, 180), "coords": Vector2i(0, 2), "cells": Vector2i.ONE, "floor": true})
	entries.append({"name": "floor_butter_smear", "rect": Rect2i(293, 823, 207, 180), "coords": Vector2i(1, 2), "cells": Vector2i.ONE, "floor": true})
	var machines := [
		["dough_mixer", Rect2i(36, 84, 205, 232), Vector2i(0, 3), Vector2i(2, 2)],
		["bakery_oven", Rect2i(277, 84, 214, 231), Vector2i(2, 3), Vector2i(2, 2)],
		["prep_table", Rect2i(517, 116, 228, 206), Vector2i(4, 3), Vector2i(2, 2)],
		["conveyor_station", Rect2i(770, 148, 379, 174), Vector2i(0, 5), Vector2i(3, 2)],
		["pipe_valve", Rect2i(1178, 83, 74, 239), Vector2i(3, 5), Vector2i(1, 2)],
		["machine_cabinet", Rect2i(1253, 145, 160, 177), Vector2i(4, 5), Vector2i(2, 2)],
	]
	for machine in machines:
		entries.append({"name": machine[0], "rect": machine[1], "coords": machine[2], "cells": machine[3], "floor": false})
	var manifest: Array = []
	var resource := "[gd_resource type=\"TileSetAtlasSource\" load_steps=2 format=3]\n\n[ext_resource type=\"Texture2D\" path=\"res://assets/bakery/bakery_tiles.png\" id=\"1_texture\"]\n\n[resource]\nresource_name = \"Bakery sheet — floors and machines\"\ntexture = ExtResource(\"1_texture\")\ntexture_region_size = Vector2i(16, 16)\n"
	for entry in entries:
		var art := source.get_region(entry.rect)
		for y in range(art.get_height()):
			for x in range(art.get_width()):
				var color := art.get_pixel(x, y)
				color.a = 1.0 if entry.floor or color.a >= 0.5 else 0.0
				# Discard green/magenta fringe left by background extraction.
				if not entry.floor:
					var green_fringe := color.g > 0.15 and color.g > maxf(color.r, color.b) * 1.4
					var magenta_fringe := minf(color.r, color.b) > 0.25 and color.g < minf(color.r, color.b) * 0.5
					if green_fringe or magenta_fringe:
						color.a = 0.0
				art.set_pixel(x, y, color)
		if not entry.floor:
			art = art.get_region(art.get_used_rect())
		art.save_png("res://assets/bakery/cutouts/%s.png" % entry.name)
		var target: Vector2i = entry.cells * 16
		var output := Image.create(target.x, target.y, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		if entry.floor:
			art.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)
		else:
			var ratio := minf(float(target.x) / art.get_width(), float(target.y) / art.get_height())
			art.resize(maxi(1, roundi(art.get_width() * ratio)), maxi(1, roundi(art.get_height() * ratio)), Image.INTERPOLATE_NEAREST)
		output.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), (target - art.get_size()) / 2)
		output.save_png("res://assets/bakery/tiles/%s.png" % entry.name)
		atlas.blit_rect(output, Rect2i(Vector2i.ZERO, target), entry.coords * 16)
		var key := "%d:%d" % [entry.coords.x, entry.coords.y]
		if entry.cells != Vector2i.ONE:
			resource += "%s/size_in_atlas = Vector2i(%d, %d)\n" % [key, entry.cells.x, entry.cells.y]
		resource += "%s/0 = 0\n" % key
		if entry.cells != Vector2i.ONE:
			resource += "%s/0/texture_origin = Vector2i(%d, %d)\n" % [key, -(entry.cells.x - 1) * 8, -(entry.cells.y - 1) * 8]
		resource += "%s/0/custom_data_0 = \"bakery/%s\"\n" % [key, entry.name]
		resource += "%s/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, %d, -8, %d, %d, -8, %d)\n" % [key, target.x - 8, target.x - 8, target.y - 8, target.y - 8]
		manifest.append({"name": entry.name, "atlas_coords": [entry.coords.x, entry.coords.y], "tile_footprint": [entry.cells.x, entry.cells.y], "pixel_size": [target.x, target.y], "file": "tiles/%s.png" % entry.name})
	atlas.save_png("res://assets/bakery/bakery_tiles.png")
	atlas.resize(1024, 896, Image.INTERPOLATE_NEAREST)
	atlas.save_png("res://assets/bakery/preview.png")
	FileAccess.open("res://assets/bakery/bakery_atlas.tres", FileAccess.WRITE).store_string(resource)
	FileAccess.open("res://assets/bakery/manifest.json", FileAccess.WRITE).store_string(JSON.stringify({"tile_size": [16,16], "tiles": manifest}, "\t") + "\n")
	print("Built 24 assets with native 16px tile footprints")
	quit()
