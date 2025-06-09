extends Control

@onready var name_input = $HBoxContainer/PlayerNameInput
@onready var color_picker = $HBoxContainer/ColorPicker
@onready var ip_input = $HBoxContainer/IPInput
@onready var join_button = $HBoxContainer/JoinButton
@onready var color_preview = $HBoxContainer/ColorPreview

var color_enums = [GameManager.ColorEnum.RED, GameManager.ColorEnum.BLUE, GameManager.ColorEnum.GREEN, GameManager.ColorEnum.YELLOW]

func _ready():
	for name in GameManager.color_names:
		color_picker.add_item(name)
	color_picker.connect("item_selected", _on_color_selected)
	_on_color_selected(color_picker.get_selected_id()) # initial preview

func _on_color_selected(index):
	color_preview.color = GameManager.color_values[index]

func _on_JoinButton_pressed():
	var name = name_input.text.strip_edges()
	var ip = ip_input.text.strip_edges()
	var color_index = color_picker.get_selected_id()
	var color_enum = color_enums[color_index]
	
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
		GameManager.client_request_register_player.rpc_id(Constants.HOST_ID, multiplayer.get_unique_id(), name, color_enum)
		#put in some arbitrary wait so that request and sync back works
		await get_tree().create_timer(0.1).timeout
		get_tree().change_scene_to_file(Constants.LOBBY_SCENE_PATH)
	)


func _wait_for_connection() -> void:
	while multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await get_tree().create_timer(0.1).timeout


func _on_return_to_main_pressed():
	get_tree().change_scene_to_file(Constants.MAIN_SCENE_PATH)
