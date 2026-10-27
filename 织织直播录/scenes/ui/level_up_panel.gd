extends CanvasLayer

signal upgrade_chosen(id: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	$Panel/VBox/AttackButton.pressed.connect(_on_attack_pressed)
	$Panel/VBox/FireRateButton.pressed.connect(_on_fire_rate_pressed)
	$Panel/VBox/RangeButton.pressed.connect(_on_range_pressed)

func open() -> void:
	show()

func _on_attack_pressed() -> void:
	_choose(0)

func _on_fire_rate_pressed() -> void:
	_choose(1)

func _on_range_pressed() -> void:
	_choose(2)

func _choose(id: int) -> void:
	hide()
	upgrade_chosen.emit(id)
