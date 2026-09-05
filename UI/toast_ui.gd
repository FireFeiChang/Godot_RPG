extends Control
## 屏幕中上方的任务提示浮条（Toast）。平时隐藏，触发后闪现一下再淡出。
## 监听 TaskManager：任务目标达成（task_completed）与向 NPC 交付领奖（task_rewarded）。
##
## 为什么不放在 task_ui 里：任务列表（Q）平时是隐藏的，里面的提示看不见。
## 这里做成独立的浮条，挂在 HUD CanvasLayer 上，任何时刻都能看到。

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

## 物品 id -> 中文显示名。新增物品时在此补充；未登记则退回物品原名。
const ITEM_DISPLAY_NAME := {
	"bat": "蝙蝠材料",
	"grass": "草丛",
}

const POP_TIME := 0.2    # 弹出/淡入
const HOLD_TIME := 1.6   # 停留
const FADE_TIME := 0.4   # 淡出

var _tween: Tween = null

func _ready():
	panel.visible = false
	TaskManager.task_completed.connect(_on_task_completed)
	TaskManager.task_rewarded.connect(_on_task_rewarded)

func _on_task_completed(task) -> void:
	_show("任务完成：%s" % task.name, Color(0.9, 0.95, 0.6))

func _on_task_rewarded(task) -> void:
	var parts: Array[String] = []
	for i in range(task.rewards.size()):
		var item: InvItem = task.rewards[i]
		var amount: int = task.reward_amounts[i] if i < task.reward_amounts.size() else 1
		parts.append("%s ×%d" % [ITEM_DISPLAY_NAME.get(item.id, item.name), amount])
	if parts.is_empty():
		_show("交付完成", Color(1, 0.85, 0.3))
	else:
		_show("已领取奖励：%s" % "、".join(parts), Color(1, 0.85, 0.3))

func _show(text: String, color: Color) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	label.text = text
	label.add_theme_color_override("font_color", color)
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.6, 0.6)
	panel.visible = true

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(panel, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), POP_TIME)
	_tween.set_parallel(false)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), FADE_TIME)
	_tween.tween_callback(func(): panel.visible = false)
