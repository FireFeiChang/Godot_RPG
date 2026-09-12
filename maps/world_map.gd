extends Node2D
## 地图根脚本：把"玩家已进入本地图"交给 MapManager，并接好相机跟随。
##
## Player 必须保持是地图根的直接子节点 ——
## save/save_manager.gd 用 current_scene.get_node_or_null("Player") 找玩家。

## 相机跟随方式：**关闭位置平滑，硬跟随**。
##
## 原因：Camera2D.position_smoothing_speed 的单位是「像素/秒」，Godot 默认值只有 5.0，
## 而玩家移动速度是 100 px/秒 —— 相机永远追不上，走得越远偏得越多。
## 中途试过按落后距离/持续时长动态调速，但调速本身引入了额外的不确定性
## （依赖视口尺寸等易错 API），手感反而更差。
## 直接关掉平滑后，相机每帧精确停在玩家位置（再由 limits 钳位），
## 行为完全可预测。
##
## 若以后想要平滑跟随，把 position_smoothing_enabled 设回 true，
## 并把 position_smoothing_speed 设成**明显大于 100**（如 300），否则又会跟不上。
func _ready():
	_ensure_camera_follow()
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.position_smoothing_enabled = false
	MapManager.install(self)

## 给 Player 补挂驱动相机的 RemoteTransform2D。
##
## 为什么不直接写进 .tscn：程序化生成的场景里，加到**实例化节点内部**的
## 子节点无法被 PackedScene.pack() 序列化（实测：owner 设成地图根或实例根
## 都会被静默丢弃），所以改在运行时补挂。
## world.tscn 是手工编辑的，可以直接把该节点写在场景里；为了两种来源都能跑，
## 这里先判断是否已存在，已有就不重复添加。
func _ensure_camera_follow() -> void:
	var player := get_node_or_null("Player")
	var cam := get_node_or_null("Camera2D")
	if player == null or cam == null:
		return
	if player.get_node_or_null("RemoteTransform2D") != null:
		return   # world.tscn 里已内置
	var rt := RemoteTransform2D.new()
	rt.name = "RemoteTransform2D"
	player.add_child(rt)
	# remote_path 是**从 RemoteTransform2D 自己**开始解析的，不是从 Player。
	# 它挂在 Player 下面，所以比"玩家 -> 相机"多一层，必须是 ../../Camera2D。
	# 先 add_child 再算路径：此时 rt 在树里，get_path_to 才有意义。
	rt.remote_path = rt.get_path_to(cam)
