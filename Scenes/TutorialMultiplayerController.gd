extends Control

@export var Address = "127.0.0.1"
@export var port = 8910
var peer

# Called when the node enters the scene tree for the first time.
func _ready():
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.disconnect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_host_game_button_down():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 4)
	if error != OK:
		print("cannot host: " + error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	SendPlayerInformation($LineEdit.text, multiplayer.get_unique_id())
	print("Waiting for players!")

func _on_join_game_button_down():
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

@rpc("any_peer", "call_local")
func StartGame():
	var scene = load("res://Scenes/GameBoard.tscn").instantiate()
	get_tree().root.add_child(scene)

func _on_start_game_button_down():
	StartGame.rpc()
	#.rpc_id only calls the rpc on that 1 person
	#.rpc calls it for everyone

#gets called on server and clients
func peer_connected(id):
	print("Player Connected " + str(id))

#gets called on server and clients
func peer_disconnected(id):
	print("Player Disonnected " + str(id))

#gets called from clients
func connected_to_server():
	print("connected to server!")
	#when player other than host connects to server, update list with their name
	#and id
	SendPlayerInformation.rpc_id(1, $LineEdit.text, multiplayer.get_unique_id())
	
@rpc("any_peer")
#update player info to game manager if client or server
func SendPlayerInformation(name, id):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			"name" : name,
			"id": id,
		}
	
	if multiplayer.is_server():
		for i in GameManager.Players:
			SendPlayerInformation.rpc(GameManager.Players[i].name, i)
		

#gets called from clients
func connection_failed():
	print("connection failed!")
