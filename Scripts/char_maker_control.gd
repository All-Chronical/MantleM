extends Control

const BLANK_MANTLE_PATH := "res://Mantles/blank.tres"
const BASE_NODE_PATHS: Array[String] = [
	"HBoxContainer/Viewport/SubViewportContainer/SubViewport/Node3D/Humanoid_mk6",
]

@export var hierarchyList: Tree
@export var skeleton: Skeleton3D
@export var mesh: MeshInstance3D

@onready var _mantle_picker: OptionButton = $HBoxContainer/Viewport/OptionButton
@onready var _note_label: Label = $HBoxContainer/Inspector/VBoxContainer/Label
@onready var _note_edit: TextEdit = $HBoxContainer/Inspector/VBoxContainer/TextEdit
@onready var _rig_note_label: Label = $HBoxContainer/Inspector/VBoxContainer/RigNoteLabel
@onready var _rig_note_edit: TextEdit = $HBoxContainer/Inspector/VBoxContainer/RigNoteEdit
@onready var _rig_color_label: Label = $HBoxContainer/Inspector/VBoxContainer/BaseColorLabel
@onready var _rig_color_picker: ColorPickerButton = $HBoxContainer/Inspector/VBoxContainer/BaseColorPicker
@onready var _save_btn: Button = $HBoxContainer/Viewport/SaveBtn
@onready var _shape_keys_label: Label = $HBoxContainer/Inspector/VBoxContainer/ShapeKeysLabel
@onready var _shape_key_container: VBoxContainer = $HBoxContainer/Inspector/VBoxContainer/ShapeKeyContainer
@onready var _shape_key_template: VBoxContainer = $HBoxContainer/Inspector/VBoxContainer/ShapeKeyContainer/ShapeKeyTemplate
@onready var _cube_label: Label = $HBoxContainer/Inspector/VBoxContainer/CubeLabel
@onready var _cube_slider_container: VBoxContainer = $HBoxContainer/Inspector/VBoxContainer/CubeSliderContainer
@onready var _cube_x_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/CubeSliderContainer/XContainer/XSlider
@onready var _cube_y_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/CubeSliderContainer/YContainer/YSlider
@onready var _cube_z_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/CubeSliderContainer/ZContainer/ZSlider
@onready var _cube_color_label: Label = $HBoxContainer/Inspector/VBoxContainer/CubeColorLabel
@onready var _cube_color_picker: ColorPickerButton = $HBoxContainer/Inspector/VBoxContainer/CubeColorPicker
@onready var _add_cube_btn: Button = $HBoxContainer/Hierarchy/VBoxContainer/HBoxContainer/AddCBtn
@onready var _del_part_btn: Button = $HBoxContainer/Hierarchy/VBoxContainer/HBoxContainer/DelPBtn

var _base_nodes: Array[Node3D] = []
var _bone_order_cache: Dictionary = {}
var _blend_shape_cache: Dictionary = {}
var _current_rig_type: int = -1

var _original_mantle: Mantle = null
var _current_mantle: Mantle = null
var _current_mantle_path: String = ""
var _current_bone_order: PackedInt32Array = []
var _current_order_pos: int = -1
var _mantle_paths: Array[String] = []
var _updating_attrs: bool = false

var _save_as_dialog: ConfirmationDialog
var _save_as_name_edit: LineEdit
var _overwrite_dialog: ConfirmationDialog
var _pending_save_path: String = ""

var _cube_meshes: Dictionary = {}
var _selected_cube_idx: int = -1

func _ready():
	for path in BASE_NODE_PATHS:
		_base_nodes.append(get_node(path) as Node3D)

	hierarchyList.item_selected.connect(_on_bone_selected)
	hierarchyList.nothing_selected.connect(_on_bone_deselected)

	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	_build_save_as_dialog()
	_build_overwrite_dialog()

	_note_edit.text_changed.connect(_on_note_changed)
	_rig_note_edit.text_changed.connect(_on_rig_note_changed)
	_rig_color_picker.color_changed.connect(_on_color_changed)
	_cube_x_slider.value_changed.connect(_on_cube_slider_changed)
	_cube_y_slider.value_changed.connect(_on_cube_slider_changed)
	_cube_z_slider.value_changed.connect(_on_cube_slider_changed)
	_cube_color_picker.color_changed.connect(_on_cube_color_changed)
	_add_cube_btn.pressed.connect(_on_add_cube_pressed)
	_del_part_btn.pressed.connect(_on_del_part_pressed)
	_del_part_btn.visible = false

	_refresh_mantle_options()
	_mantle_picker.item_selected.connect(_on_mantle_selected)
	if _mantle_paths.size() > 0:
		_on_mantle_selected(0)

func _rebuild_hierarchy() -> void:
	hierarchyList.clear()
	var root := hierarchyList.create_item()
	root.set_text(0, "Rig")
	root.set_metadata(0, -1)
	for bone_idx in skeleton.get_parentless_bones():
		_add_bone_to_tree(bone_idx, root)

func _add_bone_to_tree(bone_idx: int, parent_item: TreeItem) -> void:
	var item := hierarchyList.create_item(parent_item)
	item.set_text(0, skeleton.get_bone_name(bone_idx))
	item.set_metadata(0, bone_idx)
	var order_pos := _current_bone_order.find(bone_idx)
	if order_pos >= 0 and _current_mantle != null:
		for i in range(_current_mantle.cubeBoneIndices.size()):
			if _current_mantle.cubeBoneIndices[i] == order_pos:
				var cube_item := hierarchyList.create_item(item)
				cube_item.set_text(0, "Cube Part")
				cube_item.set_metadata(0, {"cube": true, "idx": i})
	for child_idx in skeleton.get_bone_children(bone_idx):
		_add_bone_to_tree(child_idx, item)

func _swap_base(rig_type: int) -> void:
	for base in _base_nodes:
		base.visible = false
	var base := _base_nodes[rig_type]
	base.visible = true
	skeleton = base.find_children("*", "Skeleton3D", true, false)[0]
	mesh = skeleton.find_children("*", "MeshInstance3D", true, false)[0]
	if not _blend_shape_cache.has(rig_type):
		var names := PackedStringArray()
		var arr_mesh := mesh.mesh as ArrayMesh
		if arr_mesh != null:
			for i in range(arr_mesh.get_blend_shape_count()):
				names.append(arr_mesh.get_blend_shape_name(i))
		_blend_shape_cache[rig_type] = names
	_rebuild_hierarchy()
	_current_rig_type = rig_type

func _refresh_mantle_options() -> void:
	_mantle_picker.clear()
	_mantle_paths.clear()
	var dir := DirAccess.open("res://Mantles/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			_mantle_picker.add_item(fname.get_basename())
			print(fname.get_basename())
			_mantle_paths.append("res://Mantles/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()

func _on_mantle_selected(id: int) -> void:
	if id >= _mantle_paths.size():
		return
	var mantle := load(_mantle_paths[id]) as Mantle
	if mantle == null:
		return
	if mantle.rigType >= _base_nodes.size():
		push_error("[Mantle] rigType %d out of range, only %d bases registered" % [mantle.rigType, _base_nodes.size()])
		return
	_current_mantle_path = _mantle_paths[id]
	_original_mantle = mantle
	_current_mantle = _original_mantle.duplicate()
	if mantle.rigType != _current_rig_type:
		_swap_base(mantle.rigType)
	_current_bone_order = _get_bone_order(mantle.rigType)
	var blend_shape_count: int = _blend_shape_cache[mantle.rigType].size()
	var _notes := _current_mantle.notes
	if _notes.size() < _current_bone_order.size():
		_notes.resize(_current_bone_order.size())
		_current_mantle.notes = _notes
	var _shape_keys := _current_mantle.shapeKeyValues
	if _shape_keys.size() < blend_shape_count:
		_shape_keys.resize(blend_shape_count)
		_current_mantle.shapeKeyValues = _shape_keys
	var _cube_colors := _current_mantle.cubeColors
	var _cube_count := _current_mantle.cubeBoneIndices.size()
	if _cube_colors.size() < _cube_count:
		var _old_color_size := _cube_colors.size()
		_cube_colors.resize(_cube_count)
		for i in range(_old_color_size, _cube_count):
			_cube_colors[i] = Color.WHITE
		_current_mantle.cubeColors = _cube_colors
	print("[Mantle] loaded, bone_count=", _current_bone_order.size(), " notes_size=", _current_mantle.notes.size(), " shape_keys=", _current_mantle.shapeKeyValues.size())
	_save_btn.disabled = false
	_apply_base_color()
	_apply_shape_keys()
	_spawn_all_cube_meshes()
	_rebuild_hierarchy()
	_on_bone_deselected()

func _on_bone_selected() -> void:
	print("[Bone] _on_bone_selected fired")
	var item := hierarchyList.get_selected()
	if item == null or _current_mantle == null:
		print("[Bone] early exit — item=", item, " mantle=", _current_mantle)
		return
	var metadata = item.get_metadata(0)
	if typeof(metadata) == TYPE_DICTIONARY:
		_on_cube_selected(metadata["idx"])
		return
	var bone_idx: int = metadata
	if bone_idx < 0:
		_on_rig_selected()
		return
	var bone_name: String = skeleton.get_bone_name(bone_idx)
	var order_pos := _current_bone_order.find(bone_idx)
	if order_pos < 0:
		print("[Bone] order_pos not found for bone_idx=", bone_idx)
		return
	_current_order_pos = order_pos
	var stored_note: String = _current_mantle.notes[order_pos]
	print("[Bone] name=", bone_name, " idx=", bone_idx, " order_pos=", order_pos, " stored_note='" , stored_note, "'")
	_updating_attrs = true
	_note_edit.text = stored_note
	_updating_attrs = false
	print("[Bone] TextEdit.text after set='" , _note_edit.text, "'")
	_selected_cube_idx = -1
	_hide_all_attrs()
	_note_label.show()
	_note_edit.show()
	_add_cube_btn.visible = true
	_del_part_btn.visible = false

func _on_note_changed() -> void:
	if _updating_attrs or _current_mantle == null or _current_order_pos < 0:
		return
	var _notes := _current_mantle.notes
	_notes[_current_order_pos] = _note_edit.text
	_current_mantle.notes = _notes
	print("[Note] pos=", _current_order_pos, " text=", _note_edit.text)

func _on_cube_selected(cube_idx: int) -> void:
	_selected_cube_idx = cube_idx
	_current_order_pos = -1
	var pos: Vector3 = _current_mantle.cubePositions[cube_idx]
	print("[Cube] selected idx=", cube_idx, " pos=", pos)
	_updating_attrs = true
	_cube_x_slider.value = pos.x
	_cube_y_slider.value = pos.y
	_cube_z_slider.value = pos.z
	_cube_color_picker.color = _current_mantle.cubeColors[cube_idx]
	_updating_attrs = false
	_hide_all_attrs()
	_cube_label.show()
	_cube_slider_container.show()
	_cube_color_label.show()
	_cube_color_picker.show()
	_add_cube_btn.visible = false
	_del_part_btn.visible = true

func _on_bone_deselected() -> void:
	_current_order_pos = -1
	_selected_cube_idx = -1
	_updating_attrs = true
	_note_edit.text = ""
	_updating_attrs = false
	_hide_all_attrs()
	_add_cube_btn.visible = true
	_del_part_btn.visible = false

func _on_rig_selected() -> void:
	_selected_cube_idx = -1
	_hide_all_attrs()
	_updating_attrs = true
	_rig_note_edit.text = _current_mantle.rigNote
	_rig_color_picker.color = _current_mantle.baseColor
	_updating_attrs = false
	_populate_shape_key_sliders()
	_rig_note_label.show()
	_rig_note_edit.show()
	_rig_color_label.show()
	_rig_color_picker.show()
	_shape_keys_label.show()
	_shape_key_container.show()
	_add_cube_btn.visible = false
	_del_part_btn.visible = false

func _populate_shape_key_sliders() -> void:
	for child in _shape_key_container.get_children():
		if child != _shape_key_template:
			child.queue_free()
	if _current_mantle == null:
		return
	var names: PackedStringArray = _blend_shape_cache[_current_rig_type]
	for i in range(names.size()):
		var unit := _shape_key_template.duplicate() as VBoxContainer
		unit.visible = true
		var label := unit.get_child(0) as Label
		label.text = names[i]
		var slider := unit.get_child(1) as HSlider
		slider.value = _current_mantle.shapeKeyValues[i]
		slider.value_changed.connect(_on_shape_key_changed.bind(i))
		_shape_key_container.add_child(unit)

func _on_shape_key_changed(value: float, idx: int) -> void:
	if _updating_attrs or _current_mantle == null:
		return
	var values := _current_mantle.shapeKeyValues
	values[idx] = value
	_current_mantle.shapeKeyValues = values
	mesh.set_blend_shape_value(idx, value)

func _on_add_cube_pressed() -> void:
	if _current_mantle == null or _current_order_pos < 0:
		return
	var bone_order_pos := _current_order_pos
	var bone_idx: int = _current_bone_order[bone_order_pos]
	var indices := _current_mantle.cubeBoneIndices
	indices.append(bone_order_pos)
	_current_mantle.cubeBoneIndices = indices
	var positions := _current_mantle.cubePositions
	positions.append(Vector3.ZERO)
	_current_mantle.cubePositions = positions
	var colors := _current_mantle.cubeColors
	colors.append(_current_mantle.baseColor)
	_current_mantle.cubeColors = colors
	var new_cube_idx: int = _current_mantle.cubeBoneIndices.size() - 1
	_spawn_cube_mesh(new_cube_idx, bone_idx, Vector3.ZERO, _current_mantle.baseColor)
	print("[Cube] added idx=", new_cube_idx, " bone_order_pos=", bone_order_pos)
	_rebuild_hierarchy()
	_select_cube_in_tree(new_cube_idx)

func _on_del_part_pressed() -> void:
	if _current_mantle == null or _selected_cube_idx < 0:
		return
	var del_idx := _selected_cube_idx
	var bone_order_pos: int = _current_mantle.cubeBoneIndices[del_idx]
	if _cube_meshes.has(del_idx):
		_cube_meshes[del_idx].get_parent().queue_free()
		_cube_meshes.erase(del_idx)
	var new_meshes: Dictionary = {}
	for old_idx in _cube_meshes.keys():
		var new_idx: int = old_idx if old_idx < del_idx else old_idx - 1
		new_meshes[new_idx] = _cube_meshes[old_idx]
	_cube_meshes = new_meshes
	var indices := _current_mantle.cubeBoneIndices
	indices.remove_at(del_idx)
	_current_mantle.cubeBoneIndices = indices
	var positions := _current_mantle.cubePositions
	positions.remove_at(del_idx)
	_current_mantle.cubePositions = positions
	var colors := _current_mantle.cubeColors
	colors.remove_at(del_idx)
	_current_mantle.cubeColors = colors
	print("[Cube] deleted idx=", del_idx)
	_selected_cube_idx = -1
	_rebuild_hierarchy()
	_select_bone_by_order_pos(bone_order_pos)

func _on_cube_slider_changed(_value: float) -> void:
	if _updating_attrs or _current_mantle == null or _selected_cube_idx < 0:
		return
	var pos := Vector3(_cube_x_slider.value, _cube_y_slider.value, _cube_z_slider.value)
	var positions := _current_mantle.cubePositions
	positions[_selected_cube_idx] = pos
	_current_mantle.cubePositions = positions
	if _cube_meshes.has(_selected_cube_idx):
		_cube_meshes[_selected_cube_idx].position = pos
	print("[Cube] pos updated idx=", _selected_cube_idx, " pos=", pos)

func _on_cube_color_changed(color: Color) -> void:
	if _updating_attrs or _current_mantle == null or _selected_cube_idx < 0:
		return
	var colors := _current_mantle.cubeColors
	colors[_selected_cube_idx] = color
	_current_mantle.cubeColors = colors
	if _cube_meshes.has(_selected_cube_idx):
		(_cube_meshes[_selected_cube_idx].material_override as StandardMaterial3D).albedo_color = color
	print("[Cube] color updated idx=", _selected_cube_idx, " color=", color)

func _spawn_cube_mesh(cube_idx: int, bone_idx: int, pos: Vector3, color: Color) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone_idx
	skeleton.add_child(attachment)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	mesh_inst.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	attachment.add_child(mesh_inst)
	_cube_meshes[cube_idx] = mesh_inst

func _spawn_all_cube_meshes() -> void:
	for mesh_inst in _cube_meshes.values():
		mesh_inst.get_parent().queue_free()
	_cube_meshes.clear()
	if _current_mantle == null:
		return
	for i in range(_current_mantle.cubeBoneIndices.size()):
		var order_pos: int = _current_mantle.cubeBoneIndices[i]
		var bone_idx: int = _current_bone_order[order_pos]
		var pos: Vector3 = _current_mantle.cubePositions[i]
		var color: Color = _current_mantle.cubeColors[i]
		_spawn_cube_mesh(i, bone_idx, pos, color)

func _select_cube_in_tree(cube_idx: int) -> void:
	var root := hierarchyList.get_root()
	if root == null:
		return
	var found := _find_cube_item(root, cube_idx)
	if found != null:
		hierarchyList.set_selected(found, 0)
		_on_cube_selected(cube_idx)

func _find_cube_item(item: TreeItem, cube_idx: int) -> TreeItem:
	var child := item.get_first_child()
	while child != null:
		var meta = child.get_metadata(0)
		if typeof(meta) == TYPE_DICTIONARY and meta["cube"] == true and meta["idx"] == cube_idx:
			return child
		var result := _find_cube_item(child, cube_idx)
		if result != null:
			return result
		child = child.get_next()
	return null

func _select_bone_by_order_pos(order_pos: int) -> void:
	var bone_idx: int = _current_bone_order[order_pos]
	var root := hierarchyList.get_root()
	if root == null:
		return
	var found := _find_bone_item(root, bone_idx)
	if found != null:
		hierarchyList.set_selected(found, 0)
		_current_order_pos = order_pos
		_hide_all_attrs()
		_note_label.show()
		_note_edit.show()
		_updating_attrs = true
		_note_edit.text = _current_mantle.notes[order_pos]
		_updating_attrs = false
		_add_cube_btn.visible = true
		_del_part_btn.visible = false

func _find_bone_item(item: TreeItem, bone_idx: int) -> TreeItem:
	var child := item.get_first_child()
	while child != null:
		var meta = child.get_metadata(0)
		if typeof(meta) == TYPE_INT and meta == bone_idx:
			return child
		var result := _find_bone_item(child, bone_idx)
		if result != null:
			return result
		child = child.get_next()
	return null

func _hide_all_attrs() -> void:
	_note_label.hide()
	_note_edit.hide()
	_rig_note_label.hide()
	_rig_note_edit.hide()
	_rig_color_label.hide()
	_rig_color_picker.hide()
	_shape_keys_label.hide()
	_shape_key_container.hide()
	_cube_label.hide()
	_cube_slider_container.hide()
	_cube_color_label.hide()
	_cube_color_picker.hide()

func _apply_base_color() -> void:
	if _current_mantle == null:
		return
	var surface_count := mesh.mesh.get_surface_count()
	if surface_count != 1:
		push_error("[Mantle] Expected 1 surface on skin mesh, found: " + str(surface_count))
		return
	var mat := mesh.get_active_material(0)
	if mat == null:
		push_error("[Mantle] Skin mesh surface 0 has no material")
		return
	if not mat is StandardMaterial3D:
		push_error("[Mantle] Skin mesh surface 0 is not StandardMaterial3D, got: " + mat.get_class())
		return
	(mat as StandardMaterial3D).albedo_color = _current_mantle.baseColor

func _apply_shape_keys() -> void:
	if _current_mantle == null:
		return
	for i in range(_current_mantle.shapeKeyValues.size()):
		mesh.set_blend_shape_value(i, _current_mantle.shapeKeyValues[i])

func _on_color_changed(color: Color) -> void:
	if _updating_attrs or _current_mantle == null:
		return
	_current_mantle.baseColor = color
	_apply_base_color()

func _on_rig_note_changed() -> void:
	if _updating_attrs or _current_mantle == null:
		return
	_current_mantle.rigNote = _rig_note_edit.text

func _get_bone_order(rig_type: int) -> PackedInt32Array:
	if _bone_order_cache.has(rig_type):
		return _bone_order_cache[rig_type]
	var order := PackedInt32Array()
	for bone_idx in skeleton.get_parentless_bones():
		_build_bone_order(bone_idx, order)
	_bone_order_cache[rig_type] = order
	return order

func _build_bone_order(bone_idx: int, order: PackedInt32Array) -> void:
	order.append(bone_idx)
	for child_idx in skeleton.get_bone_children(bone_idx):
		_build_bone_order(child_idx, order)

func _on_save_pressed() -> void:
	if _current_mantle == null:
		return
	if _current_mantle_path == BLANK_MANTLE_PATH:
		_save_as_name_edit.text = ""
		_save_as_dialog.get_ok_button().disabled = true
		_save_as_dialog.popup_centered()
	else:
		_do_quick_save()

func _on_save_as_name_changed(text: String) -> void:
	_save_as_dialog.get_ok_button().disabled = text.strip_edges().is_empty()

func _on_save_as_confirmed() -> void:
	var name := _save_as_name_edit.text.strip_edges()
	if name.is_empty():
		return
	var path := "res://Mantles/" + name + ".tres"
	if ResourceLoader.exists(path):
		_pending_save_path = path
		_overwrite_dialog.dialog_text = "'" + name + "' already exists. Overwrite?"
		_overwrite_dialog.popup_centered()
	else:
		_do_save(path, name)

func _on_overwrite_confirmed() -> void:
	var name := _save_as_name_edit.text.strip_edges()
	_do_save(_pending_save_path, name)

func _do_quick_save() -> void:
	var err := ResourceSaver.save(_current_mantle, _current_mantle_path)
	if err != OK:
		push_error("[Mantle] Quick save failed: " + str(err))
		return
	_original_mantle = _current_mantle.duplicate()
	print("[Mantle] Quick saved to: ", _current_mantle_path)

func _do_save(path: String, mantle_name: String) -> void:
	var err := ResourceSaver.save(_current_mantle, path)
	if err != OK:
		push_error("[Mantle] Save failed: " + str(err))
		return
	_current_mantle_path = path
	_original_mantle = _current_mantle.duplicate()
	print("[Mantle] Saved to: ", path)
	_refresh_mantle_options()
	_select_mantle_by_name(mantle_name)

func _select_mantle_by_name(mantle_name: String) -> void:
	for i in range(_mantle_picker.item_count):
		if _mantle_picker.get_item_text(i) == mantle_name:
			_mantle_picker.select(i)
			break

func _build_save_as_dialog() -> void:
	_save_as_dialog = ConfirmationDialog.new()
	_save_as_dialog.title = "saving..."
	_save_as_dialog.min_size = Vector2i(300, 100)
	var lbl := Label.new()
	lbl.text = "name:"
	_save_as_name_edit = LineEdit.new()
	_save_as_dialog.add_child(lbl)
	_save_as_dialog.add_child(_save_as_name_edit)
	add_child(_save_as_dialog)
	_save_as_dialog.confirmed.connect(_on_save_as_confirmed)
	_save_as_name_edit.text_changed.connect(_on_save_as_name_changed)

func _build_overwrite_dialog() -> void:
	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = "overwrite?"
	_overwrite_dialog.min_size = Vector2i(300, 100)
	add_child(_overwrite_dialog)
	_overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)

func _process(_delta):
	pass
