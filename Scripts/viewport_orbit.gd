extends SubViewportContainer

@export var pivot: Node3D
@export var min_zoom: float = -10.0
@export var max_zoom: float = 10.0
@export var orbit_sensitivity: float = 0.3
@export var zoom_sensitivity: float = 1.0
@export var invert_y: bool = false

var _camera: Camera3D
var _initial_z: float = 0.0
var _zoom_value: float = 0.0
var _is_dragging: bool = false

func _ready() -> void:
	var vp := get_child(0) as SubViewport
	if vp:
		_camera = _find_camera(vp)
	if _camera:
		_initial_z = _camera.position.z

func _find_camera(node: Node) -> Camera3D:
	for child in node.get_children():
		if child is Camera3D:
			return child
		var result := _find_camera(child)
		if result:
			return result
	return null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_value = clampf(_zoom_value + zoom_sensitivity, min_zoom, max_zoom)
			_apply_zoom()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_value = clampf(_zoom_value - zoom_sensitivity, min_zoom, max_zoom)
			_apply_zoom()
	elif event is InputEventMouseMotion and _is_dragging and pivot:
		var motion := event as InputEventMouseMotion
		var yaw_delta := -motion.relative.x * deg_to_rad(orbit_sensitivity)
		var pitch_delta := motion.relative.y * deg_to_rad(orbit_sensitivity)
		if invert_y:
			pitch_delta = -pitch_delta
		pivot.rotate_y(yaw_delta)
		pivot.rotate_object_local(Vector3.RIGHT, pitch_delta)

func _apply_zoom() -> void:
	if _camera:
		_camera.position.z = _initial_z + _zoom_value
