extends Node

const GROUP_NAME := "battle_manager"

var _players: Array[CharacterBody3D] = []


func _ready() -> void:
	add_to_group(GROUP_NAME)


func register(player: CharacterBody3D) -> void:
	if not _players.has(player):
		_players.append(player)


func deregister(player: CharacterBody3D) -> void:
	_players.erase(player)


func find_target(requester: CharacterBody3D, facing_direction: Vector3) -> Variant:
	var best_target: CharacterBody3D = null
	var best_angle := INF
	for player in _players:
		if player == requester or not is_instance_valid(player):
			continue
		var to_target := player.global_position - requester.global_position
		to_target.y = 0.0
		if to_target.length_squared() < 0.0001:
			continue
		var angle := facing_direction.angle_to(to_target.normalized())
		if angle < best_angle:
			best_angle = angle
			best_target = player
	if best_target == null:
		return null
	return best_target.global_position
