extends Node3D

## Block Arena - a blocky third-person wave shooter.

const ArenaScript := preload("res://scripts/arena.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BotScript := preload("res://scripts/bot.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const FxScript := preload("res://scripts/fx.gd")
const SfxScript := preload("res://scripts/sfx.gd")

enum State { READY, PLAYING, WAVE_CLEAR, GAMEOVER }

const MAX_ALIVE := 6
const SPAWN_INTERVAL := 0.85
const WAVE_BREAK := 2.8
const PLAYER_SPAWN := Vector3(0.0, 0.2, 8.0)
const SAVE_PATH := "user://block_arena.cfg"
const RESTART_DELAY_MS := 800

var state := State.READY
var wave := 0
var score := 0
var kills := 0
var best := 0
var best_wave := 0
var first_person := false

var player
var arena
var cam
var hud
var fx
var sfx
var bots: Array = []

var _spawn_left := 0
var _spawn_timer := 0.0
var _wave_timer := 0.0
var _over_at := 0


func _ready() -> void:
	_build_environment()

	arena = ArenaScript.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()

	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.game = self
	player.global_position = PLAYER_SPAWN
	player.died.connect(_on_player_died)

	cam = CameraRigScript.new()
	cam.name = "Camera"
	add_child(cam)
	cam.snap_to(player.global_position)
	cam.reset_view(0.0)

	fx = FxScript.new()
	fx.name = "Fx"
	add_child(fx)

	sfx = SfxScript.new()
	sfx.name = "Sfx"
	add_child(sfx)

	hud = HudScript.new()
	hud.name = "Hud"
	add_child(hud)
	hud.tapped.connect(_on_tap)
	hud.view_toggled.connect(toggle_view)
	hud.slide_pressed.connect(_on_slide_pressed)

	_load_best()
	hud.set_best(best, best_wave)
	hud.set_mode("title")
	hud.set_stats(player.health, player.max_hp(), 1, 0, 0, 0)


func _process(delta: float) -> void:
	_tick_input(delta)
	_tick_waves(delta)

	cam.crouch = player.slide_amount()
	cam.follow(player.global_position, delta)
	if state == State.READY:
		cam.orbit(delta * 0.16)

	hud.set_stats(player.health, player.max_hp(), maxi(wave, 1), _spawn_left + alive_count(), score, kills)
	hud.set_slide(player.slide_ready(), player.slide_cooldown_ratio())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if state != State.PLAYING and state != State.WAVE_CLEAR:
				_on_tap()
		elif event.keycode == KEY_SHIFT:
			if state == State.PLAYING or state == State.WAVE_CLEAR:
				player.start_slide()


# ------------------------------------------------------------------ loop

func _tick_input(delta: float) -> void:
	if state != State.PLAYING and state != State.WAVE_CLEAR:
		player.move_dir = Vector3.ZERO
		player.shooting = false
		return

	var look: Vector2 = hud.take_look()
	if look.length() > 0.0:
		cam.add_look(look)

	var mv: Vector2 = hud.move_vec
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	if mv.length() > 1.0:
		mv = mv.normalized()

	var forward: Vector3 = cam.forward_flat()
	var right: Vector3 = cam.right_flat()
	player.move_dir = (right * mv.x + forward * mv.y).limit_length(1.0)
	player.aim_dir = forward
	player.shooting = hud.look_active or Input.is_key_pressed(KEY_SPACE)


func _tick_waves(delta: float) -> void:
	match state:
		State.PLAYING:
			_prune_bots()
			if _spawn_left > 0 and alive_count() < MAX_ALIVE:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_bot()
					_spawn_timer = SPAWN_INTERVAL
			if _spawn_left <= 0 and alive_count() == 0:
				_wave_cleared()
		State.WAVE_CLEAR:
			_wave_timer -= delta
			if _wave_timer <= 0.0:
				_start_wave(wave + 1)


func _start_wave(n: int) -> void:
	wave = n
	state = State.PLAYING
	_spawn_left = enemies_for_wave(n)
	_spawn_timer = 0.5
	_wave_timer = 0.0
	hud.banner("WAVE %d" % n, "%d HOSTILES INCOMING" % _spawn_left)
	sfx.play("wave")


func _wave_cleared() -> void:
	state = State.WAVE_CLEAR
	_wave_timer = WAVE_BREAK
	var bonus := wave_bonus(wave)
	score += bonus
	player.health = minf(player.max_hp(), player.health + 25.0)
	player.health_changed.emit(player.health, player.max_hp())
	hud.banner("WAVE %d CLEARED" % wave, "+%d POINTS    +25 HP" % bonus)
	sfx.play("wave", 1.15)


func _spawn_bot() -> void:
	var pos := _pick_spawn()

	var bot = BotScript.new()
	add_child(bot)
	bot.setup(self, bot_health_for_wave(wave), bot_speed_for_wave(wave), pos)
	bots.append(bot)
	_spawn_left -= 1


## Picks a spot on the outer ring that is clear of cover and away from the
## player.
func _pick_spawn() -> Vector3:
	var fallback := Vector3(0.0, 0.3, -18.0)
	for attempt in 10:
		var angle := randf() * TAU
		var radius := randf_range(15.0, 19.5)
		var pos := Vector3(cos(angle) * radius, 0.3, sin(angle) * radius)
		if pos.distance_to(player.global_position) < 10.0:
			continue
		var sphere := SphereShape3D.new()
		sphere.radius = 0.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), pos + Vector3(0.0, 0.7, 0.0))
		query.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return pos
		fallback = pos
	return fallback


func _clear_bots() -> void:
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
	_spawn_left = 0


func _prune_bots() -> void:
	var kept: Array = []
	for b in bots:
		if is_instance_valid(b):
			kept.append(b)
	bots = kept


func alive_count() -> int:
	var n := 0
	for b in bots:
		if is_instance_valid(b) and b.alive:
			n += 1
	return n


# ------------------------------------------------------------------ view & slide

func toggle_view() -> void:
	first_person = not first_person
	_apply_view_mode()
	_save_best()
	sfx.play("start", 1.25)


func _apply_view_mode() -> void:
	cam.set_first_person(first_person)
	player.set_first_person(first_person)
	hud.first_person = first_person


func _on_slide_pressed() -> void:
	if state == State.PLAYING or state == State.WAVE_CLEAR:
		player.start_slide()


func on_player_slide() -> void:
	sfx.play("slide", randf_range(0.95, 1.05))
	cam.add_shake(0.22)


# ------------------------------------------------------------------ run control

func _on_tap() -> void:
	if state == State.READY:
		start_run()
	elif state == State.GAMEOVER:
		if Time.get_ticks_msec() - _over_at > RESTART_DELAY_MS:
			start_run()


func start_run() -> void:
	_clear_bots()
	_apply_view_mode()
	player.reset_for_run(PLAYER_SPAWN)
	cam.snap_to(player.global_position)
	cam.reset_view(0.0)
	score = 0
	kills = 0
	wave = 0
	_spawn_left = 0
	_spawn_timer = 0.0
	_wave_timer = 0.0
	hud.set_mode("play")
	hud.set_stats(player.health, player.max_hp(), 1, 0, 0, 0)
	sfx.play("start")
	_start_wave(1)


func _on_player_died() -> void:
	if state == State.GAMEOVER:
		return
	state = State.GAMEOVER
	_over_at = Time.get_ticks_msec()
	cam.add_shake(1.0)
	sfx.play("over")
	Input.vibrate_handheld(150)

	var new_best := score > best
	best = maxi(best, score)
	best_wave = maxi(best_wave, wave)
	_save_best()

	hud.set_best(best, best_wave)
	hud.show_game_over(score, wave, kills, best, new_best)


func on_bot_killed(bot: Node) -> void:
	kills += 1
	score += 100 + wave * 25
	hud.hit_mark()


func on_player_hit(pos: Vector3) -> void:
	fx.sparks(pos, Color(1.0, 0.92, 0.45), 4, 6.0, 0.09)
	sfx.play("hit", randf_range(1.05, 1.25))


func on_player_hurt(_amount: float) -> void:
	hud.damage_flash()
	cam.add_shake(0.75)
	sfx.play("hurt")
	Input.vibrate_handheld(25)


# ------------------------------------------------------------------ environment

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.13, 0.34, 0.72)
	sky_mat.sky_horizon_color = Color(0.63, 0.78, 0.94)
	sky_mat.ground_bottom_color = Color(0.10, 0.14, 0.18)
	sky_mat.ground_horizon_color = Color(0.42, 0.52, 0.60)
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.66, 0.92)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.64, 0.76, 0.92)
	env.fog_density = 0.0035

	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -42.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


# ------------------------------------------------------------------ tuning

static func enemies_for_wave(w: int) -> int:
	return 3 + w


static func bot_health_for_wave(w: int) -> float:
	return 2.0 + floorf(float(w) * 0.5)


static func bot_speed_for_wave(w: int) -> float:
	return 3.9 + minf(float(w) * 0.16, 2.0)


static func wave_bonus(w: int) -> int:
	return 250 * w


# ------------------------------------------------------------------ saves

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("score", "best", 0))
		best_wave = int(cfg.get_value("score", "best_wave", 0))
		first_person = bool(cfg.get_value("settings", "first_person", false))
	_apply_view_mode()


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.set_value("score", "best_wave", best_wave)
	cfg.set_value("settings", "first_person", first_person)
	cfg.save(SAVE_PATH)
