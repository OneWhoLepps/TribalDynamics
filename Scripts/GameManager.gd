extends Node

var Players = {}
var Chatbox = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


@rpc("any_peer")
func HandleButtonPress(player_id, button_name):
	print("Player", player_id, "pressed", button_name)

	# tracking last action... if we ever want to?
	if Players.has(player_id):
		Players[player_id]["last_action"] = button_name


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
