extends Node3D

## Third-person spring-arm camera plus a first-person view model. Both modes
## share the same yaw/pitch, so switching view is instant and keeps your aim.

const Util := preload("res://scripts/util.gd")

const MIN_PITCH_TP := -0.60
const MAX_PITCH_TP := 0.10
const MIN_PITCH_FP := -1.25
const MAX_PITCH_FP := 0.95
const LOOK_SENS_X := 0.0042
const LOOK_SENS_Y := 0.0034

var yaw := 0.0
var pitch := -0.12
var distance := 8.4
var target_offset := Vector3(0.0, 2.80, 0.0)
var eye_height := 1.68
var first_person := false
var crouch := 0.0

var _arm: SpringArm3D
var _cam: Camera3D
var _shake := 0.0

var view_model: Node3D
var view_muzzle: Node3D


func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = distance
	_arm.margin = 0.35
	_arm.collision_mask = 1
	add_child(_arm)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.15
	_cam.far = 220.0
	_cam.current = true
	_arm.add_child(_cam)

	_build_view_model()
	_apply()


## Blocky gun shown in first person, parented to the camera.
func _build_view_model() -> void:
	view_model = Node3D.new()
	view_model.name = "ViewModel"
	_cam.add_child(view_model)
	view_model.position = Vector3(0.24, -0.24, -0.85)
	view_model.rotation = Vector3(0.02, 0.20, 0.0)
	view_model.scale = Vector3(0.90, 0.90, 0.90)

	var body: StandardMaterial3D = Util.unshaded_opaque(Color(0.20, 0.22, 0.29))
	var metal: StandardMaterial3D = Util.unshaded_opaque(Color(0.52, 0.57, 0.68))
	var accent: StandardMaterial3D = Util.unshaded_opaque(Color(0.36, 0.92, 1.0))

	Util.box(view_model, Vector3(0.09, 0.11, 0.42), Vector3.ZERO, body)
	Util.box(view_model, Vector3(0.05, 0.05, 0.34), Vector3(0.0, 0.022, -0.36), metal)
	Util.box(view_model, Vector3(0.07, 0.16, 0.09), Vector3(0.0, -0.12, 0.08), body)
	Util.box(view_model, Vector3(0.07, 0.09, 0.14), Vector3(0.0, 0.0, 0.25), metal)
	Util.box(view_model, Vector3(0.03, 0.03, 0.12), Vector3(0.0, 0.070, -0.10), accent)

	view_muzzle = Node3D.new()
	view_muzzle.position = Vector3(0.0, 0.022, -0.53)
	view_model.add_child(view_muzzle)
	view_model.visible = false


func _apply() -> void:
	rotation.y = yaw
	_arm.rotation.x = pitch
	_arm.spring_length = 0.0 if first_person else distance
	if view_model != null:
		view_model.visible = first_person


func _pitch_limits() -> Vector2:
	if first_person:
		return Vector2(MIN_PITCH_FP, MAX_PITCH_FP)
	return Vector2(MIN_PITCH_TP, MAX_PITCH_TP)


func set_first_person(enabled: bool) -> void:
	first_person = enabled
	var limits := _pitch_limits()
	pitch = clampf(pitch, limits.x, limits.y)
	_apply()


func orbit(amount: float) -> void:
	yaw += amount
	_apply()


func reset_view(v: float = 0.0) -> void:
	yaw = v
	pitch = 0.0 if first_person else -0.12
	_apply()


func add_look(delta_px: Vector2) -> void:
	yaw -= delta_px.x * LOOK_SENS_X
	var limits := _pitch_limits()
	pitch = clampf(pitch - delta_px.y * LOOK_SENS_Y, limits.x, limits.y)
	_apply()


func follow(target_pos: Vector3, delta: float) -> void:
	var height: float = eye_height if first_person else target_offset.y
	var goal := Vector3(target_pos.x, target_pos.y + height - 0.45 * crouch, target_pos.z)
	if first_person:
		global_position = goal
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-14.0 * delta))

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.6)
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.30
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.30
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func camera() -> Camera3D:
	return _cam


func forward_flat() -> Vector3:
	var f := -_cam.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.001:
		return Vector3.FORWARD
	return f.normalized()


func right_flat() -> Vector3:
	var r := _cam.global_transform.basis.x
	r.y = 0.0
	if r.length() < 0.001:
		return Vector3.RIGHT
	return r.normalized()


func snap_to(target_pos: Vector3) -> void:
	var height: float = eye_height if first_person else target_offset.y
	global_position = Vector3(target_pos.x, target_pos.y + height, target_pos.z)
