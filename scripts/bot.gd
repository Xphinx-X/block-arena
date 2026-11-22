extends CharacterBody3D

## A blocky bot: chases the player, keeps its distance, strafes and fires
## hitscan shots with a bit of spread.

const FigureScript := preload("res://scripts/figure.gd")

const GRAVITY := 30.0
const SHOOT_RANGE := 24.0
const SHIRTS := [
	Color(0.86, 0.24, 0.28),
	Color(0.56, 0.28, 0.86),
	Color(0.20, 0.62, 0.42),
	Color(0.92, 0.55, 0.12),
	Color(0.30, 0.46, 0.92),
	Color(0.80, 0.30, 0.62),
]

var game
var health := 3.0
var max_health := 3.0
var speed := 4.2
var alive := true
var figure: Node3D

var _fire_cd := 1.2
var _walk_phase := 0.0
var _strafe := 1.0
var _strafe_t := 1.4
var _face_yaw := 0.0
var _los_t := 0.0
var _los := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)


func setup(p_game: Node, hp: float, spd: float, spawn_pos: Vector3) -> void:
	game = p_game
	health = hp
	max_health = hp
	speed = spd
	global_position = spawn_pos
	add_to_group("bots")

	figure = FigureScript.new()
	add_child(figure)
	var shirt: Color = SHIRTS[randi() % SHIRTS.size()]
	figure.build(shirt, Color(0.16, 0.16, 0.24), Color(0.84, 0.67, 0.52))

	# Materialise.
	figure.scale = Vector3(0.01, 0.01, 0.01)
	var tween := create_tween()
	tween.tween_property(figure, "scale", Vector3.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	figure.flash(Color(1.0, 1.0, 1.0), 0.14)

	_face_yaw = randf() * TAU


func _physics_process(delta: float) -> void:
	if not alive or game == null:
		return
	var player = game.player
	if player == null or not player.alive:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
		_apply_gravity(delta)
		return

	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)

	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe = -1.0 if randf() < 0.5 else 1.0
		_strafe_t = randf_range(1.2, 2.6)

	var desired := Vector3.ZERO
	if dist > 13.0:
		desired = dir
	elif dist < 8.0:
		desired = -dir
	else:
		desired = Vector3(-dir.z, 0.0, dir.x) * _strafe

	# Don't pile into each other.
	for other in game.bots:
		if other == self or not is_instance_valid(other) or not other.alive:
			continue
		var off: Vector3 = global_position - other.global_position
		off.y = 0.0
		var d := off.length()
		if d > 0.001 and d < 2.1:
			desired += (off / d) * (2.1 - d) * 0.9

	desired = desired.limit_length(1.0)
	var target := desired * speed
	velocity.x = move_toward(velocity.x, target.x, 34.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 34.0 * delta)
	_apply_gravity(delta)

	# Face the player.
	var target_yaw := atan2(-dir.x, -dir.z)
	_face_yaw = lerp_angle(_face_yaw, target_yaw, 1.0 - exp(-10.0 * delta))
	figure.rotation.y = _face_yaw

	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 0.4:
		_walk_phase += delta * (5.0 + flat * 0.9)
		figure.set_walk(_walk_phase, clampf(flat / maxf(speed, 0.1), 0.0, 1.0))
	else:
		figure.set_walk(0.0, 0.0)

	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.2
		_los = _has_los(player)

	_fire_cd -= delta
	if _fire_cd <= 0.0 and dist < SHOOT_RANGE and _los:
		_shoot(player)
		_fire_cd = randf_range(1.55, 2.4)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _has_los(player: Node) -> bool:
	var from: Vector3 = figure.muzzle.global_position
	var target: Vector3 = player.global_position + Vector3(0.0, 1.15, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _shoot(player: Node) -> void:
	var from: Vector3 = figure.muzzle.global_position
	var target: Vector3 = player.global_position + Vector3(0.0, 1.15, 0.0)
	var dir := (target - from).normalized()
	dir += Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * 0.042
	dir = dir.normalized()

	var to := from + dir * 45.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var end := to
	if not hit.is_empty():
		end = hit.position
		if hit.collider == player:
			player.take_damage(6.0)

	game.fx.tracer(from, end, Color(1.0, 0.36, 0.26), 0.06, 0.07)
	game.fx.muzzle(from, Color(1.0, 0.6, 0.28), 0.20)
	game.sfx.play("enemy_shot", randf_range(0.9, 1.15))


func take_damage(amount: float, _dir: Vector3 = Vector3.ZERO) -> void:
	if not alive:
		return
	health -= amount
	figure.flash(Color(1.0, 1.0, 1.0), 0.06)
	if health <= 0.0:
		_die()
	else:
		game.sfx.play("hit", randf_range(0.95, 1.1))


func _die() -> void:
	alive = false
	remove_from_group("bots")
	collision_layer = 0
	var center: Vector3 = global_position + Vector3(0.0, 1.1, 0.0)
	game.fx.burst(center, figure.shirt, 12, 10.0, 0.26)
	game.sfx.play("kill", randf_range(0.9, 1.15))
	game.on_bot_killed(self)
	queue_free()
