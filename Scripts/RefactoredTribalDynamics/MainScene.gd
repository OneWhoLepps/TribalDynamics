extends Control

func _on_HostButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/RefactoredTribalDynamics/HostSetupScene.tscn")

func _on_JoinButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/RefactoredTribalDynamics/JoinLobbyScene.tscn")
