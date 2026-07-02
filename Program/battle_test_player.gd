extends CharacterBody3D

@export_group("Movement")
@export var move_speed := 8.0
@export var rotation_speed := 12.0

@export_group("Jump")
@export var jump_initial_impulse := 6.0
@export var jump_hold_force := 36.0
@export var jump_max_hold_time := 0.2
@export var gravity := -30.0

var _last_input_direction := Vector3.FORWARD
var _is_jumping := false
var _jump_hold_time := 0.0

@onready var _skin: Node3D = $Skin


func _physics_process(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := Vector3(raw_input.x, 0.0, raw_input.y).normalized()

	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_initial_impulse
		_is_jumping = true
		_jump_hold_time = 0.0

	velocity.y += gravity * delta

	if _is_jumping:
		if Input.is_action_pressed("jump") and velocity.y > 0.0 and _jump_hold_time < jump_max_hold_time:
			velocity.y += jump_hold_force * delta
			_jump_hold_time += delta
		else:
			_is_jumping = false

	if move_direction.length() > 0.2:
		_last_input_direction = move_direction.normalized()
	var target_angle := Vector3.FORWARD.signed_angle_to(_last_input_direction, Vector3.UP)
	_skin.rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()
