@tool
extends TileMap

# --- Configuration ---

const TILESET_PATH    = "res://Assets/BoardTileSet.tres"
const TILESET_TEXTURE = "res://Assets/Assets/Assets/Tribal_Dynamics_Tileset-Sheet.png"
const TILE_SIZE       = Vector2i(16, 16)

# Toggle guide overlay from the Inspector while editing
@export var show_guides: bool = true:
	set(v):
		show_guides = v
		queue_redraw()

# --- Guide data ---
# Corner world positions matching Player Control node offsets in GameBoard.tscn.
# Each player base should be roughly centered on these points when painting your map.
const CORNER_POSITIONS = [
	Vector2(295, 98),    # Seat 1 — top-left    (Knight)
	Vector2(292, 604),   # Seat 2 — bottom-left  (Barb)
	Vector2(964, 606),   # Seat 3 — bottom-right (Snail)
	Vector2(962, 98),    # Seat 4 — top-right    (Vamp)
]

const CORNER_COLORS = [
	Color(0.2, 0.6, 1.0),   # Blue
	Color(1.0, 0.3, 0.3),   # Red
	Color(0.3, 0.9, 0.3),   # Green
	Color(1.0, 0.85, 0.2),  # Yellow
]

const CORNER_NAMES = ["Seat 1 (Knight)", "Seat 2 (Barb)", "Seat 3 (Snail)", "Seat 4 (Vamp)"]

# --- Setup ---

func _ready():
	if tile_set == null:
		tile_set = _load_or_create_tileset()

func _load_or_create_tileset() -> TileSet:
	if ResourceLoader.exists(TILESET_PATH):
		return load(TILESET_PATH)
	var ts = _build_tileset()
	if Engine.is_editor_hint():
		ResourceSaver.save(ts, TILESET_PATH)
	return ts

func _build_tileset() -> TileSet:
	var ts     = TileSet.new()
	ts.tile_size = TILE_SIZE
	var source = TileSetAtlasSource.new()
	source.texture             = load(TILESET_TEXTURE)
	source.texture_region_size = TILE_SIZE
	if source.texture:
		var tex  = source.texture.get_size()
		var cols = int(tex.x / TILE_SIZE.x)
		var rows = int(tex.y / TILE_SIZE.y)
		for col in range(cols):
			for row in range(rows):
				source.create_tile(Vector2i(col, row))
	ts.add_source(source, 0)
	return ts

# --- Guide overlay (editor only) ---
# Disable show_guides in the Inspector before running the game,
# or it will draw over the board at runtime too.

func _draw():
	if not show_guides:
		return
	_draw_road_guides()
	_draw_base_guides()

func _draw_road_guides():
	for i in range(CORNER_POSITIONS.size()):
		for j in range(i + 1, CORNER_POSITIONS.size()):
			draw_line(CORNER_POSITIONS[i], CORNER_POSITIONS[j], Color(1, 1, 1, 0.2), 4.0)

func _draw_base_guides():
	for i in range(CORNER_POSITIONS.size()):
		var center = CORNER_POSITIONS[i]
		var color  = CORNER_COLORS[i]
		var rect   = Rect2(center - Vector2(32, 32), Vector2(64, 64))
		draw_rect(rect, color * Color(1, 1, 1, 0.2), true)
		draw_rect(rect, color, false, 2.0)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-28, -36),
			CORNER_NAMES[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 1, 1, 0.9)
		)
