extends CharacterBody2D

@export var speed: float = 220.0
@export var attack_range: float = 320.0
@export var fire_interval: float = 0.45
@export var damage: int = 20
@export var damage_type: int = DamageNumber.Type.FIRE
@export var fan_ring_radius: float = 160.0
@export var max_hp: float = 400.0
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8
@export var bullet_scene: PackedScene

# 新增属性（基础值，书升级后由 battle.gd 同步）
@export var defense: float = 0.0          # 减伤百分比 0~1
@export var crit_rate: float = 0.0        # 暴击率 0~1
@export var crit_damage: float = 1.5      # 暴击伤害倍率
@export var regen_per_sec: float = 0.0    # 每秒回复
@export var dodge_rate: float = 0.0       # 闪避率 0~1

var hp: float
var fire_timer: float = 0.0
var _damage_accum: float = 0.0
var _damage_cd: float = 0.0
var _danmaku_iframes: float = 0.0   # 弹幕叠伤保护 0.5s
var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _last_dir: Vector2 = Vector2.ZERO
var _regen_timer: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, fan_ring_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.45), 2.0)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_last_dir = dir.normalized()
	_update_dash(delta, dir)
	if _dash_time > 0.0:
		velocity = _dash_dir * dash_speed
	else:
		velocity = dir * speed
	move_and_slide()
	_auto_fire(delta)
	_update_damage_numbers(delta)
	_danmaku_iframes = maxf(0.0, _danmaku_iframes - delta)
	_update_regen(delta)

func _update_regen(delta: float) -> void:
	if regen_per_sec <= 0.0 or hp >= max_hp:
		return
	_regen_timer += delta
	if _regen_timer >= 1.0:
		var ticks := int(_regen_timer)
		var healed := regen_per_sec * float(ticks)
		hp = minf(hp + healed, max_hp)
		Fx.spawn_damage(global_position + Vector2(0.0, -30.0), healed, DamageNumber.Type.HEAL)
		_regen_timer -= float(ticks)

func _update_dash(delta: float, dir: Vector2) -> void:
	_dash_cd -= delta
	_dash_time -= delta
	if _dash_time > 0.0 or _dash_cd > 0.0:
		return
	if not Input.is_action_just_pressed("dash"):
		return
	_dash_dir = dir.normalized() if dir != Vector2.ZERO else _last_dir
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT
	_dash_time = dash_duration
	_dash_cd = dash_cooldown

# 弹幕伤害（带 0.5s 叠伤保护和闪避/防御判定）
func take_damage(amount: float, from_danmaku: bool = true) -> void:
	if from_danmaku and _danmaku_iframes > 0.0:
		return
	# 闪避判定
	if randf() < dodge_rate:
		return
	# 防御减伤
	var final := amount * (1.0 - defense)
	hp -= final
	_damage_accum += final
	if from_danmaku:
		_danmaku_iframes = 0.5
	if hp <= 0.0:
		get_tree().call_group("battle", "on_player_dead")

func _update_damage_numbers(delta: float) -> void:
	_damage_cd -= delta
	if _damage_accum <= 0.0 or _damage_cd > 0.0:
		return
	Fx.spawn_damage(global_position + Vector2(0.0, -30.0), _damage_accum, DamageNumber.Type.PLAYER_HURT)
	_damage_accum = 0.0
	_damage_cd = 0.35

func heal(amount: float) -> void:
	var before := hp
	hp = minf(hp + amount, max_hp)
	var actual := hp - before
	if actual > 0.0:
		Fx.spawn_damage(global_position + Vector2(0.0, -30.0), actual, DamageNumber.Type.HEAL)

func _auto_fire(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	fire_timer = fire_interval
	_spawn_bullet(target)

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_dist := attack_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d := global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d
			nearest = enemy
	return nearest

func _spawn_bullet(target: Node2D) -> void:
	var bullet := bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = (target.global_position - global_position).normalized()
	# 暴击判定
	var dmg := damage
	if randf() < crit_rate:
		dmg = int(round(float(damage) * crit_damage))
	bullet.damage = dmg
	bullet.damage_type = damage_type
	get_parent().add_child(bullet)
