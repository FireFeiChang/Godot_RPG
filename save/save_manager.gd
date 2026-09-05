extends Node

const SAVE_DIR = "user://saves/"
const SAVE_FILE = "save_data.json"

signal save_completed()
signal load_completed()

func save_game(slot: int = 1):
	var save_data = {
		"player_states": {
			"health": PlayerStates.health,
			"max_health": PlayerStates.max_health
		},
		"player_position": {
			"x": 0,
			"y": 0
		},
		"inventory": [],
		"tasks": []
	}
	
	var player = get_tree().current_scene.get_node_or_null("Player")
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
	
	if save_data.has("player_position"):
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player != null:
			player.global_position = Vector2(
				save_data["player_position"].get("x", 344),
				save_data["player_position"].get("y", 196)
			)
	
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
				task.status = task_data["status"]
				task.objectives = task_data["objectives"]
	
	load_completed.emit()
	return true

func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(SAVE_DIR + str(slot) + "_" + SAVE_FILE)

func delete_save(slot: int = 1):
	if FileAccess.file_exists(SAVE_DIR + str(slot) + "_" + SAVE_FILE):
		DirAccess.remove_absolute(SAVE_DIR + str(slot) + "_" + SAVE_FILE)
