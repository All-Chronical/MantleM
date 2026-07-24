extends Resource
class_name Moveset

enum Move { NL, NH, NC, DL, DH, AL, AH }

const MOVE_CODES: Array[String] = ["NL", "NH", "NC", "DL", "DH", "AL", "AH"]

@export var movesetName: String = ""
@export var animLib: AnimationLibrary

var _resolved: PackedStringArray = PackedStringArray()

func resolve(lib_key: String) -> void:
	_resolved = PackedStringArray()
	_resolved.resize(MOVE_CODES.size())
	for i in range(MOVE_CODES.size()):
		var anim_name := movesetName + MOVE_CODES[i]
		if animLib != null and animLib.has_animation(anim_name):
			_resolved[i] = lib_key + "/" + anim_name
		else:
			_resolved[i] = ""

func get_play_path(move: Move) -> String:
	if move < 0 or move >= _resolved.size():
		return ""
	return _resolved[move]

func has_move(move: Move) -> bool:
	return get_play_path(move) != ""
