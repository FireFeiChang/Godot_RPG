extends CharacterBody2D
## 可对话 NPC（可扩展基类）。
## 站在 SpeakBox 范围内按 [Enter] 或 [E]（ui_accept / interact）即可对话，头顶显示交互提示。
## 对话期间通过 Dialog.freeze_player 锁定玩家移动，结束/离开后自动解除。
##
## 两种模式：
## - 普通闲聊 NPC：task_ids 留空，用 start_title 起始对话。
## - 任务 NPC：给 task_ids 按顺序填一串任务 id（**串行链**，一次只给一条，
##   交付领奖后才解锁下一条）。NPC 按链上"第一条还没领奖"的任务实时状态选标题：
##   `<id>_offer`（未接，可接）、`<id>_in_progress`（进行中）、
##   `<id>_turnin`（已完成可交付）、`<id>_rewarded`（已领奖，但还有后续）。
##   全部领完用 all_done_title。
##   玩家在对话中选择接取/交付时，.dialogue 内用 `set Dialog.task_accept_request` /
##   `set Dialog.task_turnin_request` 填入任务 id，本脚本每帧消费并执行真正的任务操作。
## 新增 NPC：复制 npc.tscn，改 dialogue_path（与/或 start_title / task_ids）即可。

@export var dialogue_path: String = "res://NPC/Test.dialogue"
@export var start_title: String = "hello"

## 任务链（串行）。留空 = 纯闲聊 NPC。
@export var task_ids: PackedStringArray = PackedStringArray()

## 链上所有任务都领完奖后用的对话标题；找不到该标题则退回 start_title。
@export var all_done_title: String = "all_done"

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

## 本轮对话要用的起始标题。链逻辑在 TaskManager 里（和 female_adventurer 共用一份）。
func current_title() -> String:
	return TaskManager.chain_title(task_ids, start_title, all_done_title)

func start_dialogue():
	if dialogue_resource == null or balloon != null:
		return
	var title := current_title()
	# 若任务 NPC 所需的标题不存在则退回闲聊标题，避免空白对话
	if not _has_title(title):
		title = start_title
	can_start = false
	freeze_owned = true
	Dialog.freeze_player = true
	balloon = DialogueManager.show_example_dialogue_balloon(dialogue_resource, title)
	balloon.tree_exited.connect(_on_balloon_closed)

func _has_title(title: String) -> bool:
	return dialogue_resource != null and dialogue_resource.titles.has(title)

## 消费 Dialog 上的任务握手请求（只认自己链上当前那条）。
func _consume_task_requests():
	TaskManager.consume_chain_requests(task_ids)

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
