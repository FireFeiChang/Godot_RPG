extends Node

const SAVE_DIR = "user://saves/"
const SAVE_FILE = "save_data.json"

signal save_completed()
signal load_completed()

## 取当前地图里的玩家节点。
## 地图根始终是 Player 的直接父节点，所以直接走 current_scene 即可。
func _find_player() -> Node2D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player") as Node2D

func save_game(slot: int = 1):
	var save_data = {
		"player_states": {
			"health": PlayerStates.health,
			"max_health": PlayerStates.max_health
		},
		# 记录所在地图，读档时才知道该回到哪张图
		"map_id": MapManager.current_map_id,
		"player_position": {
			"x": 0,
			"y": 0
		},
		"gold": Wallet.gold,
		"inventory": [],
		"tasks": []
	}

	var player := _find_player()
	if player != null:
		save_data["player_position"]["x"] = player.global_position.x
		save_data["player_position"]["y"] = player.global_position.y

	for slot_obj in Inventory.inv.slots:
		if slot_obj.item != null:
			save_data["inventory"].append({
				# 优先用 id 存档（便于读档反查）；旧存档/兼容保留 name
				"item_id": slot_obj.item.id,
				"item_name": slot_obj.item.name,
				"amount": slot_obj.amount
			})
	
	for task in TaskManager.get_all_tasks():
		save_data["tasks"].append({
			"id": task.id,
			"status": task.status,
			"objectives": task.objectives.duplicate()
		})
	
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		DirAccess.make_dir_absolute(SAVE_DIR)
	
	var file = FileAccess.open(SAVE_DIR + str(slot) + "_" + SAVE_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))
		file.close()
		save_completed.emit()

func load_game(slot: int = 1):
	var file = FileAccess.open(SAVE_DIR + str(slot) + "_" + SAVE_FILE, FileAccess.READ)
	if file == null:
		return false
	
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if save_data.has("player_states"):
		PlayerStates.health = save_data["player_states"].get("health", 5)
		PlayerStates.max_health = save_data["player_states"].get("max_health", 5)
	
	# 位置还原：只有玩家确实在当前场景里时才写。
	# MapManager.install() 保证调用本函数时current_scene 已经是目标地图。
	if save_data.has("player_position"):
		var player := _find_player()
		if player != null:
			player.global_position = Vector2(
				save_data["player_position"].get("x", 184),
				save_data["player_position"].get("y", 500)
			)

	if save_data.has("gold"):
		Wallet.gold = save_data["gold"]
		Wallet.gold_changed.emit(Wallet.gold)
	
	if save_data.has("inventory"):
		for item_data in save_data["inventory"]:
			# 优先用注册表按 id 反查；兼容旧存档按 name 回退到注册表
			var item: InvItem = null
			if item_data.has("item_id"):
				item = Inventory.get_item(item_data["item_id"])
			if item == null and item_data.has("item_name"):
				item = Inventory.get_item_by_name(item_data["item_name"])
			if item != null:
				for i in range(item_data["amount"]):
					Inventory.inv.insert(item)
	
	if save_data.has("tasks"):
		for task_data in save_data["tasks"]:
			var task = TaskManager.get_task(task_data["id"])
			if task != null:
				task.status = int(task_data["status"])
				task.objectives = _normalize_objectives(task_data.get("objectives", []))

	# 账本是运行期状态，没有进存档；不按进度补回来的话，
	# 读档后第一次击杀会把进度"设为账本值"，使进度**倒退**（详见 reseed_ledger_from_tasks）。
	TaskManager.reseed_ledger_from_tasks()

	load_completed.emit()
	return true

## 把存档里的 objectives 转回目标要求的类型。
##
## 必须做：JSON 的数字都是 double，`JSON.parse_string` 读回来是 **float**，
## 于是 `progress`/`target` 会变成 3.0 / 5.0 —— 任务面板用 `str()` 直接显示，
## 会变成 "3.0/5.0"。这里统一转回 int 并丢弃未知键。
func _normalize_objectives(raw) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is not Array:
		return result
	for entry in raw:
		if not (entry is Dictionary):
			continue
		var obj := {
			"name": String(entry.get("name", "")),
			"progress": int(entry.get("progress", 0)),
			"target": int(entry.get("target", 1)),
		}
		# source 决定该目标由哪种事件推进；缺失的目标不会自动推进（安全默认）
		if entry.has("source"):
			obj["source"] = String(entry["source"])
		result.append(obj)
	return result

## 只读取存档里记录的地图 id（不应用任何状态）。
## 供 MapManager 决定"继续游戏"该切到哪张地图；存档不存在或无记录时返回 ""。
func peek_map_id(slot: int = 1) -> String:
	var path := SAVE_DIR + str(slot) + "_" + SAVE_FILE
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()
	if save_data is Dictionary and save_data.has("map_id"):
		return str(save_data["map_id"])
	return ""

func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(SAVE_DIR + str(slot) + "_" + SAVE_FILE)

func delete_save(slot: int = 1):
	if FileAccess.file_exists(SAVE_DIR + str(slot) + "_" + SAVE_FILE):
		DirAccess.remove_absolute(SAVE_DIR + str(slot) + "_" + SAVE_FILE)
