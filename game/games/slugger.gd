extends MiniGame
## Batting practice. Time your swing to the pitch; timing picks the angle.

const PITCH_Z := -18.4
const PLATE_Z := 0.0
const G := 9.8
const PITCHES := 10

var ball: MeshInstance3D
var pitcher: Node3D
var bat_pivot: Node3D
var state_b := "wait"      # wait | windup | pitch | hit | done
var t := 0.0
var vel := Vector3.ZERO
var pos := Vector3.ZERO
var swung := false
var pitch_speed := 22.0
var thrown := 0
var homers := 0
var best_dist := 0.0
var hits := 0
var swing_t := -1.0
var ball_hit_dist := 0.0
var wait_t := 1.0
var bat_angle := 0.0


func _setup() -> void:
	Build.environment(self, Color("6ec6ff"), Color("ffffff"), Color("bfe8a8"))
	Build.box(self, Vector3(200, 0.2, 200), Vector3(0, -0.1, -60), Color("4f9a45"))
	Build.cyl(self, 2.0, 0.22, Vector3(0, -0.098, PITCH_Z), Color("b5834f"))
	Build.cyl(self, 4.0, 0.21, Vector3(0, -0.099, 0), Color("b5834f"))
	Build.box(self, Vector3(0.43, 0.02, 0.43), Vector3(0, 0.02, 0), Color.WHITE)
	# fence arc
	for i in 31:
		var a := deg_to_rad(-60.0 + i * 4.0)
		var f := Build.box(self, Vector3(4.2, 2.5, 0.3), Vector3(sin(a) * 85.0, 1.25, -cos(a) * 85.0), Color("1d5b34"))
		f.rotation.y = -a
	pitcher = Build.avatar(self, Color("ffb3c7"), Color("ffd9a8"), {"hat": 1, "pattern": 1})
	pitcher.position = Vector3(0, 0.2, PITCH_Z)
	var batter := Build.player_egg(self)
	batter.position = Vector3(0.9, 0, 0.3)
	batter.rotation.y = -0.6
	bat_pivot = Node3D.new()
	bat_pivot.position = Vector3(0.45, 1.1, 0.2)
	Build.cyl(bat_pivot, 0.04, 0.95, Vector3(0, 0, -0.5), Color("d9a05b")).rotation.x = deg_to_rad(90)
	add_child(bat_pivot)
	ball = Build.sphere(self, 0.06, Vector3(0, 1.4, PITCH_Z), Color.WHITE)
	ball.visible = false
	cam.position = Vector3(-1.4, 1.5, 4.0)
	cam.look_at(Vector3(0, 1.2, -12.0))
	_hud()


func _hud() -> void:
	set_title("Slugger")
	set_score("Pitch %d/%d   Hits %d   Home runs %d   Longest %.0f m" % [mini(thrown + 1, PITCHES), PITCHES, hits, homers, best_dist])
	set_status("Swing as the ball reaches the plate.")


func _begin() -> void:
	state_b = "wait"
	wait_t = 1.0
	_hud()


func _throw() -> void:
	thrown += 1
	pitch_speed = randf_range(20.0, 30.0)
	pos = Vector3(0, 1.5, PITCH_Z)
	var target := Vector3(randf_range(-0.25, 0.25), randf_range(0.7, 1.2), PLATE_Z)
	var tt := absf(PITCH_Z) / pitch_speed
	vel = Vector3((target.x - pos.x) / tt, (target.y - pos.y) / tt + 0.5 * G * tt, (target.z - pos.z) / tt)
	ball.visible = true
	ball.position = pos
	state_b = "pitch"
	swung = false
	swing_t = -1.0
	Sfx.play(&"whoosh", 0.7)
	_hud()


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if not is_turn(slot) or swung or state_b == "hit" or state_b == "done":
		return
	swung = true
	swing_t = 0.0
	bat_angle = 0.0
	Sfx.play(&"whoosh")
	if state_b != "pitch":
		return
	# timing: ball z relative to plate when the swing lands (~0.1 s after trigger)
	var contact_z := pos.z + vel.z * 0.08
	var timing := contact_z - PLATE_Z   # negative = early, positive = late
	var ball_y := pos.y + vel.y * 0.08
	if absf(timing) > 1.1 or ball_y < 0.2 or ball_y > 2.0:
		banner("MISS")
		rumble(0.2, 40)
		return
	var yaw := clampf(timing * -0.5, -0.8, 0.8) + dir.x * 0.25   # early pulls, late goes opposite
	var pitch_up := clampf(0.35 + dir.y * 0.5 - (ball_y - 1.0) * 0.3, 0.05, 0.9)
	var exit_speed := 24.0 + power * 26.0 - absf(timing) * 6.0
	vel = Vector3(sin(yaw), sin(pitch_up), -cos(yaw)) * exit_speed
	state_b = "hit"
	t = 0.0
	hits += 1
	Sfx.play(&"hit")
	rumble(1.0, 200)
	if absf(yaw) > 0.78:
		banner("FOUL")
		state_b = "done"
		wait_t = 1.5
		hits -= 1


func _tick(delta: float) -> void:
	if swing_t >= 0.0:
		swing_t += delta
		bat_angle = lerpf(-1.4, 1.6, clampf(swing_t / 0.18, 0.0, 1.0))
		bat_pivot.rotation.y = bat_angle
		if swing_t > 0.4:
			swing_t = -1.0
			bat_pivot.rotation.y = 0.0
	match state_b:
		"wait":
			wait_t -= delta
			pitcher.get_node("ArmR").rotation.x = 0.0
			if wait_t <= 0.0:
				state_b = "windup"
				wait_t = 0.8
		"windup":
			wait_t -= delta
			pitcher.get_node("ArmR").rotation.x = -wait_t * 3.5
			if wait_t <= 0.0:
				_throw()
		"pitch":
			vel.y -= G * delta
			pos += vel * delta
			ball.position = pos
			if pos.z > 2.5:
				if not swung:
					banner("STRIKE")
				elif thrown > 0:
					pass
				_next_pitch()
		"hit":
			t += delta
			vel.y -= G * delta
			pos += vel * delta
			if pos.y < 0.06:
				pos.y = 0.06
				if absf(vel.y) > 2.0:
					vel.y = -vel.y * 0.4
				else:
					vel = Vector3.ZERO
			var horiz := Vector2(pos.x, pos.z).length()
			ball.position = pos
			cam.position = cam.position.lerp(Vector3(pos.x * 0.3, 3.0, pos.z + 12.0).clamp(Vector3(-40, 1.5, -200), Vector3(40, 30, 6)), 0.04)
			cam.look_at(pos)
			if horiz > 85.0 and pos.y > 0.5 and pos.y < 30.0:
				homers += 1
				banner("HOME RUN!", 2.0)
				Sfx.play(&"cheer")
				best_dist = maxf(best_dist, horiz + 15.0)
				state_b = "done"
				wait_t = 2.2
			elif t > 6.0 or (vel.length() < 0.1):
				best_dist = maxf(best_dist, horiz)
				state_b = "done"
				wait_t = 1.2
		"done":
			wait_t -= delta
			if wait_t <= 0.0:
				_next_pitch()


func _next_pitch() -> void:
	ball.visible = false
	cam.position = Vector3(-1.4, 1.5, 4.0)
	cam.look_at(Vector3(0, 1.2, -12.0))
	if thrown >= PITCHES:
		state_b = "over"
		finish("Home runs: %d\nHits: %d / %d\nLongest: %.0f m" % [homers, hits, PITCHES, best_dist], float(homers * 100) + best_dist)
		return
	state_b = "wait"
	wait_t = 0.9
	_hud()
