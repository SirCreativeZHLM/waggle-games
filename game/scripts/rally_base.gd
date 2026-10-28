class_name RallyBase
extends MiniGame
## Shared logic for Court Rally (tennis-like) and Paddle Rally (table-tennis-like).
## The ball is integrated by hand: gravity, one bounce per side, CPU opponent.

var half_w := 4.0          # half court width
var half_l := 11.0         # half court length
var net_h := 0.9
var gravity := 9.8
var bounce_k := 0.78
var hit_zone := 1.6        # distance from player's baseline where a swing connects
var player_y := 0.0
var serve_speed := 12.0
var ret_speed := 15.0
var cpu_skill := 0.78
var points_to_win := 4
var win_by := 1
var title_text := "Rally"
var court_color := Color("4f9d5d")
var line_color := Color.WHITE

var ball: MeshInstance3D
var opp: Node3D
var me: Node3D
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var bounces := 0            # bounces since last hit
var last_hitter := 0        # 0 player, 1 cpu
var rally := "serve"        # serve | live | dead
var timer := 1.0
var score := [0, 0]
var swing_ready := true
var player_x := 0.0
var opp_x := 0.0
var arm_t := 0.0
var server := 0


func _setup() -> void:
	_build_court()
	ball = Build.sphere(self, 0.08 if half_l > 8 else 0.06, Vector3(0, 1, 0), Color("e6f542") if half_l > 8 else Color.WHITE)
	me = Build.player_egg(self)
	opp = Build.avatar(self, Color("b8f0b0"), Color("ffd9a8"), {"hat": 5, "face": 1})
	opp.rotation.y = PI
	me.position = Vector3(0, player_y, half_l + 1.4)
	opp.position = Vector3(0, player_y, -half_l - 1.4)
	cam.position = Vector3(0, 2.6 if half_l > 8 else 1.9, half_l + 4.8)
	cam.look_at(Vector3(0, 0.6, -2.0))
	_hud()


func _build_court() -> void:
	pass


func _hud() -> void:
	set_title(title_text)
	set_score("You %s  -  %s CPU" % [_pt(score[0], score[1]), _pt(score[1], score[0])])
	set_status("Swing across the court as the ball reaches you. Swing direction aims the return.")


func _pt(a: int, b: int) -> String:
	if points_to_win == 4:   # tennis-style call
		var names := ["0", "15", "30", "40"]
		if a >= 3 and b >= 3:
			return "AD" if a > b else ("40" if a == b else "-")
		return names[mini(a, 3)]
	return str(a)


func _begin() -> void:
	_start_point()


func _start_point() -> void:
	rally = "serve"
	timer = 1.0
	bounces = 0
	swing_ready = true
	ball.visible = true
	if server == 0:
		pos = Vector3(player_x, 1.1, half_l)
	else:
		pos = Vector3(opp_x, 1.1, -half_l)
	vel = Vector3.ZERO
	ball.position = pos
	_hud()


func _serve_cpu() -> void:
	var tx := randf_range(-half_w * 0.6, half_w * 0.6)
	_launch(Vector3(tx, 0, half_l * 0.6), serve_speed, 0.55, 1)


## Launch from current pos toward a ground target so that it lands there after ~one bounce.
func _launch(target: Vector3, speed: float, arc: float, hitter: int) -> void:
	last_hitter = hitter
	bounces = 0
	var d := Vector3(target.x - pos.x, 0, target.z - pos.z)
	var dist := d.length()
	var tt := maxf(dist / speed, 0.2)
	# aim for the first bounce around 60% of the way, using simple ballistics for y
	var t1 := tt * 0.6
	var vy := (0.0 - pos.y + 0.5 * gravity * t1 * t1) / t1
	vel = Vector3(d.x / tt, vy + arc * 0.0, d.z / tt)
	rally = "live"
	Sfx.play(&"hit" if half_l > 8 else &"bounce")


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if not is_turn(slot):
		return
	arm_t = 0.25
	Sfx.play(&"whoosh", 1.2)
	if rally == "serve" and server == 0:
		var tx := clampf(aim().x * half_w * 0.8 + dir.x * 1.5, -half_w, half_w)
		_launch(Vector3(tx, 0, -half_l * 0.55), serve_speed + power * 6.0, 0.6, 0)
		return
	if rally != "live" or vel.z < 0.0 or not swing_ready:
		return
	var dz := pos.z - (half_l + 0.5)
	if absf(dz) > hit_zone or pos.y > 2.4 or absf(pos.x - player_x) > 1.7:
		return
	var tx := clampf(dir.x * half_w * 0.9 + aim().x * half_w * 0.4, -half_w * 0.95, half_w * 0.95)
	var depth := lerpf(0.35, 0.95, clampf(power * 1.2, 0.0, 1.0))
	pos.z = minf(pos.z, half_l + 0.6)
	_launch(Vector3(tx, 0, -half_l * depth), ret_speed + power * 9.0, 0.7, 0)
	swing_ready = false
	rumble(0.6, 90)


func _tick(delta: float) -> void:
	player_x = lerpf(player_x, clampf(pos.x, -half_w, half_w) if rally == "live" and vel.z > 0 else aim().x * half_w * 0.6, 0.12)
	player_x = clampf(player_x + 0.0, -half_w, half_w)
	me.position.x = player_x
	me.get_node("ArmR").rotation.x = -arm_t * 8.0
	arm_t = maxf(0.0, arm_t - delta)
	timer -= delta
	match rally:
		"serve":
			if server == 0:
				pos = Vector3(player_x + 0.4, 1.1, half_l)
				ball.position = pos
			elif timer <= 0.0:
				opp_x = clampf(opp_x, -half_w, half_w)
				pos = Vector3(opp_x, 1.1, -half_l)
				_serve_cpu()
		"live":
			_step(delta)
		"dead":
			if timer <= 0.0:
				_start_point()
	# cpu movement
	if rally == "live":
		var follow := pos.x if vel.z < 0.0 else 0.0
		opp_x = move_toward(opp_x, clampf(follow, -half_w, half_w), delta * (6.0 * cpu_skill))
	opp.position.x = opp_x
	opp.get_node("ArmR").rotation.x = -maxf(0.0, 1.0 - absf(pos.z + half_l + 1.0)) * 1.5


func _step(delta: float) -> void:
	vel.y -= gravity * delta
	var prev := pos
	pos += vel * delta
	if pos.y <= 0.06 and vel.y < 0.0:
		pos.y = 0.06
		vel.y = -vel.y * bounce_k
		bounces += 1
		Sfx.play(&"bounce")
		var in_court := absf(pos.x) <= half_w + 0.15 and absf(pos.z) <= half_l + 0.2
		var side_ok: bool = (pos.z < 0.0) if last_hitter == 0 else (pos.z > 0.0)
		if not in_court or not side_ok:
			_point_over(1 - last_hitter if bounces == 1 else last_hitter, "OUT" if not in_court else "NET")
			return
		if bounces >= 2:
			_point_over(last_hitter, "WINNER")
			return
	# net
	if prev.z * pos.z < 0.0 and pos.y < net_h:
		_point_over(1 - last_hitter, "NET")
		return
	# cpu return
	if vel.z < 0.0 and pos.z < -half_l - 0.3 and last_hitter == 0:
		if bounces >= 1 and randf() < cpu_skill and absf(pos.x - opp_x) < 1.8:
			var tx := randf_range(-half_w * 0.85, half_w * 0.85) + (-player_x * 0.3)
			_launch(Vector3(clampf(tx, -half_w, half_w), 0, half_l * randf_range(0.55, 0.9)), ret_speed * 0.9, 0.7, 1)
			Sfx.play(&"hit")
		elif bounces >= 1:
			_point_over(0, "WINNER")
			return
	# player missed
	if vel.z > 0.0 and pos.z > half_l + 3.0:
		_point_over(1 if last_hitter == 1 else last_hitter, "MISS")
		return
	if absf(pos.x) > 30.0 or pos.length() > 80.0:
		_point_over(1 - last_hitter, "OUT")
		return
	ball.position = pos


func _point_over(winner: int, why: String) -> void:
	rally = "dead"
	timer = 1.5
	score[winner] += 1
	if winner == 0:
		banner("POINT!  %s" % ("Nice one" if why == "WINNER" else why), 1.2)
		Sfx.play(&"win")
	else:
		banner("CPU point  %s" % why, 1.2)
		Sfx.play(&"lose")
	_hud()
	var a: int = score[0]
	var b: int = score[1]
	if (a >= points_to_win or b >= points_to_win) and absi(a - b) >= win_by:
		var won := a > b
		finish("%s  %d - %d" % ["You win!" if won else "CPU wins", a, b], float(a - b))
		return
	server = (int((a + b) / 2.0) if points_to_win > 4 else (a + b)) % 2
