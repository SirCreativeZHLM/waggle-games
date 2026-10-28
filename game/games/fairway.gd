extends MiniGame
## Three golf holes on a procedural meadow. Point, then swing.

const HOLES := [
	{"par": 3, "dist": 70.0, "off": 0.0},
	{"par": 4, "dist": 130.0, "off": 8.0},
	{"par": 4, "dist": 160.0, "off": -12.0},
]
const G := 9.8
const CUP_R := 0.4

var hole := 0
var strokes := [0, 0]
var totals := [0, 0]
var ball: MeshInstance3D
var flag: Node3D
var cup_pos := Vector3.ZERO
var ball_pos := Vector3.ZERO
var vel := Vector3.ZERO
var flying := false
var wind := Vector2.ZERO
var tee := Vector3.ZERO
var trail_t := 0.0
var aim_line: MeshInstance3D
var putting := false
var terrain: Node3D


func _setup() -> void:
	Build.environment(self, Color("4aa3df"), Color("dff1ff"), Color("4b7a3a"))
	ball = Build.sphere(self, 0.06, Vector3.ZERO, Color.WHITE)
	aim_line = Build.box(self, Vector3(0.06, 0.02, 6.0), Vector3.ZERO, Color("ffee55"))
	flag = Node3D.new()
	Build.cyl(flag, 0.03, 3.0, Vector3(0, 1.5, 0), Color("dddddd"))
	Build.box(flag, Vector3(0.9, 0.5, 0.02), Vector3(0.45, 2.7, 0), Color("e53935"))
	add_child(flag)
	terrain = Node3D.new()
	add_child(terrain)
	_load_hole()


func _load_hole() -> void:
	for c in terrain.get_children():
		c.queue_free()
	var h: Dictionary = HOLES[hole]
	var dist: float = h["dist"]
	var off: float = h["off"]
	tee = Vector3(0, 0.06, 0)
	cup_pos = Vector3(off, 0, -dist)
	Build.box(terrain, Vector3(120, 0.2, dist + 80), Vector3(0, -0.1, -dist * 0.5), Color("55934a"))
	var fair := Build.box(terrain, Vector3(26, 0.21, dist + 20), Vector3((off) * 0.5, -0.099, -dist * 0.5), Color("6bb85c"))
	fair.rotation.y = atan2(off, dist) * -0.0
	Build.cyl(terrain, 11.0, 0.22, Vector3(off, -0.098, -dist), Color("86d476"))
	Build.cyl(terrain, 0.4, 0.23, Vector3(off, -0.097, -dist), Color("111111"))
	for i in 14:
		var rng := RandomNumberGenerator.new()
		rng.seed = hole * 100 + i
		var tx := rng.randf_range(20.0, 45.0) * (1 if i % 2 == 0 else -1)
		var tz := -rng.randf_range(5.0, dist + 20.0)
		Build.cyl(terrain, 0.35, 3.0, Vector3(tx, 1.5, tz), Color("6b4a2b"))
		Build.sphere(terrain, 2.2, Vector3(tx, 4.2, tz), Color("2f7d32"))
	flag.position = cup_pos
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = hole + 5
	wind = Vector2(rng2.randf_range(-3.0, 3.0), rng2.randf_range(-1.5, 1.5))
	ball_pos = tee
	ball.position = ball_pos
	flying = false
	strokes[turn] = 0
	_place_camera()
	_hud()


func _place_camera() -> void:
	var to_cup := (cup_pos - ball_pos)
	to_cup.y = 0
	var dir := to_cup.normalized() if to_cup.length() > 0.1 else Vector3(0, 0, -1)
	cam.position = ball_pos - dir * 4.0 + Vector3(0, 2.2, 0)
	cam.look_at(ball_pos + dir * 14.0 + Vector3(0, 0.5, 0))


func _hud() -> void:
	var h: Dictionary = HOLES[hole]
	set_title("Fairway - Hole %d  Par %d" % [hole + 1, h["par"]])
	var dist := Vector2(cup_pos.x - ball_pos.x, cup_pos.z - ball_pos.z).length()
	set_score("%s  strokes %d   to pin %.0f m   wind %.1f m/s %s" % [player_label(turn), strokes[turn], dist, wind.length(), "->" if wind.x > 0 else "<-"])
	set_status("Point, then swing. Longer, faster swing = longer shot.")


func _begin() -> void:
	_hud()


func _aim_dir() -> Vector3:
	var to_cup := cup_pos - ball_pos
	to_cup.y = 0
	var base := to_cup.normalized() if to_cup.length() > 0.05 else Vector3(0, 0, -1)
	return base.rotated(Vector3.UP, -aim().x * deg_to_rad(25.0))


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if flying or not is_turn(slot):
		return
	putting = Vector2(cup_pos.x - ball_pos.x, cup_pos.z - ball_pos.z).length() < 12.0 and Remote.is_down(slot, &"b")
	var d := _aim_dir()
	if putting:
		vel = d * (power * 9.0)
	else:
		var speed := 12.0 + power * 38.0
		var loft := deg_to_rad(18.0 + clampf(dir.y, -0.3, 1.0) * 14.0)
		vel = Vector3(d.x * cos(loft), sin(loft), d.z * cos(loft)) * speed
		# slice/hook from sideways swing component
		vel += Vector3(d.z, 0, -d.x) * (dir.x * 0.1 * speed)
	strokes[turn] += 1
	flying = true
	trail_t = 0.0
	aim_line.visible = false
	Sfx.play(&"hit")
	rumble(0.8, 150)


func _tick(delta: float) -> void:
	if flying:
		_step_ball(delta)
	else:
		aim_line.visible = true
		var d := _aim_dir()
		aim_line.position = ball_pos + d * 3.0
		aim_line.rotation.y = atan2(-d.x, -d.z)
		_place_camera()


func _step_ball(delta: float) -> void:
	trail_t += delta
	if ball_pos.y > 0.07:
		vel.y -= G * delta
		vel.x += wind.x * 0.25 * delta
		vel.z += wind.y * 0.25 * delta
	ball_pos += vel * delta
	if ball_pos.y <= 0.06:
		ball_pos.y = 0.06
		if vel.y < -1.5:
			vel.y = -vel.y * 0.35
			vel.x *= 0.7
			vel.z *= 0.7
			Sfx.play(&"bounce")
		else:
			vel.y = 0.0
			var drag := pow(0.55, delta)
			vel.x *= drag
			vel.z *= drag
	ball.position = ball_pos
	cam.look_at(ball_pos)
	# holed?
	var to_cup := Vector2(ball_pos.x - cup_pos.x, ball_pos.z - cup_pos.z)
	if to_cup.length() < CUP_R and ball_pos.y < 0.1 and Vector2(vel.x, vel.z).length() < 6.0:
		_holed()
		return
	if ball_pos.y <= 0.061 and Vector2(vel.x, vel.z).length() < 0.4:
		flying = false
		vel = Vector3.ZERO
		if strokes[turn] >= 9:
			_holed()
		else:
			_place_camera()
			_hud()
	if ball_pos.length() > 600.0:
		flying = false
		ball_pos = tee
		ball.position = tee


func _holed() -> void:
	flying = false
	var par: int = HOLES[hole]["par"]
	var diff: int = strokes[turn] - par
	var names := {-2: "EAGLE!", -1: "BIRDIE!", 0: "PAR", 1: "BOGEY"}
	banner(names.get(diff, "HOLED") if strokes[turn] > 1 else "HOLE IN ONE!", 1.8)
	Sfx.play(&"cheer")
	totals[turn] += strokes[turn] - par
	var next_p := turn + 1
	if next_p < Game.players:
		turn = next_p
		strokes[turn] = 0
		ball_pos = tee
		ball.position = tee
		await get_tree().create_timer(1.6).timeout
		_place_camera()
		_hud()
		return
	turn = 0
	hole += 1
	await get_tree().create_timer(1.8).timeout
	if hole >= HOLES.size():
		var s := "Score vs par: %+d" % totals[0]
		if Game.players > 1:
			s = "P1 %+d  -  P2 %+d" % [totals[0], totals[1]]
		finish(s, float(totals[0]), false)
		return
	_load_hole()
