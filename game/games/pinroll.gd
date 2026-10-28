extends MiniGame
## Ten-pin rolling. Tilt to aim, swing underhand to release, twist for hook.

const LANE_W := 1.06
const START_Z := 8.0
const PIN_Z := -7.0
const BALL_R := 0.11

var rolls: Array = [[], []]       # per player: list of pins per roll
var frame := [0, 0]
var ball_in_frame := [0, 0]
var first_roll := [0, 0]
var ball: RigidBody3D
var pins: Array[RigidBody3D] = []
var arrow: MeshInstance3D
var phase := "aim"                # aim | rolling | settle
var phase_t := 0.0
var spin := 0.0
var standing_before := 10
var ball_ready_x := 0.0


static func total_score(r: Array) -> int:
	var score := 0
	var i := 0
	for f in 10:
		if i >= r.size():
			break
		if r[i] == 10:
			score += 10 + _at(r, i + 1) + _at(r, i + 2)
			i += 1
		elif _at(r, i) + _at(r, i + 1) == 10:
			score += 10 + _at(r, i + 2)
			i += 2
		else:
			score += _at(r, i) + _at(r, i + 1)
			i += 2
	return score


static func _at(r: Array, i: int) -> int:
	return r[i] if i < r.size() else 0


func _setup() -> void:
	Build.environment(self, Color("6ec6ff"), Color("ffffff"), Color("cfe0ff"))
	Build.box(self, Vector3(LANE_W, 0.2, 19.0), Vector3(0, -0.1, -1.0), Color("d9a65f"))
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LANE_W, 0.2, 19.0)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.1, -1.0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	floor_body.physics_material_override = pm
	add_child(floor_body)
	for side in [-1, 1]:
		Build.box(self, Vector3(0.36, 0.1, 19.0), Vector3(side * 0.71, -0.2, -1.0), Color("8fa3c8"))
		var g := StaticBody3D.new()
		var gs := CollisionShape3D.new()
		var gb := BoxShape3D.new()
		gb.size = Vector3(0.36, 0.1, 19.0)
		gs.shape = gb
		g.add_child(gs)
		g.position = Vector3(side * 0.71, -0.2, -1.0)
		add_child(g)
		var wall := StaticBody3D.new()
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(0.1, 0.6, 19.0)
		ws.shape = wb
		wall.add_child(ws)
		wall.position = Vector3(side * 0.94, 0.1, -1.0)
		add_child(wall)
		Build.box(self, Vector3(0.1, 0.5, 19.0), Vector3(side * 0.94, 0.05, -1.0), Color("c3d0ea"))
	Build.box(self, Vector3(2.4, 2.0, 0.3), Vector3(0, 0.8, -10.6), Color("7a8fb8"))
	var back := StaticBody3D.new()
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(2.4, 2.0, 0.3)
	bcs.shape = bsh
	back.add_child(bcs)
	back.position = Vector3(0, 0.8, -10.6)
	add_child(back)
	Build.player_egg(self).position = Vector3(1.4, 0, 9.0)
	Build.label(self, "PIN ROLL", Vector3(0, 2.4, -10.4), 3.0, Color("ffcc33"))
	arrow = Build.box(self, Vector3(0.05, 0.01, 2.0), Vector3(0, 0.01, 7.0), Color("ffffff"))
	cam.position = Vector3(0, 1.5, 10.6)
	cam.look_at(Vector3(0, 0.2, -6.0))
	_rack_pins([true, true, true, true, true, true, true, true, true, true])
	_spawn_ball()
	_hud()


func _rack_pins(keep: Array) -> void:
	for p in pins:
		if is_instance_valid(p):
			p.queue_free()
	pins.clear()
	var idx := 0
	for row in 4:
		for k in row + 1:
			if keep[idx]:
				var pin := RigidBody3D.new()
				pin.mass = 1.6
				pin.linear_damp = 0.05
				pin.angular_damp = 0.1
				var shape := CollisionShape3D.new()
				var cap := CapsuleShape3D.new()
				cap.radius = 0.06
				cap.height = 0.38
				shape.shape = cap
				pin.add_child(shape)
				Build.cyl(pin, 0.055, 0.38, Vector3.ZERO, Color("f4f4f4"))
				Build.cyl(pin, 0.057, 0.04, Vector3(0, 0.1, 0), Color("d33"))
				add_child(pin)
				pin.position = Vector3((k - row * 0.5) * 0.3, 0.2, PIN_Z - row * 0.26)
				pin.set_meta("slot", idx)
				pins.append(pin)
			idx += 1


func _spawn_ball() -> void:
	if ball:
		ball.queue_free()
	ball = RigidBody3D.new()
	ball.mass = 6.0
	ball.gravity_scale = 1.0
	ball.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.2
	pm.bounce = 0.0
	ball.physics_material_override = pm
	var shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = BALL_R
	shape.shape = sp
	ball.add_child(shape)
	Build.sphere(ball, BALL_R, Vector3.ZERO, Color("2255cc"))
	add_child(ball)
	ball.freeze = true
	ball.position = Vector3(0, BALL_R, START_Z)
	phase = "aim"
	spin = 0.0


func _hud() -> void:
	set_title("Pin Roll")
	var lines := PackedStringArray()
	for p in Game.players:
		lines.append("%s  frame %d   score %d   %s" % [player_label(p), mini(frame[p] + 1, 10), total_score(rolls[p]), str(rolls[p])])
	set_score("\n".join(lines))
	set_status("Tilt to aim, swing forward underhand to release. Twist for hook.")


func _begin() -> void:
	_hud()


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if phase != "aim" or not is_turn(slot):
		return
	phase = "rolling"
	phase_t = 0.0
	standing_before = pins.size()
	var a := aim()
	var angle := a.x * 0.04
	var speed := 5.0 + power * 9.0
	ball.freeze = false
	ball.linear_velocity = Vector3(sin(angle) * speed, 0, -cos(angle) * speed)
	spin = clampf(roll() * 1.5, -1.0, 1.0)
	Sfx.play(&"whoosh")


func _tick(delta: float) -> void:
	match phase:
		"aim":
			var a := aim()
			ball.position.x = clampf(a.x * 0.42, -0.42, 0.42)
			arrow.position.x = ball.position.x - 0.0
			arrow.rotation.y = -a.x * 0.04
			arrow.visible = true
		"rolling":
			arrow.visible = false
			phase_t += delta
			if ball.position.z > -5.5 and absf(ball.position.x) < 0.5:
				ball.apply_central_force(Vector3(spin * 1.6, 0, 0))
			var done := ball.position.z < -9.8 or ball.position.y < -0.6 or phase_t > 7.0
			if done or (phase_t > 1.5 and ball.linear_velocity.length() < 0.25):
				phase = "settle"
				phase_t = 0.0
		"settle":
			phase_t += delta
			if phase_t > 1.6:
				_resolve_roll()


func _is_down(p: RigidBody3D) -> bool:
	return p.global_transform.basis.y.y < 0.75 or p.position.y < -0.05 or absf(p.position.x) > 0.6 or p.position.z < -9.3


func _resolve_roll() -> void:
	var keep := [false, false, false, false, false, false, false, false, false, false]
	var knocked := 0
	for p in pins:
		if _is_down(p):
			knocked += 1
		else:
			keep[p.get_meta("slot")] = true
	var pl := turn
	rolls[pl].append(knocked)
	Sfx.play(&"pin" if knocked > 0 else &"thud")
	var all_down := knocked == standing_before
	var next_turn := false
	var reset := false
	if frame[pl] < 9:
		if ball_in_frame[pl] == 0 and all_down:
			banner("STRIKE!")
			Sfx.play(&"cheer")
			next_turn = true
			reset = true
		elif ball_in_frame[pl] == 0:
			first_roll[pl] = knocked
			ball_in_frame[pl] = 1
		else:
			if all_down:
				banner("SPARE!")
			next_turn = true
			reset = true
	else:
		ball_in_frame[pl] += 1
		var n: int = ball_in_frame[pl]
		var r10: Array = rolls[pl].slice(rolls[pl].size() - n)
		if all_down:
			reset = true
			banner("STRIKE!" if n == 1 or r10[n - 1] == 10 else "SPARE!")
		if (n == 2 and r10[0] < 10 and r10[0] + r10[1] < 10) or n == 3:
			next_turn = true
	if next_turn:
		frame[pl] += 1
		ball_in_frame[pl] = 0
		turn = (turn + 1) % Game.players
		reset = true
	if reset:
		keep = [true, true, true, true, true, true, true, true, true, true]
	_rack_pins(keep)
	_hud()
	if frame[0] >= 10 and (Game.players == 1 or frame[1] >= 10):
		var best := 0
		var winner := 0
		for p in Game.players:
			if total_score(rolls[p]) > best:
				best = total_score(rolls[p])
				winner = p
		var summary := "Final score: %d" % total_score(rolls[0])
		if Game.players > 1:
			summary = "P1 %d  -  P2 %d\nP%d wins!" % [total_score(rolls[0]), total_score(rolls[1]), winner + 1]
		finish(summary, float(best))
		return
	_spawn_ball()
