extends Node

# World positions matching the Player Control node offsets in GameBoard.tscn
const GENERAL_POSITIONS = {
	1: Vector2(286, 86),
	2: Vector2(286, 600),
	3: Vector2(964, 606),
	4: Vector2(962, 86),
}

const GENERAL_SCALE = Vector2(2.0, 2.0)

# --- Heart display ---
# Atlas regions inside Tribal_Dynamics_UIAssets.png (8×8 px sprites)
const UI_ASSETS_PATH    = "res://Assets/Assets/Assets/Tribal_Dynamics_UIAssets.png"
const HEART_FULL_REGION  = Rect2(24, 40, 8, 8)
const HEART_EMPTY_REGION = Rect2(24, 48, 8, 8)
const HEART_SCALE        = Vector2(3.0, 3.0)  # renders each heart as 24×24 px
const HEART_SPACING      = 26                  # px between heart origins
const HEARTS_COUNT       = 5                   # hearts visible per player
const MAX_HP             = 10                  # matches GameManager.startingHealth

# Top seats: hearts above name label (name label world y ≈ 63–86)
# Bottom seats: hearts below name label (name label world y ≈ 650–673)
const HEART_ORIGINS = {
	1: Vector2(254,14),    # top-left  → extends right, above name
	2: Vector2(254, 696),   # bot-left  → extends right, below name
	3: Vector2(1000, 696),  # bot-right → extends left,  below name
	4: Vector2(1000, 14),   # top-right → extends left,  above name
}
const HEART_DIR = { 1: 1, 2: 1, 3: -1, 4: -1 }

# Ocean tile color (rgb 91,110,225) used to replace the UIAssets green background on hearts
const OCEAN_COLOR = Color(0.357, 0.431, 0.882, 1.0)
const _HEART_SHADER_CODE = "shader_type canvas_item;
uniform vec4 ocean_color : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length(c.rgb - vec3(0.294, 0.412, 0.184));
	COLOR = d < 0.12 ? ocean_color : c;
}"

var state: BoardState
var sounds: Dictionary
var heart_sprites: Dictionary = {}  # seat → Array[Sprite2D]

func _ready():
	sounds = { "lose": preload("res://Assets/SoundBytes/wet-fart-meme.mp3") }
	_place_generals()
	_setup_heart_displays()
	if GameManager._is_server():
		state = BoardState.create_from_players(GameManager.players)
		sync_board_state.rpc(state.serialize())
	hookup_lane_buttons()

func _place_generals():
	for seat in GENERAL_POSITIONS:
		var player = null
		for p in GameManager.players.values():
			if p.playerTableAssignment == seat:
				player = p
				break
		if player == null:
			continue

		var tribe = player.tribe
		var sprite = Sprite2D.new()
		sprite.texture  = GameManager.TRIBE_GENERAL_TEXTURES[tribe]
		sprite.position = GENERAL_POSITIONS[seat]
		sprite.scale    = GENERAL_SCALE
		sprite.z_index  = 0
		add_child(sprite)

func _setup_heart_displays():
	var texture = load(UI_ASSETS_PATH)

	var shader = Shader.new()
	shader.code = _HEART_SHADER_CODE

	for seat in HEART_ORIGINS:
		get_hp_label(seat).hide()
		heart_sprites[seat] = []
		var origin = HEART_ORIGINS[seat]
		var dir    = HEART_DIR[seat]
		for i in range(HEARTS_COUNT):
			var atlas        = AtlasTexture.new()
			atlas.atlas      = texture
			atlas.region     = HEART_FULL_REGION
			var mat          = ShaderMaterial.new()
			mat.shader       = shader
			mat.set_shader_parameter("ocean_color", OCEAN_COLOR)
			var sprite       = Sprite2D.new()
			sprite.texture   = atlas
			sprite.position  = origin + Vector2(dir * HEART_SPACING * i, 0)
			sprite.scale     = HEART_SCALE
			sprite.z_index   = 2
			sprite.material  = mat
			add_child(sprite)
			heart_sprites[seat].append(sprite)

func _update_hearts(seat: int, hp: int):
	if not heart_sprites.has(seat):
		return
	var full_count = roundi(clampi(hp, 0, MAX_HP) * HEARTS_COUNT / float(MAX_HP))
	var sprites = heart_sprites[seat]
	for i in range(sprites.size()):
		var atlas = sprites[i].texture as AtlasTexture
		if atlas:
			atlas.region = HEART_FULL_REGION if i < full_count else HEART_EMPTY_REGION

# --- Node helpers ---

func get_hp_label(seat: int) -> Label:
	return get_node("Player%d/LabelP%dHP" % [seat, seat])

func get_name_label(seat: int) -> Label:
	return get_node("Player%d/LabelP%dPlayername" % [seat, seat])

func get_stored_unit_label(seat: int) -> Label:
	return get_node("Player%d/StoredUnitCountP%d" % [seat, seat])

func get_lane_buttons_for_seat(seat: int) -> Array:
	var result = []
	for child in get_node("Player%d" % seat).get_children():
		if child is Button:
			result.append(child)
	return result

func get_buttons_targeting_seat(target_seat: int) -> Array:
	var result = []
	for player in GameManager.players.values():
		var src = player.playerTableAssignment
		if src == target_seat:
			continue
		var btn = get_node_or_null("Player%d/Button%do%d" % [src, src, target_seat])
		if btn:
			result.append(btn)
	return result

func get_player_id_by_seat(seat: int) -> int:
	for player_id in GameManager.players:
		if GameManager.players[player_id].playerTableAssignment == seat:
			return player_id
	return -1

# --- Rendering ---
# All UI reads from state — never from button.text or other UI elements.
# To add sprites/animations, extend render_player_ui() or apply_death_visuals()
# without touching any game logic.

func render_state():
	var local_id = multiplayer.get_unique_id()
	for player_id in GameManager.players:
		render_player_ui(player_id, local_id)
	render_end_screen()

func render_player_ui(player_id: int, local_id: int):
	var player = GameManager.players[player_id]
	var seat = player.playerTableAssignment
	var is_local = player_id == local_id
	var is_dead = player_id in state.dead_player_ids

	_update_hearts(seat, state.player_hp.get(player_id, 0))
	get_name_label(seat).text = player.name
	get_stored_unit_label(seat).text = str(state.stored_units.get(player_id, 0))
	get_stored_unit_label(seat).visible = is_local

	for target_id in state.lane_units.get(player_id, {}):
		if not GameManager.players.has(target_id):
			continue
		var target_seat = GameManager.players[target_id].playerTableAssignment
		var btn = get_node_or_null("Player%d/Button%do%d" % [seat, seat, target_seat])
		if btn:
			btn.text = str(state.lane_units[player_id][target_id])
			btn.visible = is_local
			btn.disabled = not is_local or is_dead

	if is_dead:
		apply_death_visuals(seat)

func apply_death_visuals(seat: int):
	var gray = Color(0.5, 0.5, 0.5, 0.7)
	for btn in get_lane_buttons_for_seat(seat):
		btn.disabled = true
		btn.modulate = gray
	get_stored_unit_label(seat).modulate = gray
	for btn in get_buttons_targeting_seat(seat):
		btn.disabled = true

func render_end_screen():
	if state.phase != BoardState.Phase.ENDED:
		return
	if state.winner_name.is_empty():
		var screen = get_node_or_null("EveryoneLosesScreen")
		if screen:
			screen.visible = true
	else:
		var overlay = $OverlayContainer
		overlay.visible = true
		overlay.get_node("VictoryLabel").text = "%s wins!" % state.winner_name

# --- Input ---

func hookup_lane_buttons():
	var local_id = multiplayer.get_unique_id()
	if not GameManager.players.has(local_id):
		return
	var my_seat = GameManager.players[local_id].playerTableAssignment
	for target_id in GameManager.players:
		if target_id == local_id:
			continue
		var target_seat = GameManager.players[target_id].playerTableAssignment
		var btn = get_node_or_null("Player%d/Button%do%d" % [my_seat, my_seat, target_seat])
		if not btn:
			continue
		var captured_target_id = target_id
		btn.gui_input.connect(func(event): _handle_lane_input(event, local_id, captured_target_id))

func _handle_lane_input(event: InputEvent, attacker_id: int, target_id: int):
	if state == null:
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		request_place_unit.rpc_id(1, attacker_id, target_id)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		request_remove_unit.rpc_id(1, attacker_id, target_id)

func _on_reset_button_pressed():
	request_reset_units.rpc_id(1, multiplayer.get_unique_id())

func _on_end_turn_pressed():
	request_end_turn.rpc_id(1, multiplayer.get_unique_id())

func _on_restart_game_button_pressed():
	if GameManager._is_not_server():
		return
	GameManager.restart_game.rpc()

# --- Combat (host-only logic) ---

func resolve_combat():
	var seats = GameManager.players.values().map(func(p): return p.playerTableAssignment)
	for i in range(seats.size()):
		for j in range(i + 1, seats.size()):
			var id_a = get_player_id_by_seat(seats[i])
			var id_b = get_player_id_by_seat(seats[j])
			if id_a == -1 or id_b == -1:
				continue
			var units_a = state.lane_units.get(id_a, {}).get(id_b, 0)
			var units_b = state.lane_units.get(id_b, {}).get(id_a, 0)
			var results = CombatMath.decide_victor(str(units_a), str(units_b))
			state.player_hp[id_a] += results[0]
			state.player_hp[id_b] += results[1]

func check_deaths():
	var all_dead = true
	for player_id in GameManager.players:
		if state.player_hp.get(player_id, 0) <= 0:
			if player_id not in state.dead_player_ids:
				play_sound.rpc("lose")
				state.dead_player_ids.append(player_id)
				state.alive_count -= 1
		else:
			all_dead = false

	if all_dead:
		state.phase = BoardState.Phase.ENDED
		state.winner_name = ""
	elif state.alive_count == 1:
		for player_id in GameManager.players:
			if player_id not in state.dead_player_ids:
				state.phase = BoardState.Phase.ENDED
				state.winner_name = GameManager.players[player_id].name
				break

func reset_all_lanes():
	for player_id in state.lane_units:
		for target_id in state.lane_units[player_id]:
			state.lane_units[player_id][target_id] = 0
	for player_id in state.stored_units:
		if player_id not in state.dead_player_ids:
			state.stored_units[player_id] = GameManager.startingStoredUnits

# --- Turn control helpers ---

func lock_turn_controls(player_id: int):
	disable_end_turn_button.rpc_id(player_id)
	disable_reset_button.rpc_id(player_id)

func unlock_turn_controls(player_id: int):
	enable_end_turn_button.rpc_id(player_id)
	enable_reset_button.rpc_id(player_id)

# --- RPCs ---

# Unit placement — clients send intent to host, host validates and broadcasts new state.

@rpc("any_peer", "call_local")
func request_place_unit(attacker_id: int, target_id: int):
	if GameManager._is_not_server(): return
	if not GameManager.players.has(attacker_id): return
	if attacker_id in state.dead_player_ids: return
	if state.stored_units.get(attacker_id, 0) <= 0: return
	state.lane_units[attacker_id][target_id] += 1
	state.stored_units[attacker_id] -= 1
	sync_board_state.rpc(state.serialize())

@rpc("any_peer", "call_local")
func request_remove_unit(attacker_id: int, target_id: int):
	if GameManager._is_not_server(): return
	if not GameManager.players.has(attacker_id): return
	if state.lane_units.get(attacker_id, {}).get(target_id, 0) <= 0: return
	state.lane_units[attacker_id][target_id] -= 1
	state.stored_units[attacker_id] += 1
	sync_board_state.rpc(state.serialize())

@rpc("any_peer", "call_local")
func request_reset_units(player_id: int):
	if GameManager._is_not_server(): return
	if not GameManager.players.has(player_id): return
	if player_id in state.dead_player_ids: return
	for target_id in state.lane_units.get(player_id, {}):
		state.stored_units[player_id] += state.lane_units[player_id][target_id]
		state.lane_units[player_id][target_id] = 0
	sync_board_state.rpc(state.serialize())

@rpc("any_peer", "call_local")
func request_end_turn(player_id: int):
	if GameManager._is_not_server(): return
	if player_id in state.ended_turn_player_ids: return
	state.ended_turn_player_ids.append(player_id)
	lock_turn_controls(player_id)
	if state.ended_turn_player_ids.size() == state.alive_count:
		resolve_combat()
		check_deaths()
		reset_all_lanes()
		state.ended_turn_player_ids.clear()
		for pid in GameManager.players:
			if pid not in state.dead_player_ids:
				unlock_turn_controls(pid)
		for pid in state.player_hp:
			if GameManager.players.has(pid):
				GameManager.players[pid].health = state.player_hp[pid]
	sync_board_state.rpc(state.serialize())

@rpc("authority", "call_local")
func sync_board_state(state_dict: Dictionary):
	state = BoardState.deserialize(state_dict)
	render_state()

@rpc("call_local", "any_peer")
func play_sound(sound_name: String):
	var stream = sounds.get(sound_name)
	if stream:
		$AudioStreamPlayer2D.stream = stream
		$AudioStreamPlayer2D.play()

@rpc("any_peer", "call_local")
func disable_end_turn_button():
	$EndTurnTextureButton.disabled = true

@rpc("any_peer", "call_local")
func enable_end_turn_button():
	$EndTurnTextureButton.disabled = false

@rpc("any_peer", "call_local")
func disable_reset_button():
	$ResetUnitsTextureButton.disabled = true

@rpc("any_peer", "call_local")
func enable_reset_button():
	$ResetUnitsTextureButton.disabled = false
