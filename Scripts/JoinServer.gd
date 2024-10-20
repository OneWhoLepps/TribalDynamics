extends Node2D

# Variables to store player info and IP address
var player_name = ""
var server_ip = ""

# Called when the scene is ready
func _ready():
	# Connect the button's signal to the join_server function
	$JoinGameButton.connect("pressed", Callable(self, "_on_Join_pressed"))

# Triggered when the "Join" button is pressed
func _on_Join_pressed():
	# Get input values
	player_name = $PlayerNameTextbox.text
	server_ip = $ServerIPTextbox.text
	
	if player_name == "" or server_ip == "":
		print("Please enter both a name and an IP address.")
		return
	
	# Try to connect to the server
	var result = ENetMultiplayerPeer.new()
	result.create_client(server_ip, 7777)  # Assuming port 7777
	get_tree().network_peer = result
	
	# Check if connection is successful
	if get_tree().multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		print("Successfully connected!")
		# Move to the hosted lobby and update player list
		get_tree().change_scene("res://scenes/hostedlobby.tscn")
		rpc("add_player_to_list", player_name)
	else:
		print("Failed to connect.")

func _on_go_back_button_down():
		get_tree().change_scene_to_file("res://Scenes/StartMenu.tscn")
