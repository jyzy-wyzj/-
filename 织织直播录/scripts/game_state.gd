extends Node

const SAVE_PATH := "user://save.cfg"
const SAVE_DIR := "user://saves"

var day: int = 1
var total_fans: int = 1000

func _ready() -> void:
	load_game()

func add_fans(amount: int) -> void:
	total_fans += amount

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "day", day)
	cfg.set_value("progress", "total_fans", total_fans)
	cfg.save(SAVE_PATH)

func load_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	day = int(cfg.get_value("progress", "day", 1))
	total_fans = int(cfg.get_value("progress", "total_fans", 1000))
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_slot(index: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "day", day)
	cfg.set_value("progress", "total_fans", total_fans)
	cfg.set_value("meta", "time", _now_text())
	cfg.save(_slot_path(index))

func load_slot(index: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(index)) != OK:
		return false
	day = int(cfg.get_value("progress", "day", 1))
	total_fans = int(cfg.get_value("progress", "total_fans", 1000))
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
