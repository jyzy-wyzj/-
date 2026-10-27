extends Node2D

@export var enemy_scene: PackedScene
@export var passerby_scene: PackedScene
@export var exp_orb_scene: PackedScene
@export var danmaku_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var passerby_interval: float = 3.0
@export var danmaku_interval: float = 1.2
@export var max_passersby: int = 10
@export var enemy_spawn_radius: float = 700.0
@export var exp_per_level: int = 5

var level: int = 1
var exp_points: int = 0
var kill_count: int = 0
var fan_count: int = 0

@onready var player: CharacterBody2D = $Player
@onready var enemy_container: Node2D = $EnemyContainer
@onready var passerby_container: Node2D = $PasserbyContainer
@onready var orb_container: Node2D = $OrbContainer
@onready var danmaku_container: Node2D = $DanmakuContainer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var passerby_timer: Timer = $PasserbyTimer
@onready var danmaku_timer: Timer = $DanmakuTimer
@onready var stats_label: Label = $HUD/StatsLabel
@onready var level_up_panel: CanvasLayer = $LevelUpPanel

func _ready() -> void:
	add_to_group("battle")
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	passerby_timer.wait_time = passerby_interval
	passerby_timer.timeout.connect(_on_passerby_timer_timeout)
	passerby_timer.start()
	danmaku_timer.wait_time = danmaku_interval
	danmaku_timer.timeout.connect(_on_danmaku_timer_timeout)
	danmaku_timer.start()
	level_up_panel.upgrade_chosen.connect(_on_upgrade_chosen)
	$HUD/QuitButton.pressed.connect(_on_quit_pressed)
	for i in 5:
		_spawn_passerby()
	_update_hud()

func _on_spawn_timer_timeout() -> void:
	var enemy := enemy_scene.instantiate()
	enemy.global_position = _random_pos_around_player(enemy_spawn_radius)
	enemy.died.connect(_on_enemy_died)
	enemy_container.add_child(enemy)

func _on_passerby_timer_timeout() -> void:
	if passerby_container.get_child_count() >= max_passersby:
		return
	_spawn_passerby()

func _spawn_passerby() -> void:
	var p := passerby_scene.instantiate()
	p.global_position = _random_pos_around_player(randf_range(300.0, 700.0))
	p.converted.connect(_on_passerby_converted)
	passerby_container.add_child(p)

func _on_danmaku_timer_timeout() -> void:
	_spawn_danmaku()

func _spawn_danmaku() -> void:
	var d := danmaku_scene.instantiate()
	var direction := _random_danmaku_direction()
	var spawn_pos := player.global_position - direction * 900.0 + direction.orthogonal() * randf_range(-250.0, 250.0)
	d.global_position = spawn_pos
	d.direction = direction
	d.speed = randf_range(150.0, 260.0)
	d.kind = _random_danmaku_kind()
	danmaku_container.add_child(d)

func _random_danmaku_direction() -> Vector2:
	if randf() < 0.5:
		if randf() < 0.5:
			return Vector2.RIGHT
		return Vector2.LEFT
	return Vector2.from_angle(randf() * TAU)

func _random_danmaku_kind() -> int:
	var r := randf()
	if r < 0.5:
		return 0
	if r < 0.8:
		return 1
	return 2

func _random_pos_around_player(radius: float) -> Vector2:
	return player.global_position + Vector2.from_angle(randf() * TAU) * radius

func _on_enemy_died(pos: Vector2) -> void:
	kill_count += 1
	var orb := exp_orb_scene.instantiate()
	orb.global_position = pos
	orb_container.add_child.call_deferred(orb)
	_update_hud()

func add_exp(amount: int) -> void:
	exp_points += amount
	if exp_points >= exp_per_level:
		exp_points -= exp_per_level
		level += 1
		_open_level_up()
	_update_hud()

func _on_passerby_converted() -> void:
	fan_count += 1
	GameState.add_fans(1)
	_update_hud()

func on_player_dead() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/bedroom/bedroom.tscn")

func _open_level_up() -> void:
	get_tree().paused = true
	level_up_panel.open()

func _on_upgrade_chosen(id: int) -> void:
	match id:
		0:
			player.damage += 1
		1:
			player.fire_interval *= 0.9
		2:
			player.attack_range *= 1.15
	get_tree().paused = false
	_update_hud()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/bedroom/bedroom.tscn")

func _update_hud() -> void:
	stats_label.text = "等级 %d   经验 %d/%d   击杀 %d   粉丝 %d   生命 %d" % [level, exp_points, exp_per_level, kill_count, fan_count, int(max(player.hp, 0.0))]
