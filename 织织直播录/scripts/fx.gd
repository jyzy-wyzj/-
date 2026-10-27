extends Node

const DAMAGE_SCENE = preload("res://scenes/ui/damage_number.tscn")

func spawn_damage(pos: Vector2, amount: float, type: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var n := DAMAGE_SCENE.instantiate()
	n.position = pos
	n.setup(amount, type)
	scene.add_child(n)
