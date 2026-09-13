extends CharacterBody2D

const PlayerHurtSoundScene = preload("res://Player/player_hurt_sound.tscn")
const SwingEffectScene = preload("res://Effects/swing_effect.tscn")
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
var _sword_armed := false
var state = PlayerStates
var dialog = Dialog

@onready var animationPlayer = $AnimationPlayer
@onready var animationTree = $AnimationTree
@onready var animationState = animationTree.get("parameters/playback")
@onready var swordHitBox = $HitBoxPivot/SwordHitBox
@onready var hurtBox = $HurtBox
@onready var blinkAnimationPlayer = $BlinkAnimationPlayer

func _ready():
	randomize()
	state.connect("no_health", queue_free)
	animationTree.active = true
	TaskManager.ensure_default_tasks()
	# 只有"本局第一次进入地图"才重置。
	# 地图之间来回切换时必须保留血/背包/金币/任务，否则换图等于清档。
	if MapManager.consume_fresh_start():
		_reset_new_game()

## 换图后由 MapManager 调用：清速度、回到 MOVE 态、收刀，
## 避免上一张地图残留的硬直/攻击状态带过来。
func reset_for_teleport():
	velocity = Vector2.ZERO
	moving_state = MOVE
	_sword_armed = false
	if is_instance_valid(swordHitBox):
		_sword_shape().disabled = true

## 新开局重置（覆盖主菜单开始与编辑器直接运行两种路径）。
func _reset_new_game():
	state.health = state.max_health
	for slot in Inventory.inv.slots:
		slot.item = null
		slot.amount = 0
	Inventory.inv.update.emit()
	Wallet.reset()
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
		

func roll_state(_delta):
	velocity = roll_vector * ROLL_SPEED
	animationState.travel("Roll")
	move_and_slide()

func attack_state(_delta):
	velocity = Vector2.ZERO
	# 只有真正进入一次挥刀时才启用剑判定盒 + 挥砍刀光
	if not _sword_armed:
		_sword_armed = true
		_spawn_swing_effect()
		var tw := get_tree().create_timer(0.1)
		tw.timeout.connect(_enable_sword)
	animationState.travel("Attack")


func roll_animation_finished():
	velocity = Vector2.ZERO
	moving_state = MOVE

func attack_animation_finished():
	_sword_armed = false
	_sword_shape().disabled = true  # 收招：关闭剑判定盒，避免平时误伤
	moving_state = MOVE

## 挥刀中：短暂开启剑判定盒，命中由 HurtBox 检测。
func _enable_sword():
	if moving_state == ATTACK and is_instance_valid(swordHitBox):
		_sword_shape().disabled = false

func _sword_shape() -> CollisionShape2D:
	return swordHitBox.get_node("CollisionShape2D")

## 播放挥砍刀光：以玩家为中心、朝攻击朝向偏移少许并旋转，播完自动销毁。
func _spawn_swing_effect():
	var fx: AnimatedSprite2D = SwingEffectScene.instantiate()
	get_tree().current_scene.add_child(fx)
	# 刀光随攻击朝向（roll_vector 记录最近一次移动/默认朝下）定位与旋转
	var dir := roll_vector.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	fx.global_position = global_position + dir * 10.0
	# 朝左（纯左右，y 很小）时：旋转 180° 会把“从上往下挥”的刀光
	# 颠倒成“从下往上”，所以改用水平镜像（只左右对调、上下不变）。
	# 斜向仍走 angle 旋转（用户未报斜向问题，避免误伤）。
	if dir.x < -0.9 and absf(dir.y) < 0.45:
		fx.flip_h = true
	else:
		fx.rotation = dir.angle()

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
	# 广播采集事件，供任务系统累计（如"采集止血草 x10"）。
	# 用 item.id 而不是物品引用：任务只关心"采的是哪种"。
	if item != null:
		TaskManager.notify_progress("collect:" + String(item.id))
