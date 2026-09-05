extends Node
## 背包全局管理（Autoload：Inventory）。
## 整个项目唯一的背包数据源与物品注册入口。玩家场景、背包 UI、物品计数、
## 存档与任务奖励都从这里读取 `inv`，不再各自 preload 资源或在场景节点上导出副本。

## 玩家背包实例（全局唯一，Godot 资源缓存保证各处拿到同一对象）
var inv: Inv = preload("res://inventory/playerInv.tres")

## 物品 id -> 资源路径注册表。新增物品时在此登记，即可被存档/读档使用。
const ITEM_REGISTRY: Dictionary = {
	"grass": "res://inventory/item/grass.tres",
	"bat": "res://inventory/item/bat.tres",
}

## 按 id 返回物品资源；未登记返回 null。
func get_item(id: String) -> InvItem:
	var path: String = ITEM_REGISTRY.get(id, "")
	if path == "":
		return null
	return load(path) as InvItem

## 按物品 name 回退查找（兼容旧存档）；找不到返回 null。
func get_item_by_name(item_name: String) -> InvItem:
	for id in ITEM_REGISTRY:
		var item: InvItem = get_item(id)
		if item != null and item.name == item_name:
			return item
	return null
