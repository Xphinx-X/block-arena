extends Node3D

## Short-lived visual effects: tracers, muzzle flashes, hit sparks, death bursts.
## Everything is pooled in one node and stepped manually to avoid a scene per
## particle.

const Util := preload("res://scripts/util.gd")

var _items: Array = []


func tracer(from: Vector3, to: Vector3, color: Color, width: float = 0.07, life: float = 0.07) -> void:
	var d := from.distance_to(to)
	if d < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, d)
	mi.mesh = bm
	var m: StandardMaterial3D = Util.unshaded(color)
	mi.material_override = m
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	var dir := (to - from).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.995:
		mi.look_at(to, Vector3.UP)
	_add(mi, m, color, Vector3.ZERO, life, 0.0, Vector3.ZERO)


func muzzle(pos: Vector3, color: Color, size: float = 0.24) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Util.box_mesh(Vector3(size, size, size))
	var m: StandardMaterial3D = Util.unshaded(color)
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	_add(mi, m, color, Vector3.ZERO, 0.05, 0.0, Vector3.ZERO)


func sparks(pos: Vector3, color: Color, count: int = 4, power: float = 6.0, size: float = 0.10) -> void:
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = Util.box_mesh(Vector3(size, size, size))
		var m: StandardMaterial3D = Util.mat(color, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		add_child(mi)
		mi.global_position = pos
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.4), randf_range(-1.0, 1.0)).normalized()
		_add(mi, m, color, dir * power * randf_range(0.5, 1.0), 0.32, 24.0, Vector3(randf() * 12.0, randf() * 12.0, randf() * 12.0))


func burst(pos: Vector3, color: Color, count: int = 10, power: float = 9.0, size: float = 0.24) -> void:
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = Util.box_mesh(Vector3(size, size, size))
		var m: StandardMaterial3D = Util.mat(color, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		add_child(mi)
		mi.global_position = pos
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.5), randf_range(-1.0, 1.0)).normalized()
		_add(mi, m, color, dir * power * randf_range(0.6, 1.3), 0.9, 26.0, Vector3(randf() * 10.0, randf() * 10.0, randf() * 10.0))


func _add(node: MeshInstance3D, mat: StandardMaterial3D, color: Color, vel: Vector3, life: float, gravity: float, spin: Vector3) -> void:
	_items.append({
		"node": node,
		"mat": mat,
		"color": color,
		"vel": vel,
		"life": life,
		"max": life,
		"grav": gravity,
		"spin": spin,
	})


func _process(delta: float) -> void:
	for i in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[i]
		var node: MeshInstance3D = item["node"]
		if not is_instance_valid(node):
			_items.remove_at(i)
			continue
		item["life"] = float(item["life"]) - delta
		var life: float = item["life"]
		if life <= 0.0:
			node.queue_free()
			_items.remove_at(i)
			continue
		var vel: Vector3 = item["vel"]
		vel.y -= float(item["grav"]) * delta
		vel *= 1.0 - 2.0 * delta
		node.global_position += vel * delta
		node.rotate_x(float(item["spin"].x) * delta)
		node.rotate_y(float(item["spin"].y) * delta)
		var mat: StandardMaterial3D = item["mat"]
		var c: Color = item["color"]
		var k: float = clampf(life / float(item["max"]), 0.0, 1.0)
		mat.albedo_color = Color(c.r, c.g, c.b, c.a * k)
		item["vel"] = vel
