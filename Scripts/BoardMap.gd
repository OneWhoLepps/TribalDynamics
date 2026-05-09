extends TileMap

# --- Tile atlas coordinates within Tribal_Dynamics_Tileset-Sheet.png ---
# Tiles are 16×16. If something looks wrong, open the sheet in Godot's
# TileSet inspector and adjust these Vector2i(column, row) values.
const TILE_GRASS = Vector2i(0, 0)   # Plain green  — background fill
const TILE_PATH  = Vector2i(0, 1)   # Brown/soil   — roads between bases
const TILE_BASE  = Vector2i(1, 0)   # Bordered green — player corner zones

const SOURCE_ID = 0

# Board size in tiles (1280 / 16 = 80 wide, 720 / 16 = 45 tall)
const BOARD_COLS = 80
const BOARD_ROWS = 45

# Tile coordinate of each player base — derived from the Control node offsets
# in GameBoard.tscn (offset_left / 16, offset_top / 16).
const BASE_POSITIONS = {
	1: Vector2i(18, 6),   # Player 1 — top-left
	2: Vector2i(18, 38),  # Player 2 — bottom-left
	3: Vector2i(60, 38),  # Player 3 — bottom-right
	4: Vector2i(60, 6),   # Player 4 — top-right
}

const BASE_RADIUS    = 3  # Tiles from center that form the base zone square
const ROAD_HALF_WIDTH = 1  # Half-width of roads; actual road = 2n+1 tiles wide

func _ready():
	_configure_tileset()
	_paint_board()

# --- TileSet ----------------------------------------------------------------

func _configure_tileset():
	var ts     = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	var source = TileSetAtlasSource.new()
	source.texture              = load("res://Assets/Assets/Assets/Tribal_Dynamics_Tileset-Sheet.png")
	source.texture_region_size  = Vector2i(16, 16)
	source.create_tile(TILE_GRASS)
	source.create_tile(TILE_PATH)
	source.create_tile(TILE_BASE)

	ts.add_source(source, SOURCE_ID)
	tile_set = ts

# --- Painting ---------------------------------------------------------------

func _paint_board():
	_fill_background()
	_draw_all_roads()
	_draw_all_bases()

func _fill_background():
	for x in range(BOARD_COLS):
		for y in range(BOARD_ROWS):
			set_cell(0, Vector2i(x, y), SOURCE_ID, TILE_GRASS)

func _draw_all_roads():
	var seats = BASE_POSITIONS.keys()
	for i in range(seats.size()):
		for j in range(i + 1, seats.size()):
			_draw_road(BASE_POSITIONS[seats[i]], BASE_POSITIONS[seats[j]])

func _draw_road(from: Vector2i, to: Vector2i):
	for point in _bresenham_line(from, to):
		for dx in range(-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 1):
			for dy in range(-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 1):
				_set_board_cell(Vector2i(point.x + dx, point.y + dy), TILE_PATH)

func _draw_all_bases():
	for seat in BASE_POSITIONS:
		_draw_base(BASE_POSITIONS[seat])

func _draw_base(center: Vector2i):
	for dx in range(-BASE_RADIUS, BASE_RADIUS + 1):
		for dy in range(-BASE_RADIUS, BASE_RADIUS + 1):
			_set_board_cell(Vector2i(center.x + dx, center.y + dy), TILE_BASE)

func _set_board_cell(pos: Vector2i, atlas_coord: Vector2i):
	if pos.x >= 0 and pos.x < BOARD_COLS and pos.y >= 0 and pos.y < BOARD_ROWS:
		set_cell(0, pos, SOURCE_ID, atlas_coord)

# --- Bresenham line ---------------------------------------------------------

func _bresenham_line(from: Vector2i, to: Vector2i) -> Array:
	var points = []
	var x0 = from.x;  var y0 = from.y
	var x1 = to.x;    var y1 = to.y
	var dx = abs(x1 - x0);  var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy;  x0 += sx
		if e2 <= dx:
			err += dx;  y0 += sy
	return points
