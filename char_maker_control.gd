extends Control

@export var hierarchyList : Tree
@export var skeleton : Skeleton3D
@export var mesh : MeshInstance3D
	
func _ready():
	skeleton = find_children("*", "Skeleton3D", true, false)[0]
	mesh = skeleton.find_children("*", "MeshInstance3D", true, false)[0]

	#hierarchyList.clear()
	var root := hierarchyList.create_item()
	hierarchyList.hide_root = true
	for bone_idx in skeleton.get_parentless_bones():
		_add_bone_to_tree(bone_idx, root)

func _add_bone_to_tree(bone_idx: int, parent_item: TreeItem) -> void:
	var item := hierarchyList.create_item(parent_item)
	item.set_text(0, skeleton.get_bone_name(bone_idx))
	for child_idx in skeleton.get_bone_children(bone_idx):
		_add_bone_to_tree(child_idx, item)

func _process(delta):
	pass
