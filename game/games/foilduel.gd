extends MiniGame
## Fencing duel. Point high / mid / low to parry the attack, then swing into the opening.

const WIN_SCORE := 5
const ZONES := ["HIGH", "MID", "LOW"]

var foe: Node3D
var my_blade: Node3D
var foe_blade: Node3D
var f_state := "guard"    # guard | tell | strike | open
var f_t := 1.0
var f_zone := 1
var my_pts := 0
var foe_pts := 0
var parried := false
var open_t := 0.0
var lunge := 0.0


func _setup() -> void:
	Build.environment(self, Color("8fd3ff"), Color("ffffff"), Color("e8f0ff"))
	Build.box(self, Vector3(3.0, 0.2, 14.0), Vector3(0, -0.1, -2.0), Color("d8d2c4"))
	Build.box(self, Vector3(3.0, 3.0, 0.2), Vector3(0, 1.5, -8.2), Color("9bb7e6"))
	for x in [-1.8, 1.8]:
		Build.box(self, Vector3(0.3, 3.0, 14.0), Vector3(x, 1.5, -2.0), Color("9bb7e6"))
	foe = Build.avatar(self, Color("fff4e0"), Color("ffd9a8"), {"hat": 1, "face": 2})
	foe.position = Vector3(0, 0, -3.0)
	foe_blade = Node3D.new()
	Build.box(foe_blade, Vector3(0.03, 0.03, 1.0), Vector3(0, 0, -0.5), Color("c8d0d8"))
	foe.get_node("ArmR").add_child(foe_blade)
	foe_blade.position = Vector3(0, -0.5, 0)
	my_blade = Node3D.new()
	Build.box(my_blade, Vector3(0.03, 0.03, 1.2), Vector3(0, 0, -0.6), Color("9fc4ff"))
	Build.box(my_blade, Vector3(0.18, 0.02, 0.02), Vector3(0, 0, -0.05), Color("777777"))
	add_child(my_blade)
	cam.position = Vector3(0, 1.6, 1.4)
	cam.look_at(Vector3(0, 1.3, -3.0))
	_hud()


func _hud() -> void:
	set_title("Foil Duel")
	set_score("You %d   Foe %d   (first to %d)" % [my_pts, foe_pts, WIN_SCORE])
	set_status("Point high / mid / low to parry. After a parry, swing to riposte.")


func _begin() -> void:
	_hud()


func _my_zone() -> int:
	var y := aim().y
	return 0 if y > 0.35 else (2 if y < -0.35 else 1)


func _zone_y(z: int) -> float:
	return [1.85, 1.35, 0.85][z]


func _on_swing(slot: int, _power: float, _dir: Vector3) -> void:
	if not is_turn(slot) or f_state != "open":
		return
	_hit_foe()


func _hit_foe() -> void:
	my_pts += 1
	Sfx.play(&"hit")
	rumble(0.9, 140)
	banner("TOUCH!", 0.9)
	lunge = 0.2
	_after_point()


func _after_point() -> void:
	_hud()
	f_state = "guard"
	f_t = 1.3
	foe_blade.rotation = Vector3.ZERO
	if my_pts >= WIN_SCORE or foe_pts >= WIN_SCORE:
		finish("%s  %d - %d" % ["You win!" if my_pts > foe_pts else "Foe wins", my_pts, foe_pts], float(my_pts - foe_pts))


func _tick(delta: float) -> void:
	var z := _my_zone()
	my_blade.position = my_blade.position.lerp(Vector3(0.35 + aim().x * 0.3, _zone_y(z) - 0.1, 0.4 - lunge * 4.0), 0.4)
	my_blade.rotation.x = deg_to_rad(5.0 + (1 - z) * 12.0)
	lunge = maxf(0.0, lunge - delta)
	f_t -= delta
	match f_state:
		"guard":
			foe.get_node("ArmR").rotation.x = -1.2
			if f_t <= 0.0:
				f_state = "tell"
				f_zone = randi() % 3
				f_t = randf_range(0.7, 1.0)
				banner(ZONES[f_zone], 0.6)
				foe.get_node("ArmR").rotation.x = -0.5 - f_zone * 0.3
		"tell":
			foe.get_node("ArmR").position.y = _zone_y(f_zone) - 0.55
			if f_t <= 0.0:
				f_state = "strike"
				f_t = 0.25
				foe.position.z = -2.2
		"strike":
			if f_t <= 0.0:
				foe.position.z = -3.0
				if _my_zone() == f_zone:
					Sfx.play(&"thud", 1.6)
					banner("PARRY!", 0.8)
					f_state = "open"
					f_t = 1.2
					foe_blade.rotation.y = 0.8
				else:
					foe_pts += 1
					Sfx.play(&"lose")
					rumble(1.0, 200)
					banner("HIT", 0.8)
					_after_point()
		"open":
			if f_t <= 0.0:
				f_state = "guard"
				f_t = 0.9
				foe_blade.rotation = Vector3.ZERO
