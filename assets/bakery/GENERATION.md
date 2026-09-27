# Source and extraction

Source: user-supplied bakery/floor sprite sheet in chat.
Tool: built-in image_gen, edit mode, for transparent background extraction.
Saved result: `source.png`. The Godot build script slices this into `cutouts/` and native-grid `tiles/`, removes extraction fringe, and packs `bakery_tiles.png`.

## Exact edit prompt

Edit the attached sprite sheet for game asset extraction. Preserve every single sprite, exact artwork, pixel colors, arrangement, and positions: the top row mixer, oven, rolling-pin prep table, yellow conveyor station with attached belt, and right-hand pipe/valve plus machine; the sixteen purple damaged floor tiles in two rows of eight; the two bottom butter-spill floor tiles. Remove ONLY the almost-black sheet backdrop in the gutters and around the outer silhouettes of the top-row machines, replacing it with genuine alpha=0 transparency. Preserve all machine outlines and interior dark parts. Preserve all rectangular floor tiles as fully opaque including their dark cracks and holes. Do not redesign, relabel, add, omit, move, or resize sprites. Keep the original 1448x1086 canvas and layout exactly. Output RGBA PNG with transparent background, no checkerboard painted into image.
