extends Node

signal task_started(task)
signal task_completed(task)
signal task_rewarded(task)
signal objective_updated(task)

## 任务 id 常量：玩法代码只引用常量，不出现裸字符串。
const TASK_KILL_BATS := "kill_bats"
const TASK_VILLAGE_HERBS := "village_herbs"
const TASK_VILLAGE_BEASTS := "village_beasts"
const TASK_EAST_SLIMES := "east_slimes"
const TASK_EAST_GOBLINS := "east_goblins"
const TASK_EAST_CHESTS := "east_chests"

## 敌人种类 id。敌人死亡时广播**种类**，不要传任务 id
## （旧代码把 TASK_KILL_BATS 当敌人 id 传，多个任务并存后语义就串了）。
const ENEMY_BAT := "bat"
const ENEMY_ACORNBACK := "acornback"
const ENEMY_GOBLIN := "goblin"
const ENEMY_SLIME := "slime"
const ENEMY_MIMIC := "mimic"

## 需要玩家进入世界时确保存在的任务（id -> .tres 路径）。
const DEFAULT_TASKS := {
	TASK_KILL_BATS: "res://tasks/kill_bats_task.tres",
	TASK_VILLAGE_HERBS: "res://tasks/village_herbs_task.tres",
	TASK_VILLAGE_BEASTS: "res://tasks/village_beasts_task.tres",
	TASK_EAST_SLIMES: "res://tasks/east_slimes_task.tres",
	TASK_EAST_GOBLINS: "res://tasks/east_goblins_task.tres",
	TASK_EAST_CHESTS: "res://tasks/east_chests_task.tres",
}

var tasks: Array[Task] = []
var DropItemScene = preload("res://drop_item.tscn")

## 累计账本：source 键 -> 累计次数（如 "kill:bat" -> 7、"collect:grass" -> 23）。
##
## 为什么需要它：**游戏里敌人不重生**，而任务进度只在"接取后"才累加。
## 玩家若先把某片区域的怪清光，之后接到的击杀任务就永远做不完。
## 账本记录的是**全局累计**，与任务接没接无关；接取任务时按账本一次性补记进度，
## 于是"先打的也算数"，任务永远不会死。
##
## 键的格式见 _source_of()：`kill:<敌人种类>` / `collect:<物品id>` / `open:chest`。
var _ledger: Dictionary = {}

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

## 新开局：重置所有已登记任务为未接、进度清零，并清空累计账本。
func reset_all_tasks():
	_ledger.clear()
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
	# 先按累计账本补记进度，再广播 —— 否则 task_started 打出的 UI 会是 0 进度。
	# 补记后可能直接达标（玩家在接任务前就把活干完了），所以随后要 check 一次完成。
	_backfill_from_ledger(task)
	task_started.emit(task)
	objective_updated.emit(task)
	check_completion(task)
	print("TaskManager: accept_task success for ", task_id, " status now=", task.status)
	return true

## 按累计账本把任务的各目标进度补齐到"至今累计值"（上限为目标值）。
func _backfill_from_ledger(task: Task) -> void:
	for i in range(task.objectives.size()):
		var src := _source_of(task.objectives[i])
		if src == "" or not _ledger.has(src):
			continue
		var target: int = int(task.objectives[i].get("target", 1))
		task.objectives[i]["progress"] = mini(int(_ledger[src]), target)

## 目标计数来源：目标字典里的 "source" 字段。
## 空字符串 = 该目标不由事件驱动（没有来源，永不自动推进）。
func _source_of(objective: Dictionary) -> String:
	return String(objective.get("source", ""))

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

## 敌人击杀事件：玩法侧只需广播"杀了哪种敌人"（用 ENEMY_* 常量），
## 哪些任务的哪个目标该加进度，由目标自己的 "source" 字段决定。
func notify_enemy_killed(enemy_id: String) -> void:
	notify_progress("kill:" + enemy_id)

## 通用进度事件：累加账本，并把所有**进行中**任务的对应目标同步到账本值。
##
## 同步用"设为账本值"而不是"加 1"，是为了让补记与实时累加走同一条路径 ——
## 即使同一帧来了两次、或接任务时刚补记过，结果都收敛到同一个数，不会重复计数。
func notify_progress(source: String, amount: int = 1) -> void:
	if source == "":
		return
	_ledger[source] = int(_ledger.get(source, 0)) + amount
	var value: int = _ledger[source]
	for task in tasks:
		if task.status != Task.IN_PROGRESS:
			continue
		for i in range(task.objectives.size()):
			if _source_of(task.objectives[i]) == source:
				update_objective(task.id, i, value)

## 至今累计的某来源次数（调试/UI 用）。
func get_ledger(source: String) -> int:
	return int(_ledger.get(source, 0))

## 由已恢复的任务进度反推账本。**读档后必须调用**。
##
## 为什么需要：存档只写 task.objectives，不写账本（账本是运行期状态）。
## 读档后任务进度恢复成 3，而账本是空的 —— 下一次击杀会走
## "把进度设为账本值" 这条路，把进度从 3 改成 1，**进度倒退**。
##
## 这里按"账本不小于任何同来源目标的进度"来补齐，且**只多不少**：
## 账本偏大是安全的（进度会被 min 钳在 target 上），偏小才会倒退。
func reseed_ledger_from_tasks() -> void:
	for task in tasks:
		for obj in task.objectives:
			var src := _source_of(obj)
			if src == "":
				continue
			var progress := int(obj.get("progress", 0))
			if progress > int(_ledger.get(src, 0)):
				_ledger[src] = progress

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

# —— 任务链辅助 ——————————————————————————————————————————————
# 串行任务链：一个 NPC 一次只给一条，交付领奖后才解锁下一条。
# 放在这里而不是各个 NPC 脚本里，是因为 npc.gd（extends CharacterBody2D）和
# female_adventurer.gd（extends KinematicActor）没有共同基类，各写一遍必然走样。

## 链上第一条还没领奖的任务；全部领完（或链为空）返回 ""。
func next_in_chain(chain: Array) -> String:
	for tid in chain:
		var id := String(tid)
		if get_task_state(id) == -1:
			# 链里写了没登记的任务 id —— 跳过它，否则整条链会永远卡住，
			# 而且玩家看不到任何异常。用 push_error 让它显形。
			push_error("TaskManager: 任务链里的 id 未登记，已跳过：%s" % id)
			continue
		if get_task_state(id) != Task.REWARDED:
			return id
	return ""

## 当前该用哪个对话标题。链为空 -> start_title；链已走完 -> all_done_title。
func chain_title(chain: Array, start_title: String, all_done_title: String) -> String:
	if chain.is_empty():
		return start_title
	var id := next_in_chain(chain)
	if id == "":
		return all_done_title
	match get_task_state(id):
		Task.NOT_STARTED:
			return "%s_offer" % id
		Task.IN_PROGRESS:
			return "%s_in_progress" % id
		Task.COMPLETED:
			return "%s_turnin" % id
	return start_title

## 消费 Dialog 上的接取/交付请求。只认**链上当前那条**任务，
## 免得别的 NPC 残留的请求被这里误消费。
func consume_chain_requests(chain: Array) -> void:
	var id := next_in_chain(chain)
	if id == "":
		return
	if Dialog.task_accept_request == id:
		Dialog.task_accept_request = ""
		accept_task(id)
	if Dialog.task_turnin_request == id:
		Dialog.task_turnin_request = ""
		turn_in_task(id)

func spawn_drop_item(pos: Vector2, drop_item_resource: InvItem):
	var drop_item = DropItemScene.instantiate()
	drop_item.item = drop_item_resource
	drop_item.amount = 1
	drop_item.global_position = pos
	get_tree().current_scene.add_child(drop_item)
