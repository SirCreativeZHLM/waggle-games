extends Node
## Headless: godot --headless --path game scenes/net_test.tscn   (pair with tools/fake_phone.py)
var swings := 0
var presses := 0
var connected := false
func _ready() -> void:
	Remote.pair_code = "1234"
	Remote.swing.connect(func(s, p, d): swings += 1; print("SWING slot=%d power=%.2f dir=%s" % [s, p, d]))
	Remote.button.connect(func(s, b, down): if down: presses += 1; print("BUTTON ", b))
	Remote.phone_connected.connect(func(s, n): connected = true; print("CONNECTED slot=", s, " name=", n))
	await get_tree().create_timer(6.0).timeout
	print("RESULT connected=%s swings=%d presses=%d aim=%s" % [connected, swings, presses, Remote.aim(0)])
	get_tree().quit()
