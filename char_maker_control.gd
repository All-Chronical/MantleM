extends Control

@export var hierarchyList: Tree
@export var skeleton: Skeleton3D
@export var mesh: MeshInstance3D

@onready var _mantle_picker: OptionButton = $"Inspector/VBoxContainer/OptionButton"
@onready var _note_label: Label = $"Inspector/VBoxContainer/Label"
@onready var _note_edit: TextEdit = $"Inspector/VBoxContainer/TextEdit"

var _bone_order_cache: Dictionary = {}

var _current_mantle: Mantle = null
var _current_bone_order: PackedInt32Array = []
var _current_order_pos: int = -1
var _mantle_paths: Array[String] = []

func _ready():
	skeleton = find_children("*", "Skeleton3D", true, false)[0]
	mesh = skeleton.find_children("*", "MeshInstance3D", true, false)[0]

	hierarchyList.clear()
	var root := hierarchyList.create_item()
	for bone_idx in skeleton.get_parentless_bones():
		_add_bone_to_tree(bone_idx, root)
	hierarchyList.item_selected.connect(_on_bone_selected)

	_refresh_mantle_options()
	_mantle_picker.item_selected.connect(_on_mantle_selected)

	_note_edit.text_changed.connect(_on_note_changed)

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
	while _current_mantle.notes.size() < _current_bone_order.size():
		_current_mantle.notes.append("")
	_note_label.show()
	_note_edit.show()

func _on_bone_selected() -> void:
	var item := hierarchyList.get_selected()
	if item == null or _current_mantle == null:
		return
	var bone_idx: int = item.get_metadata(0)
	var order_pos := _current_bone_order.find(bone_idx)
	if order_pos < 0:
		return
	_current_order_pos = order_pos
	_note_edit.text = _current_mantle.notes[order_pos]

func _on_note_changed() -> void:
	if _current_mantle == null or _current_order_pos < 0:
		return
	_current_mantle.notes[_current_order_pos] = _note_edit.text

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
