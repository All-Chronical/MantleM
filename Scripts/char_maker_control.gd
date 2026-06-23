extends Control

@export var hierarchyList : Tree
@export var skeleton : Skeleton3D
@export var mesh : MeshInstance3D

@onready var menuBar: MenuBar = $Inspector/VBoxContainer/MenuBar
@onready var notesLabel: Label = $Inspector/VBoxContainer/Label
@onready var notesEdit: TextEdit = $Inspector/VBoxContainer/TextEdit

var _mantle_popup: PopupMenu
var _loaded_mantle: Mantle = null
var _bone_order_cache: Dictionary = {}  # rigType -> PackedInt32Array
var _bone_to_note_idx: Dictionary = {}  # bone_idx -> note_idx
var _updating_note: bool = false

func _ready():
	skeleton = find_children("*", "Skeleton3D", true, false)[0]
	mesh = skeleton.find_children("*", "MeshInstance3D", true, false)[0]

	# Setup menu bar with Mantles popup
	_mantle_popup = PopupMenu.new()
	_mantle_popup.name = "Mantles"
	menuBar.add_child(_mantle_popup)
	_mantle_popup.id_pressed.connect(_on_mantle_selected)
	_refresh_mantle_menu()

	# Setup tree selection
	hierarchyList.item_selected.connect(_on_bone_selected)

	# Setup text edit
	notesEdit.text_changed.connect(_on_note_edited)
	notesLabel.visible = false
	notesEdit.visible = false

func _refresh_mantle_menu() -> void:
	_mantle_popup.clear()
	var dir := DirAccess.open("res://Mantles")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var id := 0
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			_mantle_popup.add_item(file_name.get_basename(), id)
			_mantle_popup.set_item_metadata(id, "res://Mantles/" + file_name)
			id += 1
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_mantle_selected(id: int) -> void:
	var path: String = _mantle_popup.get_item_metadata(id)
	var mantle := load(path) as Mantle
	if mantle == null:
		push_error("Failed to load mantle: " + path)
		return
	_loaded_mantle = mantle

	# Get cached bone order for this rig type
	var bone_order := _get_bone_order(mantle.rigType)

	# Build bone_idx -> note_idx mapping
	_bone_to_note_idx.clear()
	for i in range(bone_order.size()):
		_bone_to_note_idx[bone_order[i]] = i

	# Populate tree
	hierarchyList.clear()
	var root := hierarchyList.create_item()
	for bone_idx in skeleton.get_parentless_bones():
		_add_bone_to_tree(bone_idx, root)

	# Show notes UI
	notesLabel.visible = true
	notesEdit.visible = true

func _get_bone_order(rig_type: int) -> PackedInt32Array:
	if _bone_order_cache.has(rig_type):
		return _bone_order_cache[rig_type]

	var order := PackedInt32Array()
	for bone_idx in skeleton.get_parentless_bones():
		_traverse_bones(bone_idx, order)
	_bone_order_cache[rig_type] = order
	return order

func _traverse_bones(bone_idx: int, order: PackedInt32Array) -> void:
	order.append(bone_idx)
	for child_idx in skeleton.get_bone_children(bone_idx):
		_traverse_bones(child_idx, order)

func _add_bone_to_tree(bone_idx: int, parent_item: TreeItem) -> void:
	var item := hierarchyList.create_item(parent_item)
	item.set_text(0, skeleton.get_bone_name(bone_idx))
	item.set_metadata(0, bone_idx)
	for child_idx in skeleton.get_bone_children(bone_idx):
		_add_bone_to_tree(child_idx, item)

func _on_bone_selected() -> void:
	if _loaded_mantle == null:
		return
	var item := hierarchyList.get_selected()
	if item == null:
		return
	var bone_idx: int = item.get_metadata(0)
	if not _bone_to_note_idx.has(bone_idx):
		return
	var note_idx: int = _bone_to_note_idx[bone_idx]
	_updating_note = true
	if note_idx < _loaded_mantle.notes.size():
		notesEdit.text = _loaded_mantle.notes[note_idx]
	else:
		notesEdit.text = ""
	_updating_note = false

func _on_note_edited() -> void:
	if _updating_note or _loaded_mantle == null:
		return
	var item := hierarchyList.get_selected()
	if item == null:
		return
	var bone_idx: int = item.get_metadata(0)
	if not _bone_to_note_idx.has(bone_idx):
		return
	var note_idx: int = _bone_to_note_idx[bone_idx]
	if _loaded_mantle.notes.size() <= note_idx:
		_loaded_mantle.notes.resize(note_idx + 1)
	_loaded_mantle.notes[note_idx] = notesEdit.text

func _process(delta):
	pass
