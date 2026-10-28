extends Control
## Main menu. The phone's pointer works as a cursor; A clicks.

var _buttons: Array[Button] = []
var _pointer: Panel
var _pair: Label
var _players_btn: Button
var _extra: Array[Control] = []
var _editor: Control
var _egg_root: Node3D
var _egg_holder: Node3D
var _egg_spin := 0.0
var _name_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.set_color("font_color", "Label", Color("1f3b6e"))
	theme = th
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color("86d4ff"))
	grad.set_color(1, Color("f4fbff"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	add_child(tr)

	var title := Label.new()
	title.text = "WAGGLE GAMES"
	title.position = Vector2(48, 24)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)
	var sub := Label.new()
	sub.text = "Open-source motion party sports. Your phone is the controller."
	sub.position = Vector2(52, 100)
	sub.add_theme_font_size_override("font_size", 22)
	add_child(sub)

	_pair = Label.new()
	_pair.position = Vector2(760, 30)
	_pair.add_theme_font_size_override("font_size", 20)
	add_child(_pair)

	var row_y := {"Classic Five": 190.0, "Holiday Sports": 440.0}
	var col := {"Classic Five": 0, "Holiday Sports": 0}
	for cat in row_y:
		var h := Label.new()
		h.text = cat
		h.position = Vector2(52, row_y[cat] - 36)
		h.add_theme_font_size_override("font_size", 24)
		add_child(h)
	for e in Game.ENTRIES:
		var cat: String = e["cat"]
		var b := Button.new()
		b.text = "%s\n%s" % [e["name"], e["blurb"]]
		var best := Game.best(e["id"])
		if best >= 0.0:
			b.text += "\nBest: %s" % str(snappedf(best, 0.1))
		b.size = Vector2(228, 190)
		b.position = Vector2(48 + col[cat] * 242, row_y[cat])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 18)
		for fc in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(fc, Color.WHITE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = (e["color"] as Color).darkened(0.25)
		sb.set_corner_radius_all(28)
		sb.set_content_margin_all(12)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.bg_color = e["color"]
		sbh.set_border_width_all(4)
		sbh.border_color = Color.WHITE
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("focus", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.pressed.connect(func(): _launch(e["id"]))
		add_child(b)
		_buttons.append(b)
		col[cat] += 1

	_players_btn = Button.new()
	_players_btn.position = Vector2(52, 668)
	_players_btn.size = Vector2(220, 40)
	_players_btn.pressed.connect(func():
		Game.players = 3 - Game.players
		_refresh())
	add_child(_players_btn)

	var egg_btn := Button.new()
	egg_btn.text = "Customize egg"
	egg_btn.position = Vector2(284, 668)
	egg_btn.size = Vector2(190, 40)
	egg_btn.pressed.connect(_open_editor)
	add_child(egg_btn)
	_extra.append(egg_btn)
	_extra.append(_players_btn)

	var tip := Label.new()
	tip.text = "Keyboard/mouse works too: drag to swing, Space = A, Shift = B, F/arrows = quick swings, Esc = pause."
	tip.position = Vector2(490, 676)
	tip.add_theme_font_size_override("font_size", 16)
	add_child(tip)

	_pointer = Panel.new()
	_pointer.size = Vector2(26, 26)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.2, 0.4, 0.8, 0.35)
	ps.set_corner_radius_all(13)
	ps.set_border_width_all(3)
	ps.border_color = Color("1f3b6e")
	_pointer.add_theme_stylebox_override("panel", ps)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pointer)

	Remote.button.connect(_on_button)
	Remote.phone_connected.connect(func(_s, _n): Sfx.play(&"beep"); _refresh())
	Remote.phone_disconnected.connect(func(_s): _refresh())
	_buttons[0].grab_focus()
	_refresh()


func _refresh() -> void:
	_players_btn.text = "Players: %d  (click)" % Game.players
	var lines := PackedStringArray()
	if Remote.listening:
		var ips := Remote.local_ips()
		lines.append("Phone pairing   code %s" % Remote.pair_code)
		lines.append("Host IP  %s   port %d" % [ips[0] if ips.size() > 0 else "?", Remote.PORT])
	else:
		lines.append("Phone server could not start (port %d busy)" % Remote.PORT)
	for i in Remote.MAX_SLOTS:
		lines.append("Controller %d: %s" % [i + 1, Remote.slot_name(i) if Remote.is_phone(i) else ("Phone not connected" if i > 0 else "Keyboard + mouse")])
	_pair.text = "\n".join(lines)


func _launch(id: String) -> void:
	Sfx.play(&"beep")
	Game.main.start_game(id)


func _on_button(_slot: int, btn: StringName, down: bool) -> void:
	if not down or btn != &"a":
		return
	var p := _pointer.position + _pointer.size * 0.5
	for b in _active_buttons():
		if b.get_global_rect().has_point(p):
			b.pressed.emit()
			return


func _process(_delta: float) -> void:
	var a := Remote.aim(0)
	if Remote.is_phone(1) and not Remote.is_phone(0):
		a = Remote.aim(1)
	var vp := get_viewport_rect().size
	_pointer.position = Vector2((a.x * 0.5 + 0.5) * vp.x, (0.5 - a.y * 0.5) * vp.y) - _pointer.size * 0.5
	if Remote.is_phone(0):
		var c := _pointer.position + _pointer.size * 0.5
		for b in _active_buttons():
			if b.get_global_rect().has_point(c):
				b.grab_focus()
	if _editor and _editor.visible:
		_egg_spin += _delta
		_egg_holder.rotation.y = sin(_egg_spin) * 0.6 + PI


func _active_buttons() -> Array[Control]:
	var out: Array[Control] = []
	if _editor and _editor.visible:
		for c in _editor.find_children("*", "Button", true, false):
			out.append(c)
		return out
	for b in _buttons:
		out.append(b)
	for e in _extra:
		out.append(e)
	return out


func _open_editor() -> void:
	if not _editor:
		_build_editor()
	_name_edit.text = Game.egg["name"]
	_rebuild_egg()
	_editor.visible = true
	_pointer.move_to_front()


func _build_editor() -> void:
	_editor = Control.new()
	_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.2, 0.4, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_editor.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(240, 80)
	panel.size = Vector2(800, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4fbff")
	sb.set_corner_radius_all(36)
	panel.add_theme_stylebox_override("panel", sb)
	_editor.add_child(panel)
	var title := Label.new()
	title.text = "Customize your egg"
	title.position = Vector2(30, 18)
	title.add_theme_font_size_override("font_size", 36)
	panel.add_child(title)
	# live 3D preview
	var svc := SubViewportContainer.new()
	svc.position = Vector2(30, 80)
	svc.size = Vector2(300, 400)
	svc.stretch = true
	var sv := SubViewport.new()
	sv.size = Vector2i(300, 400)
	sv.own_world_3d = true
	sv.transparent_bg = true
	svc.add_child(sv)
	panel.add_child(svc)
	var cam := Camera3D.new()
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.2, 3.4), Vector3(0, 0.95, 0))
	Build.environment(sv)
	_egg_holder = Node3D.new()
	sv.add_child(_egg_holder)
	var rows := [["Shell", "color", Game.EGG_COLORS.size()], ["Pattern", "pattern", Game.EGG_PATTERNS.size()],
		["Hat", "hat", Game.EGG_HATS.size()], ["Face", "face", Game.EGG_FACES.size()]]
	var y := 100.0
	for r in rows:
		var key: String = r[1]
		var count: int = r[2]
		var lbl := Label.new()
		lbl.text = r[0]
		lbl.position = Vector2(370, y + 8)
		lbl.add_theme_font_size_override("font_size", 26)
		panel.add_child(lbl)
		var val := Label.new()
		val.position = Vector2(540, y + 8)
		val.size = Vector2(150, 30)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 24)
		panel.add_child(val)
		val.set_meta("key", key)
		for dirn in [-1, 1]:
			var b := Button.new()
			b.text = "<" if dirn < 0 else ">"
			b.position = Vector2(480 if dirn < 0 else 700, y)
			b.size = Vector2(50, 46)
			b.pressed.connect(func():
				Game.egg[key] = posmod(int(Game.egg[key]) + dirn, count)
				Sfx.play(&"beep")
				_rebuild_egg())
			panel.add_child(b)
		y += 70.0
	var nl := Label.new()
	nl.text = "Name"
	nl.position = Vector2(370, y + 8)
	nl.add_theme_font_size_override("font_size", 26)
	panel.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(480, y)
	_name_edit.size = Vector2(270, 46)
	_name_edit.max_length = 12
	_name_edit.text_changed.connect(func(t: String): Game.egg["name"] = t)
	panel.add_child(_name_edit)
	var done := Button.new()
	done.text = "Done"
	done.position = Vector2(560, 460)
	done.size = Vector2(190, 52)
	done.pressed.connect(func():
		Game.save_egg()
		_editor.visible = false)
	panel.add_child(done)
	add_child(_editor)
	_editor.set_meta("panel", panel)


func _rebuild_egg() -> void:
	for c in _egg_holder.get_children():
		c.queue_free()
	Build.player_egg(_egg_holder)
	var panel: Panel = _editor.get_meta("panel")
	for l in panel.get_children():
		if l is Label and l.has_meta("key"):
			var key: String = l.get_meta("key")
			var i := int(Game.egg[key])
			match key:
				"color": l.text = "#%d" % (i + 1)
				"pattern": l.text = Game.EGG_PATTERNS[i]
				"hat": l.text = Game.EGG_HATS[i]
				"face": l.text = Game.EGG_FACES[i]
