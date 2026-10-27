extends CanvasLayer

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var stats_label: RichTextLabel = $Panel/VBox/StatsLabel
@onready var fans_label: Label = $Panel/VBox/FansLabel
@onready var home_button: Button = $Panel/VBox/HomeButton

func _ready() -> void:
	visible = false
	home_button.pressed.connect(_on_home_pressed)

func show_result(mode: int, in_battle_push: int, tier_push: int, base_fans: int, gained: int, boss_defeated: bool = false) -> void:
	visible = true
	var is_dream := GameState.daily_activity == 2
	match mode:
		0:
			title_label.text = "梦境挑战结算" if is_dream else "直播结算"
		1:
			title_label.text = "梦境结束" if is_dream else "下播结算"
		_:
			title_label.text = "梦境中断" if is_dream else "直播中断"
	# 推流 = (档位基础推流 + 局内推流) × (0.8 + 书·推流加成)
	var push_coeff: float = 0.8 + 0.10 * float(GameState.book_levels.get("stream_push", 0))
	var total_push := int(round(float(tier_push + in_battle_push) * push_coeff))
	# 转化粉丝 = 基础粉丝 × 5 × (1 + 书·粉丝转化率)
	var convert_bonus: float = 1.0 + 0.03 * float(GameState.book_levels.get("fan_convert_rate", 0))
	var converted_fans := int(round(base_fans * 5.0 * convert_bonus))
	var boss_tag := "  [color=yellow]Boss×2[/color]" if boss_defeated else ""
	stats_label.text = "基础粉丝 %d × 5 = %d    推流 %d%s\n本次获得粉丝 %d" % [base_fans, converted_fans, total_push, boss_tag, gained]
	fans_label.text = "gachi %d" % [GameState.gachi]

func _on_home_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/bedroom/bedroom.tscn")
