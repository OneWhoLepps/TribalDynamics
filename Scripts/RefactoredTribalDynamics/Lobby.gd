extends Control

@onready var player_list = $VBoxContainer
@onready var chatbox = $Chatbox
var has_initialized_players = false

# Called when the node enters the scene tree for the first time.
func _ready():
	GameManager.connect(Constants.SIGNAL_CHAT_UPDATED, Callable(self, "_refresh_chatbox"))
	GameManager.connect(Constants.SIGNAL_PLAYER_LEFT_LOBBY, Callable(self, "_on_player_left_lobby"))
	GameManager.connect(Constants.SIGNAL_PLAYER_ADDED, Callable(self, "add_player_to_player_list"))
	GameManager.connect(Constants.SIGNAL_PLAYER_REMOVED, Callable(self, "remove_player_from_player_list"))
	#need to hookup a modify signal when everything else is settled
	#GameManager.connect(Constants.SIGNAL_PLAYER_MODIFIED, Callable(self, "modify_player_in_list"))
	_introduce_player_list()
	_refresh_chatbox()

func _introduce_player_list():
	var player_entry_scene = preload("res://Scenes/RefactoredTribalDynamics/PlayerEntryInLobby.tscn")
	var sorted_ids = GameManager.players.keys()
	sorted_ids.sort()  # Sort by ID

	# Add or update existing entries
	for id in sorted_ids:
		var player = GameManager.players[id]
		var entry = player_entry_scene.instantiate()
		entry.setup(player)
		entry.connect("leave_pressed", Callable(self, "_on_player_leave_pressed"))
		entry.connect("ready_pressed", Callable(self, "_on_player_ready_pressed"))
		player_list.add_child(entry)
	turn_off_start_game.rpc_id(Constants.HOST_ID)

func add_player_to_player_list(player):
	var player_entry_scene = preload("res://Scenes/RefactoredTribalDynamics/PlayerEntryInLobby.tscn")
	var entry = player_entry_scene.instantiate()
	entry.setup(player)
	entry.connect("leave_pressed", Callable(self, "_on_player_leave_pressed"))
	entry.connect("ready_pressed", Callable(self, "_on_player_ready_pressed"))
	player_list.add_child(entry)
	check_for_all_players_ready.rpc_id(Constants.HOST_ID)
	
func remove_player_from_player_list(player):
	for child in player_list.get_children():
		if child.has_method("get_player_id") and child.get_player_id() == player.id:
			child.queue_free()
			break

func _refresh_chatbox():
	chatbox.clear()
	for message in GameManager.get_chat_history():
		chatbox.add_item(message)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not has_initialized_players and multiplayer.get_unique_id() != 0:
		has_initialized_players = true
		
func _on_player_ready_pressed(id: int):
	# Send ready toggle request to host
	if GameManager._is_not_server():
		GameManager.player_toggled_ready.rpc_id(Constants.HOST_ID, id)
	else:
		# If host clicks it (for self), apply directly
		GameManager.player_toggled_ready(id)
	#send rpc to host to turn on begin game button if all players ready
	check_for_all_players_ready.rpc_id(Constants.HOST_ID)

func _on_player_leave_pressed(id: int):
	if (GameManager._is_not_server()):
		#Client tells server that someone is leaving
		GameManager.request_removal_from_players_dictionary.rpc_id(Constants.HOST_ID, multiplayer.get_unique_id())
		await get_tree().create_timer(0.1).timeout
		#dispose the scene by force because if we dont the lobby control
		#doesnt leave... fucking weird
		check_for_all_players_ready.rpc_id(Constants.HOST_ID)
		return_to_main()
		GameNetworkManager.leave_game()
	else:
		var playersToBoot = GameManager.players.duplicate(true)
		GameManager.reset_all()
		for peer_id in multiplayer.get_peers():
			return_to_main.rpc_id(peer_id)
			#add some buffer wait so that players can get kicked to the lobby
			await get_tree().create_timer(0.2).timeout
		kick_all_non_host_players(playersToBoot)
		
		#after host sends everyone to main and removes them from network connection
		#do it to himself
		GameNetworkManager.leave_game()
		return_to_main()


func _on_player_left_lobby(leaver_id: int, name: String):
	notify_player_left.rpc(leaver_id)
	GameManager.add_chat_message_to_all_but_given(name + " has left the game.", leaver_id)

#remove the player thats leaving from list of players in this lobby
@rpc("any_peer", "call_local")
func notify_player_left(id):
	for child in player_list.get_children():
		if child.has_method("get_player_id") and child.get_player_id() == id:
			child.queue_free()
			break

@rpc("any_peer", "call_local")
func return_to_main():
	get_tree().change_scene_to_file(Constants.MAIN_SCENE_PATH)
	
func kick_all_non_host_players(playersToBoot):
	for player in playersToBoot:
			if playersToBoot[player].id == Constants.HOST_ID:
				continue
			GameNetworkManager.kick_player.rpc_id(playersToBoot[player].id)

@rpc("any_peer", "call_local")
func turn_on_start_game():
	$StartGameButton.disabled = false;
@rpc("any_peer", "call_local")
func turn_off_start_game():
	$StartGameButton.disabled = true;

@rpc("any_peer", "call_local")
func check_for_all_players_ready():
	if(GameManager.all_players_ready()):
		turn_on_start_game.rpc_id(Constants.HOST_ID)
	else:
		turn_off_start_game.rpc_id(Constants.HOST_ID)

func _on_start_game_button_pressed():
	#move all players into board game
	send_to_board_game.rpc()
	#update each players game state from lobby to in game
	pass # Replace with function body.

@rpc("any_peer", "call_local")
func send_to_board_game():
	get_tree().change_scene_to_file(Constants.BOARD_GAME_PATH)
