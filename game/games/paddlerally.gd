extends RallyBase
## Fast table duel to eleven.


func _setup() -> void:
	title_text = "Paddle Rally"
	half_w = 0.76
	half_l = 1.37
	net_h = 0.15
	gravity = 9.8
	bounce_k = 0.9
	serve_speed = 3.2
	ret_speed = 4.2
	hit_zone = 0.55
	player_y = -0.76
	points_to_win = 11
	win_by = 2
	cpu_skill = 0.8
	super._setup()
	me.scale = Vector3.ONE * 1.0
	opp.scale = Vector3.ONE * 1.0
	me.position = Vector3(0, -0.76, half_l + 1.0)
	opp.position = Vector3(0, -0.76, -half_l - 1.0)
	cam.position = Vector3(0, 1.45, half_l + 2.0)
	cam.look_at(Vector3(0, 0.6, -0.5))


func _build_court() -> void:
	Build.environment(self, Color("7fd0ff"), Color("ffffff"), Color("dfeeff"))
	Build.box(self, Vector3(20, 0.2, 20), Vector3(0, -0.8, 0), Color("dce8f7"))
	Build.box(self, Vector3(1.525, 0.05, 2.74), Vector3(0, -0.025, 0), Color("1f5aa8"))
	Build.box(self, Vector3(0.02, 0.052, 2.74), Vector3(0, -0.024, 0), Color.WHITE)
	for z in [-1.37, 1.37]:
		Build.box(self, Vector3(1.525, 0.052, 0.02), Vector3(0, -0.024, z), Color.WHITE)
	for x in [-0.76, 0.76]:
		Build.box(self, Vector3(0.02, 0.052, 2.74), Vector3(x, -0.024, 0), Color.WHITE)
	for x in [-0.7, 0.7]:
		for z in [-1.2, 1.2]:
			Build.box(self, Vector3(0.06, 0.74, 0.06), Vector3(x, -0.4, z), Color("8a97b0"))
	Build.box(self, Vector3(1.8, 0.15, 0.015), Vector3(0, 0.075, 0), Color(0.85, 0.85, 0.9))
