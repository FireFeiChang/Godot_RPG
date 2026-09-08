extends KinematicActor
## 女性冒险者 NPC：6 方向动画（Down/Up/Left_Down/Left_Up/Right_Down/Right_Up）。
## 根据速度角度决定朝向，播放对应方向的 Idle/Walk 动画。
## 内置 Timer 驱动随机游走；玩家靠近 SpeakBox 按 Enter 对话。

@export var dialogue_path: String = "res://NPC/Test.dialogue"
@export var start_title: String = "hello"
@export var task_id: String = ""

const RETRY_COOLDOWN := 0.5
const WANDER_TARGET_RANGE = 6
const WANDER_TIMER_DURATION = 3
const WANDER_RANGE = 32
const MOVE_THRESHOLD := 5.0        # 速度低于此值视为静止

enum { IDLE, WANDER }

var moving_state = IDLE
var can_start := true
var cooldown := 0.0
var freeze_owned := false
var dialogue_resource = null
var balloon: CanvasLayer = null
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var facing := "Down"               # 当前朝向（6 方向之一）

@onready var animatedSprite = $AnimatedSprite
@onready var speak_box: Area2D = $SpeakBox
@onready var prompt: Label = $Prompt
@onready var wander_timer: Timer = $WanderTimer

func _ready():
	if dialogue_path != "":
		dialogue_resource = load(dialogue_path)
	if dialogue_resource == null:
		push_warning("FemaleAdventurer：对话资源加载失败：%s" % dialogue_path)
	prompt.visible = false
	start_position = global_position
	target_position = global_position
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	_update_wander_target()

func _process(delta):
	if cooldown > 0.0:
		cooldown -= delta
	_consume_task_requests()
	var player_near := speak_box.get_overlapping_bodies().size() > 0
	prompt.visible = player_near and can_start and balloon == null
	if player_near and can_start and balloon == null and cooldown <= 0.0 \
			and Input.is_action_just_pressed("ui_accept"):
		start_dialogue()

func _physics_process(delta):
	if balloon != null:
		velocity = Vector2.ZERO
		_play("Idle", true)
		return
	match moving_state:
		IDLE:
			_play("Idle", false)
			apply_friction(delta)
			if wander_timer.get_time_left() == 0.0:
				_update_wander()
		WANDER:
			if wander_timer.get_time_left() == 0.0:
				_update_wander()
			if target_position != global_position:
				accelerate_towards_point(target_position, delta)
				_update_facing_from_velocity()
				_play("walk", false)
				if global_position.distance_to(target_position) <= WANDER_TARGET_RANGE:
					_update_wander()
			else:
				_play("Idle", false)
				apply_friction(delta)
	move_and_slide()

## 根据速度向量更新朝向（仅在速度超过阈值时更新，避免静止时乱转）
func _update_facing_from_velocity() -> void:
	if velocity.length() < MOVE_THRESHOLD:
		return
	var deg = fposmod(rad_to_deg(velocity.angle()), 360.0)
	# 6 方向：Right_Down(45°) / Down(90°) / Left_Down(135°) / Left_Up(225°) / Up(270°) / Right_Up(315°)
	# 边界在 67.5 / 112.5 / 180 / 247.5 / 292.5 / 337.5
	if deg < 67.5:
		facing = "Right_Down"
	elif deg < 112.5:
		facing = "Down"
	elif deg < 180.0:
		facing = "Left_Down"
	elif deg < 247.5:
		facing = "Left_Up"
	elif deg < 292.5:
		facing = "Up"
	else:
		facing = "Right_Up"

## 播放指定类型的动画（Idle 或 Walk），自动拼接朝向后缀
## force=true 时强制重新播放（用于对话冻结等需要立即切换的场景）
func _play(anim_type: String, force: bool) -> void:
	var target = "%s_%s" % [anim_type, facing]
	if animatedSprite.animation != target or force:
		animatedSprite.play(target)

func _update_wander() -> void:
	if randf() < 0.5:
		moving_state = IDLE
		target_position = global_position
	else:
		moving_state = WANDER
		var offset = Vector2(randi_range(-WANDER_RANGE, WANDER_RANGE), randi_range(-WANDER_RANGE, WANDER_RANGE))
		target_position = start_position + offset
	wander_timer.start(randi_range(1, WANDER_TIMER_DURATION))

func _update_wander_target() -> void:
	start_position = global_position
	target_position = global_position

func _on_wander_timer_timeout() -> void:
	_update_wander()

func current_title() -> String:
	if task_id == "":
		return start_title
	match TaskManager.get_task_state(task_id):
		Task.NOT_STARTED:
			return "%s_offer" % task_id
		Task.IN_PROGRESS:
			return "%s_in_progress" % task_id
		Task.COMPLETED:
			return "%s_turnin" % task_id
		Task.REWARDED:
			return "%s_rewarded" % task_id
	return "%s_offer" % task_id

func start_dialogue():
	if dialogue_resource == null or balloon != null:
		return
	var title := current_title()
	if task_id != "" and not _has_title(title):
		title = start_title
	can_start = false
	freeze_owned = true
	Dialog.freeze_player = true
	balloon = DialogueManager.show_example_dialogue_balloon(dialogue_resource, title)
	balloon.tree_exited.connect(_on_balloon_closed)

func _has_title(title: String) -> bool:
	return dialogue_resource != null and dialogue_resource.titles.has(title)

func _consume_task_requests():
	if task_id == "":
		return
	if Dialog.task_accept_request == task_id:
		Dialog.task_accept_request = ""
		TaskManager.accept_task(task_id)
	if Dialog.task_turnin_request == task_id:
		Dialog.task_turnin_request = ""
		TaskManager.turn_in_task(task_id)

func _on_balloon_closed():
	balloon = null
	can_start = true
	cooldown = RETRY_COOLDOWN
	prompt.visible = false
	if freeze_owned:
		freeze_owned = false
		Dialog.freeze_player = false

func _exit_tree():
	if freeze_owned:
		freeze_owned = false
		Dialog.freeze_player = false
