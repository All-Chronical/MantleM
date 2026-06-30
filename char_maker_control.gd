extends Control

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

var _bone_order_cache: Dictionary = {}

var _current_mantle: Mantle = null
var _current_bone_order: PackedInt32Array = []
var _current_order_pos: int = -1
var _mantle_paths: Array[String] = []
var _updating_attrs: bool = false

func _ready():
	skeleton = find_children("*", "Skeleton3D", true, false)[0]
	mesh = skeleton.find_children("*", "MeshInstance3D", true, false)[0]

	hierarchyList.clear()
	var root := hierarchyList.create_item()
	root.set_text(0, "Rig")
	root.set_metadata(0, -1)
	for bone_idx in skeleton.get_parentless_bones():
		_add_bone_to_tree(bone_idx, root)
	hierarchyList.item_selected.connect(_on_bone_selected)

	_refresh_mantle_options()
	_mantle_picker.item_selected.connect(_on_mantle_selected)
	if _mantle_paths.size() > 0:
		_on_mantle_selected(0)

	_note_edit.text_changed.connect(_on_note_changed)
	_rig_note_edit.text_changed.connect(_on_rig_note_changed)
	_rig_color_picker.color_changed.connect(_on_color_changed)
	hierarchyList.nothing_selected.connect(_on_bone_deselected)

func _add_bone_to_tree(bone_idx: int, parent_item: TreeItem) -> void:
	var item := hierarchyList.create_item(parent_item)
	item.set_text(0, skeleton.get_bone_name(bone_idx))
	item.set_metadata(0, bone_idx)
	for child_idx in skeleton.get_bone_children(bone_idx):
		_add_bone_to_tree(child_idx, item)

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
	_current_mantle = mantle
	_current_bone_order = _get_bone_order(mantle.rigType)
	var _notes := _current_mantle.notes
	if _notes.size() < _current_bone_order.size():
		_notes.resize(_current_bone_order.size())
		_current_mantle.notes = _notes
	print("[Mantle] loaded, bone_count=", _current_bone_order.size(), " notes_size=", _current_mantle.notes.size())
	_apply_base_color()
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
	_rig_note_label.show()
	_rig_note_edit.show()
	_rig_color_label.show()
	_rig_color_picker.show()

func _hide_all_attrs() -> void:
	_note_label.hide()
	_note_edit.hide()
	_rig_note_label.hide()
	_rig_note_edit.hide()
	_rig_color_label.hide()
	_rig_color_picker.hide()

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

func _process(_delta):
	pass
