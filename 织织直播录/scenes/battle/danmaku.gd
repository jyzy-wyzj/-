extends Area2D

enum Kind { BLACK, RED, GREEN }

const BLACK_TEXTS: Array[String] = ["哈哈哈哈", "主播菜", "就这?", "绷不住了", "路过", "打卡", "前排放个眼", "笑死"]
const RED_TEXTS: Array[String] = ["垃圾主播", "退钱!", "真菜", "别播了", "恶心", "举报了"]
const GREEN_TEXTS: Array[String] = ["主播加油", "好耶", "爱你", "打赏一个", "冲冲冲", "支持"]

@export var speed: float = 200.0
@export var damage: float = 10.0
@export var heal_amount: float = 8.0

var kind: int = Kind.BLACK
var direction: Vector2 = Vector2.RIGHT

var _traveled: float = 0.0
var _hit_player: bool = false

@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_kind()

func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= 2000.0:
		queue_free()

func _apply_kind() -> void:
	match kind:
		Kind.RED:
			label.text = RED_TEXTS[randi() % RED_TEXTS.size()]
			label.modulate = Color(1.0, 0.35, 0.35)
		Kind.GREEN:
			label.text = GREEN_TEXTS[randi() % GREEN_TEXTS.size()]
			label.modulate = Color(0.4, 1.0, 0.5)
		_:
			label.text = BLACK_TEXTS[randi() % BLACK_TEXTS.size()]
			label.modulate = Color(0.85, 0.85, 0.85)
	var s := label.get_combined_minimum_size()
	label.size = s
	label.position = -s * 0.5
	var rect: RectangleShape2D = $CollisionShape2D.shape
	rect.size = s

func _on_body_entered(body: Node2D) -> void:
	if _hit_player or not body.is_in_group("player"):
		return
	_hit_player = true
	match kind:
		Kind.RED:
			body.take_damage(damage)
		Kind.GREEN:
			body.heal(heal_amount)
