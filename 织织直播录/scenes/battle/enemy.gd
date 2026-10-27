extends Area2D

signal died(pos: Vector2)

# 串子（近战）基础数值，4× 缩放
@export var max_hp: int = 48
@export var move_speed: float = 65.0
@export var drain_rate: float = 200.0
@export var touch_damage: float = 24.0
@export var exp_value: int = 4

var hp: int

func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	var target := _pick_target()
	if target == null:
		return
	if global_position.distance_to(target.global_position) > 26.0:
		position += (target.global_position - global_position).normalized() * move_speed * delta
	else:
		_attack_target(target, delta)

func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("passerby"):
		if p.convert_progress > 0.0:
			var d := global_position.distance_to(p.global_position)
			if d < best_dist:
				best_dist = d
				best = p
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var pl: Node2D = players[0]
		var d := global_position.distance_to(pl.global_position)
		if d < best_dist:
			best = pl
	return best

func _attack_target(target: Node2D, delta: float) -> void:
	if target.is_in_group("player"):
		# 接触伤害不触发弹幕 iframe，也不触发闪避（闪避只对弹幕）
		target.take_damage(touch_damage * delta, false)
	else:
		target.drain_progress(drain_rate * delta)

func take_damage(amount: int, type: int = DamageNumber.Type.FIRE) -> void:
	hp -= amount
	Fx.spawn_damage(global_position + Vector2(0.0, -24.0), float(amount), type)
	if hp <= 0:
		died.emit(global_position)
		queue_free()
