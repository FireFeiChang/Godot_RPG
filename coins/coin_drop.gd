extends Area2D
## 金币拾取物：从敌人身上掉落后原地旋转、轻微浮动；玩家接触即入钱包。
## 长时间无人捡会淡出消失，避免地面堆积太多。

@export var amount: int = 1

const LIFETIME := 30.0
const FLOAT_HEIGHT := 1.5   # 浮动幅度(px)
const FLOAT_SPEED := 3.5    # 浮动频率

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## 金币视觉整体比例（场景里 AnimatedSprite2D.scale=0.75；这里只做"落地压扁/回弹"的相对形变）
const SPRITE_SCALE := Vector2(0.75, 0.75)

var _age := 0.0
var _collected := false

func _ready():
	sprite.play("spin")
	# 落地小弹跳反馈：先压扁再回弹（相对当前 0.75 缩放）
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.75 * 1.2, 0.75 * 0.6), 0.06)
	tw.tween_property(sprite, "scale", SPRITE_SCALE, 0.14)

func _process(delta):
	_age += delta
	if _age >= LIFETIME:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.4)
		fade.tween_callback(queue_free)
		set_process(false)
		return
	sprite.position.y = sin(_age * FLOAT_SPEED) * FLOAT_HEIGHT

func _on_body_entered(body):
	if _collected:
		return
	if body.has_method("player"):
		_collected = true
		Wallet.add_gold(amount)
		queue_free()
