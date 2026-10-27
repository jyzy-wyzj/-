extends Area2D

signal converted

@export var wander_speed: float = 40.0
@export var convert_need: float = 100.0
@export var convert_rate: float = 40.0

var convert_progress: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0

func _ready() -> void:
	add_to_group("passerby")
	_pick_new_dir()

func _physics_process(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_dir()
	position += _dir * wander_speed * delta
	_check_convert(delta)

func drain_progress(amount: float) -> void:
	convert_progress = max(0.0, convert_progress - amount)
	_update_tint()

func _pick_new_dir() -> void:
	_wander_timer = randf_range(1.5, 3.0)
	if randf() < 0.7:
		_dir = Vector2.from_angle(randf() * TAU)
	else:
		_dir = Vector2.ZERO

func _check_convert(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0]
	if global_position.distance_to(player.global_position) <= player.fan_ring_radius:
		convert_progress += convert_rate * delta
		_update_tint()
		if convert_progress >= convert_need:
			converted.emit()
			queue_free()

func _update_tint() -> void:
	var ratio := clampf(convert_progress / convert_need, 0.0, 1.0)
	modulate = Color(0.4, 1.0, 0.5).lerp(Color.WHITE, 1.0 - ratio)
	queue_redraw()

func _draw() -> void:
	if convert_progress <= 0.0:
		return
	var ratio := clampf(convert_progress / convert_need, 0.0, 1.0)
	draw_rect(Rect2(-22.0, -32.0, 44.0, 6.0), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-22.0, -32.0, 44.0 * ratio, 6.0), Color(0.4, 1.0, 0.5, 1.0))
