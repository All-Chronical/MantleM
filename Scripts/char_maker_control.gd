extends Control

@export var hierarchyList: Tree
@export var mantle_skin: MantleSkin

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
@onready var _add_flat_btn: Button = $HBoxContainer/Hierarchy/VBoxContainer/HBoxContainer/AddFBtn
@onready var _del_part_btn: Button = $HBoxContainer/Hierarchy/VBoxContainer/HBoxContainer/DelPBtn
@onready var _flat_label: Label = $HBoxContainer/Inspector/VBoxContainer/FlatLabel
@onready var _flat_slider_container: VBoxContainer = $HBoxContainer/Inspector/VBoxContainer/FlatSliderContainer
@onready var _flat_x_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/FlatSliderContainer/XContainer/XSlider
@onready var _flat_y_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/FlatSliderContainer/YContainer/YSlider
@onready var _flat_z_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/FlatSliderContainer/ZContainer/ZSlider
@onready var _flat_color_label: Label = $HBoxContainer/Inspector/VBoxContainer/FlatColorLabel
@onready var _flat_color_picker: ColorPickerButton = $HBoxContainer/Inspector/VBoxContainer/FlatColorPicker
@onready var _cube_scale_label: Label = $HBoxContainer/Inspector/VBoxContainer/CubeScaleLabel
@onready var _cube_scale_slider_container: VBoxContainer = $HBoxContainer/Inspector/VBoxContainer/CubeScaleSliderContainer
@onready var _cube_sx_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/CubeScaleSliderContainer/XContainer/XSlider
@onready var _cube_sy_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/CubeScaleSliderContainer/YContainer/YSlider
@onready var _cube_sz_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/CubeScaleSliderContainer/ZContainer/ZSlider
@onready var _flat_scale_label: Label = $HBoxContainer/Inspector/VBoxContainer/FlatScaleLabel
@onready var _flat_scale_slider_container: VBoxContainer = $HBoxContainer/Inspector/VBoxContainer/FlatScaleSliderContainer
@onready var _flat_sx_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/FlatScaleSliderContainer/XContainer/XSlider
@onready var _flat_sy_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/FlatScaleSliderContainer/YContainer/YSlider
@onready var _flat_sz_slider: HSlider = $HBoxContainer/Inspector/VBoxContainer/FlatScaleSliderContainer/ZContainer/ZSlider

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

var _selected_cube_idx: int = -1
var _selected_flat_idx: int = -1
var _selected_part_type: int = 0

func _ready():
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
	_add_flat_btn.pressed.connect(_on_add_flat_pressed)
	_del_part_btn.pressed.connect(_on_del_part_pressed)
	_del_part_btn.visible = false
	_flat_x_slider.value_changed.connect(_on_flat_slider_changed)
	_flat_y_slider.value_changed.connect(_on_flat_slider_changed)
	_flat_z_slider.value_changed.connect(_on_flat_slider_changed)
	_flat_color_picker.color_changed.connect(_on_flat_color_changed)
	_cube_sx_slider.value_changed.connect(_on_cube_scale_changed)
	_cube_sy_slider.value_changed.connect(_on_cube_scale_changed)
	_cube_sz_slider.value_changed.connect(_on_cube_scale_changed)
	_flat_sx_slider.value_changed.connect(_on_flat_scale_changed)
	_flat_sy_slider.value_changed.connect(_on_flat_scale_changed)
	_flat_sz_slider.value_changed.connect(_on_flat_scale_changed)

	_refresh_mantle_options()
	_mantle_picker.item_selected.connect(_on_mantle_selected)
	if _mantle_paths.size() > 0:
		_on_mantle_selected(0)

func _rebuild_hierarchy() -> void:
	hierarchyList.clear()
	var root := hierarchyList.create_item()
	root.set_text(0, "Rig")
	root.set_metadata(0, -1)
	var skeleton := mantle_skin.get_skeleton()
	if skeleton == null:
		return
	for bone_idx in skeleton.get_parentless_bones():
		_add_bone_to_tree(bone_idx, root, skeleton)

func _add_bone_to_tree(bone_idx: int, parent_item: TreeItem, skeleton: Skeleton3D) -> void:
	var item := hierarchyList.create_item(parent_item)
	item.set_text(0, skeleton.get_bone_name(bone_idx))
	item.set_metadata(0, bone_idx)
	var order_pos := _current_bone_order.find(bone_idx)
	if order_pos >= 0 and _current_mantle != null:
		for i in range(_current_mantle.cubeBoneIndices.size()):
			if _current_mantle.cubeBoneIndices[i] == order_pos:
				var cube_item := hierarchyList.create_item(item)
				cube_item.set_text(0, "Cube Part")
				cube_item.set_metadata(0, {"type": 1, "idx": i})
		for i in range(_current_mantle.flatBoneIndices.size()):
			if _current_mantle.flatBoneIndices[i] == order_pos:
				var flat_item := hierarchyList.create_item(item)
				flat_item.set_text(0, "Flat Part")
				flat_item.set_metadata(0, {"type": 2, "idx": i})
	for child_idx in skeleton.get_bone_children(bone_idx):
		_add_bone_to_tree(child_idx, item, skeleton)

func _refresh_mantle_options() -> void:
	_mantle_picker.clear()
	_mantle_paths.clear()
	_mantle_paths = MantleSerializer.list_mantle_paths()
	for path in _mantle_paths:
		_mantle_picker.add_item(path.get_file().get_basename())
		print(path.get_file().get_basename())

func _on_mantle_selected(id: int) -> void:
	if id >= _mantle_paths.size():
		return
	var mantle := load(_mantle_paths[id]) as Mantle
	if mantle == null:
		return
	if not MantleSkin.RIG_SCENES.has(mantle.rigType):
		push_error("[Mantle] rigType %d not in RIG_SCENES" % mantle.rigType)
		return
	_current_mantle_path = _mantle_paths[id]
	_original_mantle = mantle
	_current_mantle = _original_mantle.duplicate()
	mantle_skin.apply_mantle(_current_mantle)
	_current_bone_order = mantle_skin.get_bone_order()
	print("[Mantle] loaded, bone_count=", _current_bone_order.size(), " notes_size=", _current_mantle.notes.size(), " shape_keys=", _current_mantle.shapeKeyValues.size())
	_save_btn.disabled = false
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
		if metadata["type"] == 1:
			_on_cube_selected(metadata["idx"])
		else:
			_on_flat_selected(metadata["idx"])
		return
	var bone_idx: int = metadata
	if bone_idx < 0:
		_on_rig_selected()
		return
	var skeleton := mantle_skin.get_skeleton()
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
	_selected_flat_idx = -1
	_selected_part_type = 0
	_hide_all_attrs()
	_note_label.show()
	_note_edit.show()
	_add_cube_btn.visible = true
	_add_flat_btn.visible = true
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
	_selected_flat_idx = -1
	_selected_part_type = 1
	_current_order_pos = -1
	var pos: Vector3 = _current_mantle.cubePositions[cube_idx]
	print("[Cube] selected idx=", cube_idx, " pos=", pos)
	_updating_attrs = true
	_cube_x_slider.value = pos.x
	_cube_y_slider.value = pos.y
	_cube_z_slider.value = pos.z
	_cube_color_picker.color = _current_mantle.cubeColors[cube_idx]
	var scl: Vector3 = _current_mantle.cubeScales[cube_idx]
	_cube_sx_slider.value = scl.x
	_cube_sy_slider.value = scl.y
	_cube_sz_slider.value = scl.z
	_updating_attrs = false
	_hide_all_attrs()
	_cube_label.show()
	_cube_slider_container.show()
	_cube_scale_label.show()
	_cube_scale_slider_container.show()
	_cube_color_label.show()
	_cube_color_picker.show()
	_add_cube_btn.visible = false
	_add_flat_btn.visible = false
	_del_part_btn.visible = true

func _on_flat_selected(flat_idx: int) -> void:
	_selected_flat_idx = flat_idx
	_selected_cube_idx = -1
	_selected_part_type = 2
	_current_order_pos = -1
	var pos: Vector3 = _current_mantle.flatPositions[flat_idx]
	print("[Flat] selected idx=", flat_idx, " pos=", pos)
	_updating_attrs = true
	_flat_x_slider.value = pos.x
	_flat_y_slider.value = pos.y
	_flat_z_slider.value = pos.z
	_flat_color_picker.color = _current_mantle.flatColors[flat_idx]
	var scl: Vector3 = _current_mantle.flatScales[flat_idx]
	_flat_sx_slider.value = scl.x
	_flat_sy_slider.value = scl.y
	_flat_sz_slider.value = scl.z
	_updating_attrs = false
	_hide_all_attrs()
	_flat_label.show()
	_flat_slider_container.show()
	_flat_scale_label.show()
	_flat_scale_slider_container.show()
	_flat_color_label.show()
	_flat_color_picker.show()
	_add_cube_btn.visible = false
	_add_flat_btn.visible = false
	_del_part_btn.visible = true

func _on_bone_deselected() -> void:
	_current_order_pos = -1
	_selected_cube_idx = -1
	_selected_flat_idx = -1
	_selected_part_type = 0
	_updating_attrs = true
	_note_edit.text = ""
	_updating_attrs = false
	_hide_all_attrs()
	_add_cube_btn.visible = true
	_add_flat_btn.visible = true
	_del_part_btn.visible = false

func _on_rig_selected() -> void:
	_selected_cube_idx = -1
	_selected_flat_idx = -1
	_selected_part_type = 0
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
	_add_flat_btn.visible = false
	_del_part_btn.visible = false

func _populate_shape_key_sliders() -> void:
	for child in _shape_key_container.get_children():
		if child != _shape_key_template:
			child.queue_free()
	if _current_mantle == null:
		return
	var names: PackedStringArray = mantle_skin.get_blend_shape_names()
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
	mantle_skin.apply_shape_key(idx, value)

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
	var scales := _current_mantle.cubeScales
	scales.append(Vector3.ONE)
	_current_mantle.cubeScales = scales
	var new_cube_idx: int = _current_mantle.cubeBoneIndices.size() - 1
	mantle_skin.spawn_cube(new_cube_idx, bone_idx, Vector3.ZERO, _current_mantle.baseColor, Vector3.ONE)
	print("[Cube] added idx=", new_cube_idx, " bone_order_pos=", bone_order_pos)
	_rebuild_hierarchy()
	_select_cube_in_tree(new_cube_idx)

func _on_add_flat_pressed() -> void:
	if _current_mantle == null or _current_order_pos < 0:
		return
	var bone_order_pos := _current_order_pos
	var bone_idx: int = _current_bone_order[bone_order_pos]
	var indices := _current_mantle.flatBoneIndices
	indices.append(bone_order_pos)
	_current_mantle.flatBoneIndices = indices
	var positions := _current_mantle.flatPositions
	positions.append(Vector3.ZERO)
	_current_mantle.flatPositions = positions
	var colors := _current_mantle.flatColors
	colors.append(_current_mantle.baseColor)
	_current_mantle.flatColors = colors
	var scales := _current_mantle.flatScales
	scales.append(Vector3.ONE)
	_current_mantle.flatScales = scales
	var new_flat_idx: int = _current_mantle.flatBoneIndices.size() - 1
	mantle_skin.spawn_flat(new_flat_idx, bone_idx, Vector3.ZERO, _current_mantle.baseColor, Vector3.ONE)
	print("[Flat] added idx=", new_flat_idx, " bone_order_pos=", bone_order_pos)
	_rebuild_hierarchy()
	_select_flat_in_tree(new_flat_idx)

func _on_del_part_pressed() -> void:
	if _current_mantle == null or _selected_part_type == 0:
		return
	if _selected_part_type == 1:
		_delete_cube(_selected_cube_idx)
	else:
		_delete_flat(_selected_flat_idx)

func _delete_cube(del_idx: int) -> void:
	var bone_order_pos: int = _current_mantle.cubeBoneIndices[del_idx]
	mantle_skin.despawn_cube(del_idx)
	var indices := _current_mantle.cubeBoneIndices
	indices.remove_at(del_idx)
	_current_mantle.cubeBoneIndices = indices
	var positions := _current_mantle.cubePositions
	positions.remove_at(del_idx)
	_current_mantle.cubePositions = positions
	var colors := _current_mantle.cubeColors
	colors.remove_at(del_idx)
	_current_mantle.cubeColors = colors
	var scales := _current_mantle.cubeScales
	scales.remove_at(del_idx)
	_current_mantle.cubeScales = scales
	print("[Cube] deleted idx=", del_idx)
	_selected_cube_idx = -1
	_selected_part_type = 0
	_rebuild_hierarchy()
	_select_bone_by_order_pos(bone_order_pos)

func _delete_flat(del_idx: int) -> void:
	var bone_order_pos: int = _current_mantle.flatBoneIndices[del_idx]
	mantle_skin.despawn_flat(del_idx)
	var indices := _current_mantle.flatBoneIndices
	indices.remove_at(del_idx)
	_current_mantle.flatBoneIndices = indices
	var positions := _current_mantle.flatPositions
	positions.remove_at(del_idx)
	_current_mantle.flatPositions = positions
	var colors := _current_mantle.flatColors
	colors.remove_at(del_idx)
	_current_mantle.flatColors = colors
	var scales := _current_mantle.flatScales
	scales.remove_at(del_idx)
	_current_mantle.flatScales = scales
	print("[Flat] deleted idx=", del_idx)
	_selected_flat_idx = -1
	_selected_part_type = 0
	_rebuild_hierarchy()
	_select_bone_by_order_pos(bone_order_pos)

func _on_cube_slider_changed(_value: float) -> void:
	if _updating_attrs or _current_mantle == null or _selected_cube_idx < 0:
		return
	var pos := Vector3(_cube_x_slider.value, _cube_y_slider.value, _cube_z_slider.value)
	var positions := _current_mantle.cubePositions
	positions[_selected_cube_idx] = pos
	_current_mantle.cubePositions = positions
	mantle_skin.update_cube_position(_selected_cube_idx, pos)
	print("[Cube] pos updated idx=", _selected_cube_idx, " pos=", pos)

func _on_cube_color_changed(color: Color) -> void:
	if _updating_attrs or _current_mantle == null or _selected_cube_idx < 0:
		return
	var colors := _current_mantle.cubeColors
	colors[_selected_cube_idx] = color
	_current_mantle.cubeColors = colors
	mantle_skin.update_cube_color(_selected_cube_idx, color)
	print("[Cube] color updated idx=", _selected_cube_idx, " color=", color)

func _on_cube_scale_changed(_value: float) -> void:
	if _updating_attrs or _current_mantle == null or _selected_cube_idx < 0:
		return
	var scl := Vector3(_cube_sx_slider.value, _cube_sy_slider.value, _cube_sz_slider.value)
	var scales := _current_mantle.cubeScales
	scales[_selected_cube_idx] = scl
	_current_mantle.cubeScales = scales
	mantle_skin.update_cube_scale(_selected_cube_idx, scl)
	print("[Cube] scale updated idx=", _selected_cube_idx, " scale=", scl)

func _on_flat_slider_changed(_value: float) -> void:
	if _updating_attrs or _current_mantle == null or _selected_flat_idx < 0:
		return
	var pos := Vector3(_flat_x_slider.value, _flat_y_slider.value, _flat_z_slider.value)
	var positions := _current_mantle.flatPositions
	positions[_selected_flat_idx] = pos
	_current_mantle.flatPositions = positions
	mantle_skin.update_flat_position(_selected_flat_idx, pos)
	print("[Flat] pos updated idx=", _selected_flat_idx, " pos=", pos)

func _on_flat_color_changed(color: Color) -> void:
	if _updating_attrs or _current_mantle == null or _selected_flat_idx < 0:
		return
	var colors := _current_mantle.flatColors
	colors[_selected_flat_idx] = color
	_current_mantle.flatColors = colors
	mantle_skin.update_flat_color(_selected_flat_idx, color)
	print("[Flat] color updated idx=", _selected_flat_idx, " color=", color)

func _on_flat_scale_changed(_value: float) -> void:
	if _updating_attrs or _current_mantle == null or _selected_flat_idx < 0:
		return
	var scl := Vector3(_flat_sx_slider.value, _flat_sy_slider.value, _flat_sz_slider.value)
	var scales := _current_mantle.flatScales
	scales[_selected_flat_idx] = scl
	_current_mantle.flatScales = scales
	mantle_skin.update_flat_scale(_selected_flat_idx, scl)
	print("[Flat] scale updated idx=", _selected_flat_idx, " scale=", scl)

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
		if typeof(meta) == TYPE_DICTIONARY and meta["type"] == 1 and meta["idx"] == cube_idx:
			return child
		var result := _find_cube_item(child, cube_idx)
		if result != null:
			return result
		child = child.get_next()
	return null

func _select_flat_in_tree(flat_idx: int) -> void:
	var root := hierarchyList.get_root()
	if root == null:
		return
	var found := _find_flat_item(root, flat_idx)
	if found != null:
		hierarchyList.set_selected(found, 0)
		_on_flat_selected(flat_idx)

func _find_flat_item(item: TreeItem, flat_idx: int) -> TreeItem:
	var child := item.get_first_child()
	while child != null:
		var meta = child.get_metadata(0)
		if typeof(meta) == TYPE_DICTIONARY and meta["type"] == 2 and meta["idx"] == flat_idx:
			return child
		var result := _find_flat_item(child, flat_idx)
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
		_add_flat_btn.visible = true
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
	_cube_scale_label.hide()
	_cube_scale_slider_container.hide()
	_cube_color_label.hide()
	_cube_color_picker.hide()
	_flat_label.hide()
	_flat_slider_container.hide()
	_flat_scale_label.hide()
	_flat_scale_slider_container.hide()
	_flat_color_label.hide()
	_flat_color_picker.hide()

func _on_color_changed(color: Color) -> void:
	if _updating_attrs or _current_mantle == null:
		return
	_current_mantle.baseColor = color
	mantle_skin.apply_base_color()

func _on_rig_note_changed() -> void:
	if _updating_attrs or _current_mantle == null:
		return
	_current_mantle.rigNote = _rig_note_edit.text

func _on_save_pressed() -> void:
	if _current_mantle == null:
		return
	if MantleSerializer.is_blank(_current_mantle_path):
		_save_as_name_edit.text = ""
		_save_as_dialog.get_ok_button().disabled = true
		_save_as_dialog.popup_centered()
	else:
		_do_quick_save()

func _on_save_as_name_changed(text: String) -> void:
	_save_as_dialog.get_ok_button().disabled = text.strip_edges().is_empty()

func _on_save_as_confirmed() -> void:
	var mantle_name := _save_as_name_edit.text.strip_edges()
	if mantle_name.is_empty():
		return
	var result := MantleSerializer.save_as(_current_mantle, mantle_name)
	if result["needs_overwrite"]:
		_pending_save_path = result["path"]
		_overwrite_dialog.dialog_text = "'" + mantle_name + "' already exists. Overwrite?"
		_overwrite_dialog.popup_centered()
	elif result["error"] == OK:
		_current_mantle_path = result["path"]
		_original_mantle = _current_mantle.duplicate()
		_refresh_mantle_options()
		_select_mantle_by_name(mantle_name)

func _on_overwrite_confirmed() -> void:
	var mantle_name := _save_as_name_edit.text.strip_edges()
	var err := MantleSerializer.overwrite_save(_current_mantle, _pending_save_path)
	if err == OK:
		_current_mantle_path = _pending_save_path
		_original_mantle = _current_mantle.duplicate()
		_refresh_mantle_options()
		_select_mantle_by_name(mantle_name)

func _do_quick_save() -> void:
	var err := MantleSerializer.quick_save(_current_mantle, _current_mantle_path)
	if err == OK:
		_original_mantle = _current_mantle.duplicate()

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
