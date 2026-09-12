extends Control

@onready var inv: Inv = Inventory.inv
@onready var hBox: Array = $Frame/ScrollContainer/VBoxContainer.get_children()

var slots: Array = []
var is_open = false

func _ready():
	for i in range(hBox.size()):
		slots += hBox[i].get_children()
	inv.update.connect(update_slots)
	update_slots()
	close()

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		slots[i].update(inv.slots[i])

func _process(_delta):
	# HUD 现在常驻（autoload），主菜单里也存在。不加这道判断的话，
	# 在主菜单按 B 会穿透到标题画面上把背包打开。
	# 用 is_visible_in_tree() 而不是 HUD.visible：父级（HUD 那个 CanvasLayer）
	# 一旦隐藏，这里就自动为 false，且不依赖 autoload 全局标识符。
	if not is_visible_in_tree():
		return
	if Input.is_action_just_pressed("openInv"):
		if is_open:
			close()
		else:
			open()
	
func close():
	visible = false
	is_open = false
	
func open():
	visible = true
	is_open = true

func sort():
	slots.sort_custom(compare)
	
func compare(a, _b):
	return a == null
