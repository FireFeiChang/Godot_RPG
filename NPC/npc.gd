extends CharacterBody2D
## 可对话 NPC（可扩展基类）。
## 站在 SpeakBox 范围内按 [Enter] 或 [E]（ui_accept / interact）即可对话，头顶显示交互提示。
## 对话期间通过 Dialog.freeze_player 锁定玩家移动，结束/离开后自动解除。
##
## 两种模式：
## - 普通闲聊 NPC：留空 task_id，用 start_title 起始对话。
## - 任务 NPC：给 task_id 赋任务 id（如 "kill_bats"），NPC 会根据该任务实时状态
##   自动选择对话标题：`<task_id>_offer`（未接，可接）、`<task_id>_in_progress`（进行中）、
##   `<task_id>_turnin`（已完成可交付）、`<task_id>_rewarded`（已领奖闲聊）。
##   玩家在对话中选择接取/交付时，.dialogue 内用 `set Dialog.task_accept_request` /
##   `set Dialog.task_turnin_request` 填入任务 id，本脚本每帧消费并执行真正的任务操作。
## 新增 NPC：复制 npc.tscn，改 dialogue_path（与/或 start_title / task_id）即可。

@export var dialogue_path: String = "res://NPC/Test.dialogue"
@export var start_title: String = "hello"
@export var task_id: String = ""

## 对话结束后再次允许开启的冷却，避免连按 Enter 立刻重开。
const RETRY_COOLDOWN := 0.5

@onready var speak_box: Area2D = $SpeakBox
@onready var prompt: Label = $Prompt

var dialogue_resource = null
var balloon: CanvasLayer = null
var can_start := true
var cooldown := 0.0
var freeze_owned := false

func _ready():
	if dialogue_path != "":
		dialogue_resource = load(dialogue_path)
	if dialogue_resource == null:
		push_warning("NPC：对话资源加载失败：%s" % dialogue_path)
	prompt.visible = false

func _process(delta):
	if cooldown > 0.0:
		cooldown -= delta

	_consume_task_requests()

	# SpeakBox 只探测玩家层，因此只要重叠体非空即表示玩家靠近
	var player_near: bool = speak_box.get_overlapping_bodies().size() > 0
	prompt.visible = player_near and can_start and balloon == null

	if player_near and can_start and balloon == null and cooldown <= 0.0 \
			and _interact_pressed():
		start_dialogue()

## 交互键：Enter（ui_accept）或 E（interact）都可发起对话。
func _interact_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept") \
			or Input.is_action_just_pressed("interact")

## 本轮对话要用的起始标题。
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
	# 若任务 NPC 所需的标题不存在则退回闲聊标题，避免空白对话
	if task_id != "" and not _has_title(title):
		title = start_title
	can_start = false
	freeze_owned = true
	Dialog.freeze_player = true
	balloon = DialogueManager.show_example_dialogue_balloon(dialogue_resource, title)
	balloon.tree_exited.connect(_on_balloon_closed)

func _has_title(title: String) -> bool:
	return dialogue_resource != null and dialogue_resource.titles.has(title)

## 消费 Dialog 上的任务握手请求（对应本 NPC 的任务 id 才处理）。
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

## 兜底：若 NPC 在对话中被移除或换场景，也释放玩家锁定。
func _exit_tree():
	if freeze_owned:
		freeze_owned = false
		Dialog.freeze_player = false
