extends Node2D

@onready var hint_label: Label = $HintLabel
@onready var day_label: Label = $HUD/DayLabel
@onready var fans_label: Label = $HUD/FansLabel

func _ready() -> void:
	day_label.text = "第 %d 天" % GameState.day
	fans_label.text = "总粉丝 %d" % GameState.total_fans
	$Computer.input_event.connect(_on_computer_input_event)
	$Bed.input_event.connect(_on_bed_input_event)
	$Mirror.input_event.connect(_on_mirror_input_event)
	$Book.input_event.connect(_on_book_input_event)

func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

func _on_computer_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_left_click(event):
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")

func _on_bed_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_left_click(event):
		GameState.day += 1
		GameState.save_game()
		day_label.text = "第 %d 天" % GameState.day
		fans_label.text = "总粉丝 %d" % GameState.total_fans
		hint_label.text = "已睡觉，进入第 %d 天（已自动存档）" % GameState.day

func _on_mirror_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_left_click(event):
		hint_label.text = "镜子：机制升级（未实装）"

func _on_book_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_left_click(event):
		hint_label.text = "书：数值升级（未实装）"
