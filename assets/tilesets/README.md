# Factory TileSet

Open `scenes/floor.tscn` and select **FloorTiles** or **Props**. Paint with the
TileMap editor; its two atlas sources contain the original and extended packs.
Both layers use `factory.tres`, with native 64 × 64 cells and scale (1, 1).

The two atlas PNGs contain 149 sprites resized with nearest-neighbor filtering.
Transparent outer margins are trimmed, proportions preserved, and visible art
centered inside whole-tile footprints. Large props are 2×1, 1×2, or 2×2 tiles.
Place their upper-left cell; the texture origin handles multi-cell alignment.
Large tiles render across neighboring cells, so leave those cells free when
painting. No separate scene is needed for each sprite.

`manifest.json` maps sprite names to atlas coordinates and footprints. Original
PNGs remain in `assets/sprites` and `assets/sprites_extended`. Existing boundary
collisions remain in their own layer; these new palette tiles are visual only.

Regenerate with `godot --headless --path . --script tools/build_tilesets.gd`.
After new atlases are imported by Godot, rebuild resources if needed with
`godot --headless --path . --script tools/build_tilesets.gd -- --resources`.
