extends CanvasLayer
## 全局 HUD（Autoload：HUD）。三张地图共享同一份，不再各自复制一套。
##
## 地图外（主菜单等）整体隐藏 —— CanvasLayer 自带 visible 属性，
## 一处置 false 就能收起全部子节点。同时把背包/任务面板也关掉，
## 避免它们在隐藏状态下还保持着"已打开"的逻辑状态。

func _ready():
	# 启动时（可能直接落在主菜单）先藏起来，等 MapManager.install() 再显示
	hide_hud()

func show_hud() -> void:
	visible = true

## 由 MapManager.install() 调用：把当前地图交给小地图去绘制。
##
## 小地图自己不认识 MapManager（HUD 在 autoload 列表里排在 MapManager 之前，
## HUD._ready() 执行时 MapManager 还不存在），所以地图根与显示名都由调用方传进来，
## 小地图不反向引用任何 autoload。
func set_map(map_root: Node, map_name: String) -> void:
	var mm := get_node_or_null("Root/Minimap")
	if mm != null and mm.has_method("set_map"):
		mm.call("set_map", map_root, map_name)

func hide_hud() -> void:
	visible = false
	for path in ["Root/inv_UI", "Root/Task_UI"]:
		var panel := get_node_or_null(path)
		if panel != null and panel.has_method("close"):
			panel.call("close")
