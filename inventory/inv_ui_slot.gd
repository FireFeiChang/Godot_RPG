extends Panel

var item: InvItem = null
var self_slot: InvSlot = null

@onready var item_visual: Sprite2D = $CenterContainer/Panel/item_display
@onready var amount_text: Label = $CenterContainer/Panel/Label
@onready var button: Button = $Button

var state = PlayerStates

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		amount_text.visible = false
		item = null
		self_slot = null
		button.disabled = true
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		if slot.amount > 1:
			amount_text.visible = true
			amount_text.text = str(slot.amount)
		elif slot.amount == 1:
			amount_text.visible = false
		item = slot.item
		self_slot = slot
		button.disabled = false

func use_item(slot: InvSlot):
	if slot.item.item_type == InvItem.HEAL:
		if state.health < state.max_health:
			state.health += slot.item.heal_amount
			slot.amount -= 1
			if slot.amount == 0:
				slot.item = null
			update(slot)
	else:
		print("This item cannot be used.")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	if self_slot != null && self_slot.item != null && state.health < state.max_health:
		use_item(self_slot)
