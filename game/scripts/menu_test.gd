extends Node
## Headless: godot --headless --path game scenes/menu_test.tscn
func _ready() -> void:
	var m := Control.new()
	m.set_script(load("res://scripts/menu.gd"))
	add_child(m)
	await get_tree().process_frame
	m._open_editor()
	await get_tree().process_frame
	var buttons: Array = m._active_buttons()
	print("editor buttons: ", buttons.size())
	for b in buttons:
		for i in 7:
			b.pressed.emit()
		await get_tree().process_frame
	for c in Game.EGG_COLORS.size():
		for p in Game.EGG_PATTERNS.size():
			for h in Game.EGG_HATS.size():
				for f in Game.EGG_FACES.size():
					Game.egg = {"color": c, "pattern": p, "hat": h, "face": f, "name": "T"}
					var holder := Node3D.new()
					add_child(holder)
					Build.player_egg(holder)
					holder.queue_free()
	print("all egg combos built")
	get_tree().quit()
