extends KinematicActor
## 通用地面敌人（mob）：哥布林 / 宝箱怪 / 史莱姆 共用。
## 运行时从 @export 的 sheet 横条图按 cell_w 切帧建 SpriteFrames；
## 状态机 IDLE/WANDER/CHASE；接触伤害由常驻 HitBox 提供；
## 死亡播完 Death 动画后爆炸 + 掉落 + 销毁。
## mimic 若有 disguise_sheet，平时伪装成物件静止，玩家靠近才苏醒追击。

const EnemyDeathEffect = preload("res://Effects/enemy_death_effect.tscn")

@export_group("Sprite Sheets (64px cell strips)")
@export var sheet_idle: Texture2D
@export var sheet_walk: Texture2D
@export var sheet_attack: Texture2D
@export var sheet_death: Texture2D
@export var sheet_hurt: Texture2D
@export var disguise_sheet: Texture2D   # 仅 mimic：伪装姿态横条

@export_group("Frame Counts (per sheet)")
@export var frames_idle: int = 4
@export var frames_walk: int = 4
@export var frames_attack: int = 3
@export var frames_death: int = 8
@export var frames_hurt: int = 3
@export var frames_disguise: int = 3

@export_group("Anim Speeds")
@export var speed_idle: float = 4.0
@export var speed_walk: float = 8.0
@export var speed_attack: float = 10.0
@export var speed_death: float = 8.0
@export var speed_hurt: float = 8.0
@export var speed_disguise: float = 4.0

@export_group("AI")
@export var detection_radius: float = 46.0
@export var wander_target_range: int = 6
@export var wander_timer_duration: int = 3
@export var knockback: float = 100.0
@export var invincibility_duration: float = 0.35

@export_group("Drops")
@export var drop_item: InvItem
@export var drop_chance: float = 0.5
@export var coin_min: int = 1
@export var coin_max: int = 3

enum {
	IDLE,
	WANDER,
	CHASE,
}

var moving_state = CHASE
var player = null
var dead := false
var disguised := false

var current_anim := ""   # 追踪当前动画名，防每帧重置

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var states = $States
@onready var player_detection: Area2D = $PlayerDetection
@onready var hurt_box: Area2D = $HurtBox
@onready var hit_box: Area2D = $HitBox
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var soft_collision = $SoftCollison
@onready var wander_controller = $WanderController
@onready var particles: GPUParticles2D = $GPUParticles2D

func _ready():
	animated_sprite.animation_finished.connect(_on_animation_finished)
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	states.no_health.connect(_on_states_no_health)
	hurt_box.get_node("Timer").timeout.connect(hurt_box._on_timer_timeout)
	player_detection.body_entered.connect(player_detection._on_body_entered)
	player_detection.body_exited.connect(player_detection._on_body_exited)
	# 按 sheet 建 SpriteFrames
	_build_sprite_frames()
	if disguise_sheet != null:
		disguised = true
		moving_state = IDLE
	else:
		moving_state = pick_random_state([IDLE, WANDER])
	animated_sprite.play(_anim_name())

func _build_sprite_frames():
	# 若子场景已在编辑器里填了 sheet 导出属性则用之，否则按场景同名约定自动定位
	if sheet_idle == null:
		_auto_locate_sheets()
	var frames := SpriteFrames.new()
	_add_strip(frames, "Idle", sheet_idle, frames_idle, speed_idle, true)
	_add_strip(frames, "Walk", sheet_walk, frames_walk, speed_walk, true)
	_add_strip(frames, "Attack", sheet_attack, frames_attack, speed_attack, true)
	_add_strip(frames, "Death", sheet_death, frames_death, speed_death, false)
	if sheet_hurt != null:
		_add_strip(frames, "Hurt", sheet_hurt, frames_hurt, speed_hurt, true)
	if disguise_sheet != null:
		_add_strip(frames, "Disguise", disguise_sheet, frames_disguise, speed_disguise, true)
	animated_sprite.sprite_frames = frames

## 按场景名在 Enemies/mobs/<name>/ 下按命名约定自动加载 sheet
func _auto_locate_sheets():
	var base := "res://Enemies/mobs/" + scene_file_path.get_file().get_basename().to_lower() + "/"
	var lower: String = scene_file_path.get_file().get_basename().to_lower()
	sheet_idle = _try_load(base, "idle.png")
	if sheet_idle == null:
		sheet_idle = _try_load(base, lower + " idle.png")
	sheet_walk = _try_load(base, "walk.png")
	if sheet_walk == null:
		sheet_walk = _try_load(base, lower + " walking.png")
	sheet_attack = _try_load(base, "atak.png")
	if sheet_attack == null:
		sheet_attack = _try_load(base, "attack.png")
	sheet_death = _try_load(base, "death.png")
	if sheet_death == null:
		sheet_death = _try_load(base, lower + " death.png")
	sheet_hurt = _try_load(base, "hit.png")
	# mimic 伪装
	disguise_sheet = _try_load(base, lower + " disguise.png")

func _try_load(base: String, fname: String) -> Texture2D:
	var path: String = base + fname
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _add_strip(frames: SpriteFrames, name: String, strip: Texture2D, count: int, fps: int, loop: bool):
	if strip == null or count <= 0:
		return
	frames.add_animation(name)
	var cell_w: int = strip.get_width() / count
	var cell_h: int = strip.get_height()
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * cell_w, 0, cell_w, cell_h)
		frames.add_frame(name, atlas, 1.0)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, fps)

func _physics_process(delta):
	if dead:
		return
	if disguised:
		# 伪装中：静止，检测玩家靠近则苏醒
		animated_sprite.play("Disguise")
		apply_friction(delta)
		move_and_slide()
		_seek_player()
		return
	match moving_state:
		IDLE:
			_play("Idle")
			apply_friction(delta)
			_seek_player()
			if wander_controller.get_time_left() == 0:
				update_wander()
		WANDER:
			_play("Walk")
			_seek_player()
			if wander_controller.get_time_left() == 0:
				update_wander()
			if wander_controller.target_positon != null:
				accelerate_towards_point(wander_controller.target_positon, delta)
				_flip_to_velocity()
				if global_position.distance_to(wander_controller.target_positon) <= wander_target_range:
					update_wander()
		CHASE:
			_play("Walk")
			if player != null and is_instance_valid(player):
				accelerate_towards_point(player.global_position, delta)
				_flip_to_velocity()
			else:
				player = null
				moving_state = pick_random_state([IDLE, WANDER])
	if soft_collision.is_colliding():
		velocity += soft_collision.get_push_vector() * delta * knockback
	move_and_slide()

func _flip_to_velocity() -> void:
	if absf(velocity.x) > 5.0:
		animated_sprite.flip_h = velocity.x < 0

func _play(anim: String) -> void:
	if current_anim != anim:
		current_anim = anim
		animated_sprite.play(anim)

func _anim_name() -> String:
	if disguised:
		return "Disguise"
	match moving_state:
		IDLE: return "Idle"
		WANDER, CHASE: return "Walk"
		_: return "Idle"

func _seek_player():
	player = player_detection.can_see_player()
	if player != null:
		if disguised:
			disguised = false   # 苏醒
		moving_state = CHASE

func update_wander():
	moving_state = pick_random_state([IDLE, WANDER])
	wander_controller.start_wander_timer(randi_range(1, wander_timer_duration))

func _on_hurt_box_area_entered(area):
	if area.get_script().resource_path.find("hit_box") == -1:
		return
	if dead:
		return
	particles.emitting = true
	velocity = (area.global_position - global_position).normalized() * area.knockback_strength
	hurt_box.create_hit_effect()
	hurt_box.start_invincibility(invincibility_duration)
	states.health -= area.damage

func _on_states_no_health():
	dead = true
	velocity = Vector2.ZERO
	hurt_box.set_deferred("monitoring", false)
	hit_box.set_deferred("monitoring", false)
	hit_box.set_deferred("monitorable", false)
	body_collision.set_deferred("disabled", true)
	animated_sprite.play("Death")

func _on_animation_finished():
	if animated_sprite.animation == "Death":
		_die()

func _die():
	create_enemy_death_effect()
	if drop_item != null and randf() < drop_chance:
		TaskManager.call_deferred("spawn_drop_item", global_position, drop_item)
	Wallet.call_deferred("spawn_coin_drop", global_position, randi_range(coin_min, coin_max))
	queue_free()

func create_enemy_death_effect():
	var fx = EnemyDeathEffect.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position

func pick_random_state(state_list):
	return state_list.pick_random()
