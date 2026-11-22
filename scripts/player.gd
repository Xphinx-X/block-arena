extends CharacterBody3D

## The player: blocky avatar, camera-relative movement, hitscan gun with
## gentle auto-aim.

const FigureScript := preload("res://scripts/figure.gd")

signal health_changed(hp: float, max_hp: float)
signal died

const MAX_HEALTH := 100.0
const SPEED := 7.4
const ACCEL := 70.0
const GRAVITY := 30.0
const FIRE_INTERVAL := 0.155
const RANGE := 80.0
const AUTO_AIM_RANGE := 46.0
const AUTO_AIM_DOT := 0.930
const BOT_LAYER_MASK := 5

var game
var health := MAX_HEALTH
var alive := true

## World-space direction (length 0..1) requested by the HUD.
var move_dir := Vector3.ZERO
## World-space direction the camera is aiming along.
var aim_dir := Vector3.FORWARD
var shooting := false

var figure: Node3D
var muzzle: Node3D

var _fire_cd := 0.0
var _walk_phase := 0.0
var _face_yaw := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	figure = FigureScript.new()
	add_child(figure)
	figure.build(Color(0.96, 0.45, 0.24), Color(0.16, 0.22, 0.44), Color(0.88, 0.71, 0.55))
	muzzle = figure.muzzle


func _physics_process(delta: float) -> void:
	if alive:
		var target := move_dir * SPEED
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= GRAVITY * delta
		move_and_slide()

		_update_animation(delta)

		_fire_cd -= delta
		if shooting and _fire_cd <= 0.0:
			_fire()


func _update_animation(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 0.5:
		_walk_phase += delta * (5.0 + flat * 0.8)
		figure.set_walk(_walk_phase, clampf(flat / SPEED, 0.0, 1.0))
	else:
		figure.set_walk(0.0, 0.0)

	var face: Vector3 = aim_dir if shooting else move_dir
	if face.length() > 0.05:
		var yaw := atan2(-face.x, -face.z)
		_face_yaw = lerp_angle(_face_yaw, yaw, 1.0 - exp(-16.0 * delta))
	figure.rotation.y = _face_yaw


func _fire() -> void:
	_fire_cd = FIRE_INTERVAL
	var from: Vector3 = muzzle.global_position
	var dir := _aim_dir(from)
	var to := from + dir * RANGE

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, BOT_LAYER_MASK, [get_rid()])
	var hit := space.intersect_ray(query)

	var end := to
	var struck := false
	if not hit.is_empty():
		end = hit.position
		var collider = hit.collider
		if collider != null and collider.is_in_group("bots"):
			collider.take_damage(1.0, dir)
			struck = true

	game.fx.tracer(from, end, Color(1.0, 0.94, 0.55), 0.07, 0.06)
	game.fx.muzzle(from, Color(1.0, 0.85, 0.45), 0.26)
	game.sfx.play("shot", randf_range(0.94, 1.06))
	if struck:
		game.on_player_hit(end)


## Aim at whatever the crosshair (screen centre) is over, then nudge the shot
## toward the nearest bot inside a narrow cone.
func _aim_dir(from: Vector3) -> Vector3:
	var dir := aim_dir.normalized()
	if dir.length() < 0.1:
		dir = Vector3.FORWARD

	var cam: Camera3D = game.cam.camera()
	if cam != null:
		var origin: Vector3 = cam.global_position
		var fwd: Vector3 = -cam.global_transform.basis.z
		var far: Vector3 = origin + fwd * 90.0
		var query := PhysicsRayQueryParameters3D.create(origin, far, BOT_LAYER_MASK)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var target := far
		if not hit.is_empty():
			target = hit.position
		var to_target := target - from
		if to_target.length() > 2.0:
			dir = to_target.normalized()

	return _aim_with_assist(from, dir)


func _aim_with_assist(from: Vector3, dir: Vector3) -> Vector3:
	var best_dot := AUTO_AIM_DOT
	var best_dir := dir
	for bot in get_tree().get_nodes_in_group("bots"):
		if not is_instance_valid(bot) or not bot.alive:
			continue
		var target: Vector3 = bot.global_position + Vector3(0.0, 1.15, 0.0)
		var offset := target - from
		var dist := offset.length()
		if dist > AUTO_AIM_RANGE or dist < 0.01:
			continue
		var norm := offset / dist
		var dot := norm.dot(dir)
		if dot <= best_dot:
			continue
		var los := PhysicsRayQueryParameters3D.create(from, target, 1)
		if get_world_3d().direct_space_state.intersect_ray(los).is_empty():
			best_dot = dot
			best_dir = norm
	return best_dir


func take_damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	figure.flash(Color(1.0, 0.35, 0.30), 0.08)
	game.on_player_hurt(amount)
	if health <= 0.0:
		_die()


func _die() -> void:
	alive = false
	shooting = false
	move_dir = Vector3.ZERO
	velocity = Vector3.ZERO
	collision_layer = 0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(figure, "rotation:z", deg_to_rad(86.0), 0.55) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(figure, "position:y", 0.12, 0.55)
	tween.tween_property(figure, "rotation:x", deg_to_rad(-10.0), 0.55)

	died.emit()


func max_hp() -> float:
	return MAX_HEALTH


func reset_for_run(spawn_pos: Vector3) -> void:
	alive = true
	health = MAX_HEALTH
	shooting = false
	move_dir = Vector3.ZERO
	velocity = Vector3.ZERO
	collision_layer = 2
	_fire_cd = 0.0
	global_position = spawn_pos
	figure.rotation = Vector3.ZERO
	figure.position = Vector3.ZERO
	figure.scale = Vector3.ONE
	health_changed.emit(health, MAX_HEALTH)
