extends Node

# Signal names
const SIGNAL_CHAT_UPDATED = "chat_updated"
const SIGNAL_PLAYER_UPDATED = "player_updated"
const SIGNAL_PLAYER_LEFT_LOBBY = "player_left_lobby"
const SIGNAL_PLAYER_ADDED = "player_added"
const SIGNAL_PLAYER_REMOVED = "player_removed"
const SIGNAL_PLAYER_MODIFIED = "player_modified"

# Scene paths
const MAIN_SCENE_PATH = "res://Scenes/RefactoredTribalDynamics/MainScene.tscn"
const LOBBY_SCENE_PATH = "res://Scenes/RefactoredTribalDynamics/Lobby.tscn"
const BOARD_GAME_PATH = "res://Scenes/GameBoard.tscn"

# RPC names
const RPC_RETURN_TO_MAIN = "lobby_return_to_main"
const RPC_RESET_ALL = "reset_all"

# Network config
const HOST_ID = 1
