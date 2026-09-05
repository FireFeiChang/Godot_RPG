extends Control

@onready var item_label = $ItemLabel
@onready var inv: Inv = Inventory.inv

func _ready():
	inv.update.connect(update_count)
	update_count()

func update_count():
	var total_items = 0
	var item_counts = {}
	
	for slot in inv.slots:
		if slot.item != null:
			total_items += slot.amount
			if slot.item.name in item_counts:
				item_counts[slot.item.name] += slot.amount
			else:
				item_counts[slot.item.name] = slot.amount
	
	if total_items == 0:
		item_label.text = ""
	else:
		var text = str(total_items)
		item_label.text = text
