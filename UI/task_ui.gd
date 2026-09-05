extends Control

# 背包唯一数据源：与玩家场景 export、inv_UI/item_counter 的 preload 为同一资源实例
const PLAYER_INV: Inv = preload("res://inventory/playerInv.tres")

@onready var task_list = $ScrollContainer/TaskList
@onready var task_label = $TaskLabel
@onready var completion_label = $CompletionLabel

var tasks: Array = []

func _ready():
	TaskManager.task_started.connect(_on_task_started)
	TaskManager.objective_updated.connect(_on_objective_updated)
	TaskManager.task_completed.connect(_on_task_completed)
	completion_label.visible = false
	update_task_list()

func update_task_list():
	for child in task_list.get_children():
		child.queue_free()
	
	var active_tasks = TaskManager.get_active_tasks()
	var completed_tasks = TaskManager.get_completed_tasks()
	tasks = active_tasks
	
	if active_tasks.is_empty() and completed_tasks.is_empty():
		task_label.text = "暂无任务"
		return
	
	task_label.text = "任务"
	
	for task in active_tasks:
		var task_item = Label.new()
		task_item.text = task.name
		task_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_item.add_theme_font_size_override("font_size", 14)
		task_list.add_child(task_item)
		
		var obj = task.get_current_objective()
		if obj:
			var progress_label = Label.new()
			progress_label.text = "- " + obj.get("name", "") + ": " + str(obj.get("progress", 0)) + "/" + str(obj.get("target", 1))
			progress_label.add_theme_font_size_override("font_size", 12)
			task_list.add_child(progress_label)
	
	for task in completed_tasks:
		if task.status == Task.COMPLETED:
			var task_item = Label.new()
			task_item.text = "[已完成] " + task.name
			task_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			task_item.add_theme_font_size_override("font_size", 14)
			task_list.add_child(task_item)
			
			var claim_button = Button.new()
			claim_button.text = "领取奖励"
			claim_button.add_theme_font_size_override("font_size", 12)
			claim_button.pressed.connect(func(): claim_reward(task))
			task_list.add_child(claim_button)

func claim_reward(task):
	var rewards = TaskManager.claim_task_reward(task.id)
	for item in rewards:
		PLAYER_INV.insert(item)
	update_task_list()

func _on_task_started(task):
	update_task_list()

func _on_objective_updated(task):
	update_task_list()

func _on_task_completed(task):
	completion_label.text = "任务完成: " + task.name
	completion_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func(): completion_label.visible = false)
	update_task_list()
