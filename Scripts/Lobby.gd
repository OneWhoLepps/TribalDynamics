# Lobby.gd
extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost

@export var PORT = 7000
@export var MAX_CONNECTIONS = 4

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}

# This is the local player info.
var player_info = {"name": "Name"}
var players_loaded = 0

# Remote function to add player name to the list
@rpc
func add_player_to_list(player_name):
	players.append(player_name)
	update_player_list_ui()

# Update the UI to display the player names
func update_player_list_ui():
	var player_list_node = $PlayerList  # Assuming you have a node like a VBoxContainer for player names
	player_list_node.clear()
	for player in players:
		var label = Label.new()
		label.text = player
		player_list_node.add_child(label)

func _ready():
	# Only run this in the HostedLobby scene
	if get_tree().current_scene.name == "HostedLobby":
		multiplayer.peer_connected.connect(_on_player_connected)
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_ok)
		multiplayer.connection_failed.connect(_on_connected_fail)
		multiplayer.server_disconnected.connect(_on_server_disconnected)

		var player_list = get_node("PlayerList/VBoxContainer")  # Adjusted path
		if player_list:
			Lobby._update_player_list(Lobby.player_info, player_list)  # Initial call to add the local player
		else:
			print("PlayerList/VBoxContainer not found after switching scenes.")
	else:
		print("Not in HostedLobby, skipping multiplayer setup.")

func _update_vbox_container(vbox_container):
	if vbox_container:
		print("VBoxContainer found. Initializing player list.")
		# Update player list with current player info
		_update_player_list(Lobby.player_info, vbox_container)
	else:
		print("node not found")

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$/root/Game.start_game()
			players_loaded = 0

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	
func _on_network_peer_connected(id):
	print("Player connected: ", id)

func _on_network_peer_disconnected(id):
	print("Player disconnected: ", id)

	
# Function to update player list
func _update_player_list(player_info, vbox):
	# Create a new label for the connected player
	var player_label = Label.new()
	player_label.text = player_info.name
	
	# Add the label to the VBoxContainer
	vbox.add_child(player_label)


func _on_go_back_button_down():
	if multiplayer.multiplayer_peer:  # Ensure there's an active multiplayer peer
		if multiplayer.is_server():
			 # Disconnect all peers if you're the server
			disconnect_all_peers()
		else:
			# If you're a client, disconnect from the host
			multiplayer.multiplayer_peer.disconnect_from_host()
			multiplayer.multiplayer_peer = null
			print("Disconnected from server.")

		# Reset the Lobby state
		Lobby.players.clear()
		Lobby.players_loaded = 0
		print("Cleared player list and reset lobby state.")

		# Go back to the main menu scene
		get_tree().change_scene_to_file("res://Scenes/StartMenu.tscn")
	else:
		print("No active multiplayer session to disconnect from.")
func disconnect_all_peers():
	if multiplayer.is_server():
		var peers = multiplayer.get_peers()  # Get the list of connected peers
		
		for peer_id in peers:
			multiplayer.disconnect_peer(peer_id)  # Disconnect each peer
		
		# Optionally, you can stop the server afterward
		multiplayer.multiplayer_peer = null
		print("All peers disconnected, server stopped.")

