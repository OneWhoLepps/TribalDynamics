extends Control

var player_id: int
signal leave_pressed(id: int)
signal ready_pressed(id: int)

func setup(entry_data: Dictionary):
	player_id = entry_data["id"]
	set_ready_visual(entry_data["ready"], player_id)
	$HBoxContainer/PlayerName.text = entry_data["name"]
	$HBoxContainer/ColorPreview.color = GameManager.color_values[entry_data["color"]]
	$HBoxContainer/ReadyToggle.button_pressed = entry_data["ready"]

	# Ensure the node is fully inside the tree before checking multiplayer ID
	if not is_inside_tree():
		await ready

	var is_local = player_id == get_tree().get_multiplayer().get_unique_id()
	$HBoxContainer/ReadyToggle.disabled = not is_local
	if(not is_local):
		# Prevent mouse interaction
			$HBoxContainer/ReadyLabel.modulate.a = 0.0
			$HBoxContainer/ReadyLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$HBoxContainer/ReadyToggle.modulate.a = 0.0
			$HBoxContainer/ReadyToggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$HBoxContainer/Leave.mouse_filter = Control.MOUSE_FILTER_IGNORE
			$HBoxContainer/Leave.modulate.a = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	GameManager.connect("game_manager_ready_toggled", Callable(self, "set_ready_visual"))
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

#On pressing leave button, do this.
func _on_leave_pressed():
# Disable buttons to prevent double click
	$HBoxContainer/Leave.disabled = true
	emit_signal("leave_pressed", player_id)

func set_ready_visual(ready: bool, id):
	if(id == get_player_id()):
		$HBoxContainer/PlayerName.add_theme_color_override("font_color", Color.GREEN if ready else Color.WHITE)

func _on_ready_toggle_pressed():
	print("emitting ready signal")
	emit_signal("ready_pressed", player_id)

func get_player_id():
	return player_id
	

