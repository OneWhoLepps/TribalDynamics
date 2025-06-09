extends Node

# Autoload this script as a singleton via Project Settings > AutoLoad

signal chat_updated
signal player_updated
signal player_added
signal player_removed(id)
signal player_modified
signal game_state_changed
signal game_manager_ready_toggled(toggled, id)
signal player_left_lobby(leaver_id: int, name: String)

enum ColorEnum { RED, BLUE, GREEN, YELLOW }
enum GameStates {LOBBY, INGAME, ENDED}
var color_names = ["Red", "Blue", "Green", "Yellow"]
var color_values = [Color(1, 0, 0), Color(0, 0.4, 1), Color(0, 1, 0), Color(1, 1, 0)]
var color_enums = [ColorEnum.RED, ColorEnum.BLUE, ColorEnum.GREEN, ColorEnum.YELLOW,]

var players: Dictionary = {}
var chat_history = []
var available_colors = []
var game_state = GameStates.LOBBY
var startingHealth = 10
var startingStoredUnits = 3

func _ready():
	for e in color_enums:
		available_colors.append(int(e))
#CHAT
#---------------------------------
func add_chat_message(message: String):
	chat_history.append(message)
	emit_signal(Constants.SIGNAL_CHAT_UPDATED)
	if _is_server():
		# Only host syncs chat to everyone
		sync_all_chat()
func add_chat_message_to_all_but_given(message: String, playerId):
	chat_history.append(message)
	emit_signal(Constants.SIGNAL_CHAT_UPDATED)
	if _is_server():
		# Only host syncs chat to everyone
		sync_all_chat_but_given(playerId)
func get_chat_history():
	return chat_history.duplicate()
#---------------------------------
#CHAT

func add_player(id: int, name: String, color: int):
	if players.has(id):
		return
	var playerTableSeatId = 1;
	if(!players.is_empty()):
		playerTableSeatId = players.size() + 1
	players[id] = {
		"id": id,
		"name": name,
		"color": color,#this is gonna turn into "race" or something similar
		"health": startingHealth,
		"stored_units": startingStoredUnits,
		"ready": false,
		"playerTableAssignment": playerTableSeatId
	}
	emit_signal(Constants.SIGNAL_PLAYER_ADDED, players[id])

func remove_player(id: int):
	var playerToRemove
	if players.has(id):
		playerToRemove = players[id].duplicate(true)
		players.erase(id)

func all_players_ready() -> bool:
	for player in players.values():
		if !player.get("ready", false):
			return false
	return true
func set_game_state(state: String):
	game_state = state
	emit_signal("game_state_changed")

func request_register_player(id: int, name: String, color_enum: int):
	add_player(id, name, color_enum)
	var join_message = "%s has joined with color %s." % [name, color_names[color_enum]]
	add_chat_message(join_message)
	sync_all_player_dictionaries()
	add_player_notify_clients.rpc(players[id])
	
func _is_not_server() -> bool:
	return not multiplayer.is_server()

func _is_server() -> bool:
	return multiplayer.is_server()

# RPCs
#--------------------------------------------------------------------------------------------------
@rpc("any_peer")
func add_player_notify_clients(player):
	emit_signal(Constants.SIGNAL_PLAYER_ADDED, player)
@rpc("any_peer")
func remove_player_notify_clients(player):
	emit_signal(Constants.SIGNAL_PLAYER_REMOVED, player["id"], player["name"])

#this is marked any_peer so that CLIENTS can call this w/ rpc_id(1)
#which means the host will be running this
@rpc("any_peer")
func client_request_register_player(id: int, name: String, color_enum: int):
	if _is_not_server():
		return
	request_register_player(id, name, color_enum)

#this is marked any_peer so that CLIENTS can call this w/ rpc_id(1)
#which means the host will be running this
@rpc("any_peer")
func request_removal_from_players_dictionary(leaver_id: int):
	if _is_not_server():
		return

	#here, we know the server is calling this
	if players.has(leaver_id):
		var name = players[leaver_id].name
		
		remove_player(leaver_id)
		notify_player_left(leaver_id, name)
		sync_all_player_dictionaries()
		#Tell the guy leaving to clear his whole state
		clear_client_state.rpc_id(leaver_id)

@rpc("any_peer")
func notify_player_left(leaver_id: int, name: String):
	emit_signal(Constants.SIGNAL_PLAYER_LEFT_LOBBY, leaver_id, name)
	
@rpc("authority")
func reset_all():
	players.clear()
	chat_history.clear()
	game_state = GameStates.LOBBY
	clear_client_state.rpc()
	
#this is marked as authority because only the server will call this
@rpc("authority")
func clear_client_state():
	if _is_server():
		return  # Host doesn't need this
	players.clear()
	chat_history.clear()
	game_state = GameStates.LOBBY
	
@rpc("authority")
func sync_all_chat_but_given(playerId):
	for player in players.values():
		if player.get("id") != playerId:
			receive_all_chat.rpc_id(player.get("id"), chat_history as Array[String])
@rpc("authority")
func sync_all_chat():
	receive_all_chat.rpc(chat_history as Array[String])
#each player will get a copy of the hosts chat from these 2
@rpc("any_peer", "call_local")
func receive_all_chat(all_chat):
	chat_history = all_chat.duplicate(true)
	emit_signal(Constants.SIGNAL_CHAT_UPDATED)
	
@rpc("authority")
func sync_all_player_dictionaries():
	var player_data = players
	var chat_data = chat_history
	receive_full_sync.rpc(player_data, chat_data)

#host calls this method, hence why its tagged authority
#for all players in the rpc that arent the host, make their game states sync
@rpc("authority")
func receive_full_sync(all_players: Dictionary, chat_data):
	if _is_server():
		print("server is firing receieve full sync")
		return
	print("client is receiving full sync")
	players = all_players
	chat_history = chat_data

@rpc("any_peer")
func player_toggled_ready(id: int):
	if _is_not_server():
		return
		
	var toggle = false;
	var playerguy = players[id]
	# Toggle logic
	if playerguy.ready == false:
		toggle = true
		players[id].ready = toggle
		sync_all_player_dictionaries()
		#emit_signal("game_manager_ready_toggled", true)
	else:
		players[id].ready = false
		sync_all_player_dictionaries()
		#emit_signal("game_manager_ready_toggled", false)
	update_toggled_ui.rpc(toggle, id)

@rpc("any_peer", "call_local")
func update_toggled_ui(toggled, id):
	emit_signal("game_manager_ready_toggled", toggled, id)

@rpc("authority", "call_local")
func restart_game():
	# Reset player health
	for player_id in GameManager.players:
		GameManager.players[player_id].health = 10

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
	var overlay := new_game_scene.get_node("OverlayContainer")
	if overlay:
		overlay.visible = false
