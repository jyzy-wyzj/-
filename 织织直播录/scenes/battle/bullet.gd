extends Area2D

@export var speed: float = 520.0
@export var max_distance: float = 900.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var damage_type: int = DamageNumber.Type.FIRE
var _traveled: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		area.take_damage(damage, damage_type)
		queue_free()
