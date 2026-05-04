extends Node

var ended_turn_players = []
var dead_player_ids = []
var alive_player_count: int
var sounds: Dictionary

func _ready():
	alive_player_count = GameManager.players.size()
	sounds = {
		"lose": preload("res://Assets/SoundBytes/wet-fart-meme.mp3")
	}
	setup_board.rpc(GameManager.players)
	hookup_lane_button_handlers.rpc(GameManager.players)
	$ResetUnitsButton.pressed.connect(_on_reset_units_button_pressed)
	$EndTurn.pressed.connect(_on_end_turn_pressed)

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

# --- Helpers ---

func get_player_id_by_seat(seat: int) -> int:
	for player_id in GameManager.players:
		if GameManager.players[player_id].playerTableAssignment == seat:
			return player_id
	return -1

func lockin_player_unit_selections(player_id: int):
	disable_given_player_end_turn_button.rpc_id(player_id)
	disable_given_player_reset_units_button.rpc_id(player_id)

func unlock_player_unit_selections(player_id: int):
	enable_given_player_end_turn_button.rpc_id(player_id)
	enable_given_player_reset_units_button.rpc_id(player_id)

func hookup_button(button: Button, player_multiplayer_id: int):
	var callable = Callable(self, "_on_lane_button_input").bind(button.name, player_multiplayer_id)
	if not button.is_connected("gui_input", callable):
		button.gui_input.connect(callable)

func reset_units_for_seat(seat: int):
	get_stored_unit_label(seat).text = str(GameManager.startingStoredUnits)
	for btn in get_lane_buttons_for_seat(seat):
		btn.text = "0"

# --- Input ---

func _on_lane_button_input(event: InputEvent, button_name: String, player_multiplayer_id: int):
	if player_multiplayer_id != multiplayer.get_unique_id():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			on_lane_button_pressed.rpc_id(1, multiplayer.get_unique_id(), button_name)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			on_lane_button_right_clicked.rpc_id(1, multiplayer.get_unique_id(), button_name)

func _on_reset_units_button_pressed():
	reset_player_units.rpc_id(1, multiplayer.get_unique_id())

func _on_end_turn_pressed():
	notify_end_turn.rpc_id(1, multiplayer.get_unique_id())

func _on_restart_game_button_pressed():
	if GameManager._is_not_server():
		return
	request_restart_game()

# --- Combat ---

func resolve_combat():
	var seats = GameManager.players.values().map(func(p): return p.playerTableAssignment)
	for i in range(seats.size()):
		for j in range(i + 1, seats.size()):
			var seat_a = seats[i]
			var seat_b = seats[j]
			var btn_a = get_node_or_null("Player%d/Button%do%d" % [seat_a, seat_a, seat_b])
			var btn_b = get_node_or_null("Player%d/Button%do%d" % [seat_b, seat_b, seat_a])
			if not btn_a or not btn_b:
				continue
			var id_a = get_player_id_by_seat(seat_a)
			var id_b = get_player_id_by_seat(seat_b)
			if id_a == -1 or id_b == -1:
				continue
			var results = CombatMath.decide_victor(btn_a.text, btn_b.text)
			GameManager.players[id_a].health += results[0]
			GameManager.players[id_b].health += results[1]
	send_combat_results_to_all_players.rpc(GameManager.players)

# --- RPCs ---

@rpc("authority")
func request_restart_game():
	GameManager.restart_game.rpc()

@rpc("any_peer", "call_local")
func setup_board(players_data: Dictionary):
	var local_id = multiplayer.get_unique_id()
	for player_id in players_data:
		var player = players_data[player_id]
		var seat = player.playerTableAssignment
		get_hp_label(seat).text = str(player.health)
		get_name_label(seat).text = player.name
		get_stored_unit_label(seat).text = str(GameManager.startingStoredUnits)
		var is_local = player_id == local_id
		get_stored_unit_label(seat).visible = is_local
		for btn in get_lane_buttons_for_seat(seat):
			btn.visible = is_local
			btn.disabled = not is_local

@rpc("any_peer", "call_local")
func hookup_lane_button_handlers(players_data: Dictionary):
	var local_id = multiplayer.get_unique_id()
	for player_id in players_data:
		if player_id != local_id:
			continue
		var seat = players_data[player_id].playerTableAssignment
		for btn in get_lane_buttons_for_seat(seat):
			hookup_button(btn, player_id)

@rpc("any_peer")
func notify_end_turn(player_id: int):
	if player_id in ended_turn_players:
		return
	ended_turn_players.append(player_id)
	lockin_player_unit_selections(player_id)
	if ended_turn_players.size() == alive_player_count:
		resolve_combat()
		reset_all_player_units.rpc(GameManager.players)
		handle_deaths.rpc()

@rpc("any_peer", "call_local")
func on_lane_button_pressed(player_id: int, button_name: String):
	if not GameManager.players.has(player_id):
		return
	var seat = GameManager.players[player_id].playerTableAssignment
	var stored_label = get_stored_unit_label(seat)
	var stored_count = int(stored_label.text)
	if stored_count <= 0:
		return
	var btn = get_node("Player%d/%s" % [seat, button_name])
	var new_lane_val = int(btn.text) + 1
	update_lane_display.rpc(seat, button_name, new_lane_val, stored_count - 1)

@rpc("any_peer", "call_local")
func on_lane_button_right_clicked(player_id: int, button_name: String):
	if not GameManager.players.has(player_id):
		return
	var seat = GameManager.players[player_id].playerTableAssignment
	var btn = get_node("Player%d/%s" % [seat, button_name])
	var current_val = int(btn.text)
	if current_val <= 0:
		return
	var stored_count = int(get_stored_unit_label(seat).text)
	update_lane_display.rpc(seat, button_name, current_val - 1, stored_count + 1)

@rpc("any_peer", "call_local")
func update_lane_display(seat: int, button_name: String, lane_value: int, stored_value: int):
	var btn = get_node_or_null("Player%d/%s" % [seat, button_name])
	if btn:
		btn.text = str(lane_value)
	get_stored_unit_label(seat).text = str(stored_value)

@rpc("any_peer")
func reset_player_units(player_id: int):
	if not GameManager.players.has(player_id):
		return
	var seat = GameManager.players[player_id].playerTableAssignment
	sync_seat_reset.rpc(seat)

@rpc("any_peer", "call_local")
func sync_seat_reset(seat: int):
	reset_units_for_seat(seat)

@rpc("any_peer", "call_local")
func reset_all_player_units(players_data: Dictionary):
	for player_id in players_data:
		reset_units_for_seat(players_data[player_id].playerTableAssignment)

@rpc("any_peer", "call_local")
func send_combat_results_to_all_players(players_data: Dictionary):
	GameManager.players = players_data
	for player_id in players_data:
		get_hp_label(players_data[player_id].playerTableAssignment).text = str(players_data[player_id].health)
	ended_turn_players = []

@rpc("any_peer", "call_local")
func handle_deaths():
	var all_defeated := true
	for player_id in GameManager.players:
		unlock_player_unit_selections(player_id)
		var player = GameManager.players[player_id]
		var seat = player.playerTableAssignment
		if player.health <= 0:
			if player_id not in dead_player_ids:
				play_sound.rpc("lose")
				dead_player_ids.append(player_id)
				alive_player_count -= 1
			lockin_player_unit_selections(player_id)
			for btn in get_lane_buttons_for_seat(seat):
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
			get_stored_unit_label(seat).modulate = Color(0.5, 0.5, 0.5, 0.7)
			for btn in get_buttons_targeting_seat(seat):
				btn.disabled = true
		else:
			all_defeated = false

	if all_defeated:
		show_game_over_screen.rpc()
	elif alive_player_count == 1:
		for player_id in GameManager.players:
			if player_id not in dead_player_ids:
				show_victory_screen.rpc(GameManager.players[player_id].name)
				break

@rpc("call_local", "any_peer")
func play_sound(sound_name: String):
	var stream = sounds.get(sound_name)
	if stream:
		$AudioStreamPlayer2D.stream = stream
		$AudioStreamPlayer2D.play()

@rpc("any_peer", "call_local")
func show_victory_screen(player_name: String):
	var overlay = $OverlayContainer
	overlay.visible = true
	overlay.get_node("VictoryLabel").text = "%s wins!" % player_name

@rpc("any_peer", "call_local")
func show_game_over_screen():
	var screen = get_node_or_null("EveryoneLosesScreen")
	if screen:
		screen.visible = true

@rpc("any_peer", "call_local")
func disable_given_player_end_turn_button():
	$EndTurn.disabled = true

@rpc("any_peer", "call_local")
func enable_given_player_end_turn_button():
	$EndTurn.disabled = false

@rpc("any_peer", "call_local")
func disable_given_player_reset_units_button():
	$ResetUnitsButton.disabled = true

@rpc("any_peer", "call_local")
func enable_given_player_reset_units_button():
	$ResetUnitsButton.disabled = false
