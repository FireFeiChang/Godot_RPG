extends KinematicActor
## 宝箱怪（Mimic）：伪装成宝箱静止，玩家靠近才苏醒追击攻击。
## DISGUISE/IDLE/WANDER/CHASE/ATTACK 状态机；接触伤害由常驻 HitBox 提供；
## 死亡播完 Death 动画后爆炸 + 掉落 + 销毁。

const EnemyDeathEffect = preload("res://Effects/enemy_death_effect.tscn")
const KNOCK_BACK = 120
const WANDER_TIMER_DURATION = 3
const INVINCIBLIITY_DURATION = 0.35
const ATTACK_RANGE = 22.0
const ATTACK_DURATION = 0.6
const ATTACK_COOLDOWN = 0.9

@export var item: InvItem
@export var drop_chance: float = 0.5
@export var WANDER_TARGET_RANGE = 6

enum {
	DISGUISE,
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
}

var moving_state = DISGUISE
var player = null
var dead := false
var disguised := true
var attack_timer := 0.0
var cooldown_timer := 0.0

@onready var animatedSprite = $AnimatedSprite
@onready var state = $States
@onready var playerDetection = $PlayerDetection
@onready var hurtBox = $HurtBox
@onready var hitBox = $HitBox
@onready var bodyCollision = $CollisionShape2D
@onready var softCollision = $SoftCollison
@onready var wanderController = $WanderController
@onready var animationPlayer = $AnimationPlayer
@onready var particles = $GPUParticles2D

func _ready():
	moving_state = DISGUISE
	animatedSprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	if dead:
		return
	if disguised:
		animatedSprite.play("Disguise")
		_seek_player()
		move_and_slide()
		return
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
		CHASE:
			_play("Walk")
			if player != null and is_instance_valid(player):
				var dist = global_position.distance_to(player.global_position)
				if dist <= ATTACK_RANGE and cooldown_timer <= 0.0:
					moving_state = ATTACK
					attack_timer = 0.0
				else:
					accelerate_towards_point(player.global_position, delta)
					_flip_to_velocity()
					cooldown_timer = maxf(0.0, cooldown_timer - delta)
			else:
				apply_friction(delta)
				_flip_to_velocity()
				cooldown_timer = maxf(0.0, cooldown_timer - delta)
		ATTACK:
			_play("Attack")
			apply_friction(delta)
			if player != null and is_instance_valid(player):
				_face_toward(player.global_position)
			attack_timer += delta
			if attack_timer >= ATTACK_DURATION:
				attack_timer = 0.0
				cooldown_timer = 0.0
				moving_state = CHASE
			move_and_slide()
			return
	if softCollision.is_colliding():
		velocity += softCollision.get_push_vector() * delta * KNOCK_BACK
	move_and_slide()

func accelerate_towards_point(point: Vector2, delta: float) -> void:
	super(point, delta)

func _flip_to_velocity() -> void:
	if absf(velocity.x) > 5.0:
		animatedSprite.flip_h = velocity.x < 0

func _face_toward(point: Vector2) -> void:
	animatedSprite.flip_h = point.x < global_position.x

func _play(anim: String) -> void:
	if animatedSprite.animation != anim:
		animatedSprite.play(anim)

func _seek_player():
	player = playerDetection.can_see_player()
	if player != null:
		if disguised:
			disguised = false
		moving_state = CHASE

func update_wander():
	moving_state = pick_random_state([IDLE, WANDER])
	wanderController.start_wander_timer(randi_range(1, WANDER_TIMER_DURATION))

func _on_hurt_box_area_entered(area):
	if area.get_script().resource_path.find("hit_box") == -1:
		return
	if dead:
		return
	particles.emitting = true
	velocity = (area.global_position - global_position).normalized() * area.knockback_strength
	hurtBox.create_hit_effect()
	hurtBox.start_invincibility(INVINCIBLIITY_DURATION)
	state.health -= area.damage

func _on_states_no_health():
	dead = true
	velocity = Vector2.ZERO
	hurtBox.set_deferred("monitoring", false)
	hitBox.set_deferred("monitoring", false)
	hitBox.set_deferred("monitorable", false)
	bodyCollision.set_deferred("disabled", true)
	animatedSprite.play("Death")

func _on_animation_finished():
	if animatedSprite.animation == "Death":
		_die()

func _die():
	create_enemy_death_effect()
	if item != null and randf() < drop_chance:
		TaskManager.call_deferred("spawn_drop_item", global_position, item)
	Wallet.call_deferred("spawn_coin_drop", global_position, randi_range(3, 6))
	queue_free()

func create_enemy_death_effect():
	var fx = EnemyDeathEffect.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position

func _on_hurt_box_invincible_started():
	animationPlayer.play("start")

func _on_hurt_box_invincible_ended():
	animationPlayer.play("stop")

func pick_random_state(state_list):
	return state_list.pick_random()
