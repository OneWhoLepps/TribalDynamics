extends Node

var RedPlayerButtons
var BluePlayerButtons
var GreenPlayerButtons
var YellowPlayerButtons
var ButtonDictionary

# Called when the node enters the scene tree for the first time.
func _ready():
	RedPlayerButtons = [
		$PlayerRed/ButtonRoY, 
		$PlayerRed/ButtonRoB, 
		$PlayerRed/ButtonRoG
	]
	BluePlayerButtons = [
		$PlayerBlue/ButtonBoY, 
		$PlayerBlue/ButtonBoR, 
		$PlayerBlue/ButtonBoG
		]
	GreenPlayerButtons = [
		$PlayerGreen/ButtonGoY, 
		$PlayerGreen/ButtonGoB, 
		$PlayerGreen/ButtonGoR
	]
	YellowPlayerButtons = [
		$PlayerYellow/ButtonYoR, 
		$PlayerYellow/ButtonYoB, 
		$PlayerYellow/ButtonYoG
	]
	ButtonDictionary = {}
	
	populate_button_dictionary.rpc(GameManager.Players)
	assign_buttons_to_players.rpc(GameManager.Players)

@rpc("any_peer", "call_local")
func assign_buttons_to_players(Players):
	#dictionary is key: the unique multiplayer id
	#with values name, health and color
#logic to disable all buttons that arent yours
	for i in ButtonDictionary.keys():
		if i == multiplayer.get_unique_id():
			for btn in ButtonDictionary[i]:
				btn.disabled = false

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

func ConvertColorIntToButtonsAllotted(colorInt):
	match(colorInt):
		0:
			return RedPlayerButtons
		1:
			return BluePlayerButtons
		2:
			return GreenPlayerButtons
		3:
			return YellowPlayerButtons

@rpc("any_peer", "call_local")
func populate_button_dictionary(Players):
	for player in Players.keys():
		ButtonDictionary[player] = ConvertColorIntToButtonsAllotted(Players[player].color)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
