extends Control

@onready var name_input = $PlayerNameInput
@onready var tribe_selector = $TribePicker
@onready var tribe_preview = $TribePreview
@onready var ready_button = $BeginGameLobby

# Define color enum or mapping

func _ready():
	for name in GameManager.tribe_names:
		tribe_selector.add_item(name)

func _on_ReadyButton_pressed():
	var name = name_input.text.strip_edges()
	if name == "":
		print("Name is required.")
		return

	var selected_index = tribe_selector.get_selected_id()
	var selected_tribe = GameManager.TribeEnum.values()[selected_index]

	var net = get_node("/root/GameNetworkManager")
	net.host_server()
	await get_tree().create_timer(0.1).timeout # Give time for multiplayer to initialize
	
	# Register host as a player
	var my_id = multiplayer.get_unique_id()
	GameManager.add_player(my_id, name, selected_tribe)

	# Add chat message
	var join_message = "%s has joined." % [name]
	GameManager.add_chat_message(join_message)

	get_tree().change_scene_to_file(Constants.LOBBY_SCENE_PATH)


func _on_back_to_main_pressed():
	get_tree().change_scene_to_file(Constants.MAIN_SCENE_PATH)


func _on_tribe_picker_item_selected(index):
	var tribe = GameManager.tribe_enum[index]
	$TribePreview.texture = GameManager.TRIBE_GENERAL_TEXTURES[tribe]
