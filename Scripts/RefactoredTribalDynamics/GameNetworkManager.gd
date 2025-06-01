# scripts/NetworkManager.gd
extends Node

class_name NetworkManager

signal player_connected(id)
signal player_disconnected(id)
signal server_started()
signal client_connected()
signal connection_failed()
signal connection_succeeded()

var is_host := false

func _ready():
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		
func _process(_delta):
	# Required to keep WebSocketMultiplayerPeer responsive
	if multiplayer.has_multiplayer_peer():
		multiplayer.get_multiplayer_peer().poll()

func host_server(port: int = 8910, max_clients: int = 8):
	var server = WebSocketMultiplayerPeer.new()
	var result = server.create_server(port)
	if result != OK:
		push_error("Failed to create WebSocket server: %s" % result)
		return

	multiplayer.set_multiplayer_peer(server)
	GameManager.set_multiplayer_authority(multiplayer.get_unique_id())

	is_host = true
	print("WebSocket server started on port %d" % port)
	emit_signal("server_started")

func connect_to_server(ip: String, port: int = 8910):
	var client = WebSocketMultiplayerPeer.new()
	var url = "ws://%s:%d" % [ip, port]
	var result = client.create_client(url)
	if result != OK:
		push_error("Failed to connect to WebSocket server: %s" % result)
		emit_signal("connection_failed")
		return

	multiplayer.set_multiplayer_peer(client)

	# Wait for connection confirmation
	await get_tree().create_timer(0.5).timeout
	if multiplayer.has_multiplayer_peer():
		emit_signal("connection_succeeded")
	else:
		emit_signal("connection_failed")

func leave_game():
	multiplayer.multiplayer_peer.close()
	multiplayer.set_multiplayer_peer(null)
	is_host = false

# --- Signal Handlers ---

func _on_peer_connected(id: int):
	#ask_host_if_game_started.rpc_id(Constants.HOST_ID)
	
	print("Player connected:", id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int):
	print("Player disconnected:", id)
	 # Whenever peer disconnects, remove them from your dictionary
	GameManager.remove_player(id)
	emit_signal("player_disconnected", id)

func _on_connection_failed():
	print("Connection failed")
	emit_signal("connection_failed")

func _on_connected_to_server():
	print("Connected to server!")
	emit_signal("connection_succeeded")

@rpc("authority")
func kick_player():
	if GameManager._is_server():
		return
	leave_game()

@rpc("any_peer")
func ask_host_if_game_started(requesting_player_id):
	if(GameManager.players[Constants.HOST_ID].gameState == 0):
		tell_player_game_is_in_progress.rpc_id(requesting_player_id, requesting_player_id)

@rpc("authority")
func tell_player_game_is_in_progress(playerId):
	deny_player_access.rpc_id(playerId)
@rpc("any_peer")
func deny_player_access():
	pass
