# Bakery sheet assets

24 assets extracted from the supplied sheet:

- 8 cracked floor variants and 8 broken/hole floor variants: **16 × 16 px** each.
- Butter puddle and butter smear floor tiles: **16 × 16 px** each, retaining the floor background.
- Mixer, oven, prep table, machine cabinet: **32 × 32 px**, occupying 2 × 2 tiles.
- Conveyor station: **48 × 32 px**, occupying 3 × 2 tiles.
- Pipe and valve: **16 × 32 px**, occupying 1 × 2 tiles.

`tiles/` contains the game-sized PNGs. `cutouts/` contains the larger extracted sprites. `bakery_tiles.png` is the packed atlas; `preview.png` is an enlarged nearest-neighbor preview. `manifest.json` records coordinates, sizes, and names.

## Godot

In either sample scene, select `FloorTiles` or `Props` and choose **Bakery sheet — floors and machines** in the TileSet palette (source 4). Paint floors on `FloorTiles` and machines on `Props`. Larger assets paint as one multi-cell tile from their upper-left anchor. The scene's 4× layer scale makes one 16px tile occupy 64 world pixels.

For another level, use `bakery_tileset.tres`, or add `bakery_atlas.tres` to a TileSet with the string custom-data layer `asset_name`.

All 24 assets have solid rectangular collision on physics layer 1, covering their full tile footprint, including the floor and butter tiles. Larger machine collisions align to the upper-left paint anchor. Slippery surfaces, collection, and machine behavior are not included. The damaged floor variants are individual tiles, not a configured terrain/autotile set.

Rebuild the PNGs and atlas metadata using:

```sh
godot --headless --path . --script assets/bakery/build_tiles.gd
```

Source artwork was supplied in chat; image_gen prepared transparent machine cutouts. See `GENERATION.md` for the exact edit prompt.
