extends MiniGame
## 60 seconds of free throws.

const TIME := 60.0
const HOOP := Vector3(0, 3.05, -4.6)

var ball: MeshInstance3D
var vel := Vector3.ZERO
var flying := false
var scored_this := false
var t_left := TIME
var points := 0
var streak := 0
var shots := 0
var prev_y := 0.0
var ring_pos := HOOP


func _setup() -> void:
	Build.environment(self, Color("7fd0ff"), Color("ffffff"), Color("e0ecff"))
	Build.box(self, Vector3(16, 0.2, 18), Vector3(0, -0.1, -2), Color("c98a4b"))
	Build.box(self, Vector3(16, 0.02, 0.1), Vector3(0, 0.0, -2.8), Color.WHITE)
	Build.box(self, Vector3(1.8, 1.05, 0.06), Vector3(0, 3.5, -5.0), Color("eeeeee"))
	Build.box(self, Vector3(0.6, 0.45, 0.07), Vector3(0, 3.35, -4.99), Color(1, 1, 1, 0.0))
	Build.cyl(self, 0.07, 3.5, Vector3(0, 1.75, -5.4), Color("8a97b0"))
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.22
	tor.outer_radius = 0.24
	rim.mesh = tor
	rim.material_override = Build.mat(Color("ff6a00"))
	rim.position = HOOP
	add_child(rim)
	ball = Build.sphere(self, 0.12, Vector3(0.3, 1.2, 1.0), Color("e8742a"))
	cam.position = Vector3(0, 1.8, 2.6)
	cam.look_at(Vector3(0, 2.6, -4.6))
	_hud()


func _hud() -> void:
	set_title("Hoops")
	set_score("%s  points %d   time %d   streak %d" % [player_label(turn), points, int(t_left), streak])
	set_status("Point at the rim and swing upward. Power sets distance.")


func _begin() -> void:
	_hud()


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if flying or not is_turn(slot):
		return
	var a := aim()
	var start := Vector3(0.3, 1.5, 1.0)
	var target := HOOP + Vector3(a.x * 0.5 + (0.0), 0.0, 0.0)
	# power maps to flight time: stronger swing -> faster, flatter shot
	var tt := lerpf(1.35, 0.75, power)
	var d := target - start
	vel = Vector3(d.x / tt, (d.y + 0.5 * 9.8 * tt * tt) / tt, d.z / tt)
	# vertical aim error: aiming off shifts distance
	vel.y += (a.y - 0.25) * 2.0
	vel.z += clampf(dir.x, -1.0, 1.0) * 0.3
	ball.position = start
	flying = true
	scored_this = false
	prev_y = start.y
	shots += 1
	Sfx.play(&"whoosh")


func _tick(delta: float) -> void:
	t_left -= delta
	if t_left <= 0.0:
		finish("Points: %d\nShots: %d" % [points, shots], float(points))
		return
	if int(t_left * 4.0) % 4 == 0:
		_hud()
	if not flying:
		var a := aim()
		cam.rotation = Vector3(a.y * 0.15 + 0.08, -a.x * 0.2, 0)
		ball.position = Vector3(0.3, 1.2 + sin(Time.get_ticks_msec() * 0.005) * 0.03, 1.0)
		return
	vel.y -= 9.8 * delta
	var prev := ball.position
	ball.position += vel * delta
	# rim collision (rough): bounce on backboard and near rim
	if ball.position.z < -4.95:
		ball.position.z = -4.95
		vel.z = -vel.z * 0.4
		vel *= 0.8
		Sfx.play(&"bounce")
	var rel := ball.position - HOOP
	var hd := Vector2(rel.x, rel.z).length()
	if not scored_this and prev.y > HOOP.y and ball.position.y <= HOOP.y and vel.y < 0.0:
		if hd < 0.2:
			scored_this = true
			streak += 1
			points += 2 + (1 if streak >= 3 else 0)
			banner("SWISH!" if hd < 0.1 else "BUCKET!", 0.9)
			Sfx.play(&"win")
			rumble(0.7, 100)
			vel.x *= 0.1
			vel.z *= 0.1
		elif hd < 0.3:
			vel.y = absf(vel.y) * 0.5
			vel.x += rel.x * 5.0
			Sfx.play(&"hit", 1.5)
	if ball.position.y < 0.12:
		ball.position.y = 0.12
		vel.y = -vel.y * 0.55
		if absf(vel.y) < 1.0 or ball.position.z > 4.0:
			_reset_ball()
	if ball.position.length() > 40.0:
		_reset_ball()


func _reset_ball() -> void:
	if not scored_this:
		streak = 0
	flying = false
	_hud()
