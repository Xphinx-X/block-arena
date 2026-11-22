extends Node3D

## Third-person camera: a yawing rig with a spring arm that avoids walls.
## The yaw is driven by the right-hand touch stick (never auto-follows the
## player's aim, which would create a feedback loop).

const MIN_PITCH := -0.60
const MAX_PITCH := 0.10
const LOOK_SENS_X := 0.0042
const LOOK_SENS_Y := 0.0034

var yaw := 0.0
var pitch := -0.12
var distance := 8.4
var target_offset := Vector3(0.0, 2.80, 0.0)

var _arm: SpringArm3D
var _cam: Camera3D
var _shake := 0.0


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

	_apply()


func _apply() -> void:
	rotation.y = yaw
	_arm.rotation.x = pitch


func orbit(amount: float) -> void:
	yaw += amount
	_apply()


func reset_view(v: float = 0.0) -> void:
	yaw = v
	pitch = -0.12
	_apply()


func add_look(delta_px: Vector2) -> void:
	yaw -= delta_px.x * LOOK_SENS_X
	pitch = clampf(pitch - delta_px.y * LOOK_SENS_Y, MIN_PITCH, MAX_PITCH)
	_apply()


func follow(target_pos: Vector3, delta: float) -> void:
	var goal := target_pos + target_offset
	var t := 1.0 - exp(-14.0 * delta)
	global_position = global_position.lerp(goal, t)

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
	global_position = target_pos + target_offset
