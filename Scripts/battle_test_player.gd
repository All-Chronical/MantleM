extends CharacterBody3D

enum AttackButton { LIGHT, HEAVY }
enum Mobility { NEUTRAL, DIRECTIONAL, AIRBORNE }

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

var _attack_active := false
var _attack_mobility: Mobility = Mobility.NEUTRAL
var _attack_anim_path := ""

@onready var _skin: Node3D = $Skin
@onready var _camera: Camera3D = get_viewport().get_camera_3d()
@onready var _mantle_skin: MantleSkin = $Skin/MantleSkin
@onready var _anim_player: AnimationPlayer = _mantle_skin.get_animation_player()


func _ready() -> void:
	_anim_player.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var mobility: Mobility
	if not is_on_floor():
		mobility = Mobility.AIRBORNE
	elif raw_input.length() > 0.0:
		mobility = Mobility.DIRECTIONAL
	else:
		mobility = Mobility.NEUTRAL

	if not _attack_active:
		if Input.is_action_just_pressed("light_attack"):
			_try_attack(AttackButton.LIGHT, mobility)
		elif Input.is_action_just_pressed("heavy_attack"):
			_try_attack(AttackButton.HEAVY, mobility)

	var process_movement_input := not (_attack_active and _attack_mobility == Mobility.NEUTRAL)

	var move_direction := Vector3.ZERO
	if process_movement_input:
		var cam_to_player := global_position - _camera.global_position
		cam_to_player.y = 0.0
		var forward := cam_to_player.normalized()
		var right := forward.cross(Vector3.UP).normalized()
		move_direction = (-forward * raw_input.y + right * raw_input.x).normalized()
		velocity.x = move_direction.x * move_speed
		velocity.z = move_direction.z * move_speed

	if not _attack_active and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_initial_impulse
		_is_jumping = true
		_jump_hold_time = 0.0

	velocity.y += gravity * delta

	if _is_jumping:
		if not _attack_active and Input.is_action_pressed("jump") and velocity.y > 0.0 and _jump_hold_time < jump_max_hold_time:
			velocity.y += jump_hold_force * delta
			_jump_hold_time += delta
		else:
			_is_jumping = false

	if process_movement_input and move_direction.length() > 0.2:
		_last_input_direction = move_direction.normalized()
	var target_angle := Vector3.FORWARD.signed_angle_to(_last_input_direction, Vector3.UP)
	_skin.rotation.y = lerp_angle(_skin.rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()

	if not _attack_active:
		if not is_on_floor():
			_anim_player.play("stock_animlib/StockJump")
		elif move_direction.length() > 0.1:
			_anim_player.play("stock_animlib/StockMove")
		else:
			_anim_player.play("stock_animlib/StockIdle")


func _try_attack(button: AttackButton, mobility: Mobility) -> void:
	var moveset := _mantle_skin.get_moveset()
	if moveset == null:
		return
	var slot: Moveset.Move
	match mobility:
		Mobility.NEUTRAL:
			slot = Moveset.Move.NL if button == AttackButton.LIGHT else Moveset.Move.NH
		Mobility.DIRECTIONAL:
			slot = Moveset.Move.DL if button == AttackButton.LIGHT else Moveset.Move.DH
		Mobility.AIRBORNE:
			slot = Moveset.Move.AL if button == AttackButton.LIGHT else Moveset.Move.AH
	if not moveset.has_move(slot):
		return
	_attack_anim_path = moveset.get_play_path(slot)
	_attack_active = true
	_attack_mobility = mobility
	_anim_player.play(_attack_anim_path)


func _on_animation_finished(anim_name: StringName) -> void:
	if _attack_active and anim_name == _attack_anim_path:
		_attack_active = false
