extends Node

## Headless integration test for Block Arena.
##
##   godot --headless --path . res://tests/smoke.tscn

const STATE_READY := 0
const STATE_PLAYING := 1
const STATE_CLEAR := 2
const STATE_OVER := 3

var _fail := 0
var game


func _ready() -> void:
	await _run()
	print("")
	if _fail == 0:
		print("SMOKE: all checks passed")
	else:
		print("SMOKE: %d check(s) FAILED" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok    ", msg)
	else:
		_fail += 1
		print("  FAIL  ", msg)


func _frames(n: int) -> void:
	# Await both loops so _process and physics have both run before checking.
	for i in n:
		await get_tree().process_frame
		await get_tree().physics_frame


func _run() -> void:
	print("-- pure logic")
	var G = load("res://scripts/game.gd")
	_check(G.enemies_for_wave(1) == 4, "wave 1 sends 4 bots")
	_check(G.enemies_for_wave(5) == 8, "wave 5 sends 8 bots")
	_check(G.bot_health_for_wave(1) == 2.0, "wave 1 bots have 2 hp")
	_check(G.bot_health_for_wave(4) == 4.0, "wave 4 bots have 4 hp")
	_check(G.bot_speed_for_wave(6) > G.bot_speed_for_wave(1), "bots speed up with waves")
	_check(G.wave_bonus(3) == 750, "wave bonus scales with the wave")

	print("-- startup")
	game = load("res://main.tscn").instantiate()
	add_child(game)
	await _frames(4)
	_check(game.state == STATE_READY, "starts in READY")
	_check(game.hud.mode == "title", "title overlay is showing")
	_check(game.player.health == 100.0, "player starts at full hp")
	_check(game.player.max_hp() == 100.0, "max hp is 100")

	print("-- view modes")
	_check(not game.cam.first_person, "starts in third person")
	game.toggle_view()
	await _frames(2)
	_check(game.cam.first_person, "toggle enables first person")
	_check(game.player.first_person and not game.player.figure.visible, "body is hidden in first person")
	_check(game.hud.first_person, "hud knows the view mode")
	_check(is_equal_approx(game.cam.global_position.y, game.player.global_position.y + game.cam.eye_height),
		"first-person camera sits at eye height")
	game.toggle_view()
	await _frames(2)
	_check(not game.cam.first_person and game.player.figure.visible, "toggle returns to third person")

	var pill := InputEventScreenTouch.new()
	pill.index = 4
	pill.position = game.hud._view_rect(game.hud.size.x, game.hud.size.y).get_center()
	pill.pressed = true
	game.hud._input(pill)
	await _frames(1)
	_check(game.cam.first_person, "tapping the menu pill switches view")
	_check(game.state == STATE_READY, "the view pill does not start the run")
	game.toggle_view()
	await _frames(1)

	print("-- run")
	game.start_run()
	await _frames(3)
	_check(game.state == STATE_PLAYING, "starting a run enters PLAYING")
	_check(game.wave == 1, "first wave is wave 1")
	_check(game.hud.mode == "play", "hud switches to the play layout")
	_check(game.score == 0 and game.kills == 0, "score and kills reset")

	await get_tree().create_timer(1.2).timeout
	_check(game.bots.size() >= 1, "bots spawn")
	_check(game._spawn_left + game.alive_count() + game.kills == G.enemies_for_wave(1),
		"spawn accounting matches the wave size")

	print("-- shooting")
	var bot = null
	for b in game.bots:
		if is_instance_valid(b) and b.alive:
			bot = b
			break
	_check(bot != null, "a live bot is available")
	if bot != null:
		bot.set_physics_process(false)
		bot.health = 5.0
		bot.global_position = game.player.global_position + game.cam.forward_flat() * 7.0
		await _frames(3)
		var before: float = bot.health
		game.player._fire_cd = 0.0
		game.player._fire()
		await _frames(2)
		_check(bot.health < before, "shots damage bots")

		var kills_before: int = game.kills
		var score_before: int = game.score
		bot.take_damage(999.0)
		await _frames(2)
		_check(game.kills == kills_before + 1, "kills are counted")
		_check(game.score > score_before, "kills award score")

	print("-- waves")
	var waited := 0.0
	while game._spawn_left > 0 and waited < 15.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_check(game._spawn_left == 0, "the whole wave spawns")

	for b in game.bots.duplicate():
		if is_instance_valid(b) and b.alive:
			b.take_damage(999.0)
	await _frames(10)
	_check(game.state == STATE_CLEAR, "killing every bot clears the wave")

	await get_tree().create_timer(3.2).timeout
	_check(game.state == STATE_PLAYING, "play resumes after the break")
	_check(game.wave == 2, "the next wave starts at 2")

	print("-- damage and death")
	var hp: float = game.player.health
	game.player.take_damage(20.0)
	_check(is_equal_approx(game.player.health, hp - 20.0), "player takes damage")

	game.player.take_damage(999.0)
	await _frames(4)
	_check(game.state == STATE_OVER, "death ends the run")
	_check(game.hud.mode == "over", "game over card is showing")
	_check(not game.player.alive, "player is marked dead")
	_check(game.best >= game.score, "best score is recorded")

	print("-- restart")
	game.start_run()
	await _frames(3)
	_check(game.state == STATE_PLAYING and game.wave == 1, "restart begins a new run")
	_check(game.player.health == 100.0, "restart heals the player")
	_check(game.player.alive, "restart revives the player")
	_check(game.score == 0 and game.kills == 0, "restart resets the score")
	_check(game.alive_count() == 0, "restart clears the arena")

	print("-- slide")
	for b in game.bots:
		if is_instance_valid(b):
			b.set_physics_process(false)
	await _frames(12)
	_check(game.player.slide_ready(), "slide is ready after landing")
	var p0: Vector3 = game.player.global_position
	_check(game.player.start_slide(), "slide starts when ready")
	_check(game.player.sliding, "player is sliding")
	_check(game.player.slide_cooldown_ratio() > 0.0, "slide goes on cooldown")
	_check(not game.player.start_slide(), "cannot slide twice during cooldown")
	await _frames(45)
	_check(not game.player.sliding, "slide ends on its own")
	_check(game.player.global_position.distance_to(p0) > 1.5, "slide covers ground")
	_check(game.player.figure.rotation.x == 0.0, "body stands back up after the slide")

	print("-- touch handling")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(1400.0, 800.0)
	touch.pressed = true
	game.hud._input(touch)
	_check(game.hud.look_active, "right-side touch starts the aim stick")

	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(1400.0, 800.0)
	game.hud._input(mouse)
	_check(game.hud.look_active, "a duplicate mouse event does not disturb the stick")

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = Vector2(1400.0, 800.0)
	release.pressed = false
	game.hud._input(release)
	_check(not game.hud.look_active, "releasing the touch stops firing")

	var move := InputEventScreenTouch.new()
	move.index = 1
	move.position = Vector2(300.0, 800.0)
	move.pressed = true
	game.hud._input(move)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(300.0, 700.0)
	game.hud._input(drag)
	_check(game.hud.move_vec.length() > 0.5, "left-side drag drives movement")
	_check(game.hud.move_vec.y > 0.5, "dragging up moves forward")

	print("-- slide button")
	game.player.health = 100.0
	await get_tree().create_timer(1.6).timeout
	_check(game.player.slide_ready(), "slide cooldown expires")

	var slide_touch := InputEventScreenTouch.new()
	slide_touch.index = 6
	slide_touch.position = game.hud._slide_center(game.hud.size.x, game.hud.size.y)
	slide_touch.pressed = true
	game.hud._input(slide_touch)
	await _frames(1)
	_check(not game.hud.look_active, "the slide button does not start the aim stick")
	_check(game.player.sliding, "the slide button triggers a slide")

	var slide_up := InputEventScreenTouch.new()
	slide_up.index = 6
	slide_up.position = slide_touch.position
	slide_up.pressed = false
	game.hud._input(slide_up)
