extends CanvasLayer

signal closed

# 12 轨书的元数据：key、中文名、档位（决定成本）
const TRACK_META: Array = [
	{"key": "attack",           "name": "攻击",       "tier": "base"},
	{"key": "hp",               "name": "血量",       "tier": "base"},
	{"key": "regen",            "name": "恢复",       "tier": "base"},
	{"key": "defense",          "name": "防御",       "tier": "advance"},
	{"key": "dodge_rate",       "name": "闪避率",     "tier": "advance"},
	{"key": "charm_ring",       "name": "魅力圈",     "tier": "advance"},
	{"key": "charm",            "name": "魅力",       "tier": "advance"},
	{"key": "fire_rate",        "name": "攻速",       "tier": "core"},
	{"key": "crit_rate",        "name": "暴击率",     "tier": "advance"},
	{"key": "crit_damage",      "name": "暴伤",       "tier": "advance"},
	{"key": "stream_push",      "name": "推流",       "tier": "core"},
	{"key": "fan_convert_rate", "name": "粉丝转化率", "tier": "core"},
]

const TIER_COLORS := {
	"base": Color(0.75, 0.75, 0.75),
	"advance": Color(0.45, 0.7, 1.0),
	"core": Color(1.0, 0.65, 0.35),
}

# key -> {effect: Label, level: Label, btn: Button}
var _entries: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$Panel/VBox/CloseButton.pressed.connect(_on_close_pressed)
	_build_track_entries()

func open() -> void:
	_refresh_all()
	show()

func _on_close_pressed() -> void:
	hide()
	closed.emit()

# 构建 12 条轨道的条目
func _build_track_entries() -> void:
	var tracks_vbox := $Panel/VBox/Scroll/Tracks
	for meta in TRACK_META:
		var key: String = meta["key"]

		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 12)

		# 左侧信息
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = "%s  [%s]" % [meta["name"], _tier_name(meta["tier"])]
		name_label.add_theme_color_override("font_color", TIER_COLORS[meta["tier"]])
		name_label.add_theme_font_size_override("font_size", 18)
		info.add_child(name_label)

		var effect_label := Label.new()
		effect_label.add_theme_font_size_override("font_size", 14)
		info.add_child(effect_label)

		var lvl_label := Label.new()
		lvl_label.add_theme_font_size_override("font_size", 14)
		info.add_child(lvl_label)

		entry.add_child(info)

		# 右侧升级按钮
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 52)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_upgrade_pressed.bind(key))
		entry.add_child(btn)

		tracks_vbox.add_child(entry)
		_entries[key] = {"effect": effect_label, "level": lvl_label, "btn": btn}

func _on_upgrade_pressed(key: String) -> void:
	if not GameState.upgrade_book(key):
		return
	_refresh_all()
	get_tree().call_group("bedroom", "_refresh_labels")

func _refresh_all() -> void:
	$Panel/VBox/FansLabel.text = "gachi：%d" % GameState.gachi
	for meta in TRACK_META:
		var key: String = meta["key"]
		var lvl: int = int(GameState.book_levels.get(key, 0))
		var e: Dictionary = _entries[key]
		e["effect"].text = _effect_text(key, lvl)
		e["level"].text = "等级 %d / 5" % lvl
		var btn: Button = e["btn"]
		var cost := GameState.get_book_cost(key)
		if cost < 0:
			btn.text = "已满级"
			btn.disabled = true
		else:
			btn.text = "升级 (%d)" % cost
			btn.disabled = GameState.gachi < cost

func _effect_text(key: String, lvl: int) -> String:
	match key:
		"attack":
			return "攻击 %d → %d" % [20, 20 + lvl]
		"hp":
			return "血量 %d → %d" % [400, 400 + 30 * lvl]
		"regen":
			return "每秒回复 %d" % (2 * lvl)
		"defense":
			return "减伤 %d%%" % (2 * lvl)
		"dodge_rate":
			return "闪避率 %d%%" % (2 * lvl)
		"charm_ring":
			return "魅力圈 %d → %d" % [160, 160 + 8 * lvl]
		"charm":
			return "转化速度 %d → %d" % [160, 160 + 8 * lvl]
		"fire_rate":
			var base := 0.45
			var cur := base * pow(0.98, float(lvl))
			return "攻速间隔 %.3fs → %.3fs" % [base, cur]
		"crit_rate":
			return "暴击率 %d%%" % (2 * lvl)
		"crit_damage":
			return "暴伤 %d%% → %d%%" % [150, 150 + 10 * lvl]
		"stream_push":
			return "推流加成 +%d%%" % (10 * lvl)
		"fan_convert_rate":
			return "转化率 +%d%%" % (3 * lvl)
	return ""

func _tier_name(tier: String) -> String:
	match tier:
		"base": return "基础"
		"advance": return "进阶"
		"core": return "核心"
	return tier
