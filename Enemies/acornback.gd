extends KinematicActor
## 橡子甲虫怪（Acornback_Rollbeast）：地面系敌人，结构完全镜像 bat。
## 平时 IDLE/WANDER 缓慢爬行；发现玩家进入 ROLL 状态——卷成球高速滚向玩家撞击。
## 接触伤害由常驻 HitBox 提供（玩家 HurtBox 有 i-frame，不会连续扣血）。
## 侧视生物：用 flip_h 朝玩家左右转向；受击/无敌白闪复用 Blink AnimationPlayer。

const EnemyDeathEffect = preload("res://Effects/enemy_death_effect.tscn")
const KNOCK_BACK = 120
const WANDER_TIMER_DURATION = 3
const INVINCIBLIITY_DURATION = 0.35

@export var item: InvItem
@export var drop_chance: float = 0.5
@export var WANDER_TARGET_RANGE = 6

enum {
	IDLE,
	WANDER,
	ROLL,
}

var moving_state = ROLL
var player = null
var roll_clock := 0.0

# ROLL 状态下的滚球冲刺时长（到时自动慢下来回 WANDER，避免无限追）
const ROLL_BURST := 2.0

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
			_play("Idle")
			apply_friction(delta)
			_seek_player()
			if wanderController.get_time_left() == 0:
				update_wander()
		WANDER:
			_play("Walk")
			_seek_player()
			if wanderController.get_time_left() == 0:
				update_wander()
			if wanderController.target_positon != null:
				accelerate_towards_point(wanderController.target_positon, delta)
				_flip_to_velocity()
				if global_position.distance_to(wanderController.target_positon) <= WANDER_TARGET_RANGE:
					update_wander()
		ROLL:
			_play("Roll_Attack")
			roll_clock -= delta
			if player != null and is_instance_valid(player):
				accelerate_towards_point(player.global_position, delta)
			else:
				apply_friction(delta)
			_flip_to_velocity()
			if roll_clock <= 0.0:
				moving_state = pick_random_state([IDLE, WANDER])

	if softCollision.is_colliding():
		velocity += softCollision.get_push_vector() * delta * KNOCK_BACK
	move_and_slide()

func accelerate_towards_point(point: Vector2, delta: float) -> void:
	# 基类负责实际移动
	super(point, delta)

func _flip_to_velocity() -> void:
	if absf(velocity.x) > 5.0:
		animatedSprite.flip_h = velocity.x < 0

func _play(anim: String) -> void:
	if animatedSprite.animation != anim:
		animatedSprite.play(anim)

func _seek_player():
	player = playerDetection.can_see_player()
	if player != null:
		_start_roll()

func _start_roll():
	if moving_state == ROLL:
		return
	moving_state = ROLL
	roll_clock = ROLL_BURST

func update_wander():
	moving_state = pick_random_state([IDLE, WANDER])
	wanderController.start_wander_timer(randi_range(1, WANDER_TIMER_DURATION))

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
	Wallet.call_deferred("spawn_coin_drop", global_position, randi_range(2, 5))
	queue_free()

func create_enemy_death_effect():
	var enemyDeathEffectInstance = EnemyDeathEffect.instantiate()
	get_parent().add_child(enemyDeathEffectInstance)
	enemyDeathEffectInstance.global_position = global_position

func _on_hurt_box_invincible_started():
	animationPlayer.play("start")

func _on_hurt_box_invincible_ended():
	animationPlayer.play("stop")

func pick_random_state(state_list):
	return state_list.pick_random()
