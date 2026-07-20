extends Node3D
class_name MantleSkin

const RIG_SCENES: Dictionary = {
	0: "res://Assets/Rigs/humanoid_mk6.tscn",
	1: "res://Assets/Rigs/humanoid_mk8.tscn",
}

@export var mantle: Mantle:
	set(value):
		mantle = value
		if is_inside_tree():
			apply_mantle(mantle)

var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _anim_player: AnimationPlayer
var _rig_node: Node3D

var _bone_order_cache: Dictionary = {}
var _blend_shape_cache: Dictionary = {}
var _current_rig_type: int = -1

var _cube_meshes: Dictionary = {}
var _flat_meshes: Dictionary = {}

func _ready() -> void:
	if mantle != null:
		apply_mantle(mantle)

func apply_mantle(m: Mantle) -> void:
	if m == null:
		_clear_rig()
		return
	if m != mantle:
		mantle = m
		return
	if m.rigType != _current_rig_type:
		_instantiate_rig(m.rigType)
	_forward_port(m)
	_apply_base_color()
	_apply_shape_keys()
	_spawn_all_cube_meshes()
	_spawn_all_flat_meshes()

func get_skeleton() -> Skeleton3D:
	return _skeleton

func get_mesh() -> MeshInstance3D:
	return _mesh

func get_animation_player() -> AnimationPlayer:
	return _anim_player

func get_bone_order() -> PackedInt32Array:
	if _current_rig_type < 0:
		return PackedInt32Array()
	return _get_bone_order(_current_rig_type)

func get_blend_shape_names() -> PackedStringArray:
	if _current_rig_type < 0 or not _blend_shape_cache.has(_current_rig_type):
		return PackedStringArray()
	return _blend_shape_cache[_current_rig_type]

# --- Cube attachment methods ---

func spawn_cube(cube_idx: int, bone_idx: int, pos: Vector3, color: Color, scl: Vector3) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone_idx
	_skeleton.add_child(attachment)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	attachment.add_child(mesh_inst)
	mesh_inst.position = pos
	mesh_inst.scale = scl
	_cube_meshes[cube_idx] = mesh_inst

func despawn_cube(del_idx: int) -> void:
	if _cube_meshes.has(del_idx):
		_cube_meshes[del_idx].get_parent().queue_free()
		_cube_meshes.erase(del_idx)
	var new_meshes: Dictionary = {}
	for old_idx in _cube_meshes.keys():
		var new_idx: int = old_idx if old_idx < del_idx else old_idx - 1
		new_meshes[new_idx] = _cube_meshes[old_idx]
	_cube_meshes = new_meshes

func update_cube_position(cube_idx: int, pos: Vector3) -> void:
	if _cube_meshes.has(cube_idx):
		_cube_meshes[cube_idx].position = pos

func update_cube_color(cube_idx: int, color: Color) -> void:
	if _cube_meshes.has(cube_idx):
		(_cube_meshes[cube_idx].material_override as StandardMaterial3D).albedo_color = color

func update_cube_scale(cube_idx: int, scl: Vector3) -> void:
	if _cube_meshes.has(cube_idx):
		_cube_meshes[cube_idx].scale = scl

# --- Flat attachment methods ---

func spawn_flat(flat_idx: int, bone_idx: int, pos: Vector3, color: Color, scl: Vector3) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone_idx
	_skeleton.add_child(attachment)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = PlaneMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	attachment.add_child(mesh_inst)
	mesh_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mesh_inst.position = pos
	mesh_inst.scale = scl
	_flat_meshes[flat_idx] = mesh_inst

func despawn_flat(del_idx: int) -> void:
	if _flat_meshes.has(del_idx):
		_flat_meshes[del_idx].get_parent().queue_free()
		_flat_meshes.erase(del_idx)
	var new_meshes: Dictionary = {}
	for old_idx in _flat_meshes.keys():
		var new_idx: int = old_idx if old_idx < del_idx else old_idx - 1
		new_meshes[new_idx] = _flat_meshes[old_idx]
	_flat_meshes = new_meshes

func update_flat_position(flat_idx: int, pos: Vector3) -> void:
	if _flat_meshes.has(flat_idx):
		_flat_meshes[flat_idx].position = pos

func update_flat_color(flat_idx: int, color: Color) -> void:
	if _flat_meshes.has(flat_idx):
		(_flat_meshes[flat_idx].material_override as StandardMaterial3D).albedo_color = color

func update_flat_scale(flat_idx: int, scl: Vector3) -> void:
	if _flat_meshes.has(flat_idx):
		_flat_meshes[flat_idx].scale = scl

# --- Apply methods ---

func apply_base_color() -> void:
	_apply_base_color()

func apply_shape_key(idx: int, value: float) -> void:
	if _mesh != null:
		_mesh.set_blend_shape_value(idx, value)

# --- Internal ---

func _instantiate_rig(rig_type: int) -> void:
	_clear_rig()
	if not RIG_SCENES.has(rig_type):
		push_error("[MantleSkin] rig_type %d not in RIG_SCENES" % rig_type)
		return
	var scene := load(RIG_SCENES[rig_type]) as PackedScene
	if scene == null:
		push_error("[MantleSkin] Failed to load rig scene: %s" % RIG_SCENES[rig_type])
		return
	_rig_node = scene.instantiate() as Node3D
	add_child(_rig_node)
	_skeleton = _rig_node.find_children("*", "Skeleton3D", true, false)[0]
	_mesh = _skeleton.find_children("*", "MeshInstance3D", true, false)[0]
	var anim_players := _rig_node.find_children("*", "AnimationPlayer", true, false)
	if anim_players.size() > 0:
		_anim_player = anim_players[0]
	if not _blend_shape_cache.has(rig_type):
		var names := PackedStringArray()
		var arr_mesh := _mesh.mesh as ArrayMesh
		if arr_mesh != null:
			for i in range(arr_mesh.get_blend_shape_count()):
				names.append(arr_mesh.get_blend_shape_name(i))
		_blend_shape_cache[rig_type] = names
	_current_rig_type = rig_type
	print("[MantleSkin] Rig instantiated, type=", rig_type)

func _clear_rig() -> void:
	for mesh_inst in _cube_meshes.values():
		if is_instance_valid(mesh_inst) and is_instance_valid(mesh_inst.get_parent()):
			mesh_inst.get_parent().queue_free()
	_cube_meshes.clear()
	for mesh_inst in _flat_meshes.values():
		if is_instance_valid(mesh_inst) and is_instance_valid(mesh_inst.get_parent()):
			mesh_inst.get_parent().queue_free()
	_flat_meshes.clear()
	if _rig_node != null and is_instance_valid(_rig_node):
		_rig_node.queue_free()
		_rig_node = null
	_skeleton = null
	_mesh = null
	_anim_player = null
	_current_rig_type = -1

func _forward_port(m: Mantle) -> void:
	var bone_order := _get_bone_order(m.rigType)
	var blend_shape_count: int = _blend_shape_cache[m.rigType].size()
	var _notes := m.notes
	if _notes.size() < bone_order.size():
		_notes.resize(bone_order.size())
		m.notes = _notes
	var _shape_keys := m.shapeKeyValues
	if _shape_keys.size() < blend_shape_count:
		_shape_keys.resize(blend_shape_count)
		m.shapeKeyValues = _shape_keys
	var _cube_count := m.cubeBoneIndices.size()
	var _cube_colors := m.cubeColors
	if _cube_colors.size() < _cube_count:
		var _old := _cube_colors.size()
		_cube_colors.resize(_cube_count)
		for i in range(_old, _cube_count):
			_cube_colors[i] = Color.WHITE
		m.cubeColors = _cube_colors
	var _cube_scales := m.cubeScales
	if _cube_scales.size() < _cube_count:
		var _old := _cube_scales.size()
		_cube_scales.resize(_cube_count)
		for i in range(_old, _cube_count):
			_cube_scales[i] = Vector3.ONE
		m.cubeScales = _cube_scales
	var _flat_count := m.flatBoneIndices.size()
	var _flat_colors := m.flatColors
	if _flat_colors.size() < _flat_count:
		var _old := _flat_colors.size()
		_flat_colors.resize(_flat_count)
		for i in range(_old, _flat_count):
			_flat_colors[i] = Color.WHITE
		m.flatColors = _flat_colors
	var _flat_positions := m.flatPositions
	if _flat_positions.size() < _flat_count:
		_flat_positions.resize(_flat_count)
		m.flatPositions = _flat_positions
	var _flat_scales := m.flatScales
	if _flat_scales.size() < _flat_count:
		var _old := _flat_scales.size()
		_flat_scales.resize(_flat_count)
		for i in range(_old, _flat_count):
			_flat_scales[i] = Vector3.ONE
		m.flatScales = _flat_scales
	print("[MantleSkin] forward-ported, bones=", bone_order.size(), " shapes=", blend_shape_count)

func _apply_base_color() -> void:
	if mantle == null or _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = mantle.baseColor
	_mesh.material_override = mat

func _apply_shape_keys() -> void:
	if mantle == null or _mesh == null:
		return
	for i in range(mantle.shapeKeyValues.size()):
		_mesh.set_blend_shape_value(i, mantle.shapeKeyValues[i])

func _spawn_all_cube_meshes() -> void:
	for mesh_inst in _cube_meshes.values():
		if is_instance_valid(mesh_inst) and is_instance_valid(mesh_inst.get_parent()):
			mesh_inst.get_parent().queue_free()
	_cube_meshes.clear()
	if mantle == null:
		return
	var bone_order := _get_bone_order(mantle.rigType)
	for i in range(mantle.cubeBoneIndices.size()):
		var order_pos: int = mantle.cubeBoneIndices[i]
		var bone_idx: int = bone_order[order_pos]
		spawn_cube(i, bone_idx, mantle.cubePositions[i], mantle.cubeColors[i], mantle.cubeScales[i])

func _spawn_all_flat_meshes() -> void:
	for mesh_inst in _flat_meshes.values():
		if is_instance_valid(mesh_inst) and is_instance_valid(mesh_inst.get_parent()):
			mesh_inst.get_parent().queue_free()
	_flat_meshes.clear()
	if mantle == null:
		return
	var bone_order := _get_bone_order(mantle.rigType)
	for i in range(mantle.flatBoneIndices.size()):
		var order_pos: int = mantle.flatBoneIndices[i]
		var bone_idx: int = bone_order[order_pos]
		spawn_flat(i, bone_idx, mantle.flatPositions[i], mantle.flatColors[i], mantle.flatScales[i])

func _get_bone_order(rig_type: int) -> PackedInt32Array:
	if _bone_order_cache.has(rig_type):
		return _bone_order_cache[rig_type]
	var order := PackedInt32Array()
	for bone_idx in _skeleton.get_parentless_bones():
		_build_bone_order(bone_idx, order)
	_bone_order_cache[rig_type] = order
	return order

func _build_bone_order(bone_idx: int, order: PackedInt32Array) -> void:
	order.append(bone_idx)
	for child_idx in _skeleton.get_bone_children(bone_idx):
		_build_bone_order(child_idx, order)
