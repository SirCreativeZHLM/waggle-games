class_name Build
## Tiny helpers that assemble scenes from primitives. Every model in the game is
## made from boxes, spheres and cylinders, so there are no external art assets.


static func mat(c: Color, rough: float = 0.55, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _mi(parent: Node, mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(parent, m, pos, c)


static func sphere(parent: Node, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return _mi(parent, m, pos, c)


static func cyl(parent: Node, r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 24
	return _mi(parent, m, pos, c)


static func label(parent: Node, text: String, pos: Vector3, size: float = 0.5, c: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = 0.005 * size
	l.font_size = 64
	l.modulate = c
	l.outline_size = 8
	parent.add_child(l)
	return l


static func environment(parent: Node, top: Color = Color("6ec6ff"), horizon: Color = Color("ffffff"), ground: Color = Color("bfe8a8")) -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = top
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon
	sky.ground_bottom_color = ground
	var s := Sky.new()
	s.sky_material = sky
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = s
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.25
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.12
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_brightness = 1.05
	var we := WorldEnvironment.new()
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.8
	sun.shadow_blur = 2.5
	sun.light_color = Color(1.0, 0.98, 0.93)
	parent.add_child(sun)


static func ground(parent: Node, size: Vector2, y: float, c: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.2, size.y)
	cs.shape = shape
	cs.position.y = -0.1
	body.add_child(cs)
	box(body, Vector3(size.x, 0.2, size.y), Vector3(0, -0.1, 0), c)
	body.position.y = y
	parent.add_child(body)
	return body


static func _egg_r(y: float) -> float:
	var t := (y - 0.78) / 0.525
	return 0.42 * sqrt(maxf(1.0 - t * t, 0.05))


## The player's own egg, built from Game.egg (colour, pattern, hat, face).
static func player_egg(parent: Node) -> Node3D:
	var e: Dictionary = Game.egg
	var shell := Color(Game.EGG_COLORS[clampi(int(e["color"]), 0, Game.EGG_COLORS.size() - 1)])
	return avatar(parent, shell, Color("ffd9a8"), {"pattern": int(e["pattern"]), "hat": int(e["hat"]), "face": int(e["face"])})


## Egg character (shell colour = `shirt`). Children "ArmR"/"ArmL" are shoulder pivots you can rotate.
## opts: pattern 0-2, hat 0-5, face 0-3 (see Game.EGG_*).
static func avatar(parent: Node, shirt: Color, skin: Color = Color("ffd9a8"), opts: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	var body := sphere(root, 0.42, Vector3(0, 0.78, 0), shirt)
	body.scale = Vector3(1.0, 1.25, 1.0)
	var top := sphere(root, 0.3, Vector3(0, 1.22, 0), shirt)
	top.scale = Vector3(1.0, 1.1, 1.0)
	var accent := shirt.darkened(0.25)
	match int(opts.get("pattern", 0)):
		1:
			for k in 9:
				var y := 0.5 + (k % 3) * 0.28
				var ang := k * 2.4
				var r := _egg_r(y)
				var spot := sphere(root, 0.06, Vector3(sin(ang) * r, y, -cos(ang) * r) * Vector3(1, 1, 1), accent)
				spot.scale = Vector3(1, 1, 0.5)
				spot.look_at_from_position(spot.position, Vector3(0, y, 0), Vector3.UP)
		2:
			for y in [0.55, 0.78, 1.01]:
				var band := sphere(root, _egg_r(y) + 0.008, Vector3(0, y, 0), accent)
				band.scale = Vector3(1, 0.1, 1)
	var face := int(opts.get("face", 0))
	for side in [-1, 1]:
		if face != 3:
			sphere(root, 0.045, Vector3(0.11 * side, 1.12, -0.3), Color("2b2b3a"))
		else:
			sphere(root, 0.06, Vector3(0.11 * side, 1.12, -0.29), Color("2b2b3a"))
		sphere(root, 0.05, Vector3(0.2 * side, 0.98, -0.3), Color("ff9db5"))
		var leg := cyl(root, 0.035, 0.28, Vector3(0.12 * side, 0.14, 0), skin)
		var foot := sphere(leg, 0.07, Vector3(0, -0.13, -0.04), skin)
		foot.scale = Vector3(1.0, 0.6, 1.5)
	match face:
		0: box(root, Vector3(0.1, 0.025, 0.02), Vector3(0, 1.0, -0.38), Color("2b2b3a"))
		1:
			box(root, Vector3(0.18, 0.06, 0.02), Vector3(0, 1.0, -0.37), Color("2b2b3a"))
			box(root, Vector3(0.14, 0.025, 0.02), Vector3(0, 1.015, -0.375), Color.WHITE)
		2:
			box(root, Vector3(0.36, 0.07, 0.04), Vector3(0, 1.12, -0.31), Color("111118"))
			box(root, Vector3(0.1, 0.025, 0.02), Vector3(0, 1.0, -0.38), Color("2b2b3a"))
		3: sphere(root, 0.04, Vector3(0, 0.99, -0.38), Color("2b2b3a"))
	_hat(root, int(opts.get("hat", 0)), shirt)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "ArmR" if side > 0 else "ArmL"
		pivot.position = Vector3(0.4 * side, 1.0, 0)
		cyl(pivot, 0.04, 0.5, Vector3(0, -0.25, 0), skin)
		sphere(pivot, 0.08, Vector3(0, -0.52, 0), skin)
		root.add_child(pivot)
	parent.add_child(root)
	return root


static func _hat(root: Node3D, hat: int, shell: Color) -> void:
	match hat:
		1:  # cap
			var dome := sphere(root, 0.3, Vector3(0, 1.46, 0), Color("e03a3a"))
			dome.scale = Vector3(1, 0.6, 1)
			box(root, Vector3(0.34, 0.03, 0.3), Vector3(0, 1.42, -0.3), Color("b52a2a"))
		2:  # crown
			cyl(root, 0.24, 0.12, Vector3(0, 1.5, 0), Color("ffcc33"))
			for k in 5:
				var a := k * TAU / 5.0
				box(root, Vector3(0.06, 0.12, 0.06), Vector3(sin(a) * 0.22, 1.6, cos(a) * 0.22), Color("ffcc33"))
		3:  # bow
			sphere(root, 0.09, Vector3(-0.12, 1.58, 0), Color("ff5c8a"))
			sphere(root, 0.09, Vector3(0.12, 1.58, 0), Color("ff5c8a"))
			sphere(root, 0.06, Vector3(0, 1.58, 0), Color("d93a6a"))
		4:  # chef hat
			cyl(root, 0.2, 0.3, Vector3(0, 1.6, 0), Color.WHITE)
			sphere(root, 0.26, Vector3(0, 1.78, 0), Color.WHITE)
		5:  # party hat
			var cone := cyl(root, 0.2, 0.4, Vector3(0, 1.62, 0), Color("7a5cff"))
			(cone.mesh as CylinderMesh).top_radius = 0.0
			sphere(root, 0.05, Vector3(0, 1.84, 0), Color("ffe066"))
