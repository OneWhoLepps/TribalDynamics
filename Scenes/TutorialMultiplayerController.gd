extends Control

@export var Address = "127.0.0.1"
@export var port = 8910

@onready var chatbox = $ReadonlyChatbox
@onready var name_input = $LineEdit
@onready var start_button = $StartGame

var peer

func _ready():
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	start_button.disabled = true

func _on_host_game_button_down():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 4)
	if error != OK:
		print("Cannot host: ", error)
		return

	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	start_button.disabled = false

	var my_id = multiplayer.get_unique_id()
	SendPlayerInformation(name_input.text, my_id)

func _on_join_game_button_down():
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

func _on_start_game_button_down():
	StartGame.rpc()

@rpc("any_peer", "call_local")
func StartGame():
	var scene = load("res://Scenes/GameBoard.tscn").instantiate()
	get_tree().root.add_child(scene)

func peer_connected(id):
	print("Player Connected: ", id)

func peer_disconnected(id):
	print("Player Disconnected: ", id)

func connected_to_server():
	print("Connected to server!")
	var my_id = multiplayer.get_unique_id()
	SendPlayerInformation.rpc_id(1, name_input.text, my_id)

@rpc("any_peer")
func SendPlayerInformation(name: String, id: int):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {"name": name, "id": id}
		var message = "%s has joined the lobby." % name
		GameManager.Chatbox.append(message)
		refresh_chatbox()

		# Broadcast to all players
		AddChatMessage.rpc(message)

		# Also send full chat history to the new player
		if multiplayer.is_server():
			SendFullChatHistory.rpc_id(id, GameManager.Chatbox)

@rpc("any_peer")
func AddChatMessage(message: String):
	GameManager.Chatbox.append(message)
	refresh_chatbox()

@rpc("authority")
func SendFullChatHistory(history: Array):
	GameManager.Chatbox = history.duplicate()
	refresh_chatbox()

func add_chat_message(message: String):
	GameManager.Chatbox.append(message)
	AddChatMessage.rpc(message)
	refresh_chatbox()

func refresh_chatbox():
	chatbox.clear()
	for line in GameManager.Chatbox:
		chatbox.add_item(line)

func connection_failed():
	print("Connection failed!")
