extends RallyBase
## Grass-court racket duel. First to four points (win by two).


func _setup() -> void:
	title_text = "Court Rally"
	half_w = 4.0
	half_l = 11.0
	net_h = 0.9
	serve_speed = 13.0
	ret_speed = 16.0
	hit_zone = 1.8
	win_by = 2
	points_to_win = 4
	super._setup()


func _build_court() -> void:
	Build.environment(self, Color("4a9be0"), Color("e9f4ff"), Color("3b6a3a"))
	Build.box(self, Vector3(40, 0.2, 60), Vector3(0, -0.1, 0), Color("3e8a4e"))
	Build.box(self, Vector3(9.0, 0.21, 24.0), Vector3(0, -0.095, 0), Color("4f9d5d"))
	for x in [-4.0, 4.0]:
		Build.box(self, Vector3(0.08, 0.02, 24.0), Vector3(x, 0.02, 0), Color.WHITE)
	for z in [-11.0, 11.0]:
		Build.box(self, Vector3(8.0, 0.02, 0.08), Vector3(0, 0.02, z), Color.WHITE)
	Build.box(self, Vector3(0.08, 0.02, 12.0), Vector3(0, 0.02, 0), Color(1, 1, 1, 0.0))
	Build.box(self, Vector3(8.4, 0.9, 0.05), Vector3(0, 0.45, 0), Color("222222"))
	Build.box(self, Vector3(8.4, 0.06, 0.07), Vector3(0, 0.9, 0), Color.WHITE)
	for x in [-4.2, 4.2]:
		Build.cyl(self, 0.05, 1.1, Vector3(x, 0.55, 0), Color("cccccc"))
