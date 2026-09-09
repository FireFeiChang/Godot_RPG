extends Control
## 任务面板：使用 Kenney UI 素材重新设计。
## 平时隐藏，按 Q 开合。显示任务列表和进度。

@onready var task_list: VBoxContainer = $Panel/ScrollContainer/TaskList
@onready var task_label: Label = $Panel/TaskLabel
@onready var completion_label: Label = $Panel/CompletionLabel

var is_open = false

func _ready():
	TaskManager.task_started.connect(_on_task_changed)
	TaskManager.objective_updated.connect(_on_task_changed)
	TaskManager.task_completed.connect(_on_task_completed)
	completion_label.visible = false
	TaskManager.ensure_default_tasks()
	update_task_list()
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
	TaskManager.ensure_default_tasks()
	update_task_list()
	print("TaskPanel: opened, active tasks = ", TaskManager.get_active_tasks().size(), ", completed = ", TaskManager.get_completed_tasks().size())

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
	print("TaskPanel: _on_task_changed called")
	if _task:
		print("  task: ", _task.id, " status: ", _task.status)
	TaskManager.ensure_default_tasks()
	update_task_list()
	print("  after update, children: ", task_list.get_children().size())

func _on_task_completed(task):
	print("TaskPanel: _on_task_completed called: ", task.name)
	completion_label.text = "任务完成: " + task.name
	completion_label.visible = true
	get_tree().create_timer(3.0).timeout.connect(func(): completion_label.visible = false)
	update_task_list()
