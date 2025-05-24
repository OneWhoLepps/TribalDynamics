extends Control

@export var Address = "127.0.0.1"
@export var port = 8910

@onready var chatbox = $ReadonlyChatbox
@onready var name_input = $LineEdit
@onready var start_button = $StartGame
@onready var ip_input = $IPTextField


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
	HostGame(name_input.text, my_id, GameManager.RED)

func HostGame(name, id, color):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			"name": name,
			 "id": id,
			 "color": color,
			 "health": 10,
			"storedUnitCount": 3
			}

		var message = "%s has joined the lobby with color %s." % [name, color]
		GameManager.Chatbox.append(message)
		refresh_chatbox()

func _on_join_game_button_down():
	peer = ENetMultiplayerPeer.new()
	#swap to this when debugging
	#peer.create_client(Address, port)
	peer.create_client(ip_input.text, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

func _on_start_game_button_down():
	if multiplayer.is_server():
		start_game.rpc()

@rpc("any_peer", "call_local")
func start_game():
	var scene = preload("res://Scenes/GameBoard.tscn").instantiate()
	scene.name = "GameBoard"
	get_tree().root.add_child(scene)

	#start_game_on_clients.rpc()
#
#@rpc("any_peer")
#func start_game_on_clients():
	#var scene = preload("res://Scenes/GameBoard.tscn").instantiate()
	#scene.name = "GameBoard"
	#get_tree().root.add_child(scene)

@rpc("any_peer", "call_local")
func RemoveColorFromUnassignedList():
	GameManager.OpenColors.pop_front()

func peer_connected(id):
	print("Player Connected: ", id)

func peer_disconnected(id):
	print("Player Disconnected: ", id)

func connected_to_server():
	print("Connected to server!")
	var my_id = multiplayer.get_unique_id()
	#call request join on host client
	RequestJoin.rpc_id(1, name_input.text, multiplayer.get_unique_id())

@rpc("any_peer")
func RequestJoin(name: String, id: int):
	if !multiplayer.is_server():
		return
		
	if GameManager.OpenColors.is_empty():
		print("No colors left!")
		return

	#server pops a color
	var assigned_color = GameManager.OpenColors[0]
	GameManager.OpenColors.pop_front()

	#server adds join message to its own chatbox 
	#and adds player to its playerlist
	var join_msg = "%s has joined the lobby with color %s." % [name, assigned_color]
	GameManager.Chatbox.append(join_msg)
	AddPlayerToGameManager(id, name, assigned_color)
	
	#clients call requestjoin, and server executes
	
	#send server chat history to client that calls this
	SendFullChatHistory.rpc(GameManager.Chatbox)
	#update server's chathistory
	UpdateChatHistory(GameManager.Chatbox)
	
	
	SendAvailableColors.rpc(GameManager.OpenColors)
	SendAllPlayerData.rpc(GameManager.Players)

@rpc("authority")
func SendFullChatHistory(history: Array):
	UpdateChatHistory(history)
	
@rpc("authority")
func SendAllPlayerData(players: Dictionary):
	_sync_all_players(players)

@rpc("authority")
func SendAvailableColors(colors: Array):
	GameManager.OpenColors = colors.duplicate()

@rpc("any_peer")
func SendPlayerInformation(name: String, id: int, color: int):
	AddPlayerToGameManager(id, name, color)

func UpdateChatHistory(history: Array):
	GameManager.Chatbox = history.duplicate()
	refresh_chatbox()

func AddPlayerToGameManager(id: int, name: String, color: int):
	GameManager.Players[id] = {
		"id": id,
		"name": name,
		"color": color,
		"health": 10,
		"storedUnitCount": 3
	}

func _sync_all_players(players: Dictionary):
	GameManager.Players.clear()
	for id in players:
		var player = players[id]
		GameManager.Players[id] = {
			"name": player["name"],
			"color": player["color"],
			"health": player["health"],
			"unitsStored": player["storedUnitCount"],
			"id": player["id"]
		}

func refresh_chatbox():
	chatbox.clear()
	for line in GameManager.Chatbox:
		chatbox.add_item(line)

func connection_failed():
	print("Connection failed!")


func _on_button_button_down():
	if(multiplayer.get_unique_id() == 1):
		request_restart_game.rpc_id(1)  # Call to authority (usually peer 1)
	
@rpc("any_peer", "call_local")
func request_restart_game():
	restart_game.rpc()

@rpc("any_peer", "call_local")
func restart_game():
	# Reset player health
	for player_id in GameManager.Players:
		GameManager.Players[player_id].health = 10

	# Queue-free old GameBoard scene
	for child in get_tree().root.get_children():
		if child.name == "GameBoard":
			child.queue_free()

	await get_tree().process_frame  # Wait until scene is really freed
	await get_tree().process_frame  # Extra frame helps ensure it's gone

	# Instantiate a new GameBoard
	var new_game_scene = preload("res://Scenes/GameBoard.tscn").instantiate()
	new_game_scene.name = "GameBoard"
	get_tree().root.add_child(new_game_scene)
