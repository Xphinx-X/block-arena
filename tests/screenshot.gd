extends Node

## Dev helper: renders the game under a display and writes PNG screenshots.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/screenshot.tscn
##
## Output goes to $SHOT_DIR (default /tmp/opencode).

const OUT_DIR := "/tmp/opencode"

var _dir := OUT_DIR


func _ready() -> void:
	var env_dir := OS.get_environment("SHOT_DIR")
	if not env_dir.is_empty():
		_dir = env_dir

	# Fresh save so the title screen is clean.
	var user := DirAccess.open("user://")
	if user != null and user.file_exists("block_arena.cfg"):
		user.remove("block_arena.cfg")

	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await _wait(8)
	await _shot("title")
	print("state=", game.state, " bots=", game.bots.size())

	game.start_run()
	await get_tree().create_timer(0.75).timeout
	await _shot("wave1")
	print("wave=", game.wave, " bots=", game.bots.size())

	# Stage a close-range firefight: park a bot in the open, aim at it and hold
	# both thumbs down. The real shots are too brief for a software renderer to
	# catch, so a long-lived tracer is drawn on top for the screenshot.
	var bot = _nearest_bot(game)
	if bot != null:
		var forward: Vector3 = game.cam.forward_flat()
		var right: Vector3 = game.cam.right_flat()
		bot.global_position = game.player.global_position + forward * 10.0 + right * 3.2
		bot.speed = 0.0
		bot.set_physics_process(false)

		# Hold fire so the staged bot survives; the tracer is drawn manually.
		game.player._fire_cd = 999.0
		var win := Vector2(DisplayServer.window_get_size())
		_touch(0, win * Vector2(0.17, 0.75), true)
		_drag(0, win * Vector2(0.17, 0.66))
		_touch(1, win * Vector2(0.83, 0.75), true)
		await _wait(3)

		var from: Vector3 = game.player.muzzle.global_position
		var to: Vector3 = bot.global_position + Vector3(0.0, 1.1, 0.0)
		game.fx.tracer(from, to, Color(1.0, 0.94, 0.55), 0.09, 4.0)
		game.fx.muzzle(from, Color(1.0, 0.86, 0.45), 0.30)
		game.fx.sparks(to, Color(1.0, 0.92, 0.45), 5, 5.0, 0.10)
		await _wait(1)
		await _shot("firing")

		# Slide pose. A real slide lasts 0.36s, far shorter than a software
		# frame, so freeze the body mid-slide for the capture.
		game.player.set_physics_process(false)
		game.player.sliding = true
		game.player._slide_t = 0.18
		game.player._slide_cd = 0.7
		game.player._slide_dir = game.cam.forward_flat()
		game.player.figure.position.y = -0.55
		game.player.figure.rotation.x = -0.22
		game.player.figure.set_slide(1.0)
		await _wait(2)
		await _shot("slide")
		game.player.sliding = false
		game.player._slide_t = 0.0
		game.player._slide_cd = 0.0
		game.player.figure.position.y = 0.0
		game.player.figure.rotation.x = 0.0
		game.player.figure.set_slide(0.0)
		game.player.set_physics_process(true)

		# First-person from an open stretch of floor so the shot reads clearly.
		game.player.global_position = Vector3(0.0, 0.2, -6.0)
		game.toggle_view()
		game.cam.reset_view(0.0)
		game.cam.snap_to(game.player.global_position)
		bot.global_position = Vector3(0.0, 0.3, -15.0)
		await _wait(2)
		var fp_to: Vector3 = bot.global_position + Vector3(0.0, 1.1, 0.0)
		game.fx.sparks(fp_to, Color(1.0, 0.92, 0.45), 6, 5.0, 0.10)
		await _wait(1)
		await _shot("fps")

		game.toggle_view()
		await _wait(4)

		game.player._fire_cd = 0.0
		_touch(0, win * Vector2(0.17, 0.66), false)
		_touch(1, win * Vector2(0.83, 0.75), false)
		if is_instance_valid(bot):
			bot.set_physics_process(true)
			bot.speed = 4.0

	await get_tree().create_timer(2.5).timeout
	await _shot("combat")
	print("wave=", game.wave, " bots=", game.bots.size(), " score=", game.score, " hp=", game.player.health)

	game.player.take_damage(999.0)
	await get_tree().create_timer(1.6).timeout
	await _shot("gameover")

	print("screenshots written to ", _dir)
	get_tree().quit(0)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	Input.parse_input_event(ev)


func _nearest_bot(game) -> Node:
	var best = null
	var best_d := 1e9
	for b in game.bots:
		if not is_instance_valid(b) or not b.alive:
			continue
		var d: float = b.global_position.distance_to(game.player.global_position)
		if d < best_d:
			best_d = d
			best = b
	return best


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join("arena_%s.png" % tag)
	var err := img.save_png(path)
	print("saved %s (%s) err=%d" % [path, img.get_size(), err])
