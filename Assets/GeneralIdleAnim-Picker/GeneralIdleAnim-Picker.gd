extends Node2D

# 1. Map string names to your GameManager integer enum values explicitly
@export var selected_idle: int = GameManager.TribeEnum.BARBARIAN:
	set(value):
		selected_idle = value
		# Automatically update visibility whenever you change the choice in the Inspector
		if is_node_ready():
			_update_sprite_visibility()

# 2. Get onready references to your 4 overlapping AnimatedSprite2D nodes
@onready var sprite_1: Node2D = $"BarbGeneral-idle"
@onready var sprite_2: Node2D = $"KnightGeneral-idle"
@onready var sprite_3: Node2D = $"VampGeneral-idle"
@onready var sprite_4: Node2D = $"SnailGeneral-idle"

func _ready() -> void:
	# Ensure the correct sprite is visible when the game starts
	_update_sprite_visibility()

func _update_sprite_visibility() -> void:
	# Turn off all sprites by default
	sprite_1.visible = false
	sprite_2.visible = false
	sprite_3.visible = false
	sprite_4.visible = false
	
	# FIX: Match against the actual enum values (integers) instead of strings!
	match selected_idle:
		GameManager.TribeEnum.BARBARIAN:
			sprite_1.visible = true
		GameManager.TribeEnum.KNIGHT:
			sprite_2.visible = true
		GameManager.TribeEnum.VAMPIRE:
			sprite_3.visible = true
		GameManager.TribeEnum.SNAIL:
			sprite_4.visible = true
