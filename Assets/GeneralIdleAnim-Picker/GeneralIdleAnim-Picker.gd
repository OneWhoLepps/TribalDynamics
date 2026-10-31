extends Node2D

# 1. Create a dropdown menu in the Inspector matching your sprite names
@export_enum("None", "BarbGeneral", "KnightGeneral", "VampGeneral", "SnailGeneral") var selected_idle: String = "None":
	set(value):
		selected_idle = value
		# Automatically update visibility whenever you change the choice in the Inspector
		if is_node_ready():
			_update_sprite_visibility()

# 2. Get onready references to your 4 overlapping AnimatedSprite2D nodes
@onready var sprite_1: AnimatedSprite2D = $"BarbGeneral-idle"
@onready var sprite_2: AnimatedSprite2D = $"KnightGeneral-idle"
@onready var sprite_3: AnimatedSprite2D = $"VampGeneral-idle"
@onready var sprite_4: AnimatedSprite2D = $"SnailGeneral-idle"

func _ready() -> void:
	# Ensure the correct sprite is visible when the game starts
	_update_sprite_visibility()

func _update_sprite_visibility() -> void:
	# Turn off all sprites by default
	sprite_1.visible = false
	sprite_2.visible = false
	sprite_3.visible = false
	sprite_4.visible = false
	
	# Turn on the chosen sprite and play its animation
	match selected_idle:
		"BarbGeneral":
			sprite_1.visible = true
			sprite_1.play()
		"KnightGeneral":
			sprite_2.visible = true
			sprite_2.play()
		"VampGeneral":
			sprite_3.visible = true
			sprite_3.play()
		"SnailGeneral":
			sprite_4.visible = true
			sprite_4.play()
