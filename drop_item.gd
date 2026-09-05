extends Area2D

@export var item: InvItem
@export var amount: int = 1

@onready var sprite = $Sprite2D

func _ready():
	sprite.texture = item.texture

func _on_body_entered(body):
	if body.has_method("collect"):
		for i in range(amount):
			body.collect(item)
		queue_free()
