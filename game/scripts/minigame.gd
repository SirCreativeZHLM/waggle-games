class_name MiniGame
extends Node3D
## Base class: camera, HUD, intro/pause/result flow and turn helpers.
## Subclasses implement _setup(), _begin(), _on_swing(), _on_button(), _tick().

var info: Dictionary = {}
var cam: Camera3D
var state := "intro"  # intro | play | over
var turn := 0         # active player index (0-based)
var paused := false

var _ui: CanvasLayer
var _title: Label
var _score: Label
var _status: Label
var _banner: Label
var _overlay: PanelContainer
var _overlay_text: Label
var _pointer: Panel
var _banner_t := 0.0
var _pointer_on := true


func _ready() -> void:
	cam = Camera3D.new()
	cam.current = true
	add_child(cam)
	_build_ui()
	_setup()
	Remote.swing.connect(_swing_cb)
	Remote.button.connect(_button_cb)
	_show_overlay("%s\n\n%s\n\nPress A (Space) to start" % [info.get("name", ""), info.get("controls", "")])


# ----------------------------------------------------------------- overridables

func _setup() -> void: pass
func _begin() -> void: pass
func _on_swing(_slot: int, _power: float, _dir: Vector3) -> void: pass
func _on_button(_slot: int, _btn: StringName, _down: bool) -> void: pass
func _tick(_delta: float) -> void: pass


# ----------------------------------------------------------------- helpers

func cur_slot() -> int:
	return Remote.slot_for_player(turn)


func is_turn(slot: int) -> bool:
	return slot == cur_slot()


func aim() -> Vector2:
	return Remote.aim(cur_slot())


func roll() -> float:
	return Remote.roll(cur_slot())


func set_title(t: String) -> void:
	_title.text = t


func set_score(t: String) -> void:
	_score.text = t


func set_status(t: String) -> void:
	_status.text = t


func banner(t: String, secs: float = 1.4) -> void:
	_banner.text = t
	_banner.visible = true
	_banner_t = secs


func show_pointer(on: bool) -> void:
	_pointer_on = on
	_pointer.visible = on


func rumble(strength: float = 0.6, ms: int = 120) -> void:
	Remote.rumble(cur_slot(), strength, ms)


func player_label(p: int) -> String:
	return "P%d" % (p + 1) if Game.players > 1 else "You"


## End the game. `higher_better` false for lowest-score-wins games (golf).
func finish(summary: String, score: float, higher_better: bool = true) -> void:
	state = "over"
	var record := Game.submit(info.get("id", ""), score, higher_better)
	Sfx.play(&"win" if record else &"cheer")
	_show_overlay("%s\n\n%s%s\n\nA: back to menu     B: play again" % [info.get("name", ""), summary, "\n\nNew personal best!" if record else ""])


# ----------------------------------------------------------------- flow

func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.visible = false
	var a := Remote.aim(Remote.slot_for_player(turn))
	var vp := get_viewport().get_visible_rect().size
	_pointer.position = Vector2((a.x * 0.5 + 0.5) * vp.x, (0.5 - a.y * 0.5) * vp.y) - _pointer.size * 0.5
	if state == "play" and not paused:
		_tick(delta)


func _swing_cb(slot: int, power: float, dir: Vector3) -> void:
	if state == "play" and not paused:
		_on_swing(slot, power, dir)


func _button_cb(slot: int, btn: StringName, down: bool) -> void:
	if down and btn == &"pause" and state == "play":
		paused = not paused
		if paused:
			_show_overlay("Paused\n\nA: resume     B: quit to menu")
		else:
			_overlay.visible = false
		return
	if down and (btn == &"a" or btn == &"b"):
		if state == "intro" and btn == &"a":
			_overlay.visible = false
			state = "play"
			_begin()
			return
		if state == "intro" and btn == &"b":
			Game.main.show_menu()
			return
		if paused:
			if btn == &"a":
				paused = false
				_overlay.visible = false
			else:
				Game.main.show_menu()
			return
		if state == "over":
			if btn == &"a":
				Game.main.show_menu()
			else:
				Game.main.start_game(info["id"])
			return
	if state == "play" and not paused:
		_on_button(slot, btn, down)


func _show_overlay(t: String) -> void:
	_overlay_text.text = t
	_overlay.visible = true


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_title = _label(Vector2(24, 16), 30, HORIZONTAL_ALIGNMENT_LEFT)
	_title.text = info.get("name", "")
	_score = _label(Vector2(24, 56), 26, HORIZONTAL_ALIGNMENT_LEFT)
	_status = _label(Vector2(24, 640), 24, HORIZONTAL_ALIGNMENT_LEFT)
	_banner = _label(Vector2(0, 250), 72, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.size = Vector2(1280, 100)
	_banner.visible = false
	_pointer = Panel.new()
	_pointer.size = Vector2(22, 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.5, 1.0, 0.35)
	sb.set_corner_radius_all(11)
	sb.set_border_width_all(3)
	sb.border_color = Color("1f3b6e")
	_pointer.add_theme_stylebox_override("panel", sb)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_pointer)
	_overlay = PanelContainer.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_overlay.custom_minimum_size = Vector2(760, 300)
	_overlay.position = Vector2(260, 190)
	var ob := StyleBoxFlat.new()
	ob.bg_color = Color(0.12, 0.25, 0.5, 0.88)
	ob.set_corner_radius_all(36)
	ob.set_content_margin_all(28)
	_overlay.add_theme_stylebox_override("panel", ob)
	_overlay_text = Label.new()
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_text.add_theme_font_size_override("font_size", 28)
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.add_child(_overlay_text)
	_ui.add_child(_overlay)


func _label(pos: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	_ui.add_child(l)
	return l
