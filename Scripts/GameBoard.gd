extends Node

var RedPlayerButtons
var BluePlayerButtons
var GreenPlayerButtons
var YellowPlayerButtons

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
	
	assign_buttons_to_players()

func assign_buttons_to_players():
	var ids = GameManager.Players.keys()
	ids.sort()

	var color_button_map = [
		RedPlayerButtons,
		BluePlayerButtons,
		GreenPlayerButtons,
		YellowPlayerButtons,
	]

#logic to disable all buttons that arent yours
	for i in range(min(ids.size(), color_button_map.size())):
		var player_id = ids[i]

		if player_id == multiplayer.get_unique_id():
			for btn in color_button_map[i]:
				btn.disabled = false

func connect_buttons(group_name):
	var group_node = $group_name # Use $RedButtons, etc.
	for button in group_node.get_children():
		button.pressed.connect(_on_player_button_pressed.bind(button.name))

func _on_player_button_pressed(button_name):
	var id = multiplayer.get_unique_id()
	GameManager.HandleButtonPress.rpc_id(1, id, button_name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
