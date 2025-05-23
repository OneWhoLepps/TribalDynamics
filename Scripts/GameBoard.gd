extends Node

var RedPlayerUI
var BluePlayerUI
var GreenPlayerUI
var YellowPlayerUI
var UIDictionary

var PlayerClickableButtons
var PlayernameTextDictionary
var PlayerHpLabelDictionary
const minimumStoredUnitCount = 0
var ended_turn_players = []

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
	
	populate_UI_dictionary.rpc(GameManager.Players)
	assign_UI_to_players.rpc(GameManager.Players)
	populate_clickable_button_dictionary.rpc(GameManager.Players)
	hookup_laneButton_handlers.rpc(GameManager.Players)
	display_starting_hp.rpc(GameManager.Players)
	display_player_names.rpc(GameManager.Players)
	$ResetUnitsButton.pressed.connect(_on_reset_units_button_pressed)
	#$EndTurn.pressed.connect(_on_end_turn_pressed)

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

#func _on_end_turn_pressed():
	#var my_id = multiplayer.get_unique_id()
	#notify_end_turn.rpc_id(1, my_id)  # Send to host
#
#@rpc("any_peer", "call_local")
#func notify_end_turn(player_id: int):
	#if player_id in ended_turn_players:
		#return  # Avoid double-count
#
	#ended_turn_players.append(player_id)
#
	## Check if all players are done
	#if ended_turn_players.size() == GameManager.Players.size():
		#print("Resolving combat!")
		#resolve_combat()
		#reset_lane_labels.rpc()
		#reset_stored_units.rpc()

func resolve_combat():
	if not multiplayer.is_server():
		return  # Only host runs this

	var lane_prefixes = ["R", "B", "G", "Y"]
	var combat_data = {}

	for player_id in GameManager.Players:
		var color = GameManager.Players[player_id].color
		var color_str = ConvertColorIntToColorString(color).capitalize()
		var prefix = "Player" + color_str + "/"

		for suffix in lane_prefixes:
			if get_lane_initial_for_color(color) == suffix:
				continue  # Skip player's own lane
			var label_name = prefix + get_suffix_for_color(color, suffix) + "Count"
			var label_node = get_node(label_name)
			var unit_count = int(label_node.text)
			print("Player", player_id, "lane", suffix, "units:", unit_count)  # DEBUG

			if unit_count > 0:
				if not combat_data.has(suffix):
					combat_data[suffix] = {}
				combat_data[suffix][player_id] = []
				for _i in unit_count:
					var rollResult = randi() % 6 + 1
					combat_data[suffix][player_id].append(rollResult)
					print("%s  Rolled", rollResult)  # DEBUG

	# Roll resolution
	var hp_changes := {}
	for suffix in combat_data.keys():
		var rolls = combat_data[suffix]
		for p in rolls:
			rolls[p].sort_custom(func(a, b): return b - a)

		var ids = rolls.keys()
		var sizes = []
		for id in ids:
			sizes.append(rolls[id].size())
		var shortest = sizes.min()

		for i in shortest:
			var sorted = []
			for id in ids:
				sorted.append({ "id": id, "val": rolls[id][i] })
			sorted.sort_custom(func(a, b): return b["val"] - a["val"])

			if sorted.size() < 2 or sorted[0]["val"] == sorted[1]["val"]:
				continue
			var loser_id = sorted[1]["id"]
			hp_changes[loser_id] = hp_changes.get(loser_id, 0) + 1

	# Apply and broadcast new health values
	for player_id in GameManager.Players:
		var lost_hp = hp_changes.get(player_id, 0)
		GameManager.Players[player_id].health -= lost_hp

	# Send to all clients
	var new_health := {}
	for player_id in GameManager.Players:
		new_health[player_id] = GameManager.Players[player_id].health

	update_all_player_health.rpc(new_health)
	ended_turn_players.clear()

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

@rpc("any_peer", "call_local")
func reset_lane_labels():
	for player_id in UIDictionary.keys():
		for control in UIDictionary[player_id]:
			if control is Label and "Count" in control.name and "Stored" not in control.name:
				control.text = "0"

@rpc("any_peer", "call_local")
func reset_stored_units():
	for player_id in GameManager.Players.keys():
		var color = GameManager.Players[player_id].color
		var stored_label = MapPlayerToStoredUnitContLabel(color)
		stored_label.text = "3"

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

@rpc("any_peer")
func update_all_player_health(health_data: Dictionary):
	for player_id in health_data.keys():
		if GameManager.Players.has(player_id):
			GameManager.Players[player_id].health = health_data[player_id]
			# Now update the health label on UI for this player
			var color = GameManager.Players[player_id].color
			var color_str = ConvertColorIntToColorString(color).capitalize()
			var label_path = "Player" + color_str + "/HealthLabel"  # Adjust to your node path
			if has_node(label_path):
				var health_label = get_node(label_path)
				health_label.text = str(health_data[player_id])


func _on_reset_units_button_pressed():
	var my_id = multiplayer.get_unique_id()
	reset_player_units.rpc_id(1, my_id)
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
