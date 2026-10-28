extends MiniGame
## Boxing vs a CPU. Hooks left/right, jab forward, hold B to guard, tilt to slip.

const ROUND_TIME := 60.0
const ROUNDS := 3

var me: Node3D
var foe: Node3D
var my_hp := 100.0
var foe_hp := 100.0
var guard := false
var round_i := 0
var round_t := ROUND_TIME
var foe_state := "idle"     # idle | wind | strike | stun
var foe_t := 1.0
var foe_side := 0.0
var my_wins := 0
var foe_wins := 0
var punch_t := 0.0
var punch_arm := &"ArmR"
var foe_stun := 0.0
var slip := 0.0
var locked := false


func _setup() -> void:
	Build.environment(self, Color("7fd0ff"), Color("ffffff"), Color("e8f4ff"))
	Build.box(self, Vector3(8, 0.3, 8), Vector3(0, -0.15, -3.5), Color("ff7b7b"))
	for c in [Vector3(-4, 0, -7.5), Vector3(4, 0, -7.5), Vector3(-4, 0, 0.5), Vector3(4, 0, 0.5)]:
		Build.cyl(self, 0.1, 1.6, c + Vector3(0, 0.8, 0), Color("dddddd"))
	for h in [0.5, 1.0, 1.4]:
		Build.box(self, Vector3(8, 0.05, 0.05), Vector3(0, h, -7.5), Color("e8e8e8"))
		Build.box(self, Vector3(0.05, 0.05, 8), Vector3(-4, h, -3.5), Color("e8e8e8"))
		Build.box(self, Vector3(0.05, 0.05, 8), Vector3(4, h, -3.5), Color("e8e8e8"))
	foe = Build.avatar(self, Color("d9a066"), Color("ffd9a8"), {"pattern": 2, "face": 1})
	foe.position = Vector3(0, 0, -3.2)
	for a in ["ArmL", "ArmR"]:
		Build.sphere(foe.get_node(a), 0.14, Vector3(0, -0.55, 0), Color("c0392b"))
	me = Node3D.new()
	add_child(me)
	for s in [-1, 1]:
		var glove := Build.sphere(me, 0.17, Vector3(0.28 * s, 1.0, -0.6), Color("2e6fd8"))
		glove.name = "GloveR" if s > 0 else "GloveL"
	me.position = Vector3(0, 0, -0.3)
	cam.position = Vector3(0, 1.7, 0.6)
	cam.look_at(Vector3(0, 1.4, -4.0))
	_hud()


func _hud() -> void:
	set_title("Sparring - Round %d/%d" % [mini(round_i + 1, ROUNDS), ROUNDS])
	set_score("You %d%%   Foe %d%%   Time %d   Rounds %d-%d" % [int(my_hp), int(foe_hp), int(round_t), my_wins, foe_wins])
	set_status("Swing left/right = hook, forward = jab, hold B = guard, tilt to slip.")


func _begin() -> void:
	_new_round()


func _new_round() -> void:
	my_hp = 100.0
	foe_hp = 100.0
	round_t = ROUND_TIME
	foe_state = "idle"
	foe_t = 1.2
	banner("ROUND %d" % (round_i + 1))
	_hud()


func _on_button(slot: int, btn: StringName, down: bool) -> void:
	if btn == &"b" and is_turn(slot):
		guard = down


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if not is_turn(slot) or punch_t > 0.0:
		return
	var kind := "jab"
	var arm := &"GloveR"
	if absf(dir.x) > 0.55:
		kind = "hook"
		arm = &"GloveL" if dir.x < 0 else &"GloveR"
	punch_arm = arm
	punch_t = 0.28
	Sfx.play(&"whoosh")
	var dmg := (6.0 if kind == "jab" else 11.0) * (0.6 + power * 0.7)
	if foe_state == "strike":
		dmg *= 0.0 if randf() < 0.0 else 1.0
	# the foe blocks if it is winding up a guard stance
	var blocked := foe_state == "idle" and randf() < 0.35
	await get_tree().create_timer(0.12).timeout
	if state != "play" or locked:
		return
	if blocked:
		Sfx.play(&"thud", 1.4)
		banner("BLOCKED", 0.5)
	else:
		foe_hp = maxf(0.0, foe_hp - dmg)
		foe_stun = 0.25
		Sfx.play(&"hit")
		rumble(0.7, 100)
		if foe_state == "wind":
			foe_state = "stun"
			foe_t = 0.5
	_hud()
	_check_round()


func _tick(delta: float) -> void:
	if locked:
		return
	round_t -= delta
	slip = lerpf(slip, aim().x * 0.35, 0.2)
	cam.position.x = slip
	cam.look_at(Vector3(0, 1.4, -4.0))
	if punch_t > 0.0:
		punch_t -= delta
	var g := me.get_node(NodePath(punch_arm if punch_t > 0.0 else &"GloveR"))
	var gl := me.get_node(NodePath("GloveL"))
	var gr := me.get_node(NodePath("GloveR"))
	var gy := 0.55 if guard else 1.0
	gl.position = Vector3(-0.28, gy, -0.6 if not guard else -0.45)
	gr.position = Vector3(0.28, gy, -0.6 if not guard else -0.45)
	if punch_t > 0.0:
		g.position = g.position.lerp(Vector3(g.position.x * 0.4, 1.3, -2.0), 0.7)
	foe_stun = maxf(0.0, foe_stun - delta)
	foe.position.x = lerpf(foe.position.x, foe_side * 0.6, 0.1)
	foe.rotation.z = foe_stun * 0.6
	foe_t -= delta
	match foe_state:
		"idle":
			if foe_t <= 0.0:
				foe_state = "wind"
				foe_side = [-1.0, 0.0, 1.0].pick_random()
				foe_t = randf_range(0.5, 0.8)
		"wind":
			foe.get_node("ArmR").rotation.x = -2.2 * (1.0 - foe_t)
			if foe_t <= 0.0:
				foe_state = "strike"
				foe_t = 0.25
				foe.get_node("ArmR").rotation.x = -1.57
		"strike":
			if foe_t <= 0.0:
				var dodged: bool = absf(aim().x * 0.6 - foe_side * 0.6) > 0.5 and absf(slip) > 0.15
				if guard:
					my_hp -= 2.0
					Sfx.play(&"thud", 1.3)
				elif dodged:
					banner("DODGE", 0.5)
				else:
					my_hp = maxf(0.0, my_hp - randf_range(7.0, 12.0))
					Sfx.play(&"hit", 0.7)
					rumble(0.9, 200)
				foe.get_node("ArmR").rotation.x = 0.0
				foe_state = "idle"
				foe_t = randf_range(0.6, 1.4)
				_hud()
				_check_round()
		"stun":
			if foe_t <= 0.0:
				foe_state = "idle"
				foe_t = 0.5
	if round_t <= 0.0:
		_check_round(true)
	if int(round_t * 4) % 4 == 0:
		_hud()


func _check_round(time_up: bool = false) -> void:
	if locked or state != "play":
		return
	if my_hp > 0.0 and foe_hp > 0.0 and not time_up:
		return
	if foe_hp <= 0.0 or (time_up and foe_hp < my_hp):
		my_wins += 1
		banner("YOU WIN THE ROUND", 1.6)
	else:
		foe_wins += 1
		banner("ROUND LOST", 1.6)
	round_i += 1
	locked = true
	await get_tree().create_timer(2.0).timeout
	if my_wins >= 2 or foe_wins >= 2 or round_i >= ROUNDS:
		locked = false
		finish("%s\nRounds %d - %d" % ["Victory!" if my_wins > foe_wins else "Defeat", my_wins, foe_wins], float(my_wins * 100 + int(my_hp)))
		return
	locked = false
	_new_round()
