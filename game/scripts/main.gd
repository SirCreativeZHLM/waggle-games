extends Node
## Owns whichever screen (menu or mini-game) is currently showing.

var current: Node


func _ready() -> void:
	Game.main = self
	show_menu()


func show_menu() -> void:
	var m := Control.new()
	m.set_script(load("res://scripts/menu.gd"))
	_swap(m)
	Sfx.music(true)


func start_game(id: String) -> void:
	var n := Node3D.new()
	n.set_script(load("res://games/%s.gd" % id))
	n.set("info", Game.entry(id))
	Sfx.music(false)
	_swap(n)


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)
