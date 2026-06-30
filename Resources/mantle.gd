extends Resource
class_name Mantle

@export var rigType: int = 0
@export var baseColor: Color = Color.BLACK
@export var rigNote: String = ""
@export var notes: PackedStringArray
@export var shapeKeyValues: PackedFloat32Array
@export var cubeBoneIndices: PackedInt32Array
@export var cubePositions: PackedVector3Array
@export var cubeColors: PackedColorArray
@export var cubeScales: PackedVector3Array
@export var flatBoneIndices: PackedInt32Array
@export var flatPositions: PackedVector3Array
@export var flatColors: PackedColorArray
@export var flatScales: PackedVector3Array
