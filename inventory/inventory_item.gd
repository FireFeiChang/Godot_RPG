extends Resource

class_name InvItem

enum {
	HEAL,
	MATERIAL,
	KEY
}

@export var id: String = ""
@export var name: String = ""
@export var texture: Texture2D
@export var item_type: int = MATERIAL
@export var heal_amount: int = 1
