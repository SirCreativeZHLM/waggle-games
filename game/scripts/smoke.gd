extends Node
## Headless smoke test:  godot --headless --path game scenes/smoke.tscn -- [game_id] [--shot]
## Loads each mini-game, starts it, feeds scripted input for a few seconds and reports script errors.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = []
	for e in Game.ENTRIES:
		ids.append(e["id"])
	if args.size() > 0 and args[0] != "--shot":
		ids = [args[0]]
	var shot := args.has("--shot")
	var main_script := load("res://scripts/main.gd")
	var main := Node.new()
	main.set_script(main_script)
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	for id in ids:
		print("== ", id)
		main.start_game(id)
		await get_tree().process_frame
		await get_tree().process_frame
		var g: Node = main.current
		Remote.inject_button(0, &"a", true)
		Remote.inject_button(0, &"a", false)
		for i in 360:
			if i % 45 == 10:
				Remote.set_aim(0, Vector2(sin(i * 0.1) * 0.6, 0.1))
				Remote.inject_swing(0, 0.7, Vector3(0.2, 0.3, -1.0))
			if i % 90 == 50:
				Remote.inject_button(0, &"a", true)
			if i % 90 == 80:
				Remote.inject_button(0, &"a", false)
			if i == 200 and shot:
				var img := get_viewport().get_texture().get_image()
				img.save_png("%s/waggle_%s.png" % [OS.get_environment("SHOT_DIR"), id])
			await get_tree().physics_frame
		print("   state=", g.get("state"))
	get_tree().quit()
