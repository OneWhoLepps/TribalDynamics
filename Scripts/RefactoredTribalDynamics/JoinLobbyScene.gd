extends Control

@onready var name_input = $HBoxContainer/PlayerNameInput
@onready var tribe_picker = $HBoxContainer/TribePicker
@onready var ip_input = $HBoxContainer/IPInput
@onready var join_button = $HBoxContainer/JoinButton
@onready var tribe_preview = $HBoxContainer/TribePreview

func _ready():
	for name in GameManager.tribe_names:
		tribe_picker.add_item(name)

func _on_JoinButton_pressed():
	var name = name_input.text.strip_edges()
	var ip = ip_input.text.strip_edges()
	var tribe_index = tribe_picker.get_selected_id()
	
	if name == "":
		print("Missing info.")
		return

	var net = get_node("/root/GameNetworkManager")
	net.connect_to_server(ip)

	net.connection_succeeded.connect(func():
		print("Connection succeeded")

		await _wait_for_connection()

		if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			print("Connection failed after wait.")
			return
		
		GameManager.set_multiplayer_authority(1)
		#after peer is connected, ask the server to register the joining player
		GameManager.client_request_register_player.rpc_id(Constants.HOST_ID, multiplayer.get_unique_id(), name, GameManager.TribeEnum.values()[tribe_index])
		#put in some arbitrary wait so that request and sync back works
		await get_tree().create_timer(0.1).timeout
		get_tree().change_scene_to_file(Constants.LOBBY_SCENE_PATH)
	)


func _wait_for_connection() -> void:
	while multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await get_tree().create_timer(0.1).timeout


func _on_return_to_main_pressed():
	get_tree().change_scene_to_file(Constants.MAIN_SCENE_PATH)

func _on_tribe_picker_item_selected(index):
	var tribe = GameManager.tribe_enum[index]
	tribe_preview.texture = GameManager.TRIBE_GENERAL_TEXTURES[tribe]
