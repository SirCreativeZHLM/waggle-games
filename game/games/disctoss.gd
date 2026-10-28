extends MiniGame
## Disc golf-ish target toss. Flick sideways; wrist tilt at release bends the flight.

const THROWS := 6
const RING_Z := -34.0

var disc: Node3D
var vel := Vector3.ZERO
var flying := false
var bend := 0.0
var thrown := 0
var points := 0
var landed_t := 0.0
var ring: Node3D
var ring_x := 0.0
var wind := 0.0
var spin_a := 0.0


func _setup() -> void:
	Build.environment(self, Color("6bb8e8"), Color("f6fbff"), Color("5c8a4a"))
	Build.box(self, Vector3(120, 0.2, 120), Vector3(0, -0.1, -25), Color("5d9a4c"))
	ring = Node3D.new()
	for i in 3:
		var c := Build.cyl(ring, 3.0 - i * 1.0, 0.04, Vector3(0, 0.02 + i * 0.01, 0), [Color("f4d03a"), Color("e03030"), Color("2a7de1")][i])
		c.name = "R%d" % i
	add_child(ring)
	disc = Node3D.new()
	Build.cyl(disc, 0.13, 0.025, Vector3.ZERO, Color("f5f5f5"))
	Build.cyl(disc, 0.1, 0.03, Vector3(0, 0.005, 0), Color("9b59b6"))
	add_child(disc)
	for i in 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var tx := rng.randf_range(10.0, 30.0) * (1 if i % 2 == 0 else -1)
		var tz := -rng.randf_range(8.0, 60.0)
		Build.cyl(self, 0.3, 3.0, Vector3(tx, 1.5, tz), Color("6b4a2b"))
		Build.sphere(self, 2.0, Vector3(tx, 4.0, tz), Color("2f7d32"))
	cam.position = Vector3(0, 1.7, 3.0)
	cam.look_at(Vector3(0, 1.0, -20.0))
	disc.position = Vector3(0, 1.2, 0)
	_new_target()
	_hud()


func _new_target() -> void:
	ring_x = randf_range(-6.0, 6.0)
	ring.position = Vector3(ring_x, 0, RING_Z + randf_range(-6.0, 6.0))
	wind = randf_range(-1.5, 1.5)


func _hud() -> void:
	set_title("Disc Toss")
	set_score("%s  throw %d/%d   points %d   wind %.1f" % [player_label(turn), mini(thrown + 1, THROWS), THROWS, points, wind])
	set_status("Aim, flick sideways, tilt your wrist to bend the throw.")


func _begin() -> void:
	_hud()


func _on_swing(slot: int, power: float, dir: Vector3) -> void:
	if flying or not is_turn(slot):
		return
	var a := aim()
	var speed := 14.0 + power * 22.0
	var yaw := -a.x * deg_to_rad(18.0)
	vel = Vector3(sin(yaw), 0.18, -cos(yaw)) * speed
	bend = clampf(roll() * 1.2 + dir.x * 0.5, -1.2, 1.2)
	flying = true
	landed_t = 0.0
	Sfx.play(&"whoosh", 0.8)
	rumble(0.5, 90)


func _tick(delta: float) -> void:
	spin_a += delta * 20.0
	disc.rotation.y = spin_a
	if not flying:
		var a := aim()
		cam.rotation = Vector3(a.y * 0.1, -a.x * deg_to_rad(18.0), 0)
		disc.position = Vector3(0.4, 1.2, 1.0)
		disc.rotation.x = 0
		landed_t = 0
		return
	var forward := Vector3(vel.x, 0, vel.z).normalized()
	var side := Vector3(-forward.z, 0, forward.x)
	vel += side * bend * 3.0 * delta
	vel.x += wind * 0.5 * delta
	vel.y -= 3.2 * delta       # disc glides: less gravity than a ball
	disc.position += vel * delta
	disc.rotation.x = bend * 0.5
	cam.look_at(disc.position)
	cam.position = cam.position.lerp(disc.position + Vector3(0, 2, 8), 0.03)
	if disc.position.y <= 0.05:
		disc.position.y = 0.05
		flying = false
		_scored()


func _scored() -> void:
	var d := Vector2(disc.position.x - ring.position.x, disc.position.z - ring.position.z).length()
	var pts := 0
	if d < 1.0:
		pts = 10
	elif d < 2.0:
		pts = 6
	elif d < 3.0:
		pts = 3
	points += pts
	thrown += 1
	Sfx.play(&"thud")
	banner("+%d" % pts if pts > 0 else "MISS")
	if pts == 10:
		Sfx.play(&"cheer")
	await get_tree().create_timer(1.4).timeout
	cam.position = Vector3(0, 1.7, 3.0)
	if thrown >= THROWS * Game.players:
		finish("Points: %d" % points, float(points))
		return
	if thrown % THROWS == 0:
		turn = (turn + 1) % Game.players
	_new_target()
	_hud()
