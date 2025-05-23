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


@rpc("any_peer", "call_local")
func assign_UI_to_players(Players):
	#dictionary is key: the unique multiplayer id
	#with values name, health and color
	#logic to disable all buttons that arent yours
	for i in UIDictionary.keys():
		if i == multiplayer.get_unique_id():
			for control in UIDictionary[i]:
				if control is Label:
					control.visible = true
				else:
					control.visible = true
					control.disabled = false

#foreach dictionary entry in PlayerClickableButtons setup click handler for that player
@rpc("any_peer", "call_local")
func hookup_laneButton_handlers(Players):
	for player in Players.keys():
		for button in PlayerClickableButtons[player]:
			hookup_button(button, Players[player].id, Players[player].color)
	

func hookup_button(button, player_multiplayer_id, color):
	if button.is_connected("pressed", Callable(self, "_on_lane_button_pressed")):
		return # prevent double connection

	button.pressed.connect(
		func():
			if player_multiplayer_id != multiplayer.get_unique_id():
				return # only let the local player use their own buttons

			var stored_label = MapPlayerToStoredUnitContLabel(color)
			var stored_count = int(stored_label.text)

			if stored_count <= 0:
				return # don't allow click if no units left

			# Find the label next to this button and increment it
			var suffix = button.name.substr(button.name.length() - 2) # e.g., "RoY", "BoG"
			var count_label_name = suffix + "Count" # e.g., "RoYCount"
			var count_label = button.get_parent().get_node(count_label_name)

			if count_label and count_label is Label:
				var current_val = int(count_label.text)
				count_label.text = str(current_val + 1)

			# Decrease stored unit count
			stored_label.text = str(stored_count - 1)
	)

func connect_buttons(group_name):
	var group_node = $group_name # Use $RedButtons, etc.
	for button in group_node.get_children():
		button.pressed.connect(_on_player_button_pressed.bind(button.name))

func _on_player_button_pressed(button_name):
	var id = multiplayer.get_unique_id()
	GameManager.HandleButtonPress.rpc_id(1, id, button_name)

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
