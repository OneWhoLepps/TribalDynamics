extends Control

signal leave_pressed(id: int)
signal ready_pressed(id: int)
signal tribe_changed(id: int, tribe: int)   # now (id, tribe) to match the lobby handler

var player_id: int
var tribe: int = 0
var is_local: bool = false   # member now, so other functions can use it

func setup(entry_data: Dictionary):
	player_id = entry_data["id"]
	set_ready_visual(entry_data["ready"], player_id)
	tribe = entry_data["tribe"]
	$HBoxContainer/PlayerName.text = entry_data["name"]
	$HBoxContainer/ReadyToggle.button_pressed = entry_data["ready"]

	# Ensure the node is fully inside the tree before checking multiplayer ID
	if not is_inside_tree():
		await ready

	is_local = player_id == get_tree().get_multiplayer().get_unique_id()
	$HBoxContainer/ReadyToggle.disabled = not is_local
	$HBoxContainer/TribePicker.disabled = not is_local
	if not is_local:
		$HBoxContainer/ReadyLabel.modulate.a = 0.0
		$HBoxContainer/ReadyLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HBoxContainer/ReadyToggle.modulate.a = 0.0
		$HBoxContainer/ReadyToggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HBoxContainer/Leave.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HBoxContainer/Leave.modulate.a = 0.0
		$HBoxContainer/TribePicker.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready():
	GameManager.connect("game_manager_ready_toggled", Callable(self, "set_ready_visual"))
	GameManager.connect("player_tribe_changed", Callable(self, "set_tribe_visual"))   # FIX 1: listen for host broadcast
	for n in GameManager.tribe_names:
		$HBoxContainer/TribePicker.add_item(n)
	_apply_tribe_visual(tribe)

func _on_leave_pressed():
	$HBoxContainer/Leave.disabled = true
	emit_signal("leave_pressed", player_id)

func set_ready_visual(is_ready: bool, id):
	if id == get_player_id():
		$HBoxContainer/PlayerName.add_theme_color_override("font_color", Color.GREEN if is_ready else Color.WHITE)

func _on_ready_toggle_pressed():
	emit_signal("ready_pressed", player_id)

func get_player_id():
	return player_id

# When tribe picker changes in the lobby, notify the host, then update local visuals
func _on_tribe_picker_item_selected(index):
	if not is_local:
		return
	emit_signal("tribe_changed", player_id, index)
	_apply_tribe_visual(index)

# Host broadcast arrives here on every peer; only the matching entry reacts
func set_tribe_visual(id: int, new_tribe: int):
	if id != player_id:
		return
	tribe = new_tribe
	_apply_tribe_visual(new_tribe)

#Initialize tribe picker dropdown value AND set the animation to match
func _apply_tribe_visual(index: int):
	$HBoxContainer/TribePicker.select(index)
	$"HBoxContainer/SubViewportContainer/SubViewport/GeneralIdleAnim-picker".selected_idle = index
