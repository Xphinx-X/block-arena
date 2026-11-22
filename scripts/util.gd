extends RefCounted

## Small helpers for building the blocky world from primitive meshes.


static func mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.35
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func emissive(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## A solid, collidable box (floor, wall, crate).
static func static_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = material
	body.add_child(mi)

	parent.add_child(body)
	return body


## Fades a mesh out over `time` and frees it.
static func fade_out(node: Node3D, material: StandardMaterial3D, time: float) -> void:
	var tween := node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, time)
	tween.tween_callback(node.queue_free)
