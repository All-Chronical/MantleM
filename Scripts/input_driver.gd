extends Node

@onready var _body: CharacterBody3D = get_parent()


func _physics_process(_delta: float) -> void:
	_body.move_input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_body.is_jump_just_pressed = Input.is_action_just_pressed("jump")
	_body.is_jump_pressed = Input.is_action_pressed("jump")
	_body.is_light_just_pressed = Input.is_action_just_pressed("light_attack")
	_body.is_heavy_just_pressed = Input.is_action_just_pressed("heavy_attack")
