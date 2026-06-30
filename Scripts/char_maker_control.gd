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
	print("[Mantle] loaded, bone_count=", _current_bone_order.size(), " notes_size=", _current_mantle.notes.size(), " shape_keys=", _current_mantle.shapeKeyValues.size())
	_save_btn.disabled = false
	_apply_base_color()
	_apply_shape_keys()
	_on_bone_deselected()

func _on_bone_selected() -> void:
	print("[Bone] _on_bone_selected fired")
	var item := hierarchyList.get_selected()
	if item == null or _current_mantle == null:
		print("[Bone] early exit — item=", item, " mantle=", _current_mantle)
		return
	var bone_idx: int = item.get_metadata(0)
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
	_hide_all_attrs()
	_note_label.show()
	_note_edit.show()

func _on_note_changed() -> void:
	if _updating_attrs or _current_mantle == null or _current_order_pos < 0:
		return
	var _notes := _current_mantle.notes
	_notes[_current_order_pos] = _note_edit.text
	_current_mantle.notes = _notes
	print("[Note] pos=", _current_order_pos, " text=", _note_edit.text)

func _on_bone_deselected() -> void:
	_current_order_pos = -1
	_updating_attrs = true
	_note_edit.text = ""
	_updating_attrs = false
	_hide_all_attrs()

func _on_rig_selected() -> void:
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

func _hide_all_attrs() -> void:
	_note_label.hide()
	_note_edit.hide()
	_rig_note_label.hide()
	_rig_note_edit.hide()
	_rig_color_label.hide()
	_rig_color_picker.hide()
	_shape_keys_label.hide()
	_shape_key_container.hide()

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
