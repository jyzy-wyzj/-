extends Node2D

@export var enemy_scene: PackedScene
@export var passerby_scene: PackedScene
@export var exp_orb_scene: PackedScene
@export var danmaku_scene: PackedScene
@export var passerby_interval: float = 1.5
@export var danmaku_interval: float = 1.2
@export var max_passersby: int = 20
@export var enemy_spawn_radius: float = 700.0

# 普通日 5 波：[刷怪间隔, 敌人HP系数, 时长]（测试模式：时长÷10）
const NORMAL_WAVES: Array = [
	[1.9, 1.0, 6.0],   # 第1波 6秒（原1分钟）
	[1.7, 1.15, 9.0],  # 第2波 9秒（原1分30秒）
	[1.5, 1.3, 9.0],   # 第3波 9秒
	[1.3, 1.5, 9.0],   # 第4波 9秒
	[1.1, 1.7, 12.0],  # 第5波 12秒（原2分钟）
]

# Boss 日 7 波：普通日 5 波 + 1 个普通波 + 1 个 Boss 波（测试模式：时长÷10）
const BOSS_WAVES: Array = [
	[1.9, 1.0, 6.0],
	[1.7, 1.15, 9.0],
	[1.5, 1.3, 9.0],
	[1.3, 1.5, 9.0],
	[1.1, 1.7, 12.0],
	[1.0, 2.0, 12.0],   # 额外普通波 12秒（原2分钟）
	[1.5, 2.5, 18.0],   # Boss 波 18秒（原3分钟，Boss 未实装，暂用强化普通敌人）
]

var wave_config: Array = []
var is_boss_day: bool = false

# 经验表：升到下一级所需
const EXP_TABLE: Array = [32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, 128, 136]

var level: int = 1
var exp_points: int = 0
var fan_count: int = 0
var push_gain: int = 0       # 本局累积的局内推流（击杀+1/转化+2/礼物+5~50）
var current_wave: int = 0
var wave_timer: float = 0.0
var battle_over: bool = false
var boss_defeated: bool = false  # Boss 局是否击败 Boss（击败则结算×2）
var gift_timer: float = 0.0       # 礼物掉落计时
var next_gift_interval: float = 50.0  # 下次礼物掉落间隔

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
@onready var settlement: CanvasLayer = $Settlement

func _ready() -> void:
	add_to_group("battle")
	is_boss_day = GameState.day % 5 == 0
	wave_config = BOSS_WAVES if is_boss_day else NORMAL_WAVES
	push_gain = 0
	_apply_book_bonuses()
	_setup_wave(0)
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
	for i in 10:
		_spawn_passerby()
	_update_hud()

func _apply_book_bonuses() -> void:
	# 从 GameState 读取书等级，应用到玩家
	var lvl: Dictionary = GameState.book_levels
	var hp_lvl: int = int(lvl.get("hp", 0))
	var atk_lvl: int = int(lvl.get("attack", 0))
	var fr_lvl: int = int(lvl.get("fire_rate", 0))
	var cr_lvl: int = int(lvl.get("crit_rate", 0))
	var cd_lvl: int = int(lvl.get("crit_damage", 0))
	var def_lvl: int = int(lvl.get("defense", 0))
	var dodge_lvl: int = int(lvl.get("dodge_rate", 0))
	var regen_lvl: int = int(lvl.get("regen", 0))
	var ring_lvl: int = int(lvl.get("charm_ring", 0))
	player.max_hp = 400.0 + 30.0 * float(hp_lvl)
	player.hp = player.max_hp
	player.damage = 20 + atk_lvl
	player.fire_interval = 0.45 * pow(0.98, float(fr_lvl))
	player.crit_rate = 0.02 * float(cr_lvl)
	player.crit_damage = 1.5 + 0.10 * float(cd_lvl)
	player.defense = 0.02 * float(def_lvl)
	player.dodge_rate = 0.02 * float(dodge_lvl)
	player.regen_per_sec = 2.0 * float(regen_lvl)
	player.fan_ring_radius = 160.0 + 8.0 * float(ring_lvl)
	# 魅力（转化速度）作用在路人身上，见 _spawn_passerby

func _setup_wave(idx: int) -> void:
	current_wave = idx
	if idx >= wave_config.size():
		_finish_battle(0)  # 正常完成
		return
	var cfg: Array = wave_config[idx]
	spawn_timer.wait_time = float(cfg[0])
	wave_timer = 0.0

func _process(delta: float) -> void:
	if battle_over:
		return
	# 礼物掉落计时：每 45-60 秒掉一个
	gift_timer += delta
	if gift_timer >= next_gift_interval:
		gift_timer = 0.0
		next_gift_interval = randf_range(45.0, 60.0)
		_spawn_gift()
	wave_timer += delta
	var cfg: Array = wave_config[current_wave]
	if wave_timer >= float(cfg[2]):
		_setup_wave(current_wave + 1)
	_update_hud()

# 掉落礼物（打赏），增加局内推流
func _spawn_gift() -> void:
	var r := randf()
	var amount: int
	if r < 0.6:
		amount = 5    # 小礼物 60%
	elif r < 0.9:
		amount = 15   # 中礼物 30%
	else:
		amount = 50   # 大礼物 10%
	push_gain += amount
	Fx.spawn_damage(player.global_position + Vector2(0.0, -50.0), amount, DamageNumber.Type.LIGHT)
	_update_hud()

func _on_spawn_timer_timeout() -> void:
	if battle_over:
		return
	var enemy := enemy_scene.instantiate()
	enemy.global_position = _random_pos_around_player(enemy_spawn_radius)
	# 按波次 HP 系数放大
	var hp_coeff: float = float(wave_config[current_wave][1])
	enemy.max_hp = int(round(float(enemy.max_hp) * hp_coeff))
	enemy.died.connect(_on_enemy_died)
	enemy_container.add_child(enemy)

func _on_passerby_timer_timeout() -> void:
	if passerby_container.get_child_count() >= max_passersby:
		return
	_spawn_passerby()

func _spawn_passerby() -> void:
	var p := passerby_scene.instantiate()
	# 魅力加成：转化速度提升
	var charm_lvl: int = int(GameState.book_levels.get("charm", 0))
	p.convert_rate = 160.0 + 8.0 * float(charm_lvl)
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
	push_gain += 1  # 击杀串子 +1 局内推流
	# Boss 局：在 Boss 波（最后一波）击杀敌人视为击败 Boss
	if is_boss_day and current_wave >= wave_config.size() - 1:
		boss_defeated = true
	var orb := exp_orb_scene.instantiate()
	orb.global_position = pos
	# 传递敌人经验值（exp_orb 新增 exp_amount 字段）
	orb.exp_amount = 4  # 串子经验 4
	orb_container.add_child.call_deferred(orb)
	_update_hud()

func add_exp(amount: int) -> void:
	exp_points += amount
	var leveled := false
	var need := _exp_needed()
	while exp_points >= need and level < EXP_TABLE.size() + 1:
		exp_points -= need
		level += 1
		leveled = true
		need = _exp_needed()
	if leveled and level <= EXP_TABLE.size():
		_open_level_up()
	_update_hud()

func _exp_needed() -> int:
	if level <= EXP_TABLE.size():
		return EXP_TABLE[level - 1]
	return EXP_TABLE[EXP_TABLE.size() - 1]

func _on_passerby_converted() -> void:
	fan_count += 1
	push_gain += 2  # 转化路人 +2 局内推流
	# 随机粉丝奖励，按当前总粉丝档位
	var fans := GameState.get_random_passerby_fans()
	GameState.add_pending_fans(fans)
	_update_hud()

func on_player_dead() -> void:
	_end_battle(2)

func _open_level_up() -> void:
	get_tree().paused = true
	level_up_panel.open()

func _on_upgrade_chosen(id: int) -> void:
	match id:
		0:
			player.damage += 2
		1:
			player.fire_interval *= 0.91
		2:
			player.attack_range += 32
	get_tree().paused = false
	_update_hud()

func _on_quit_pressed() -> void:
	_end_battle(1)

func _finish_battle(mode: int) -> void:
	_end_battle(mode)

func _end_battle(mode: int) -> void:
	if battle_over:
		return
	battle_over = true
	spawn_timer.stop()
	passerby_timer.stop()
	danmaku_timer.stop()
	var converted: int = GameState.pending_fans
	# 结算前捕获档位基础推流（结算后总粉丝变化会影响档位）
	var tier_push: int = 0
	if mode == 0:
		tier_push = GameState.get_tier_push()
	var gained: int = GameState.settle(mode, push_gain, boss_defeated)
	get_tree().paused = true
	settlement.show_result(mode, push_gain, tier_push, converted, gained, boss_defeated)

func _update_hud() -> void:
	var need := _exp_needed()
	var idx: int = clampi(current_wave, 0, wave_config.size() - 1)
	var total_time: float = float(wave_config[idx][2])
	var remain := maxf(0.0, total_time - wave_timer)
	var mm := int(int(remain) / 60.0)
	var ss := int(remain) % 60
	# 推流 = (档位基础推流 + 局内推流) × (0.8 + 书·推流加成)
	var push_coeff: float = 0.8 + 0.10 * float(GameState.book_levels.get("stream_push", 0))
	var tier_push: int = GameState.get_tier_push()
	var total_push: int = int(round(float(tier_push + push_gain) * push_coeff))
	stats_label.text = "等级 %d   经验 %d/%d   推流 %d   本局粉丝 %d   生命 %d   波次 %d/%d  剩余 %02d:%02d" % [
		level, exp_points, need, total_push, GameState.pending_fans, int(max(player.hp, 0.0)),
		idx + 1, wave_config.size(), mm, ss
	]
