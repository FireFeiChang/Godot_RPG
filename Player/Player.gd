extends CharacterBody2D

const PlayerHurtSoundScene = preload("res://Player/player_hurt_sound.tscn")
const ACCELERATION = 500
const FRICTION = 500
const MAX_SPEED = 100
const ROLL_SPEED = 125
const INVINCIBLIITY_DURATION = 0.6

enum {
	MOVE,
	ROLL,
	ATTACK
}

var moving_state = MOVE
var roll_vector = Vector2.DOWN
var state = PlayerStates
var dialog = Dialog

@onready var animationPlayer = $AnimationPlayer
@onready var animationTree = $AnimationTree
@onready var animationState = animationTree.get("parameters/playback")
# @onready var swordHitBox = $HitBoxPivot/SwordHitBox
@onready var hurtBox = $HurtBox
@onready var blinkAnimationPlayer = $BlinkAnimationPlayer

func _ready():
	randomize()
	state.connect("no_health", queue_free)
	animationTree.active = true
	TaskManager.ensure_default_tasks()
	# 每次进入世界都是一次全新开局：重置血/背包/任务，不继承上一局
	_reset_new_game()

## 新开局重置（覆盖标题开始与编辑器直接运行两种路径）。
func _reset_new_game():
	state.health = state.max_health
	for slot in Inventory.inv.slots:
		slot.item = null
		slot.amount = 0
	Inventory.inv.update.emit()
	TaskManager.reset_all_tasks()

func _physics_process(delta):
	# 对话中（Dialog.freeze_player）：停住角色、不再响应移动/攻击/翻滚输入
	if dialog.freeze_player == true:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		if moving_state == MOVE:
			animationState.travel("Idle")
		return

	match moving_state:
		MOVE:
			move_state(delta)
		ROLL:
			roll_state(delta)
		ATTACK:
			attack_state(delta)

	if dialog.del_player == true:
		queue_free()

func move_state(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_d") - Input.get_action_strength("move_a")
	input_vector.y = Input.get_action_strength("move_s") - Input.get_action_strength("move_w")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		roll_vector = input_vector
		# swordHitBox.knockback_vector = input_vector
		animationTree.set("parameters/Idle/blend_position", input_vector)
		animationTree.set("parameters/Run/blend_position", input_vector)
		animationTree.set("parameters/Attack/blend_position", input_vector)
		animationTree.set("parameters/Roll/blend_position", input_vector)
		animationState.travel("Run")
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	else:
		animationState.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	
	if Input.is_action_just_pressed("roll"):
		moving_state = ROLL
		
	if Input.is_action_just_pressed("attack"):
		moving_state = ATTACK
		

func roll_state(delta):
	velocity = roll_vector * ROLL_SPEED
	animationState.travel("Roll")
	move_and_slide()

func attack_state(delta):
	velocity = Vector2.ZERO
	animationState.travel("Attack")
	
	
func roll_animation_finished():
	velocity = Vector2.ZERO
	moving_state = MOVE

func attack_animation_finished():
	moving_state = MOVE

func _on_hurt_box_area_entered(area):
	if area.get_script().resource_path.find("hit_box") == -1:
		return
	hurtBox.start_invincibility(INVINCIBLIITY_DURATION)
	hurtBox.create_hit_effect()
	var playHurtSound = PlayerHurtSoundScene.instantiate()
	get_tree().current_scene.add_child(playHurtSound)
	state.health -= area.damage
	velocity = (global_position - area.global_position).normalized() * area.knockback_strength
	
func _on_hurt_box_invincible_started():
	blinkAnimationPlayer.play("Start")
	
func _on_hurt_box_invincible_ended():
	blinkAnimationPlayer.play("Stop")
	
func player():
	pass
	
func collect(item):
	Inventory.inv.insert(item)
