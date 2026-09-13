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
	# HUD 现在常驻（autoload），主菜单里也存在。不加这道判断的话，
	# 在主菜单按 Q 会穿透到标题画面上把任务面板打开。
	#
	# ⚠️ 这里**不能**用 is_visible_in_tree()：它把节点**自己**的 visible 也算进去，
	# 而任务面板 _ready() 里就调了 close()（visible=false）—— 守卫第一行就 return，
	# Q 键永远读不到，面板再也打不开（曾真实踩到）。
	# 改为只查**祖先链**：祖先可见 = 至少在地图里（HUD 没被隐藏），
	# 与自己的开合状态无关。
	if not _ancestors_visible():
		return
	if Input.is_action_just_pressed("openTask"):
		if is_open:
			close()
		else:
			open()

## 祖先链是否可见（不含自己）。HUD 那个 CanvasLayer 一旦 hide_hud()，
## 这里就是 false，主菜单按 Q 不会穿透。
##
## 两种类型都要判：CanvasLayer **不是** CanvasItem，只查 CanvasItem 会漏掉 HUD 那一层。
func _ancestors_visible() -> bool:
	var n: Node = get_parent()
	while n != null:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			return false
		n = n.get_parent()
	return true

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
		task_item.add_theme_font_size_override("font_size", 8)
		task_list.add_child(task_item)

		var obj = task.get_current_objective()
		if obj:
			var progress_label = Label.new()
			progress_label.text = "- " + obj.get("name", "") + ": " + str(obj.get("progress", 0)) + "/" + str(obj.get("target", 1))
			progress_label.add_theme_font_size_override("font_size", 8)
			task_list.add_child(progress_label)

	for task in completed_tasks:
		var task_item = Label.new()
		task_item.text = "[可交付] " + task.name
		task_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_item.add_theme_font_size_override("font_size", 8)
		task_list.add_child(task_item)

		var hint = Label.new()
		hint.text = "- 回到村长处交付，领取奖励"
		hint.add_theme_font_size_override("font_size", 8)
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
