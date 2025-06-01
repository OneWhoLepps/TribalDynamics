extends Control

@onready var name_input = $PlayerNameInput
@onready var color_selector = $ColorPicker
@onready var color_preview = $ColorPreview
@onready var ready_button = $BeginGameLobby

# Define color enum or mapping
var color_names = ["Red", "Blue", "Green", "Yellow"]
var color_enums = [GameManager.ColorEnum.RED, GameManager.ColorEnum.BLUE, GameManager.ColorEnum.GREEN, GameManager.ColorEnum.YELLOW]

func _ready():
	for name in GameManager.color_names:
		color_selector.add_item(name)
	_update_color_preview()
	color_selector.connect("item_selected", Callable(self, "_update_color_preview"))

func _update_color_preview(index := -1):
	if index == -1:
		index = color_selector.get_selected_id()
	color_preview.color = GameManager.color_values[index]

func _on_ReadyButton_pressed():
	var name = name_input.text.strip_edges()
	if name == "":
		print("Name is required.")
		return

	var selected_index = color_selector.get_selected_id()
	var selected_enum = color_enums[selected_index]

	var net = get_node("/root/GameNetworkManager")
	net.host_server()
	await get_tree().create_timer(0.1).timeout # Give time for multiplayer to initialize
	
	# Register host as a player
	var my_id = multiplayer.get_unique_id()
	GameManager.add_player(my_id, name, selected_enum)

	# Add chat message
	var join_message = "%s has joined with color %s." % [name, GameManager.color_names[selected_enum]]
	GameManager.add_chat_message(join_message)

	get_tree().change_scene_to_file(Constants.LOBBY_SCENE_PATH)


func _on_back_to_main_pressed():
	get_tree().change_scene_to_file(Constants.MAIN_SCENE_PATH)
