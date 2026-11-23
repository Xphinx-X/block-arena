extends Node3D

## A blocky humanoid built from boxes, with swinging limbs and a muzzle node.

const Util := preload("res://scripts/util.gd")

var shirt := Color(0.95, 0.42, 0.25)
var pants := Color(0.18, 0.22, 0.42)
var skin := Color(0.97, 0.80, 0.65)

var muzzle: Node3D
var head: Node3D

var _mats: Array = []
var _base: Array = []
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _flash_tween: Tween


func build(p_shirt: Color, p_pants: Color, p_skin: Color) -> void:
	shirt = p_shirt
	pants = p_pants
	skin = p_skin

	var m_shirt: StandardMaterial3D = _add_mat(shirt)
	var m_pants: StandardMaterial3D = _add_mat(pants)
	var m_skin: StandardMaterial3D = _add_mat(skin)
	var m_gun: StandardMaterial3D = _add_mat(Color(0.13, 0.14, 0.18), 0.6, 0.25)
	var m_eye: StandardMaterial3D = _add_mat(Color(0.06, 0.07, 0.10))
	var m_hair: StandardMaterial3D = _add_mat(Color(0.17, 0.13, 0.11))

	# Torso.
	Util.box(self, Vector3(0.80, 0.76, 0.46), Vector3(0.0, 1.20, 0.0), m_shirt)

	# Head with eyes on the front face (-Z).
	head = Node3D.new()
	head.position = Vector3(0.0, 1.82, 0.0)
	add_child(head)
	Util.box(head, Vector3(0.56, 0.56, 0.54), Vector3.ZERO, m_skin)
	Util.box(head, Vector3(0.60, 0.22, 0.58), Vector3(0.0, 0.20, 0.0), m_hair)
	Util.box(head, Vector3(0.10, 0.13, 0.05), Vector3(-0.13, 0.05, -0.28), m_eye)
	Util.box(head, Vector3(0.10, 0.13, 0.05), Vector3(0.13, 0.05, -0.28), m_eye)

	# Limbs hang from pivots so they can swing.
	_leg_l = _limb(Vector3(-0.20, 0.84, 0.0), Vector3(0.28, 0.84, 0.30), m_pants)
	_leg_r = _limb(Vector3(0.20, 0.84, 0.0), Vector3(0.28, 0.84, 0.30), m_pants)
	_arm_l = _limb(Vector3(-0.52, 1.50, 0.0), Vector3(0.22, 0.68, 0.26), m_skin)
	_arm_r = _limb(Vector3(0.52, 1.50, 0.0), Vector3(0.22, 0.68, 0.26), m_skin)

	# Right arm holds the gun up and forward.
	_arm_r.rotation.x = 1.25

	# Gun in the right hand, pointing down -Z.
	Util.box(self, Vector3(0.15, 0.18, 0.62), Vector3(0.46, 1.24, -0.32), m_gun)
	Util.box(self, Vector3(0.10, 0.26, 0.10), Vector3(0.46, 1.10, -0.16), m_gun)

	muzzle = Node3D.new()
	muzzle.position = Vector3(0.46, 1.24, -0.70)
	add_child(muzzle)


func _limb(pivot: Vector3, size: Vector3, material: Material) -> Node3D:
	var node := Node3D.new()
	node.position = pivot
	add_child(node)
	Util.box(node, size, Vector3(0.0, -size.y * 0.5, 0.0), material)
	return node


func _add_mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = Util.mat(color, roughness, metallic)
	_mats.append(m)
	_base.append(color)
	return m


## phase drives the swing, amount is 0..1 based on movement speed.
func set_walk(phase: float, amount: float) -> void:
	var swing := sin(phase) * 0.75 * amount
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = 1.25 + swing * 0.12


## Slide pose: legs thrown forward, arms trailing. amount is 0..1.
func set_slide(amount: float) -> void:
	var k := clampf(amount, 0.0, 1.0)
	_leg_l.rotation.x = 1.30 * k
	_leg_r.rotation.x = 1.05 * k
	_arm_l.rotation.x = -0.55 * k
	_arm_r.rotation.x = 1.25 + 0.35 * k


## Brief white/hurt flash on every part.
func flash(color: Color = Color(1.0, 1.0, 1.0), time: float = 0.07) -> void:
	for m in _mats:
		m.albedo_color = color
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(time)
	_flash_tween.tween_callback(_restore)


func _restore() -> void:
	for i in _mats.size():
		_mats[i].albedo_color = _base[i]
