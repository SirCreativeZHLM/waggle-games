extends Node
## Phone-as-controller server (UDP) with a keyboard/mouse fallback for slot 0.
## Wire format is documented in docs/PROTOCOL.md.

signal swing(slot: int, power: float, dir: Vector3)
signal button(slot: int, btn: StringName, down: bool)
signal phone_connected(slot: int, phone_name: String)
signal phone_disconnected(slot: int)

const PORT := 47777
const MAX_SLOTS := 2
const TIMEOUT := 2.5
const SWING_START_G := 1.25
const SWING_WINDOW := 0.10
const SWING_COOLDOWN := 0.30
const BUTTONS: Array[StringName] = [&"a", &"b", &"home", &"pause"]
const AIM_YAW := deg_to_rad(35.0)
const AIM_PITCH := deg_to_rad(25.0)

var pair_code := ""
var host_name := ""
var listening := false

var _udp := PacketPeerUDP.new()
var _slots: Array[Dictionary] = []
var _mouse_down := false
var _mouse_path := Vector2.ZERO
var _mouse_t := 0.0


func _ready() -> void:
	for i in MAX_SLOTS:
		_slots.append(_new_slot())
	host_name = OS.get_environment("HOSTNAME") if OS.has_environment("HOSTNAME") else "Waggle Host"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	pair_code = "%04d" % rng.randi_range(0, 9999)
	listening = _udp.bind(PORT, "*") == OK


func _new_slot() -> Dictionary:
	return {
		"connected": false, "phone": false, "id": "", "name": "", "ip": "", "port": 0,
		"last": 0.0, "basis": Basis.IDENTITY, "accel": Vector3.ZERO, "gyro": Vector3.ZERO,
		"down": {}, "yaw0": 0.0, "pitch0": 0.0, "calibrated": false,
		"aim": Vector2.ZERO, "roll": 0.0,
		"swing_t": -1.0, "swing_peak": 0.0, "swing_acc": Vector3.ZERO, "cooldown": 0.0,
	}


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ---------------------------------------------------------------- public API

func is_phone(slot: int = 0) -> bool:
	return _slots[slot]["phone"] and _slots[slot]["connected"]


## Pointer position, each axis -1..1 (x right, y up).
func aim(slot: int = 0) -> Vector2:
	return _slots[slot]["aim"]


## Wrist twist in radians (0 = phone level).
func roll(slot: int = 0) -> float:
	return _slots[slot]["roll"]


func is_down(slot: int, btn: StringName) -> bool:
	return _slots[slot]["down"].get(btn, false)


func connected_count() -> int:
	var n := 0
	for s in _slots:
		if s["phone"] and s["connected"]:
			n += 1
	return n


## Which controller slot plays as player index `p` (falls back to slot 0 / keyboard).
func slot_for_player(p: int) -> int:
	if p < MAX_SLOTS and is_phone(p):
		return p
	return 0


func slot_name(slot: int) -> String:
	return _slots[slot]["name"] if is_phone(slot) else "Keyboard + mouse"


func rumble(slot: int, strength: float = 0.6, ms: int = 120) -> void:
	var s := _slots[slot]
	if s["phone"] and s["connected"]:
		_send(s["ip"], s["port"], {"t": "r", "s": strength, "ms": ms})


func recenter(slot: int = 0) -> void:
	var s := _slots[slot]
	if s["phone"]:
		var p: Vector3 = s["basis"].y
		s["yaw0"] = atan2(p.y, p.x)
		s["pitch0"] = asin(clampf(p.z, -1.0, 1.0))
		s["calibrated"] = true


func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		out.append(ip)
	return out


## Test helpers (also used by the headless smoke test).
func inject_swing(slot: int, power: float, dir: Vector3) -> void:
	swing.emit(slot, power, dir.normalized())


func inject_button(slot: int, btn: StringName, down: bool) -> void:
	_set_button(slot, btn, down)


func set_aim(slot: int, v: Vector2) -> void:
	_slots[slot]["aim"] = v


# ---------------------------------------------------------------- networking

func _process(_delta: float) -> void:
	if listening:
		while _udp.get_available_packet_count() > 0:
			var data := _udp.get_packet()
			_handle_packet(data, _udp.get_packet_ip(), _udp.get_packet_port())
	var now := _now()
	for i in MAX_SLOTS:
		var s := _slots[i]
		if s["connected"] and s["phone"] and now - float(s["last"]) > TIMEOUT:
			s["connected"] = false
			s["phone"] = false
			s["down"] = {}
			phone_disconnected.emit(i)


func _send(ip: String, port: int, msg: Dictionary) -> void:
	_udp.set_dest_address(ip, port)
	_udp.put_packet(JSON.stringify(msg).to_utf8_buffer())


func _handle_packet(data: PackedByteArray, ip: String, port: int) -> void:
	var text := data.get_string_from_utf8()
	if text == "WAGGLE?":
		_send(ip, port, {"t": "host", "name": host_name, "port": PORT})
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	match d.get("t", ""):
		"hello":
			_on_hello(d, ip, port)
		"s":
			var slot := _slot_of(str(d.get("id", "")), ip)
			if slot >= 0:
				_on_state(slot, d, port)


func _slot_of(id: String, ip: String) -> int:
	for i in MAX_SLOTS:
		var s := _slots[i]
		if s["phone"] and s["id"] == id and s["ip"] == ip:
			return i
	return -1


func _on_hello(d: Dictionary, ip: String, port: int) -> void:
	if str(d.get("code", "")) != pair_code:
		_send(ip, port, {"t": "no", "why": "code"})
		return
	var id := str(d.get("id", ""))
	var slot := _slot_of(id, ip)
	if slot < 0:
		for i in MAX_SLOTS:
			if not _slots[i]["phone"]:
				slot = i
				break
	if slot < 0:
		_send(ip, port, {"t": "no", "why": "full"})
		return
	var s := _slots[slot]
	var fresh: bool = not s["phone"]
	s["phone"] = true
	s["connected"] = true
	s["id"] = id
	s["ip"] = ip
	s["port"] = port
	s["name"] = str(d.get("name", "Phone"))
	s["last"] = _now()
	s["calibrated"] = false
	_send(ip, port, {"t": "ok", "slot": slot, "host": host_name})
	if fresh:
		phone_connected.emit(slot, s["name"])


func _vec(v: Variant) -> Vector3:
	if v is Array and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


## CoreMotion-style world (x,y horizontal, z up) -> play frame (x right, y up, -z forward),
## rotated so the calibrated heading becomes "forward".
func _to_play(v: Vector3, yaw0: float) -> Vector3:
	var c := cos(yaw0)
	var sn := sin(yaw0)
	var fx := v.x * c + v.y * sn
	var fy := -v.x * sn + v.y * c
	return Vector3(-fy, v.z, -fx)


func _on_state(slot: int, d: Dictionary, port: int) -> void:
	var s := _slots[slot]
	var now := _now()
	s["last"] = now
	s["port"] = port
	var bx := _vec(d.get("x"))
	var by := _vec(d.get("y"))
	var bz := _vec(d.get("z"))
	s["basis"] = Basis(bx, by, bz)
	s["accel"] = _vec(d.get("a"))
	s["gyro"] = _vec(d.get("g"))
	if not s["calibrated"]:
		recenter(slot)
	var yaw: float = wrapf(atan2(by.y, by.x) - float(s["yaw0"]), -PI, PI)
	var pitch: float = asin(clampf(by.z, -1.0, 1.0)) - float(s["pitch0"])
	s["aim"] = Vector2(clampf(-yaw / AIM_YAW, -1.0, 1.0), clampf(pitch / AIM_PITCH, -1.0, 1.0))
	s["roll"] = asin(clampf(bx.z, -1.0, 1.0))
	_detect_swing(slot, now)
	var mask := int(d.get("b", 0))
	for bi in BUTTONS.size():
		_set_button(slot, BUTTONS[bi], (mask >> bi) & 1 == 1)


func _detect_swing(slot: int, now: float) -> void:
	var s := _slots[slot]
	var a: Vector3 = s["accel"]
	var mag := a.length()
	if float(s["swing_t"]) < 0.0:
		if mag > SWING_START_G and now >= float(s["cooldown"]):
			s["swing_t"] = now
			s["swing_peak"] = mag
			s["swing_acc"] = Vector3.ZERO
		else:
			return
	s["swing_peak"] = maxf(float(s["swing_peak"]), mag)
	var world: Vector3 = s["basis"] * a
	s["swing_acc"] = Vector3(s["swing_acc"]) + _to_play(world, float(s["yaw0"])) * mag
	if now - float(s["swing_t"]) >= SWING_WINDOW:
		var power := clampf((float(s["swing_peak"]) - 1.0) / 3.0, 0.12, 1.0)
		var dir: Vector3 = Vector3(s["swing_acc"]).normalized()
		s["swing_t"] = -1.0
		s["cooldown"] = now + SWING_COOLDOWN
		swing.emit(slot, power, dir)


func _set_button(slot: int, btn: StringName, down: bool) -> void:
	var s := _slots[slot]
	var was: bool = s["down"].get(btn, false)
	if was == down:
		return
	s["down"][btn] = down
	if btn == &"home" and down:
		recenter(slot)
	button.emit(slot, btn, down)


# ---------------------------------------------------- keyboard / mouse fallback

func _unhandled_input(event: InputEvent) -> void:
	if is_phone(0):
		return
	var s := _slots[0]
	if event is InputEventMouseMotion:
		var vp := get_viewport().get_visible_rect().size
		var p: Vector2 = event.position
		s["aim"] = Vector2(clampf(p.x / vp.x * 2.0 - 1.0, -1.0, 1.0), clampf(1.0 - p.y / vp.y * 2.0, -1.0, 1.0))
		if _mouse_down:
			_mouse_path += event.relative
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_mouse_path = Vector2.ZERO
			_mouse_t = _now()
		elif _mouse_down:
			_mouse_down = false
			_finish_mouse_swing()
	elif event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				_set_button(0, &"a", event.pressed)
			KEY_SHIFT, KEY_B:
				_set_button(0, &"b", event.pressed)
			KEY_ESCAPE, KEY_P:
				_set_button(0, &"pause", event.pressed)
			KEY_F:
				if event.pressed: swing.emit(0, 0.8, Vector3(0, 0.1, -1).normalized())
			KEY_LEFT:
				if event.pressed: swing.emit(0, 0.8, Vector3(-1, 0, -0.2).normalized())
			KEY_RIGHT:
				if event.pressed: swing.emit(0, 0.8, Vector3(1, 0, -0.2).normalized())
			KEY_UP:
				if event.pressed: swing.emit(0, 0.8, Vector3(0, 1, -0.3).normalized())
			KEY_DOWN:
				if event.pressed: swing.emit(0, 0.8, Vector3(0, -1, -0.3).normalized())
			KEY_A:
				s["roll"] = clampf(float(s["roll"]) - 0.3, -1.0, 1.0) if event.pressed else s["roll"]
			KEY_D:
				s["roll"] = clampf(float(s["roll"]) + 0.3, -1.0, 1.0) if event.pressed else s["roll"]


func _finish_mouse_swing() -> void:
	var dt := maxf(_now() - _mouse_t, 0.05)
	var len := _mouse_path.length()
	if len < 12.0:
		swing.emit(0, 0.7, Vector3(0, 0.1, -1).normalized())
		return
	var speed := len / dt
	var power := clampf(speed / 2500.0, 0.2, 1.0)
	var n := _mouse_path / len
	swing.emit(0, power, Vector3(n.x, -n.y, -maxf(-n.y, 0.2)).normalized())
