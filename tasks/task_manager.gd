extends Node

signal task_started(task)
signal task_completed(task)
signal task_rewarded(task)
signal objective_updated(task)

## 任务 id 常量：玩法代码只引用常量，不出现裸字符串。
const TASK_KILL_BATS := "kill_bats"

## 需要玩家进入世界时确保存在的任务（id -> .tres 路径）。
const DEFAULT_TASKS := {
	TASK_KILL_BATS: "res://tasks/kill_bats_task.tres",
}

var tasks: Array[Task] = []
var DropItemScene = preload("res://drop_item.tscn")

## 注册所有内置默认任务（重复调用安全，已存在的任务不会重复添加）。
## 注意：只登记，不自动 start —— 任务需由 NPC 接取后才进入进行中。
func ensure_default_tasks():
	for task_id in DEFAULT_TASKS:
		if get_task(task_id) != null:
			continue
		var task: Task = load(DEFAULT_TASKS[task_id]) as Task
		if task != null:
			task.status = Task.NOT_STARTED
			_zero_objectives(task)
			add_task(task)

## 把单个任务重置回"全新未接"状态（进度清零、status=NOT_STARTED）。
func reset_task(task_id: String):
	var task = get_task(task_id)
	if task != null:
		task.status = Task.NOT_STARTED
		_zero_objectives(task)

## 新开局：重置所有已登记任务为未接、进度清零。
func reset_all_tasks():
	for task_id in DEFAULT_TASKS:
		reset_task(task_id)

## 把任务的每个目标进度归零（原地修改）。
func _zero_objectives(task: Task):
	for obj in task.objectives:
		obj["progress"] = 0

## 玩家从 NPC 接取任务。仅当任务存在且未开始时生效；返回是否成功。
func accept_task(task_id: String) -> bool:
	print("TaskManager: accept_task called for ", task_id)
	var task = get_task(task_id)
	if task == null or task.status != Task.NOT_STARTED:
		print("TaskManager: accept_task failed for ", task_id, " task=", task, " status=", task.status if task else "null")
		return false
	task.start()
	task_started.emit(task)
	print("TaskManager: accept_task success for ", task_id, " status now=", task.status)
	return true

## 玩家向 NPC 交付已完成任务，发放奖励并入背包。返回是否成功。
func turn_in_task(task_id: String) -> bool:
	var task = get_task(task_id)
	if task == null or task.status != Task.COMPLETED:
		return false
	var rewards = claim_task_reward(task_id)
	for item in rewards:
		Inventory.inv.insert(item)
	return true

## 任务当前状态（-1=未登记；否则为 Task 状态枚举值）。
func get_task_state(task_id: String) -> int:
	var task = get_task(task_id)
	if task == null:
		return -1
	return task.status

## 该任务是否正等待玩家交付（COMPLETED 未领取）。
func is_task_ready_to_turn_in(task_id: String) -> bool:
	return get_task_state(task_id) == Task.COMPLETED

## 该任务是否进行中。
func is_task_in_progress(task_id: String) -> bool:
	return get_task_state(task_id) == Task.IN_PROGRESS

## 敌人击杀事件：玩法侧只需广播"杀了谁"，具体任务进度由本管理器路由。
func notify_enemy_killed(enemy_id: String):
	match enemy_id:
		TASK_KILL_BATS:
			add_objective_progress(TASK_KILL_BATS, 0, 1)

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
