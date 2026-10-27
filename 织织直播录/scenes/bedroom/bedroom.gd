extends Node2D

const ACTIVITY_STREAM := 1
const ACTIVITY_DREAM := 2
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

@onready var hint_label: Label = $HintLabel
@onready var day_label: Label = $HUD/DayLabel
@onready var fans_label: Label = $HUD/FansLabel
@onready var book_panel: CanvasLayer = $BookPanel

func _ready() -> void:
	add_to_group("bedroom")
	_refresh_labels()
	$Computer.input_event.connect(_on_computer_input_event)
	$Bed.input_event.connect(_on_bed_input_event)
	$Mirror.input_event.connect(_on_mirror_input_event)
	$Book.input_event.connect(_on_book_input_event)
	book_panel.closed.connect(_on_book_panel_closed)

func _refresh_labels() -> void:
	day_label.text = "第 %d 天" % GameState.day
	fans_label.text = "总粉丝 %d  gachi %d" % [GameState.total_fans, GameState.gachi]
	if GameState.daily_activity == 0:
		hint_label.text = "第 %d 天 —— 请选择：直播（电脑）或 梦境挑战（床）" % GameState.day
	elif GameState.daily_activity == ACTIVITY_STREAM:
		hint_label.text = "今天已经直播过了，点击床睡觉进入下一天"
	else:
		hint_label.text = "今天已经做过梦境挑战了，点击床睡觉进入下一天"

func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

func _on_computer_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_left_click(event):
		return
	if GameState.daily_activity == 0:
		GameState.start_activity(ACTIVITY_STREAM)
		get_tree().change_scene_to_file(BATTLE_SCENE)
		return
	if GameState.daily_activity == ACTIVITY_STREAM:
		hint_label.text = "今天已经直播过了，点击床睡觉进入下一天"
	else:
		hint_label.text = "今天已经做过梦境挑战了，明天再直播"

func _on_bed_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_left_click(event):
		return
	if GameState.daily_activity == 0:
		GameState.start_activity(ACTIVITY_DREAM)
		get_tree().change_scene_to_file(BATTLE_SCENE)
		return
	GameState.day += 1
	GameState.reset_daily()
	GameState.sleep_save()
	_refresh_labels()
	hint_label.text = "已睡觉，进入第 %d 天（已自动存档）" % GameState.day

func _on_mirror_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_left_click(event):
		hint_label.text = "镜子：机制升级（未实装）"

func _on_book_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_left_click(event):
		return
	book_panel.open()

func _on_book_panel_closed() -> void:
	pass
