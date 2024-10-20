extends Node


func _ready():
	$JoinGameButton.connect("pressed", Callable(self, "_on_JoinGame_pressed"))

	# Function that gets called when the "Join Game" button is pressed
func _on_JoinGame_pressed():
	get_tree().change_scene_to_file("res://scenes/joinServer.tscn")

func _on_host_game_button_pressed():
	# Call the function to create the server
	var error = create_game()
	if error != OK:
		print("Error starting server: ", error)
		return

	var lobby_scene = load("res://Scenes/HostedLobby.tscn")
	if lobby_scene == null:
		print("Failed to load lobby scene.")
		return

	# Change the scene to the new instance
	var change_scene_result = get_tree().change_scene_to_file("res://Scenes/HostedLobby.tscn")
	if change_scene_result != OK:
		print("Failed to change to the new scene: ", change_scene_result)

	# Connect the player_connected signal to update the player list
	Lobby.player_connected.connect(_on_player_connected)
	
	 # Call this to add the existing player to the list after switching to the new scene
	

func _on_player_connected(peer_id, player_info):
	var player_list = get_tree().current_scene.get_node("PlayerList/VBoxContainer")  # Correct path
	if player_list:
		# Call the update function
		Lobby._update_player_list(player_info, player_list)  # Use the correct namespace if necessary

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(Lobby.PORT, Lobby.MAX_CONNECTIONS)
	if error != OK:
		print("Failed to create server: ", error)  # Print the actual error code
		return error
	
	multiplayer.multiplayer_peer = peer

	Lobby.players[1] = Lobby.player_info
	Lobby.player_connected.emit(1, Lobby.player_info)
	return OK
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_exit():
	get_tree().quit()
