extends Node

var Player1UI
var Player2UI
var Player3UI
var Player4UI
var ended_turn_players = []
var deadPlayerIds = []

var UIDictionary = {}
var PlayerClickableButtons = {}
var ButtonsUsedToAttackGivenPlayerDictionary = {}

const minimumStoredUnitCount = 0

var sounds
var alivePlayerCount

# Called when the node enters the scene tree for the first time.
func _ready():
	Player1UI = [
		$Player1/Button1o2, 
		$Player1/Button1o3, 
		$Player1/Button1o4,
		$Player1/StoredUnitCountP1,
	]
	Player2UI = [
		$Player2/Button2o1, 
		$Player2/Button2o3, 
		$Player2/Button2o4,
		$Player2/StoredUnitCountP2,
		]
	Player3UI = [
		$Player3/Button3o1, 
		$Player3/Button3o2, 
		$Player3/Button3o4,
		$Player3/StoredUnitCountP3,
	]
	Player4UI = [
		$Player4/Button4o1, 
		$Player4/Button4o2, 
		$Player4/Button4o3,
		$Player4/StoredUnitCountP4,
	]
	ButtonsUsedToAttackGivenPlayerDictionary = {
		1: [$Player2/Button2o1, $Player4/Button4o1, $Player3/Button3o1],
		2: [$Player1/Button1o2, $Player4/Button4o2, $Player3/Button3o2],
		3: [$Player1/Button1o3, $Player2/Button2o3, $Player4/Button4o3],
		4: [$Player1/Button1o4, $Player2/Button2o4, $Player3/Button3o4]
	}
	alivePlayerCount = GameManager.players.size()
	sounds = {
		#"attack": preload("res://sounds/attack.mp3"),
		#"win": preload("res://sounds/win.mp3"),
		"lose": preload("res://Assets/SoundBytes/wet-fart-meme.mp3")
	}
	
	prepare_UI_per_player.rpc(GameManager.players)
	hookup_laneButton_handlers.rpc(GameManager.players)
	for player in GameManager.players:
		InitializePlayerHPLabel.rpc(GameManager.players[player].id)
	$ResetUnitsButton.pressed.connect(_on_reset_units_button_pressed)
	$EndTurn.pressed.connect(_on_end_turn_pressed)

func resolve_combat():
	var streets = {
		"12": [$Player1/Button1o2.text, $Player2/Button2o1.text],
		"14": [$Player1/Button1o4.text, $Player4/Button4o1.text],
		"13": [$Player1/Button1o3.text, $Player3/Button3o1.text],
		"42": [$Player4/Button4o2.text, $Player2/Button2o4.text],
		"43" : [$Player4/Button4o3.text, $Player3/Button3o4.text],
		"23": [$Player2/Button2o3.text, $Player3/Button3o2.text]
	}
	
	for roadway in streets:
		var playerCombatants = ConvertStreetToCombatants(roadway)
		var player1_id = get_player_id_by_seat(playerCombatants[0])
		var player2_id = get_player_id_by_seat(playerCombatants[1])
		if(player1_id == -1 || player2_id == -1): continue
		var results = CombatMath.decide_victor(streets[roadway][0], streets[roadway][1])
		GameManager.players[player1_id].health += results[0]
		GameManager.players[player2_id].health += results[1]
	send_combat_results_to_all_players.rpc(GameManager.players)

func lockin_player_unit_selections(player_id):
	disable_given_player_end_turn_button.rpc_id(player_id)
	disable_given_player_reset_units_button.rpc_id(player_id)
func unlock_player_unit_selections(player_id):
	enable_given_player_end_turn_button.rpc_id(player_id)
	enable_given_player_reset_units_button.rpc_id(player_id)
	pass

func hookup_button(button, player_multiplayer_id):
	var callable = Callable(self, "_on_lane_button_input").bind(button.name, player_multiplayer_id)
	if not button.is_connected("gui_input", callable):
		button.gui_input.connect(callable)

func _on_lane_button_input(event: InputEvent, button_name: String, player_multiplayer_id: int) -> void:
	if player_multiplayer_id != multiplayer.get_unique_id():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			on_lane_button_pressed.rpc_id(1, multiplayer.get_unique_id(), button_name)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			on_lane_button_right_clicked.rpc_id(1, multiplayer.get_unique_id(), button_name)

func _on_lane_button_pressed_wrapper(button_name: String, player_multiplayer_id: int):
	if player_multiplayer_id != multiplayer.get_unique_id():
		return
	on_lane_button_pressed.rpc_id(1, multiplayer.get_unique_id(), button_name)

func _on_reset_units_button_pressed():
	var my_id = multiplayer.get_unique_id()
	reset_player_units.rpc_id(1, my_id)

func _on_end_turn_pressed():
	var my_id = multiplayer.get_unique_id()
	notify_end_turn.rpc_id(1, my_id)

func _on_restart_game_button_pressed():
	if(GameManager._is_not_server()):
		return
	else:
		request_restart_game()

func get_player_id_by_seat(seatAssignment: int) -> int:
	for player_id in GameManager.players:
		if GameManager.players[player_id].playerTableAssignment == seatAssignment:
			return player_id
	return -1

#region Dictionary-Mappings
func ConvertPlayerSeatToClickableButtons(seatId):
	match(seatId):
		1:
			return [$Player1/Button1o2, $Player1/Button1o3, $Player1/Button1o4]
		2:
			return [$Player2/Button2o1, $Player2/Button2o3, $Player2/Button2o4]
		3:
			return [$Player3/Button3o1, $Player3/Button3o2, $Player3/Button3o4]
		4:
			return [$Player4/Button4o1, $Player4/Button4o2, $Player4/Button4o3]
func MutuallyExclusiveUIPerSeat(seatId):
	match(seatId):
		1:
			return Player1UI
		2:
			return Player2UI
		3:
			return Player3UI
		4:
			return Player4UI
func ConvertStreetToCombatants(laneName):
	match(laneName):
		"12": 
			return [1, 2]
		"14": 
			return [1, 4]
		"13": 
			return [1, 3]
		"42": 
			return [4, 2]
		"43" : 
			return [4, 3]
		"23": 
			return [2, 3]
func MapPlayerToHpLabel(seatId):
	match(seatId):
		1:
			return $Player1/LabelP1HP
		2:
			return $Player2/LabelP2HP
		3:
			return $Player3/LabelP3HP
		4:
			return $Player4/LabelP4HP
func MapPlayerToPlayernameLabel(seatId):
	match(seatId):
		1:
			return $Player1/LabelP1Playername
		2:
			return $Player2/LabelP2Playername
		3:
			return $Player3/LabelP3Playername
		4:
			return $Player4/LabelP4Playername
func MapPlayerToStoredUnitContLabel(seatId):
	match(seatId):
		1:
			return $Player1/StoredUnitCountP1
		2:
			return $Player2/StoredUnitCountP2
		3:
			return $Player3/StoredUnitCountP3
		4:
			return $Player4/StoredUnitCountP4
#endregion

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#region RPCs
@rpc("authority")
func request_restart_game():
	GameManager.restart_game.rpc()

@rpc("any_peer", "call_local")
func prepare_UI_per_player(Players):
	for player in Players.keys():
		UIDictionary[player] = MutuallyExclusiveUIPerSeat(Players[player].playerTableAssignment)
		PlayerClickableButtons[player] = ConvertPlayerSeatToClickableButtons(Players[player].playerTableAssignment)
		var playernameLabel = MapPlayerToPlayernameLabel(Players[player].playerTableAssignment)
		playernameLabel.text = Players[player].name
		var hpLabel = MapPlayerToHpLabel(Players[player].playerTableAssignment)
		hpLabel.text = str(Players[player].health)
		var storedUnitCount = MapPlayerToStoredUnitContLabel(Players[player].playerTableAssignment)
		storedUnitCount.text = "3"
		
	for player_id in UIDictionary.keys():
		var is_local_player = player_id == multiplayer.get_unique_id()
		for control in UIDictionary[player_id]:
			if control is Label:
				control.visible = is_local_player
			else:
				control.visible = is_local_player
				control.disabled = not is_local_player

@rpc("any_peer", "call_local")
func notify_end_turn(player_id: int):
	if player_id in ended_turn_players:
		return  # Avoid double-count
	ended_turn_players.append(player_id)
	lockin_player_unit_selections(player_id)

	# Check if all players are done
	if ended_turn_players.size() == alivePlayerCount:
		print("Resolving combat!")
		resolve_combat()
		reset_all_player_units.rpc(GameManager.players)
		handleAndDisableDeaths.rpc()

@rpc("any_peer", "call_local")
func update_all_player_health(health_data: Dictionary):
	for player_id in health_data.keys():
		if GameManager.players.has(player_id):
			GameManager.players[player_id].health = health_data[player_id].health
			match GameManager.players[player_id].playerTableAssignment:
				1:
					$Player1/LabelP1HP.text = str(GameManager.players[player_id].health)
				2:
					$Player2/LabelP2HP.text = str(GameManager.players[player_id].health)
				3:
					$Player3/LabelP3HP.text = str(GameManager.players[player_id].health)
				4:
					$Player4/LabelP4HP.text = str(GameManager.players[player_id].health)
@rpc("any_peer", "call_local")
func InitializePlayerHPLabel(player):
		match GameManager.players[player].playerTableAssignment:
			1:
				$Player1/LabelP1HP.text = str(GameManager.players[player].health)
			2:
				$Player2/LabelP2HP.text = str(GameManager.players[player].health)
			3:
				$Player3/LabelP3HP.text = str(GameManager.players[player].health)
			4:
				$Player4/LabelP4HP.text = str(GameManager.players[player].health)
@rpc("any_peer", "call_local")
func reset_all_player_units(Players):
	for player in Players.keys():
		reset_player_units.rpc(int(Players[player].id))
@rpc("any_peer", "call_local")
func reset_player_units(player_id: int):
	if not GameManager.players.has(player_id):
		return
	var seat = GameManager.players[player_id].playerTableAssignment
	reset_units_ui.rpc(seat)
@rpc("any_peer", "call_local")
func reset_units_ui(seatAssignment):
	var stored_label = MapPlayerToStoredUnitContLabel(seatAssignment)
	stored_label.text = "3"

	var player_node = get_node("Player" + str(seatAssignment))

	for control in player_node.get_children():
		if control.name.contains("Button") && control is Button:
			control.text = "0"
@rpc("any_peer", "call_local")
func on_lane_button_right_clicked(player_id: int, button_name: String):
	if !GameManager.players.has(player_id):
		return

	var playerSeatId = GameManager.players[player_id].playerTableAssignment
	var stored_label = MapPlayerToStoredUnitContLabel(playerSeatId)
	var stored_count = int(stored_label.text)

	var suffix = button_name.substr(button_name.length() - 3)
	var count_label = get_node("Player" + str(playerSeatId) + "/" + button_name)

	if count_label:
		var current_val = int(count_label.text)
		if current_val > 0:
			count_label.text = str(current_val - 1)
			stored_label.text = str(stored_count + 1)

			update_lane_label.rpc(playerSeatId, suffix, current_val - 1, stored_count + 1)
			update_lane_label(playerSeatId, suffix, current_val - 1, stored_count + 1)

@rpc("call_local", "any_peer")
func play_sound(sound_name: String):
	var sound_stream = sounds.get(sound_name)
	if sound_stream:
		$AudioStreamPlayer2D.stream = sound_stream
		$AudioStreamPlayer2D.play()
	else:
		print("Unknown sound:", sound_name)

@rpc("any_peer", "call_local")
func showVictoryScreen(playername):
	var overlay = get_node("OverlayContainer")
	overlay.visible = true

	var label = overlay.get_node("VictoryLabel")
	label.text = "%s wins!" % playername

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

@rpc("any_peer", "call_local")
func show_game_over_screen():
	var lose_screen = get_node_or_null("EveryoneLosesScreen")
	if lose_screen:
		lose_screen.visible = true
	else:
		print("ERROR: Could not find EveryoneLosesScreen")

@rpc("any_peer", "call_local")
func hookup_laneButton_handlers(Players):
	for player_id in Players.keys():
		if player_id == multiplayer.get_unique_id():
			for button in PlayerClickableButtons[player_id]:
				hookup_button(button, Players[player_id].id)

@rpc("any_peer")
func update_lane_label(seatId: int, suffix: String, new_lane_value: int, new_stored_value: int):
	var count_label = get_node("Player" + str(seatId) + "/Button" + suffix)
	if count_label:
		count_label.text = str(new_lane_value)

	var stored_label = MapPlayerToStoredUnitContLabel(seatId)
	stored_label.text = str(new_stored_value)

@rpc("any_peer", "call_local")
func on_lane_button_pressed(player_id: int, button_name: String):
	if !GameManager.players.has(player_id):
		return

	#TODO: make this work even if you dont have any units in store, take from
	#other lanes
	var playerSeatId = GameManager.players[player_id].playerTableAssignment
	var stored_label = MapPlayerToStoredUnitContLabel(playerSeatId)
	var stored_count = int(stored_label.text)

	if stored_count <= 0:
		return

	var suffix = button_name.substr(button_name.length() - 3)
	var count_label = get_node("Player"+str(playerSeatId)+"/"+button_name)

	if count_label:
		var current_val = int(count_label.text)
		count_label.text = str(current_val + 1)

	stored_label.text = str(stored_count - 1)

	update_lane_label.rpc(playerSeatId, suffix, int(count_label.text), stored_count - 1)
	update_lane_label(playerSeatId, suffix, int(count_label.text), stored_count - 1)

@rpc("any_peer", "call_local")
func send_combat_results_to_all_players(Players):
	GameManager.players = Players;
	update_all_player_health(Players);
	ended_turn_players = [];

@rpc("any_peer", "call_local")
func handleAndDisableDeaths():
	var all_defeated := true  # Assume all are defeated unless we find one alive
	for player_id in GameManager.players.keys():
		unlock_player_unit_selections(player_id)
		if GameManager.players[player_id].health <= 0:
			if player_id not in deadPlayerIds:
				play_sound.rpc("lose")
				deadPlayerIds.append(player_id)
				alivePlayerCount -= 1
			lockin_player_unit_selections(player_id)
			if PlayerClickableButtons.has(player_id):
				for button in PlayerClickableButtons[player_id]:
					button.disabled = true
			if UIDictionary.has(player_id):
				for control in UIDictionary[player_id]:
					control.modulate = Color(0.5, 0.5, 0.5, 0.7)  # semi-transparent gray
			if ButtonsUsedToAttackGivenPlayerDictionary.has(GameManager.players[player_id].playerTableAssignment):
				for control in ButtonsUsedToAttackGivenPlayerDictionary[GameManager.players[player_id].playerTableAssignment]:
					control.disabled = true;
		else:
			all_defeated = false
			
	if all_defeated:
		show_game_over_screen.rpc()
		
	if(alivePlayerCount == 1):
		var alivePlayer
		for player in GameManager.players:
			if player not in deadPlayerIds:
				alivePlayer = GameManager.players[player]
				showVictoryScreen.rpc(alivePlayer.name)

@rpc("any_peer", "call_local")
func assign_UI_to_players(Players):
	for player_id in UIDictionary.keys():
		var is_local_player = player_id == multiplayer.get_unique_id()
		for control in UIDictionary[player_id]:
			if control is Label:
				control.visible = is_local_player
			else:
				control.visible = is_local_player
				control.disabled = not is_local_player
#endregion
