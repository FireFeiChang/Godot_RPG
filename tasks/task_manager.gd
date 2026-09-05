extends Node

signal task_started(task)
signal task_completed(task)
signal task_rewarded(task)
signal objective_updated(task)

var tasks: Array[Task] = []
var DropItemScene = preload("res://drop_item.tscn")

func add_task(task: Task):
	tasks.append(task)
	task_started.emit(task)

func get_task(task_id: String) -> Task:
	for task in tasks:
		if task.id == task_id:
			return task
	return null

func update_objective(task_id: String, objective_index: int, progress: int):
	var task = get_task(task_id)
	if task and task.status == Task.IN_PROGRESS:
		if objective_index < task.objectives.size():
			task.objectives[objective_index]["progress"] = min(progress, task.objectives[objective_index].get("target", 1))
			objective_updated.emit(task)
			check_completion(task)

func add_objective_progress(task_id: String, objective_index: int, amount: int = 1):
	var task = get_task(task_id)
	if task and task.status == Task.IN_PROGRESS:
		if objective_index < task.objectives.size():
			var current_progress = task.objectives[objective_index].get("progress", 0)
			update_objective(task_id, objective_index, current_progress + amount)

func check_completion(task: Task):
	for obj in task.objectives:
		if obj.get("progress", 0) < obj.get("target", 1):
			return
	task.complete()
	task_completed.emit(task)

func claim_task_reward(task_id: String) -> Array:
	var task = get_task(task_id)
	if task:
		var rewards = task.claim_reward()
		if rewards.size() > 0:
			task_rewarded.emit(task)
		return rewards
	return []

func get_active_tasks() -> Array:
	return tasks.filter(func(t): return t.status == Task.IN_PROGRESS)

func get_completed_tasks() -> Array:
	return tasks.filter(func(t): return t.status == Task.COMPLETED)

func get_all_tasks() -> Array:
	return tasks.duplicate()

func spawn_drop_item(pos: Vector2, drop_item_resource: InvItem):
	var drop_item = DropItemScene.instantiate()
	drop_item.item = drop_item_resource
	drop_item.amount = 1
	drop_item.global_position = pos
	get_tree().current_scene.add_child(drop_item)
