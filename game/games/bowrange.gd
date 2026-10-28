extends MiniGame
## Archery. Hold A to draw, release A to loose. Point to aim, mind the wind.

const TARGET_Z := -40.0
const ROUNDS := 3
const ARROWS := 3

var target: Node3D
var arrow: Node3D
var arrow_vel := Vector3.ZERO
var flying := false
var drawing := false
var draw := 0.0
var wind := 0.0
var shots := 0
var total := 0
var flag: MeshInstance3D
var stuck: Array[Node3D] = []
var target_x := 0.0
var target_dir := 1.0
var rings: Array = []


func _setup() -> void:
	Build.environment(self, Color("5aa9e6"), Color("f0f7ff"), Color("5c8a4a"))
	Build.box(self, Vector3(100, 0.2, 120), Vector3(0, -0.1, -30), Color("5d9a4c"))
	target = Node3D.new()
	target.position = Vector3(0, 1.6, TARGET_Z)
	var colors := [Color("f5f5f5"), Color("222222"), Color("2a7de1"), Color("e03030"), Color("f4d03a")]
	for i in 5:
		var r := 1.0 - i * 0.2
		var c := Build.cyl(target, r, 0.1 + i * 0.01, Vector3.ZERO, colors[i])
		c.rotation.x = deg_to_rad(90)
		c.position.z = i * 0.012
	Build.cyl(target, 0.07, 1.8, Vector3(0, -1.2, -0.1), Color("6b4a2b"))
	add_child(target)
	flag = Build.box(self, Vector3(1.0, 0.4, 0.03), Vector3(3.0, 3.0, -6.0), Color("e53935"))
	Build.cyl(self, 0.04, 3.0, Vector3(2.5, 1.5, -6.0), Color("dddddd"))
	arrow = Node3D.new()
	var shaft := Build.cyl(arrow, 0.012, 0.9, Vector3.ZERO, Color("c9a06b"))
	shaft.rotation.x = deg_to_rad(90)
	Build.cyl(arrow, 0.025, 0.06, Vector3(0, 0, -0.46), Color("777777")).rotation.x = deg_to_rad(90)
	Build.box(arrow, Vector3(0.1, 0.1, 0.01), Vector3(0, 0, 0.42), Color("e03030"))
	add_child(arrow)
	cam.position = Vector3(0, 1.6, 2.0)
	cam.look_at(Vector3(0, 1.6, TARGET_Z))
	_new_wind()
	_hud()


func _new_wind() -> void:
	wind = randf_range(-2.5, 2.5)
	flag.scale.x = 0.4 + absf(wind) * 0.3
	flag.position.x = 2.5 + sign(wind) * flag.scale.x * 0.5


func _hud() -> void:
	set_title("Bow Range")
	set_score("%s  arrows %d/%d   score %d   wind %s %.1f" % [player_label(turn), shots % ARROWS, ARROWS, total, "->" if wind > 0 else "<-", absf(wind)])
	set_status("Hold A to draw, release to shoot.")


func _begin() -> void:
	_hud()


func _on_button(slot: int, btn: StringName, down: bool) -> void:
	if btn != &"a" or not is_turn(slot) or flying:
		return
	if down:
		drawing = true
		draw = 0.0
		Sfx.play(&"beep", 0.6)
	elif drawing:
		drawing = false
		_loose()


func _loose() -> void:
	var a := aim()
	var p := clampf(draw, 0.25, 1.0)
	var speed := 20.0 + p * 40.0
	var yaw := -a.x * deg_to_rad(12.0)
	var pitch := a.y * deg_to_rad(8.0) + 0.02
	arrow.position = Vector3(0, 1.5, 1.0)
	arrow_vel = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * speed
	flying = true
	Sfx.play(&"whoosh")
	rumble(0.4, 80)


func _tick(delta: float) -> void:
	var a := aim()
	if drawing:
		draw = minf(1.0, draw + delta * 0.8)
		cam.fov = lerpf(cam.fov, 55.0, 0.1)
		set_status("Draw %d%%" % int(draw * 100))
	else:
		cam.fov = lerpf(cam.fov, 70.0, 0.1)
	if not flying:
		cam.rotation = Vector3(a.y * deg_to_rad(8.0), -a.x * deg_to_rad(12.0), 0)
		arrow.visible = false
		target_x += target_dir * delta * 0.4
		if absf(target_x) > 4.0:
			target_dir *= -1.0
		target.position.x = target_x
	else:
		arrow.visible = true
		arrow_vel.y -= 9.8 * delta
		arrow_vel.x += wind * 0.8 * delta
		arrow.position += arrow_vel * delta
		arrow.look_at(arrow.position + arrow_vel, Vector3.UP)
		if arrow.position.z <= TARGET_Z:
			_land()
		elif arrow.position.y < 0.0:
			_score_shot(0)


func _land() -> void:
	var local := Vector2(arrow.position.x - target.position.x, arrow.position.y - target.position.y)
	var d := local.length()
	var pts := 0
	if d < 0.2:
		pts = 10
	elif d < 0.4:
		pts = 8
	elif d < 0.6:
		pts = 6
	elif d < 0.8:
		pts = 4
	elif d < 1.0:
		pts = 2
	_score_shot(pts)


func _score_shot(pts: int) -> void:
	flying = false
	total += pts
	shots += 1
	Sfx.play(&"hit" if pts > 0 else &"thud")
	banner(("%d!" % pts) if pts > 0 else "MISS", 1.0)
	if pts > 0:
		var stuck_arrow := arrow.duplicate()
		add_child(stuck_arrow)
		stuck.append(stuck_arrow)
		arrow.visible = false
	if shots >= ARROWS * ROUNDS * Game.players:
		finish("Total: %d" % total, float(total))
		return
	if shots % ARROWS == 0:
		turn = (turn + 1) % Game.players
		_new_wind()
	_hud()
