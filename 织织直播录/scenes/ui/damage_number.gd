class_name DamageNumber
extends Label

enum Type { FIRE, WATER, LIGHT, GUN, DRONE, DARK, PLAYER_HURT, HEAL }

const COLORS: Dictionary = {
	Type.FIRE: Color(1.0, 0.25, 0.15),
	Type.WATER: Color(0.3, 0.6, 1.0),
	Type.LIGHT: Color(1.0, 0.85, 0.25),
	Type.GUN: Color(0.85, 0.62, 0.15),
	Type.DRONE: Color(0.25, 0.95, 0.95),
	Type.DARK: Color(0.7, 0.08, 0.18),
	Type.PLAYER_HURT: Color(0.62, 0.06, 0.06),
	Type.HEAL: Color(0.2, 0.95, 0.35),
}

func setup(amount: float, type: int) -> void:
	var color: Color = COLORS.get(type, Color.WHITE)
	add_theme_color_override("font_color", color)
	var value := int(round(amount))
	if value <= 0:
		value = 1
	text = str(value)
	if type == Type.PLAYER_HURT:
		text = "-" + text
	elif type == Type.HEAL or type == Type.LIGHT:
		text = "+" + text
	position.x += randf_range(-14.0, 14.0)

func _ready() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 46.0, 0.7)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(queue_free)
