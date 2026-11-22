extends Node3D

## Builds the arena: textured floor, boundary walls, crates and pillars.

const Util := preload("res://scripts/util.gd")

const HALF := 22.0
const WALL_H := 4.5

## Fixed cover layout so every run is fair.
const CRATES := [
	Vector3(-8.0, 1.2, -6.0),
	Vector3(9.0, 1.2, 5.0),
	Vector3(4.5, 1.2, -12.0),
	Vector3(-14.0, 1.2, 9.0),
	Vector3(14.0, 1.2, -9.5),
	Vector3(-14.5, 1.2, 14.5),
	Vector3(-11.0, 1.2, -15.0),
	Vector3(16.5, 1.2, 14.5),
]

const PILLARS := [
	Vector2(-17.0, -17.0),
	Vector2(17.0, -17.0),
	Vector2(-17.0, 17.0),
	Vector2(17.0, 17.0),
]


func build() -> void:
	var floor_mat: StandardMaterial3D = Util.mat(Color(0.31, 0.54, 0.31), 0.95)
	floor_mat.albedo_texture = _grid_texture()
	floor_mat.uv1_scale = Vector3(11.0, 11.0, 1.0)
	Util.static_box(self, Vector3(HALF * 2.0, 1.0, HALF * 2.0), Vector3(0.0, -0.5, 0.0), floor_mat)

	var wall_mat: StandardMaterial3D = Util.mat(Color(0.50, 0.55, 0.66), 0.9)
	var trim_mat: StandardMaterial3D = Util.emissive(Color(0.35, 0.92, 1.0), 1.6)

	# Boundary walls.
	Util.static_box(self, Vector3(HALF * 2.0 + 2.0, WALL_H, 1.0), Vector3(0.0, WALL_H * 0.5, -HALF - 0.5), wall_mat)
	Util.static_box(self, Vector3(HALF * 2.0 + 2.0, WALL_H, 1.0), Vector3(0.0, WALL_H * 0.5, HALF + 0.5), wall_mat)
	Util.static_box(self, Vector3(1.0, WALL_H, HALF * 2.0 + 2.0), Vector3(-HALF - 0.5, WALL_H * 0.5, 0.0), wall_mat)
	Util.static_box(self, Vector3(1.0, WALL_H, HALF * 2.0 + 2.0), Vector3(HALF + 0.5, WALL_H * 0.5, 0.0), wall_mat)

	# Glowing trim along the top of each wall.
	Util.box(self, Vector3(HALF * 2.0, 0.14, 0.10), Vector3(0.0, WALL_H - 0.12, -HALF), trim_mat)
	Util.box(self, Vector3(HALF * 2.0, 0.14, 0.10), Vector3(0.0, WALL_H - 0.12, HALF), trim_mat)
	Util.box(self, Vector3(0.10, 0.14, HALF * 2.0), Vector3(-HALF, WALL_H - 0.12, 0.0), trim_mat)
	Util.box(self, Vector3(0.10, 0.14, HALF * 2.0), Vector3(HALF, WALL_H - 0.12, 0.0), trim_mat)

	# Crates.
	var crate_mat: StandardMaterial3D = Util.mat(Color(0.74, 0.52, 0.30), 0.85)
	var crate_edge: StandardMaterial3D = Util.mat(Color(0.52, 0.35, 0.19), 0.9)
	for crate in CRATES:
		Util.static_box(self, Vector3(2.4, 2.4, 2.4), crate, crate_mat)
		Util.box(self, Vector3(2.46, 0.12, 2.46), crate + Vector3(0.0, 1.14, 0.0), crate_edge)

	# Corner pillars.
	var pillar_mat: StandardMaterial3D = Util.mat(Color(0.62, 0.65, 0.74), 0.8)
	for p in PILLARS:
		Util.static_box(self, Vector3(1.7, 6.0, 1.7), Vector3(p.x, 3.0, p.y), pillar_mat)

	# Player spawn pad: dark slab with a thin glowing rim.
	var pad_mat: StandardMaterial3D = Util.mat(Color(0.16, 0.34, 0.38), 0.9)
	var pad_rim: StandardMaterial3D = Util.emissive(Color(0.32, 0.88, 1.0), 0.7)
	Util.box(self, Vector3(3.6, 0.05, 3.6), Vector3(0.0, 0.025, 8.0), pad_mat)
	for side in [-1.0, 1.0]:
		Util.box(self, Vector3(3.6, 0.06, 0.10), Vector3(0.0, 0.05, 8.0 + side * 1.75), pad_rim)
		Util.box(self, Vector3(0.10, 0.06, 3.6), Vector3(side * 1.75, 0.05, 8.0), pad_rim)

	# Low centre wall for cover.
	Util.static_box(self, Vector3(7.0, 1.4, 1.6), Vector3(0.0, 0.7, 0.0), crate_mat)
	Util.box(self, Vector3(7.06, 0.10, 1.66), Vector3(0.0, 1.36, 0.0), crate_edge)


func _grid_texture() -> ImageTexture:
	var size := 128
	var cells := 4
	var cell := size / cells
	var base := Color(0.31, 0.54, 0.31)
	var line := Color(0.26, 0.46, 0.27)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(base)
	for i in cells + 1:
		var p: int = mini(i * cell, size - 2)
		img.fill_rect(Rect2i(p, 0, 2, size), line)
		img.fill_rect(Rect2i(0, p, size, 2), line)
	return ImageTexture.create_from_image(img)
