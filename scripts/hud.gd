extends Control

## Landscape HUD: health, wave, score, touch sticks, crosshair and overlays.
## Everything is drawn procedurally so it scales to any screen.

const ACCENT := Color(0.36, 0.92, 1.0)
const WARN := Color(1.0, 0.40, 0.34)
const TEXT := Color(0.97, 0.98, 1.0)
const MUTED := Color(0.70, 0.77, 0.90)
const STICK_R := 120.0

signal tapped

var mode := "title"  # title | play | over
var move_vec := Vector2.ZERO
var look_active := false

var _hp := 100.0
var _hp_max := 100.0
var _hp_shown := 100.0
var _wave := 1
var _left := 0
var _score := 0
var _kills := 0
var _best := 0
var _best_wave := 0
var _new_best := false

var _move_idx := -1
var _look_idx := -1
var _move_origin := Vector2.ZERO
var _look_origin := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _look_knob := Vector2.ZERO
var _look_last := Vector2.ZERO
var _look_delta := Vector2.ZERO

var _t := 0.0
var _damage := 0.0
var _hit := 0.0
var _banner_text := ""
var _banner_sub := ""
var _banner_t := 0.0

var _style_small: StyleBoxFlat
var _style_big: StyleBoxFlat
var _fade_top: GradientTexture2D
var _fade_bottom: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_style_small = _make_style(20, Color(0.03, 0.05, 0.10, 0.62), Color(0.36, 0.92, 1.0, 0.22))
	_style_big = _make_style(40, Color(0.04, 0.06, 0.13, 0.88), Color(0.36, 0.92, 1.0, 0.32))
	_fade_top = _make_fade(true)
	_fade_bottom = _make_fade(false)

	size = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_t += delta
	_hp_shown = lerpf(_hp_shown, _hp, 1.0 - exp(-10.0 * delta))
	_damage = maxf(0.0, _damage - delta * 2.4)
	_hit = maxf(0.0, _hit - delta * 4.0)
	_banner_t = maxf(0.0, _banner_t - delta)
	queue_redraw()


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if mode != "play":
				tapped.emit()
				return
			if _move_idx == -1 and event.position.x < size.x * 0.5:
				_move_idx = event.index
				_move_origin = event.position
				_move_knob = event.position
			elif _look_idx == -1 and event.position.x >= size.x * 0.5:
				_look_idx = event.index
				_look_origin = event.position
				_look_last = event.position
				_look_knob = event.position
				look_active = true
		else:
			if event.index == _move_idx:
				_move_idx = -1
				move_vec = Vector2.ZERO
			if event.index == _look_idx:
				_look_idx = -1
				look_active = false
	elif event is InputEventScreenDrag:
		if event.index == _move_idx:
			var d: Vector2 = event.position - _move_origin
			if d.length() > STICK_R:
				d = d.normalized() * STICK_R
			_move_knob = _move_origin + d
			move_vec = Vector2(d.x / STICK_R, -d.y / STICK_R)
			if move_vec.length() > 1.0:
				move_vec = move_vec.normalized()
		elif event.index == _look_idx:
			_look_delta += event.position - _look_last
			_look_last = event.position
			_look_knob = event.position
			look_active = true


## Returns accumulated look delta (pixels) and clears it.
func take_look() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d


# ------------------------------------------------------------------ api

func set_mode(m: String) -> void:
	mode = m
	if m != "play":
		_move_idx = -1
		_look_idx = -1
		move_vec = Vector2.ZERO
		look_active = false
		_look_delta = Vector2.ZERO


func set_stats(hp: float, hp_max: float, wave: int, left: int, score: int, kills: int) -> void:
	_hp = hp
	_hp_max = maxf(hp_max, 1.0)
	_wave = wave
	_left = left
	_score = score
	_kills = kills


func set_best(best: int, best_wave: int) -> void:
	_best = best
	_best_wave = best_wave


func show_game_over(score: int, wave: int, kills: int, best: int, new_best: bool) -> void:
	_score = score
	_wave = wave
	_kills = kills
	_best = best
	_new_best = new_best
	mode = "over"


func banner(text: String, sub: String = "") -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = 2.2


func hit_mark() -> void:
	_hit = 1.0


func damage_flash() -> void:
	_damage = 1.0


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var w := size.x
	var h := size.y

	if mode != "title":
		_draw_health(Vector2(40.0, 34.0))
		_draw_wave(w)
		_draw_score(Vector2(w - 40.0, 40.0))

	if _damage > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.12, 0.14, _damage * 0.30))

	if mode == "play":
		_draw_sticks(w, h)
		_draw_crosshair(Vector2(w * 0.5, h * 0.5))

	if _banner_t > 0.0 and _banner_text != "":
		_draw_banner(w, h)

	if mode == "title":
		_draw_title(w, h)
	elif mode == "over":
		_draw_over(w, h)


func _draw_health(pos: Vector2) -> void:
	var rect := Rect2(pos, Vector2(470.0, 96.0))
	draw_style_box(_style_small, rect)

	_text("HP", pos + Vector2(22.0, 32.0), 24, MUTED)

	var bar := Rect2(pos + Vector2(22.0, 44.0), Vector2(426.0, 30.0))
	draw_rect(bar, Color(0.08, 0.11, 0.17, 0.95))

	var ratio := clampf(_hp_shown / _hp_max, 0.0, 1.0)
	var col := Color(1.0, 0.38, 0.32).lerp(Color(0.36, 0.94, 0.58), ratio)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 5.0)), Color(1.0, 1.0, 1.0, 0.20))
	_text("%d / %d" % [int(round(_hp)), int(round(_hp_max))],
		Vector2(bar.position.x, bar.position.y + 23.0), 22, Color(1.0, 1.0, 1.0, 0.95),
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)


func _draw_wave(w: float) -> void:
	_text("WAVE %d" % _wave, Vector2(0.0, 76.0), 52, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
	var left_text := "%d LEFT" % _left if _left > 0 else "AREA CLEAR"
	var left_col := MUTED if _left > 0 else ACCENT
	_text(left_text, Vector2(0.0, 112.0), 26, left_col, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_score(right: Vector2) -> void:
	_text("SCORE", right + Vector2(-420.0, 0.0), 24, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 420.0)
	_text("%d" % _score, right + Vector2(-420.0, 56.0), 46, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 420.0)
	_text("KILLS %d" % _kills, right + Vector2(-420.0, 90.0), 24, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, 420.0)


func _draw_crosshair(c: Vector2) -> void:
	var a := 0.40 + 0.45 * _hit
	var col := Color(1.0, 1.0, 1.0, a)
	if _hit > 0.02:
		col = Color(1.0, 0.92, 0.45, 1.0)
		draw_line(c + Vector2(-16, -16), c + Vector2(-6, -6), col, 3.0, true)
		draw_line(c + Vector2(16, -16), c + Vector2(6, -6), col, 3.0, true)
		draw_line(c + Vector2(-16, 16), c + Vector2(-6, 6), col, 3.0, true)
		draw_line(c + Vector2(16, 16), c + Vector2(6, 6), col, 3.0, true)
	draw_arc(c, 14.0, 0.0, TAU, 40, col, 2.5, true)
	draw_circle(c, 2.5, col)


func _draw_sticks(w: float, h: float) -> void:
	var home_l := Vector2(210.0, h - 200.0)
	var home_r := Vector2(w - 210.0, h - 200.0)

	if _move_idx < 0:
		_ring(home_l, 94.0, Color(1.0, 1.0, 1.0, 0.07), Color(1.0, 1.0, 1.0, 0.16))
		_text("MOVE", Vector2(home_l.x - 80.0, home_l.y + 132.0), 22, Color(1.0, 1.0, 1.0, 0.36), HORIZONTAL_ALIGNMENT_CENTER, 160.0)
	else:
		_ring(_move_origin, STICK_R, Color(0.36, 0.92, 1.0, 0.08), Color(0.36, 0.92, 1.0, 0.30))
		_ring(_move_knob, 50.0, Color(0.36, 0.92, 1.0, 0.30), Color(0.55, 0.96, 1.0, 0.70))

	if _look_idx < 0:
		_ring(home_r, 94.0, Color(1.0, 1.0, 1.0, 0.07), Color(1.0, 0.75, 0.40, 0.18))
		_text("AIM & FIRE", Vector2(home_r.x - 110.0, home_r.y + 132.0), 22, Color(1.0, 0.85, 0.55, 0.36), HORIZONTAL_ALIGNMENT_CENTER, 220.0)
	else:
		_ring(_look_origin, STICK_R * 0.85, Color(1.0, 0.72, 0.35, 0.07), Color(1.0, 0.72, 0.35, 0.28))
		_ring(_look_knob, 44.0, Color(1.0, 0.72, 0.35, 0.28), Color(1.0, 0.86, 0.55, 0.70))
		# Firing indicator.
		var c := Vector2(_look_origin.x, _look_origin.y - STICK_R * 0.85 - 26.0)
		_text("FIRING", Vector2(c.x - 70.0, c.y), 20, Color(1.0, 0.80, 0.45, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 140.0)


func _draw_banner(w: float, h: float) -> void:
	var k := clampf(_banner_t / 2.2, 0.0, 1.0)
	var age := 2.2 - _banner_t
	var alpha := clampf(age / 0.15, 0.0, 1.0) * clampf(_banner_t / 0.55, 0.0, 1.0)
	var grow := 1.0 + (1.0 - k) * 0.05
	_text(_banner_text, Vector2(0.0, h * 0.31), int(76.0 * grow), Color(1.0, 1.0, 1.0, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)
	if _banner_sub != "":
		_text(_banner_sub, Vector2(0.0, h * 0.31 + 52.0), 32, Color(0.36, 0.92, 1.0, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_title(w: float, h: float) -> void:
	draw_texture_rect(_fade_top, Rect2(0.0, 0.0, w, h * 0.40), false)
	draw_texture_rect(_fade_bottom, Rect2(0.0, h * 0.62, w, h * 0.38), false)

	_text("BLOCK ARENA", Vector2(0.0, h * 0.155), 116, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
	_text("WAVE  SURVIVAL", Vector2(0.0, h * 0.215), 34, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, w)

	var pulse := 0.80 + 0.20 * sin(_t * 3.0)
	_text("TAP TO START", Vector2(0.0, h * 0.845), 54, Color(1.0, 1.0, 1.0, pulse), HORIZONTAL_ALIGNMENT_CENTER, w)
	_text("LEFT SIDE   MOVE        RIGHT SIDE   AIM & FIRE", Vector2(0.0, h * 0.905), 26, MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)

	if _best > 0:
		_text("BEST %d      BEST WAVE %d" % [_best, _best_wave], Vector2(0.0, h * 0.955), 26, Color(0.55, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_over(w: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.58))
	var cw := minf(900.0, w - 140.0)
	var ch := 620.0
	var rect := Rect2((w - cw) * 0.5, (h - ch) * 0.5, cw, ch)
	draw_style_box(_style_big, rect)

	var top := rect.position.y
	_text("ELIMINATED", Vector2(0.0, top + 152.0), 96, WARN, HORIZONTAL_ALIGNMENT_CENTER, w)
	_text("SCORE  %d" % _score, Vector2(0.0, top + 268.0), 72, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
	_text("WAVE %d      KILLS %d" % [_wave, _kills], Vector2(0.0, top + 336.0), 34, MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)

	if _new_best:
		_text("NEW BEST!", Vector2(0.0, top + 404.0), 40, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, w)
	elif _best > 0:
		_text("BEST  %d" % _best, Vector2(0.0, top + 404.0), 34, MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)

	var pulse := 0.80 + 0.20 * sin(_t * 3.0)
	_text("TAP TO RETRY", Vector2(0.0, top + 528.0), 50, Color(1.0, 1.0, 1.0, pulse), HORIZONTAL_ALIGNMENT_CENTER, w)


# ------------------------------------------------------------------ primitives

func _ring(center: Vector2, radius: float, fill: Color, line: Color) -> void:
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 48, line, 3.0, true)


func _text(text: String, pos: Vector2, px: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if px <= 0:
		return
	var font := get_theme_default_font()
	var w := width
	if w < 0.0:
		w = size.x
	draw_string_outline(font, pos, text, align, w, px, maxi(3, int(px * 0.16)), Color(0.02, 0.02, 0.05, 0.80))
	draw_string(font, pos, text, align, w, px, color)


func _make_fade(top: bool) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.07, 0.86))
	g.set_color(1, Color(0.02, 0.03, 0.07, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0 if top else 1.0)
	t.fill_to = Vector2(0.5, 1.0 if top else 0.0)
	t.width = 8
	t.height = 64
	return t


func _make_style(radius: int, fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	s.shadow_size = 18
	return s
