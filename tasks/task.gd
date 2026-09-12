extends Resource

class_name Task

enum {
	NOT_STARTED,
	IN_PROGRESS,
	COMPLETED,
	REWARDED
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var status: int = NOT_STARTED
@export var objectives: Array[Dictionary] = []
@export var rewards: Array[InvItem] = []
@export var reward_amounts: Array[int] = []

func start():
	if status == NOT_STARTED:
		status = IN_PROGRESS

func complete():
	if status == IN_PROGRESS:
		status = COMPLETED

func claim_reward():
	if status == COMPLETED:
		status = REWARDED
		var result = []
		for i in range(rewards.size()):
			for j in range(reward_amounts[i] if i < reward_amounts.size() else 1):
				result.append(rewards[i])
		return result
	return []

func is_completed():
	return status == COMPLETED or status == REWARDED

func get_current_objective():
	for obj in objectives:
		if obj.get("progress", 0) < obj.get("target", 1):
			return obj
	return null
