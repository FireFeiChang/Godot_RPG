extends StaticBody2D
## 篝火：可攻击切换状态的交互物，结构完全镜像敌人（bat）。
## 玩家挥剑攻击切换燃烧/熄灭状态。

const CampfireEffectScene = preload("res://Effects/grass_effect.tscn")

@export var hits_to_extinguish := 3
@export var hits_to_ignite := 3

@onready var animatedSprite = $AnimatedSprite
@onready var state = $States
@onready var hurtBox = $HurtBox
@onready var playerDetection = $PlayerDetection
@onready var light: PointLight2D = $PointLight2D

enum {
	BURNING,
	EXTINGUISHED,
}

var state_machine = BURNING
var hit_count := 0
var player = null

func _ready():
	animatedSprite.play("Burning")

func _on_hurt_box_area_entered(area):
	if area.get_script().resource_path.find("hit_box") == -1:
		return
	if player == null or not is_instance_valid(player):
		return

	hit_count += 1
	_spawn_effect()

	if state_machine == BURNING and hit_count >= hits_to_extinguish:
		state_machine = EXTINGUISHED
		hit_count = 0
		light.enabled = false
		animatedSprite.play("Extinguished")
	elif state_machine == EXTINGUISHED and hit_count >= hits_to_ignite:
		state_machine = BURNING
		hit_count = 0
		light.enabled = true
		animatedSprite.play("Burning")

func _spawn_effect():
	var fx = CampfireEffectScene.instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position

func _on_player_detection_body_entered(body):
	if body.has_method("player"):
		player = body

func _on_player_detection_body_exited(body):
	if body.has_method("player"):
		player = null
