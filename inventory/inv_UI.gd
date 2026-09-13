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
	# HUD 现在常驻（autoload），主菜单里也存在。不加判断的话，
	# 在主菜单按 B 会穿透到标题画面上把背包打开。
	#
	# ⚠️ 这里**不能**用 is_visible_in_tree()：它把节点**自己**的 visible 也算进去，
	# 而背包 _ready() 里就调了 close()（visible=false）—— 守卫第一行就 return，
	# B 键永远读不到，背包再也打不开（曾真实踩到）。
	# 改为只查**祖先链**：祖先可见 = 至少在地图里（HUD 没被隐藏），
	# 与自己的开合状态无关。
	if not _ancestors_visible():
		return
	if Input.is_action_just_pressed("openInv"):
		if is_open:
			close()
		else:
			open()

## 祖先链是否可见（不含自己）。HUD 那个 CanvasLayer 一旦 hide_hud()，
## 这里就是 false，主菜单按 B 不会穿透。
##
## 两种类型都要判：CanvasLayer **不是** CanvasItem，只查 CanvasItem 会漏掉 HUD 那一层。
func _ancestors_visible() -> bool:
	var n: Node = get_parent()
	while n != null:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			return false
		n = n.get_parent()
	return true

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
