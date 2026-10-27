extends CanvasLayer

const KEY_ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down", "dash"]
const BUTTON_NAMES: Dictionary = {
	"move_left": "BtnLeft",
	"move_right": "BtnRight",
	"move_up": "BtnUp",
	"move_down": "BtnDown",
	"dash": "BtnDash",
}

var _rebind_action: String = ""

@onready var open_button: Button = $OpenButton
@onready var panel: Panel = $Panel
@onready var volume_slider: HSlider = $Panel/VBox/VolumeSlider
@onready var key_list: GridContainer = $Panel/VBox/KeyList
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	open_button.pressed.connect(_on_open_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_button.pressed.connect(_on_close_pressed)
	for action in KEY_ACTIONS:
		var btn := key_list.get_node(BUTTON_NAMES[action]) as Button
		btn.pressed.connect(_on_key_button_pressed.bind(action))
	_refresh_key_buttons()
	_on_volume_changed(volume_slider.value)

func _on_open_pressed() -> void:
	panel.visible = not panel.visible
	_rebind_action = ""
	_refresh_key_buttons()

func _on_close_pressed() -> void:
	panel.visible = false
	_rebind_action = ""
	_refresh_key_buttons()

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
	AudioServer.set_bus_mute(0, value <= 0.0)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_key_button_pressed(action: String) -> void:
	_rebind_action = action
	var btn := key_list.get_node(BUTTON_NAMES[action]) as Button
	btn.text = "请按键..."

func _input(event: InputEvent) -> void:
	if _rebind_action == "":
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	if key_event.physical_keycode == KEY_ESCAPE:
		_rebind_action = ""
		_refresh_key_buttons()
		return
	_apply_key(_rebind_action, key_event)

func _apply_key(action: String, key_event: InputEventKey) -> void:
	InputMap.action_erase_events(action)
	var new_event := InputEventKey.new()
	new_event.physical_keycode = key_event.physical_keycode
	InputMap.action_add_event(action, new_event)
	_rebind_action = ""
	_refresh_key_buttons()

func _refresh_key_buttons() -> void:
	for action in KEY_ACTIONS:
		var btn := key_list.get_node(BUTTON_NAMES[action]) as Button
		var key_event := _first_key(action)
		if key_event == null:
			btn.text = "未设置"
		else:
			btn.text = OS.get_keycode_string(key_event.physical_keycode)

func _first_key(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null:
			return key_event
	return null
