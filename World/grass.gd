extends Node2D

const grassEffectScene = preload("res://Effects/grass_effect.tscn")

@export var item: InvItem
var player = null

func create_grass_effect():
	var grassEffectInstance = grassEffectScene.instantiate()
	get_parent().add_child(grassEffectInstance)
	grassEffectInstance.global_position = global_position

func _on_hurt_box_area_entered(area):
	# 玩家必须仍在草丛侦测范围内且未被释放（玩家死亡等情况）
	if player == null or not is_instance_valid(player):
		return
	create_grass_effect()
	queue_free()
	player.collect(item)


func _on_area_2d_body_entered(body):
	if body.has_method("player"):
		player = body


func _on_area_2d_body_exited(body):
	if body.has_method("player"):
		player = null
