extends Node

var RedPlayerUI
var BluePlayerUI
var GreenPlayerUI
var YellowPlayerUI
var UIDictionary

var PlayerClickableButtons
var PlayernameTextDictionary
var PlayerHpLabelDictionary
var ButtonsUsedToAttackGivenColorDictionary
const minimumStoredUnitCount = 0
var ended_turn_players = []
var deadPlayerIds
var alivePlayerCount

# Called when the node enters the scene tree for the first time.
func _ready():
	RedPlayerUI = [
		$PlayerRed/ButtonRoY, 
		$PlayerRed/ButtonRoB, 
		$PlayerRed/ButtonRoG,
		$PlayerRed/StoredUnitCountRed,
		$PlayerRed/RoYCount,
		$PlayerRed/RoGCount,
		$PlayerRed/RoBCount
	]
	BluePlayerUI = [
		$PlayerBlue/ButtonBoY, 
		$PlayerBlue/ButtonBoR, 
		$PlayerBlue/ButtonBoG,
		$PlayerBlue/StoredUnitCountBlue,
		$PlayerBlue/BoGCount,
		$PlayerBlue/BoYCount,
		$PlayerBlue/BoRCount
		]
	GreenPlayerUI = [
		$PlayerGreen/ButtonGoY, 
		$PlayerGreen/ButtonGoB, 
		$PlayerGreen/ButtonGoR,
		$PlayerGreen/StoredUnitCountGreen,
		$PlayerGreen/GoYCount,
		$PlayerGreen/GoBCount,
		$PlayerGreen/GoRCount
	]
	YellowPlayerUI = [
		$PlayerYellow/ButtonYoR, 
		$PlayerYellow/ButtonYoB, 
		$PlayerYellow/ButtonYoG,
		$PlayerYellow/StoredUnitCountYellow,
		$PlayerYellow/YoGCount,
		$PlayerYellow/YoRCount,
		$PlayerYellow/YoBCount
	]
	UIDictionary = {}
	PlayernameTextDictionary = {}
	PlayerHpLabelDictionary = {}
	PlayerClickableButtons = {}
	ButtonsUsedToAttackGivenColorDictionary = {
		0: [$PlayerBlue/ButtonBoR, $PlayerYellow/ButtonYoR, $PlayerGreen/ButtonGoR],
		1: [$PlayerRed/ButtonRoB, $PlayerYellow/ButtonYoB, $PlayerGreen/ButtonGoB],
		2: [$PlayerRed/ButtonRoG, $PlayerBlue/ButtonBoG, $PlayerYellow/ButtonYoG],
		3: [$PlayerRed/ButtonRoY, $PlayerBlue/ButtonBoY, $PlayerGreen/ButtonGoY]
	}
	deadPlayerIds = []
	
	alivePlayerCount = GameManager.Players.size()
	
	populate_UI_dictionary.rpc(GameManager.Players)
	assign_UI_to_players.rpc(GameManager.Players)
	populate_clickable_button_dictionary.rpc(GameManager.Players)
	#populate_player_health_dictionary.rpc(GameManager.Players)
	
	hookup_laneButton_handlers.rpc(GameManager.Players)
	display_starting_hp.rpc(GameManager.Players)
	display_player_names.rpc(GameManager.Players)
	for player in GameManager.Players:
		UpdatePlayerHealthRpc.rpc(GameManager.Players[player].id)
	$ResetUnitsButton.pressed.connect(_on_reset_units_button_pressed)
	$EndTurn.pressed.connect(_on_end_turn_pressed)



@rpc("any_peer", "call_local")
func assign_UI_to_players(Players):
	#logic to disable all buttons that arent yours
	for i in UIDictionary.keys():
		if i == multiplayer.get_unique_id():
			for control in UIDictionary[i]:
				if control is Label:
					control.visible = true
				else:
					control.visible = true
					control.disabled = false

func resolve_combat():
	var laneCombinations = {
		"RedBlue": [$PlayerRed/RoBCount.text, $PlayerBlue/BoRCount.text],
		"RedYellow": [$PlayerRed/RoYCount.text, $PlayerYellow/YoRCount.text],
		"RedGreen": [$PlayerRed/RoGCount.text, $PlayerGreen/GoRCount.text],
		"YellowBlue": [$PlayerYellow/YoBCount.text, $PlayerBlue/BoYCount.text],
		"YellowGreen" : [$PlayerYellow/YoGCount.text, $PlayerGreen/GoYCount.text],
		"BlueGreen": [$PlayerBlue/BoGCount.text, $PlayerGreen/GoBCount.text]
	}
	
	for combo in laneCombinations:
		var playerColors = ConvertLaneToPlayerColor(combo)
		var player1_id = get_player_id_by_color(playerColors[0])
		var player2_id = get_player_id_by_color(playerColors[1])
		if(player1_id == -1 || player2_id == -1): continue
		var results = decide_victor(laneCombinations[combo][0], laneCombinations[combo][1])
		GameManager.Players[player1_id].health += results[0]
		GameManager.Players[player2_id].health += results[1]
	send_combat_results_to_all_players.rpc(GameManager.Players)

@rpc("any_peer", "call_local")
func send_combat_results_to_all_players(Players):
	GameManager.Players = Players;
	update_all_player_health(Players);
	ended_turn_players = [];

func decide_victor(player1Lane, player2Lane):
	var p1_hp_change := 0
	var p2_hp_change := 0

	# If both lanes are empty, nothing happens
	if player1Lane.is_empty() and player2Lane.is_empty():
		return [
			0,
			0
		]

	var diceResults = roll_combat_dice(int(player1Lane), int(player2Lane))
	var player1rolls = diceResults.player1_rolls;
	var player2rolls = diceResults.player2_rolls;

	player1rolls.sort()
	player1rolls.reverse()
	player2rolls.sort()
	player2rolls.reverse()

	# Equalize lengths
	while player1rolls.size() != player2rolls.size():
		if player1rolls.size() < player2rolls.size():
			p1_hp_change -= 1
			player2rolls.pop_back()
		else:
			p2_hp_change -= 1
			player1rolls.pop_back()

	# Compare dice rolls one by one
	for i in range(player1rolls.size()):
		var p1_roll = player1rolls[i]
		var p2_roll = player2rolls[i]

		if p1_roll > p2_roll:
			p2_hp_change -= 1
		elif p2_roll > p1_roll:
			p1_hp_change -= 1
		# Tie does nothing

	return [
		p1_hp_change,
		p2_hp_change
	]
func roll_combat_dice(player1Count: int, player2Count: int) -> Dictionary:
	if player1Count == 0 and player2Count == 0:
		return {
			"player1_rolls": [],
			"player2_rolls": []
		}

	var player1_rolls := []
	var player2_rolls := []

	for i in player1Count:
		player1_rolls.append(randi() % 6 + 1)

	for i in player2Count:
		player2_rolls.append(randi() % 6 + 1)

	return {
		"player1_rolls": player1_rolls,
		"player2_rolls": player2_rolls
	}

@rpc("any_peer", "call_local")
func handleAndDisableDeaths():
	var all_defeated := true  # Assume all are defeated unless we find one alive
	for player_id in GameManager.Players.keys():
		unlock_player_unit_selections(player_id)
		if GameManager.Players[player_id].health <= 0:
			if player_id not in deadPlayerIds:
				deadPlayerIds.append(player_id)
				alivePlayerCount -= 1
			lockin_player_unit_selections(player_id)
			if PlayerClickableButtons.has(player_id):
				for button in PlayerClickableButtons[player_id]:
					button.disabled = true
			if UIDictionary.has(player_id):
				for control in UIDictionary[player_id]:
					control.modulate = Color(0.5, 0.5, 0.5, 0.7)  # semi-transparent gray
			if ButtonsUsedToAttackGivenColorDictionary.has(GameManager.Players[player_id].color):
				for control in ButtonsUsedToAttackGivenColorDictionary[GameManager.Players[player_id].color]:
					control.disabled = true;
		else:
			all_defeated = false
			
	if all_defeated:
		show_game_over_screen.rpc()
		
	if(alivePlayerCount == 1):
		var alivePlayer
		for player in GameManager.Players:
			if player not in deadPlayerIds:
				alivePlayer = GameManager.Players[player]
				showVictoryScreen.rpc(alivePlayer.name)

func lockin_player_unit_selections(player_id):
	disable_given_player_end_turn_button.rpc_id(player_id)
	disable_given_player_reset_units_button.rpc_id(player_id)
func unlock_player_unit_selections(player_id):
	enable_given_player_end_turn_button.rpc_id(player_id)
	enable_given_player_reset_units_button.rpc_id(player_id)
	pass

@rpc("any_peer", "call_local")
func showVictoryScreen(playername):
	print(playername + " wins!")

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
	var my_id = multiplayer.get_unique_id()
	for player_id in Players.keys():
		if player_id == my_id:
			for button in PlayerClickableButtons[player_id]:
				hookup_button(button, Players[player_id].id, Players[player_id].color)
func hookup_button(button, player_multiplayer_id, color):
	var callable = Callable(self, "_on_lane_button_pressed_wrapper").bind(player_multiplayer_id, button.name)

	if not button.is_connected("pressed", callable):
		button.pressed.connect(callable)
func _on_lane_button_pressed_wrapper(player_multiplayer_id: int, button_name: String):
	if player_multiplayer_id != multiplayer.get_unique_id():
		return
	on_lane_button_pressed.rpc_id(1, multiplayer.get_unique_id(), button_name)
@rpc("any_peer")
func update_lane_label(color: int, suffix: String, new_lane_value: int, new_stored_value: int):
	var count_label = get_node_or_null("Player" + ConvertColorIntToColorString(color).capitalize() + "/" + suffix + "Count")
	if count_label and count_label is Label:
		count_label.text = str(new_lane_value)

	var stored_label = MapPlayerToStoredUnitContLabel(color)
	stored_label.text = str(new_stored_value)
@rpc("any_peer", "call_local")
func on_lane_button_pressed(player_id: int, button_name: String):
	print(str(multiplayer.get_unique_id()) + " is calling, " + str(player_id) + " is argument")
	if !GameManager.Players.has(player_id):
		return

	var color = GameManager.Players[player_id].color
	var stored_label = MapPlayerToStoredUnitContLabel(color)
	var stored_count = int(stored_label.text)

	if stored_count <= 0:
		return

	var suffix = button_name.substr(button_name.length() - 3) # "RoY", "BoR", etc.
	var count_label = get_node_or_null("Player" + ConvertColorIntToColorString(color).capitalize() + "/" + suffix + "Count")

	if count_label and count_label is Label:
		var current_val = int(count_label.text)
		count_label.text = str(current_val + 1)

	stored_label.text = str(stored_count - 1)

	# Broadcast to all peers to sync UI
	update_lane_label.rpc(color, suffix, int(count_label.text), stored_count - 1)
	update_lane_label(color, suffix, int(count_label.text), stored_count - 1)

@rpc("any_peer", "call_local")
func update_all_player_health(health_data: Dictionary):
	for player_id in health_data.keys():
		if GameManager.Players.has(player_id):
			GameManager.Players[player_id].health = health_data[player_id].health
			# Now update the health label on UI for this player
			var color = GameManager.Players[player_id].color
			var color_str = ConvertColorIntToColorString(color).capitalize()
			UpdatePlayerHealth(player_id)
func UpdatePlayerHealth(player):
		match GameManager.Players[player].color:
			0:
				$PlayerRed/LabelRedHP.text = str(GameManager.Players[player].health)
			1:
				$PlayerBlue/LabelBlueHP.text = str(GameManager.Players[player].health)
			2:
				$PlayerGreen/LabelGreenHP.text = str(GameManager.Players[player].health)
			3:
				$PlayerYellow/LabelYellowHP.text = str(GameManager.Players[player].health)
@rpc("any_peer", "call_local")
func UpdatePlayerHealthRpc(player):
		match GameManager.Players[player].color:
			0:
				$PlayerRed/LabelRedHP.text = str(GameManager.Players[player].health)
			1:
				$PlayerBlue/LabelBlueHP.text = str(GameManager.Players[player].health)
			2:
				$PlayerGreen/LabelGreenHP.text = str(GameManager.Players[player].health)
			3:
				$PlayerYellow/LabelYellowHP.text = str(GameManager.Players[player].health)

func _on_reset_units_button_pressed():
	var my_id = multiplayer.get_unique_id()
	reset_player_units.rpc_id(1, my_id)
@rpc("any_peer", "call_local")
func reset_all_player_units(Players):
	for player in Players.keys():
		reset_player_units.rpc(int(Players[player].id))
@rpc("any_peer", "call_local")
func reset_player_units(player_id: int):
	if not GameManager.Players.has(player_id):
		return
	var color = GameManager.Players[player_id].color
	reset_units_ui.rpc(color)
@rpc("any_peer", "call_local")
func reset_units_ui(color: int):
	var stored_label = MapPlayerToStoredUnitContLabel(color)
	stored_label.text = "3"

	var group_name = ConvertColorIntToColorString(color).capitalize()
	var player_node = get_node("Player" + group_name)

	for label in player_node.get_children():
		if label.name.ends_with("Count") and label.name != "StoredUnitCount" + group_name:
			if label is Label:
				label.text = "0"

func _on_end_turn_pressed():
	var my_id = multiplayer.get_unique_id()
	notify_end_turn.rpc_id(1, my_id)
@rpc("any_peer", "call_local")#allow host to call this on himself
func notify_end_turn(player_id: int):
	if player_id in ended_turn_players:
		return  # Avoid double-count
	ended_turn_players.append(player_id)
	lockin_player_unit_selections(player_id)

	# Check if all players are done
	if ended_turn_players.size() == alivePlayerCount:
		print("Resolving combat!")
		resolve_combat()
		reset_all_player_units.rpc(GameManager.Players)
		handleAndDisableDeaths.rpc()


@rpc("any_peer", "call_local")
func populate_UI_dictionary(Players):
	for player in Players.keys():
		UIDictionary[player] = ConvertColorToDisplayedUI(Players[player].color)
#have dictionary of each player with each unique clickable button of said player
@rpc("any_peer", "call_local")
func populate_clickable_button_dictionary(Players):
	for player in Players.keys():
		PlayerClickableButtons[player] = ConvertColorToClickableButtons(Players[player].color)
		
@rpc("any_peer", "call_local")
func populate_player_health_dictionary(Players):
	for player in Players.keys():
		PlayerClickableButtons[player] = ConvertColorToClickableButtons(Players[player].color)

@rpc("any_peer", "call_local")
func display_starting_hp(Players):
	for player in Players.keys():
		var labelControl = MapPlayerColorToHpLabel(Players[player].color)
		labelControl.text = str(Players[player].health)
		var storedUnitCount = MapPlayerToStoredUnitContLabel(Players[player].color)
		storedUnitCount.text = "3"
@rpc("any_peer", "call_local")
func display_player_names(Players):
	for player in Players.keys():
		var labelControl = MapPlayerToPlayernameLabel(Players[player].color)
		labelControl.text = Players[player].name

func ConvertColorIntToColorString(colorInt):
	match(colorInt):
		0:
			return "red"
		1:
			return "blue"
		2:
			return "green"
		3:
			return "yellow"
func ConvertColorToClickableButtons(colorInt):
	match(colorInt):
		0:
			return [$PlayerRed/ButtonRoB, $PlayerRed/ButtonRoG, $PlayerRed/ButtonRoY]
		1:
			return [$PlayerBlue/ButtonBoR, $PlayerBlue/ButtonBoG, $PlayerBlue/ButtonBoY]
		2:
			return [$PlayerGreen/ButtonGoR, $PlayerGreen/ButtonGoB, $PlayerGreen/ButtonGoY]
		3:
			return [$PlayerYellow/ButtonYoR, $PlayerYellow/ButtonYoG, $PlayerYellow/ButtonYoB]

func ConvertColorToDisplayedUI(colorInt):
	match(colorInt):
		0:
			return RedPlayerUI
		1:
			return BluePlayerUI
		2:
			return GreenPlayerUI
		3:
			return YellowPlayerUI
func ConvertLaneToPlayerColor(laneName):
	match(laneName):
		"RedBlue": 
			return [0, 1]
		"RedYellow": 
			return [0, 3]
		"RedGreen": 
			return [0, 2]
		"YellowBlue": 
			return [3, 1]
		"YellowGreen" : 
			return [3, 2]
		"BlueGreen": 
			return [1, 2]
func MapPlayerColorToHpLabel(colorInt):
	match(colorInt):
		0:
			return $PlayerRed/LabelRedHP
		1:
			return $PlayerBlue/LabelBlueHP
		2:
			return $PlayerGreen/LabelGreenHP
		3:
			return $PlayerYellow/LabelYellowHP
func MapPlayerToPlayernameLabel(colorInt):
	match(colorInt):
		0:
			return $PlayerRed/LabelRedPlayername
		1:
			return $PlayerBlue/LabelBluePlayername
		2:
			return $PlayerGreen/LabelGreenPlayername
		3:
			return $PlayerYellow/LabelYellowPlayername
func MapPlayerToStoredUnitContLabel(colorInt):
	match(colorInt):
		0:
			return $PlayerRed/StoredUnitCountRed
		1:
			return $PlayerBlue/StoredUnitCountBlue
		2:
			return $PlayerGreen/StoredUnitCountGreen
		3:
			return $PlayerYellow/StoredUnitCountYellow
func get_suffix_for_color(color: int, suffix: String) -> String:
	match color:
		0:  # Red
			return "Ro" + suffix
		1:  # Blue
			return "Bo" + suffix
		2:  # Green
			return "Go" + suffix
		3:  # Yellow
			return "Yo" + suffix
	return suffix  # fallback
func get_lane_initial_for_color(color: int) -> String:
	match color:
		0: return "R"
		1: return "B"
		2: return "G"
		3: return "Y"
	return ""
func get_player_id_by_color(color: int) -> int:
	for player_id in GameManager.Players:
		if GameManager.Players[player_id].color == color:
			return player_id
	return -1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
