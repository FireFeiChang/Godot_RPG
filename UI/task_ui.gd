extends Control
## 任务列表弹层。平时隐藏，按 Q（openTask）开合。
## 奖励不再在此领取：已完成任务提示"回村长处交付"；交付/领奖由村长 NPC 对话完成。

@onready var task_list = $ScrollContainer/TaskList
@onready var task_label = $TaskLabel
@onready var completion_label = $CompletionLabel

var is_open = false

func _ready():
	TaskManager.task_started.connect(_on_task_changed)
	TaskManager.objective_updated.connect(_on_task_changed)
	TaskManager.task_completed.connect(_on_task_completed)
	completion_label.visible = false
	close()

func _process(_delta):
	if Input.is_action_just_pressed("openTask"):
		if is_open:
			close()
		else:
			open()

func open():
	is_open = true
	visible = true
	update_task_list()

func close():
	is_open = false
	visible = false

func update_task_list():
	for child in task_list.get_children():
		child.queue_free()

	var active_tasks = TaskManager.get_active_tasks()
	var completed_tasks = TaskManager.get_completed_tasks()

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

	# 已完成但尚未交付的任务：提示去找发布人交付（奖励由 NPC 发放）
	for task in completed_tasks:
		var task_item = Label.new()
		task_item.text = "[可交付] " + task.name
		task_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_item.add_theme_font_size_override("font_size", 14)
		task_list.add_child(task_item)

		var hint = Label.new()
		hint.text = "- 回到村长处交付，领取奖励"
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		task_list.add_child(hint)

func _on_task_changed(_task):
	if is_open:
		update_task_list()

func _on_task_completed(task):
	completion_label.text = "任务完成: " + task.name
	completion_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func(): completion_label.visible = false)
	if is_open:
		update_task_list()
