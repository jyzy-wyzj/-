extends CanvasLayer

const SLOTS_PER_PAGE := 6

var _mode: String = "save"
var _page: int = 0

@onready var save_button: Button = $BtnSave
@onready var load_button: Button = $BtnLoad
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var page_label: Label = $Panel/VBox/PageLabel
@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var prev_button: Button = $Panel/VBox/Bar/PrevButton
@onready var next_button: Button = $Panel/VBox/Bar/NextButton
@onready var close_button: Button = $Panel/VBox/Bar/CloseButton

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	close_button.pressed.connect(_on_close_pressed)
	for i in range(SLOTS_PER_PAGE):
		var slot := grid.get_node("Slot%d" % i) as Button
		slot.pressed.connect(_on_slot_pressed.bind(i))
	panel.visible = false

func _on_save_pressed() -> void:
	_open_panel("save")

func _on_load_pressed() -> void:
	_open_panel("load")

func _open_panel(mode: String) -> void:
	_mode = mode
	_page = 0
	panel.visible = true
	title_label.text = "存档" if mode == "save" else "读档"
	_refresh()

func _on_prev_pressed() -> void:
	if _page > 0:
		_page -= 1
		_refresh()

func _on_next_pressed() -> void:
	_page += 1
	_refresh()

func _on_close_pressed() -> void:
	panel.visible = false

func _refresh() -> void:
	page_label.text = "第 %d 页" % (_page + 1)
	prev_button.disabled = _page <= 0
	for i in range(SLOTS_PER_PAGE):
		var index := _page * SLOTS_PER_PAGE + i
		var slot := grid.get_node("Slot%d" % i) as Button
		var thumb := slot.get_node("VBox/Thumb") as ColorRect
		var caption := slot.get_node("VBox/Caption") as Label
		var time_text := GameState.get_slot_time(index)
		if time_text == "":
			caption.text = "空存档位"
			thumb.color = Color(0.35, 0.65, 0.95, 1.0)
		else:
			caption.text = time_text
			thumb.color = Color(0.22, 0.32, 0.48, 1.0)

func _on_slot_pressed(slot_index: int) -> void:
	var index := _page * SLOTS_PER_PAGE + slot_index
	if _mode == "save":
		GameState.save_slot(index)
		_refresh()
		return
	if GameState.get_slot_time(index) == "":
		return
	GameState.load_slot(index)
	get_tree().paused = false
	get_tree().reload_current_scene()
