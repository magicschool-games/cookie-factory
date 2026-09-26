# Kenney sample

Open `scenes/sample.tscn` and press F6 to run this alternate art version of
`level1.tscn`. Select FloorTiles, Props, or Boundary to paint using
`assets/tilesets/kenney_factory.tres`.

The original Kenney atlas uses 16 × 16 pixels. Each TileMapLayer is scaled to
(4, 4), making every cell exactly 64 × 64 world pixels. Nearest-neighbor filtering
keeps the pixel art sharp. The first palette contains all 132 Kenney tiles;
three additional sources provide 2 × 2 machine variants at the original machine
footprints. Solid wall alternatives are used only by Boundary.

The sample preserves the source scene's tile coordinates, both cookie characters,
controls, and boundary collision footprint. Hazard-marked tiles substitute for
lava; fans and dark furnace openings substitute for spikes and pits. They retain
the same visual-only behavior as their source tiles.

Assets: Kenney Tiny Factory, CC0; see `assets/kenney_tiny-factory/License.txt`.
Rebuild with `godot --headless --path . --script tools/build_kenney_sample.gd`.
Rebuilding overwrites manual edits to sample.tscn.
