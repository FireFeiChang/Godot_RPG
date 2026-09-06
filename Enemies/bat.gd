extends KinematicActor
## 蝙蝠敌人：在 KinematicActor 基础上实现 IDLE/WANDER/CHASE 行为状态机。
## 加速度/摩擦/最高速度等移动参数继承自基类，可在场景根节点上覆盖（见 bat.tscn FRICTION）。

const EnemyDeathEffect = preload("res://Effects/enemy_death_effect.tscn")
const DropItemScene = preload("res://drop_item.tscn")
const KNOCK_BACK = 80
const WANDER_TIMER_DURATION = 3
const INVINCIBLIITY_DURATION = 0.4

@export var WANDER_TARGET_RANGE = 5
@export var item: InvItem
@export var drop_chance: float = 0.5

enum {
	IDLE,
	WANDER,
	CHASE,
}

var moving_state = CHASE
var player = null

@onready var animatedSprite = $AnimatedSprite
@onready var state = $States
@onready var playerDetection = $PlayerDetection
@onready var hurtBox = $HurtBox
@onready var softCollision = $SoftCollison
@onready var wanderController = $WanderController
@onready var animationPlayer = $AnimationPlayer
@onready var particles = $GPUParticles2D

func _ready():
	moving_state = pick_random_state([IDLE, WANDER])

func _physics_process(delta):
	match moving_state:
		IDLE:
			apply_friction(delta)
			seek_player()
			if wanderController.get_time_left() == 0:
				update_wander()
				
		WANDER:
			seek_player()
			if wanderController.get_time_left() == 0:
				update_wander()
			if wanderController.target_positon != null:
				accelerate_towards_point(wanderController.target_positon, delta)
				if global_position.distance_to(wanderController.target_positon) <= WANDER_TARGET_RANGE:
					update_wander()
			
		CHASE:
			var player = playerDetection.player
			if player != null:
				accelerate_towards_point(player.global_position, delta)
			else:
				moving_state = IDLE
	
	if softCollision.is_colliding():
		velocity += softCollision.get_push_vector() * delta * KNOCK_BACK
	move_and_slide()
	
func accelerate_towards_point(point: Vector2, delta: float) -> void:
	# 基类处理实际移动，蝙蝠额外按移动方向翻转精灵
	super(point, delta)
	animatedSprite.flip_h = velocity.x < 0
	
func update_wander():
	moving_state = pick_random_state([IDLE, WANDER])
	wanderController.start_wander_timer(randi_range(1, WANDER_TIMER_DURATION))
	
func create_enemy_death_effect():
	var enemyDeathEffectInstance = EnemyDeathEffect.instantiate()
	get_parent().add_child(enemyDeathEffectInstance)
	enemyDeathEffectInstance.global_position = global_position
	
func seek_player():
	player = playerDetection.can_see_player()
	if player != null:
		moving_state = CHASE

func pick_random_state(state_list):
	return state_list.pick_random()

func _on_hurt_box_area_entered(area):
	if area.get_script().resource_path.find("hit_box") == -1:
		return
	particles.emitting = true
	velocity = (area.global_position - global_position).normalized() * area.knockback_strength
	hurtBox.create_hit_effect()
	hurtBox.start_invincibility(INVINCIBLIITY_DURATION)
	state.health -= area.damage


func _on_states_no_health():
	create_enemy_death_effect()
	if item != null and randf() < drop_chance:
		TaskManager.call_deferred("spawn_drop_item", global_position, item)
	Wallet.call_deferred("spawn_coin_drop", global_position, randi_range(1, 3))
	TaskManager.notify_enemy_killed(TaskManager.TASK_KILL_BATS)
	queue_free()

func _on_hurt_box_invincible_started():
	animationPlayer.play("start")

func _on_hurt_box_invincible_ended():
	animationPlayer.play("stop")
