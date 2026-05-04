extends Node

# Change this to 2, 3, or 4 to test different player counts without the lobby.
const DEBUG_PLAYER_COUNT = 2

func _ready():
	var offline_peer = OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = offline_peer

	GameManager.players.clear()
	var colors = [
		GameManager.ColorEnum.RED,
		GameManager.ColorEnum.BLUE,
		GameManager.ColorEnum.GREEN,
		GameManager.ColorEnum.YELLOW,
	]
	for i in range(DEBUG_PLAYER_COUNT):
		GameManager.add_player(i + 1, "Player %d" % (i + 1), colors[i])

	get_tree().change_scene_to_file(Constants.BOARD_GAME_PATH)
