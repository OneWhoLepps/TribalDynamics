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
const UI_ASSETS_PATH     = "res://Assets/Fonts/Tribal_Dynamics_UIAssets.png"
const HEART_FULL_REGION  = Rect2(24, 40, 8, 8)
const HEART_EMPTY_REGION = Rect2(24, 48, 8, 8)
const HEART_HALF_REGION  = Rect2(24, 40, 4, 8)   # left half of the full heart
const HEART_SCALE        = Vector2(3.0, 3.0)     # renders each heart as 24×24 px
const HEART_SPACING      = 26                    # px between heart origins
const HEARTS_COUNT       = 5                     # hearts visible per player
const MAX_HP             = 10                    # matches GameManager.startingHealth
const HP_PER_HEART       = MAX_HP / HEARTS_COUNT # 2

# Top seats: hearts above name label (name label world y ≈ 63–86)
# Bottom seats: hearts below name label (name label world y ≈ 650–673)
const HEART_ORIGINS = {
	1: Vector2(254, 14),    # top-left  → extends right, above name
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

# --- Combat animation ---
const FIGHT_CLOUD_SCENE = preload("res://Assets/VisualEffects/FightCloud/FightCloud.tscn")
const UNIT_SCALE      = Vector2(2.0, 2.0)
const UNIT_MOVE_SPEED = 150.0   # px per second
const V_SPACING_SIDE  = 22.0    # how wide the V fans out
const V_SPACING_BACK  = 18.0    # how far each row trails behind
const CLOUD_LOOPS     = 1

var state: BoardState
var sounds: Dictionary
var heart_sprites: Dictionary = {}       # seat → Array[Sprite2D]
var heart_half_sprites: Dictionary = {}  # seat → Array[Sprite2D]
var combat_in_progress := false
var _battles_pending := 0

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

		var scene: PackedScene = GameManager.TRIBE_GENERAL_IDLE_SCENES.get(player.tribe)
		if scene == null:
			push_warning("No general scene for tribe %s" % player.tribe)
			continue

		var general = scene.instantiate()
		general.position = GENERAL_POSITIONS[seat]
		general.scale = GENERAL_SCALE
		general.z_index = 0
		add_child(general)

func _setup_heart_displays():
	var texture = load(UI_ASSETS_PATH)

	var shader = Shader.new()
	shader.code = _HEART_SHADER_CODE

	for seat in HEART_ORIGINS:
		get_hp_label(seat).hide()
		heart_sprites[seat] = []
		heart_half_sprites[seat] = []
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

			# Half-heart overlay (left half of the full heart, drawn on top of an empty heart)
			var half_atlas    = AtlasTexture.new()
			half_atlas.atlas  = texture
			half_atlas.region = HEART_HALF_REGION
			var half          = Sprite2D.new()
			half.texture      = half_atlas
			half.centered     = false
			# align its top-left with the full heart's top-left (heart is 8x8, centered)
			half.position     = sprite.position - Vector2(4, 4) * HEART_SCALE.x
			half.scale        = HEART_SCALE
			half.z_index      = 3
			half.material     = mat
			half.visible      = false
			add_child(half)
			heart_half_sprites[seat].append(half)

func _update_hearts(seat: int, hp: int):
	if not heart_sprites.has(seat):
		return
	hp = clampi(hp, 0, MAX_HP)
	var sprites = heart_sprites[seat]
	var halves = heart_half_sprites[seat]
	for i in range(sprites.size()):
		var atlas = sprites[i].texture as AtlasTexture
		if atlas == null:
			continue
		var remaining = hp - i * HP_PER_HEART   # HP that belongs to this heart
		if remaining >= HP_PER_HEART:
			atlas.region = HEART_FULL_REGION
			halves[i].visible = false
		elif remaining == 1:
			atlas.region = HEART_EMPTY_REGION   # empty heart underneath
			halves[i].visible = true            # half-fill on top
		else:
			atlas.region = HEART_EMPTY_REGION
			halves[i].visible = false

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

# Rolls the dice ONCE on the host and describes each fight. Clients only replay the result.
func build_battles() -> Array:
	var battles = []
	var seats = GameManager.players.values().map(func(p): return p.playerTableAssignment)
	for i in range(seats.size()):
		for j in range(i + 1, seats.size()):
			var id_a = get_player_id_by_seat(seats[i])
			var id_b = get_player_id_by_seat(seats[j])
			if id_a == -1 or id_b == -1:
				continue
			var units_a = state.lane_units.get(id_a, {}).get(id_b, 0)
			var units_b = state.lane_units.get(id_b, {}).get(id_a, 0)
			if units_a == 0 and units_b == 0:
				continue

			var results = CombatMath.decide_victor(str(units_a), str(units_b))

			battles.append({
				"a": id_a, "b": id_b,
				"units_a": units_a, "units_b": units_b,
				"hp_a": results[0], "hp_b": results[1],   # these are 0 or negative
			})
			print("battle ", id_a, " vs ", id_b, " units ", units_a, "/", units_b,
				" hp ", results[0], "/", results[1])
	return battles

func apply_combat_results(battles: Array):
	for b in battles:
		state.player_hp[b.a] += b.hp_a
		state.player_hp[b.b] += b.hp_b

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

# --- Combat animation (runs on every peer) ---

# Returns when every battle has finished.
func _play_battles(battles: Array) -> void:
	_battles_pending = battles.size()
	for b in battles:
		_run_battle(b)   # intentionally not awaited, so all lanes play in parallel
	while _battles_pending > 0:
		await get_tree().process_frame

func _run_battle(b: Dictionary) -> void:
	await _run_battle_inner(b)
	_battles_pending -= 1

func _run_battle_inner(b: Dictionary) -> void:
	var pa = GameManager.players[b.a]
	var pb = GameManager.players[b.b]
	var pos_a: Vector2 = GENERAL_POSITIONS[pa.playerTableAssignment]
	var pos_b: Vector2 = GENERAL_POSITIONS[pb.playerTableAssignment]
	var mid = (pos_a + pos_b) / 2.0
	var fought = b.units_a > 0 and b.units_b > 0

	# Phase 1 + 2: armies meet in the middle, despawn, fight cloud plays.
	# Both counts are > 0 here and both sides travel the same distance,
	# so awaiting the second march also covers the first.
	if fought:
		_march(pa.tribe, b.units_a, pos_a, mid)
		await _march(pb.tribe, b.units_b, pos_b, mid)
		await _play_cloud(mid)

	# Phase 3: each HP lost = one enemy unit reaches your general.
	var through_a = -b.hp_b   # A's units that get through to B's general
	var through_b = -b.hp_a   # B's units that get through to A's general
	var start_a = mid if fought else pos_a
	var start_b = mid if fought else pos_b

	# Per-battle counter, so parallel battles don't overwrite each other.
	# Waits for BOTH marches, even if one has zero units.
	b["marches_pending"] = 2
	_march_tracked(b, pa.tribe, through_a, start_a, pos_b)
	_march_tracked(b, pb.tribe, through_b, start_b, pos_a)
	while b["marches_pending"] > 0:
		await get_tree().process_frame

func _march_tracked(b: Dictionary, tribe: int, count: int, from: Vector2, to: Vector2) -> void:
	await _march(tribe, count, from, to)
	b["marches_pending"] -= 1

# Spawns `count` units in a V (tip leading) and walks them from -> to, then frees them.
func _march(tribe: int, count: int, from: Vector2, to: Vector2) -> void:
	var scene: PackedScene = GameManager.TRIBE_UNIT_SCENES.get(tribe)
	if scene == null or count <= 0:
		return
	var dir = (to - from).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var duration = maxf(from.distance_to(to) / UNIT_MOVE_SPEED, 0.01)
	var units = []
	var tween = create_tween().set_parallel(true)

	for i in range(count):
		var row = floori((i + 1) / 2.0)                       # 0,1,1,2,2,3,3...
		var side = 0 if i == 0 else (1 if i % 2 == 1 else -1) # tip, then alternate sides
		var offset = -dir * row * V_SPACING_BACK + perp * side * row * V_SPACING_SIDE

		var u = scene.instantiate()
		u.scale = UNIT_SCALE
		u.z_index = 1
		u.position = from + offset
		add_child(u)
		units.append(u)
		tween.tween_property(u, "position", to + offset, duration)

	await tween.finished
	for u in units:
		u.queue_free()

func _play_cloud(pos: Vector2) -> void:
	var cloud = FIGHT_CLOUD_SCENE.instantiate()
	cloud.position = pos
	cloud.z_index = 1
	cloud.scale = Vector2(3.0, 3.0)
	add_child(cloud)

	var wait = 1.0   # fallback if we can't find an AnimatedSprite2D
	var sprite = _find_animated_sprite(cloud)
	if sprite:
		sprite.play()
		var frames = sprite.sprite_frames
		var fps = frames.get_animation_speed(sprite.animation)
		if fps > 0:
			wait = (frames.get_frame_count(sprite.animation) / fps) * CLOUD_LOOPS
	await get_tree().create_timer(wait).timeout
	cloud.queue_free()

func _find_animated_sprite(n: Node) -> AnimatedSprite2D:
	if n is AnimatedSprite2D:
		return n
	for c in n.get_children():
		var found = _find_animated_sprite(c)
		if found:
			return found
	return null

# --- RPCs ---

# Unit placement — clients send intent to host, host validates and broadcasts new state.

@rpc("any_peer", "call_local")
func request_place_unit(attacker_id: int, target_id: int):
	if GameManager._is_not_server(): return
	if combat_in_progress: return
	if not GameManager.players.has(attacker_id): return
	if attacker_id in state.dead_player_ids: return
	if state.stored_units.get(attacker_id, 0) <= 0: return
	state.lane_units[attacker_id][target_id] += 1
	state.stored_units[attacker_id] -= 1
	sync_board_state.rpc(state.serialize())

@rpc("any_peer", "call_local")
func request_remove_unit(attacker_id: int, target_id: int):
	if GameManager._is_not_server(): return
	if combat_in_progress: return
	if not GameManager.players.has(attacker_id): return
	if state.lane_units.get(attacker_id, {}).get(target_id, 0) <= 0: return
	state.lane_units[attacker_id][target_id] -= 1
	state.stored_units[attacker_id] += 1
	sync_board_state.rpc(state.serialize())

@rpc("any_peer", "call_local")
func request_reset_units(player_id: int):
	if GameManager._is_not_server(): return
	if combat_in_progress: return
	if not GameManager.players.has(player_id): return
	if player_id in state.dead_player_ids: return
	for target_id in state.lane_units.get(player_id, {}):
		state.stored_units[player_id] += state.lane_units[player_id][target_id]
		state.lane_units[player_id][target_id] = 0
	sync_board_state.rpc(state.serialize())

# Host -> clients only. The host plays its own copy directly so it can await it.
@rpc("authority", "call_remote", "reliable")
func play_combat_animations(battles: Array):
	_play_battles(battles)

@rpc("any_peer", "call_local")
func request_end_turn(player_id: int):
	if GameManager._is_not_server(): return
	if combat_in_progress: return
	if player_id in state.ended_turn_player_ids: return
	state.ended_turn_player_ids.append(player_id)
	lock_turn_controls(player_id)
	if state.ended_turn_player_ids.size() == state.alive_count:
		combat_in_progress = true
		var battles = build_battles()
		play_combat_animations.rpc(battles)   # clients start playing
		await _play_battles(battles)          # host plays and BLOCKS until done

		apply_combat_results(battles)         # hearts only change after the animation
		check_deaths()
		reset_all_lanes()
		state.ended_turn_player_ids.clear()
		for pid in GameManager.players:
			if pid not in state.dead_player_ids:
				unlock_turn_controls(pid)
		for pid in state.player_hp:
			if GameManager.players.has(pid):
				GameManager.players[pid].health = state.player_hp[pid]
		combat_in_progress = false
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
