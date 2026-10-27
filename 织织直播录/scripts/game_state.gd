extends Node

const SAVE_PATH := "user://save.cfg"
const SAVE_DIR := "user://saves"

var day: int = 1
var total_fans: int = 1000       # 总粉丝，只增不减，用于百万粉目标和档位判定
var gachi: int = 15              # gachi粉（核心粉），用于书升级，占总粉丝的小部分
var pending_fans: int = 0        # 本局基础粉丝总和（路人随机奖励之和），结算时×5
var daily_activity: int = 0      # 今日已选活动：0=未选择, 1=直播, 2=梦境挑战

# 粉丝档位表：[门槛, 档位基础推流, 路人随机下界, 路人随机上界]
# 档位基础推流前低后高：前期靠局内推流，后期靠档位基数
# 达到 100 万后封顶
const FAN_TIERS: Array = [
	[1000,    50,     4,  6],
	[3000,    400,    5,  7],
	[5000,    1800,   6,  8],
	[10000,   4300,   8,  10],
	[30000,   10000,  12, 15],
	[100000,  30000,  20, 25],
	[300000,  80000,  30, 35],
	[1000000, 0,      30, 35],
]

# 书的各项等级（12 轨，每轨 0-5 级）
var book_levels: Dictionary = {
	"attack": 0,
	"defense": 0,
	"dodge_rate": 0,
	"hp": 0,
	"fire_rate": 0,
	"crit_rate": 0,
	"crit_damage": 0,
	"regen": 0,
	"charm_ring": 0,
	"charm": 0,
	"stream_push": 0,
	"fan_convert_rate": 0,
}

# 书每轨 5 级成本（基础轨/进阶轨/核心轨）—— 数值已缩小，体现 gachi 的稀缺性
const BOOK_COST_TIER = {
	"base":    [10, 20, 40, 80, 160],
	"advance": [20, 40, 80, 160, 320],
	"core":    [40, 80, 160, 320, 640],
}

const BOOK_TIER_MAP = {
	"attack": "base",
	"hp": "base",
	"regen": "base",
	"defense": "advance",
	"dodge_rate": "advance",
	"charm_ring": "advance",
	"charm": "advance",
	"crit_rate": "advance",
	"crit_damage": "advance",
	"fire_rate": "core",
	"stream_push": "core",
	"fan_convert_rate": "core",
}

func _ready() -> void:
	load_game()

# --- 粉丝 ---

func add_fans(amount: int) -> void:
	total_fans += amount

func add_pending_fans(amount: int) -> void:
	pending_fans += amount

# 单个路人随机粉丝（按当前档位）
func get_random_passerby_fans(total: int = -1) -> int:
	var tier := get_fan_tier(total)
	return randi_range(int(tier[2]), int(tier[3]))

# --- 每天的直播 / 梦境挑战二选一 ---

func start_activity(kind: int) -> bool:
	if daily_activity != 0:
		return false
	daily_activity = kind
	save_game()
	return true

func reset_daily() -> void:
	daily_activity = 0

# 根据总粉丝获取当前档位索引
func get_fan_tier_index(total: int = -1) -> int:
	if total < 0:
		total = total_fans
	for i in range(FAN_TIERS.size() - 1, -1, -1):
		if total >= FAN_TIERS[i][0]:
			return i
	return 0

func get_fan_tier(total: int = -1) -> Array:
	return FAN_TIERS[get_fan_tier_index(total)]

# 获取档位基础推流
func get_tier_push(total: int = -1) -> int:
	var tier := get_fan_tier(total)
	return int(tier[1])

# 结算
# mode: 0=完整结算, 1=下播（失去档位基础推流）, 2=死亡（全丢）
# in_battle_push: 本局累积的局内推流（击杀/转化/礼物）
# boss_defeated: Boss 局是否击败 Boss，击败则结算 ×2
# 返回本次结算粉丝数
func settle(mode: int = 0, in_battle_push: int = 0, boss_defeated: bool = false) -> int:
	# 转化粉丝 = 本局基础粉丝 × 5 × (1 + 书·粉丝转化率)
	var convert_rate_bonus: float = 1.0 + 0.03 * float(book_levels.get("fan_convert_rate", 0))
	var converted_fans := int(round(pending_fans * 5.0 * convert_rate_bonus))
	# 推流 = (档位基础推流 + 局内推流) × (0.8 + 书·推流加成)
	var push_coeff: float = 0.8 + 0.10 * float(book_levels.get("stream_push", 0))
	var tier_push: int = get_tier_push() if mode == 0 else 0
	var push_total := int(round(float(tier_push + in_battle_push) * push_coeff))

	var gained := converted_fans + push_total
	if boss_defeated:
		gained *= 2

	match mode:
		0, 1:  # 正常完成 / 下播
			total_fans += gained
			gachi += int(round(gained * 0.01))
			pending_fans = 0
			save_game()
			return gained
		2:  # 死亡：全丢
			pending_fans = 0
			save_game()
			return 0
	return 0

# --- 书 ---

func get_book_cost(track_key: String) -> int:
	var level: int = int(book_levels.get(track_key, 0))
	if level >= 5:
		return -1
	var tier_name: String = String(BOOK_TIER_MAP.get(track_key, "base"))
	var costs: Array = BOOK_COST_TIER[tier_name]
	return int(costs[level])

func upgrade_book(track_key: String) -> bool:
	var cost := get_book_cost(track_key)
	if cost < 0 or gachi < cost:
		return false
	gachi -= cost
	book_levels[track_key] = book_levels.get(track_key, 0) + 1
	save_game()
	return true

# 获取书提供的属性加成
func get_book_bonus(track_key: String, per_level: float) -> float:
	return float(book_levels.get(track_key, 0)) * per_level

# --- 存档 ---

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "day", day)
	cfg.set_value("progress", "total_fans", total_fans)
	cfg.set_value("progress", "gachi", gachi)
	cfg.set_value("progress", "pending_fans", pending_fans)
	cfg.set_value("progress", "daily_activity", daily_activity)
	for key in book_levels.keys():
		cfg.set_value("book", key, book_levels[key])
	cfg.save(SAVE_PATH)

# 睡觉时调用：普通自动存档 + 覆盖第 1 个存档位（自动存档位）
func sleep_save() -> void:
	save_game()
	_save_slot(0)

func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	day = int(cfg.get_value("progress", "day", 1))
	total_fans = int(cfg.get_value("progress", "total_fans", 1000))
	gachi = int(cfg.get_value("progress", "gachi", 15))
	pending_fans = int(cfg.get_value("progress", "pending_fans", 0))
	daily_activity = int(cfg.get_value("progress", "daily_activity", 0))
	for key in book_levels.keys():
		book_levels[key] = int(cfg.get_value("book", key, 0))
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_slot(index: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_save_slot(index)

func _save_slot(index: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "day", day)
	cfg.set_value("progress", "total_fans", total_fans)
	cfg.set_value("progress", "gachi", gachi)
	cfg.set_value("progress", "pending_fans", pending_fans)
	cfg.set_value("progress", "daily_activity", daily_activity)
	for key in book_levels.keys():
		cfg.set_value("book", key, book_levels[key])
	cfg.set_value("meta", "time", _now_text())
	cfg.save(_slot_path(index))

func load_slot(index: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(index)) != OK:
		return false
	day = int(cfg.get_value("progress", "day", 1))
	total_fans = int(cfg.get_value("progress", "total_fans", 1000))
	gachi = int(cfg.get_value("progress", "gachi", 15))
	pending_fans = int(cfg.get_value("progress", "pending_fans", 0))
	daily_activity = int(cfg.get_value("progress", "daily_activity", 0))
	for key in book_levels.keys():
		book_levels[key] = int(cfg.get_value("book", key, 0))
	save_game()
	return true

func get_slot_time(index: int) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(index)) != OK:
		return ""
	return str(cfg.get_value("meta", "time", ""))

func _slot_path(index: int) -> String:
	return "%s/slot_%d.cfg" % [SAVE_DIR, index]

func _now_text() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]
