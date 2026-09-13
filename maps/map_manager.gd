extends Node
## 多地图管理（Autoload：MapManager）。
## 负责：地图注册表、边缘传送、跨图出生点定位、以及"本局第一次进图"的判定。
##
## 为什么需要它：Player 是每张地图场景里的普通子节点（不是 autoload），
## 所以 change_scene_to_file() 后新地图的 Player._ready() 会重新跑一遍。
## 若不加判定，每次换图都会触发 _reset_new_game()，把血/背包/金币/任务全部清空。

signal map_changed(map_id: String)

## 地图注册表：id -> 场景路径。新增地图只需在此登记。
const MAPS := {
	"world": "res://world.tscn",
	"north": "res://maps/map_north.tscn",
	"east": "res://maps/map_east.tscn",
}

const DEFAULT_MAP := "world"

## 地图的中文显示名（小地图底部的名字条）。
## 与 MAPS 分开：MAPS 是"id → 场景路径"的程序映射，这里是给玩家看的文案。
const MAP_NAMES := {
	"world": "村口田野",
	"north": "北坡羊道",
	"east": "东原营地",
}

## 当前所在地图 id；空字符串表示"当前场景不是地图"（如主菜单）。
var current_map_id := ""

## 待进入的地图与出生点（切图中转，install() 时消费）。
var pending_map_id := ""
var pending_spawn := ""

## true = 下一次 install() 属于"本局第一次进图"，需要重置存档。
## 初值必须是 true：scene_changed 是延迟信号，首次进图时 install() 可能先于它执行。
var _fresh_start := true

## 读档槽位；>0 时在 install() 里调用 SaveManager.load_game()。
var _load_slot := 0

## 防止同一帧内触发两次切图（两个边缘触发器重叠时）。
var _locked := false

## 延迟切图时暂存目标场景路径（由 _do_change_scene 消费）。
var _pending_path := ""

func _ready():
	get_tree().scene_changed.connect(_on_scene_changed)
	# 兜底：若本 autoload 就绪时场景已经挂好（编辑器直接运行地图），这里也能正确初始化。
	_on_scene_changed()

## 当前场景不是地图（主菜单等）时清空状态 —— 下一张地图视为全新一局。
func _on_scene_changed():
	var cs := get_tree().current_scene
	var id := _id_of_path(cs.scene_file_path if cs != null else "")
	if id == "":
		current_map_id = ""
		pending_map_id = ""
		pending_spawn = ""
		_fresh_start = true
		_set_hud_visible(false)

## 开始新一局。slot == 0 清空重来；slot > 0 从存档继续。
## 主菜单调用后，用 intended_map() 拿要切到的地图 id。
func begin_new_game(slot: int = 0):
	_fresh_start = true
	_load_slot = slot
	pending_spawn = ""
	if slot > 0:
		# 显式标注类型：SaveManager 是 autoload，其返回值在静态分析阶段拿不到类型，
		# 用 := 会报 "Cannot infer the type of saved"。
		var saved: String = SaveManager.peek_map_id(slot)
		pending_map_id = saved if MAPS.has(saved) else ""
	else:
		pending_map_id = ""

## 主菜单该切到哪张地图：读档继续时用存档记录的地图，否则用默认图。
func intended_map() -> String:
	if pending_map_id != "" and MAPS.has(pending_map_id):
		return pending_map_id
	return DEFAULT_MAP

## Player._ready() 调用：取一次就清掉，保证只重置一次。
func consume_fresh_start() -> bool:
	var f := _fresh_start
	_fresh_start = false
	return f

## 由边缘触发器调用。返回 true 表示已发起切图。
func goto_map(map_id: String, spawn_name: String) -> bool:
	if current_map_id == "" or _locked:
		return false
	if not MAPS.has(map_id):
		push_error("MapManager: 未知地图 id %s" % map_id)
		return false
	if map_id == current_map_id:
		return false

	pending_map_id = map_id
	pending_spawn = spawn_name
	_pending_path = MAPS[map_id]
	_locked = true

	# 必须延后到物理帧之外再切场景。
	# 本函数是从 Area2D.body_entered 进来的，属于物理回调；而 change_scene_to_file
	# 会立刻释放旧场景（含大量 CollisionObject2D），引擎不允许在物理回调里这么做，
	# 会报 "Removing a CollisionObject node during a physics callback is not allowed"。
	_do_change_scene.call_deferred()
	return true

## 真正执行切图（由 goto_map 延迟调用）。
func _do_change_scene() -> void:
	if _pending_path == "":
		return
	var err := get_tree().change_scene_to_file(_pending_path)
	_pending_path = ""
	if err != OK:
		pending_map_id = ""
		pending_spawn = ""
		_locked = false
		push_error("MapManager: 切换场景失败：%d" % err)

## 每张地图根的 _ready() 里调用（maps/world_map.gd）。
## 参数用 map_root 而不是 get_tree().current_scene：Player._ready() 在 add_child
## 期间执行，此时 current_scene 还指向旧地图（甚至为 null）。
func install(map_root: Node) -> void:
	var id := _id_of_path(map_root.scene_file_path)
	if id == "":
		return

	# 1) 决定出生位置
	var arrived: Vector2
	if pending_map_id == id and pending_spawn != "":
		arrived = resolve_spawn(map_root, pending_spawn)
	else:
		# 直接运行地图（编辑器 F5/F6）：用作者在场景里摆的 Player 位置
		arrived = _authored_player_position(map_root)

	current_map_id = id
	pending_map_id = ""
	pending_spawn = ""

	# 2) HUD 与对话解锁
	_set_hud_visible(true)
	_set_minimap(map_root, MAP_NAMES.get(id, id))
	Dialog.freeze_player = false

	# 3) 摆玩家 + 复位相机
	_place_player(map_root, arrived)

	# 4) 读档（必须在玩家就位后，load_game 才能找到 Player 还原位置）
	if _load_slot > 0:
		var slot := _load_slot
		_load_slot = 0
		SaveManager.load_game(slot)

	_locked = false
	map_changed.emit(id)

## 在目标地图的 Spawns 容器里找同名 Marker2D；找不到则回退到作者摆的位置。
func resolve_spawn(map_root: Node, spawn_name: String) -> Vector2:
	var marker := _spawn_marker(map_root, spawn_name)
	if marker != null:
		return marker.global_position
	push_warning("MapManager: 地图 %s 找不到出生点 %s，回退到 Player 初始位置" % [current_map_id, spawn_name])
	return _authored_player_position(map_root)

func _spawn_marker(map_root: Node, spawn_name: String) -> Node2D:
	var container := map_root.get_node_or_null("Spawns")
	if container == null or spawn_name == "":
		return null
	# Godot 会把数字开头的节点名改成 @123 形式，两边都做一次去前缀比较
	var key := spawn_name.trim_prefix("@")
	for child in container.get_children():
		if child is Node2D:
			var cname := String(child.name)
			if cname == spawn_name or cname.trim_prefix("@") == key:
				return child
	return null

func _authored_player_position(map_root: Node) -> Vector2:
	var p := map_root.get_node_or_null("Player")
	return p.global_position if p != null else Vector2.ZERO

## 把玩家摆到目标位置，并清掉跨图残留的状态与相机平滑。
func _place_player(map_root: Node, pos: Vector2) -> void:
	var p := map_root.get_node_or_null("Player")
	if p == null:
		push_warning("MapManager: 地图 %s 里找不到 Player 节点" % current_map_id)
		return
	p.global_position = pos
	if p.has_method("reset_for_teleport"):
		p.reset_for_teleport()

	# 相机是 RemoteTransform2D 驱动的，先强制刷新再清平滑，
	# 否则相机会从上一张地图的位置"飞"过来。
	var cam := map_root.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		# 回退路径：从 RemoteTransform2D 自己的 remote_path 反查相机。
		# 注意必须用 **rt** 去解析，不能用 Player —— remote_path 是相对 RT 本身的，
		# 而 RT 是 Player 的子节点，两者差一层。
		var rt := p.get_node_or_null("RemoteTransform2D") as RemoteTransform2D
		if rt != null and not rt.remote_path.is_empty():
			cam = rt.get_node_or_null(rt.remote_path) as Camera2D
	if cam != null:
		cam.force_update_scroll()
		cam.reset_smoothing()

## 动态调用 HUD 的显隐，避免在 HUD autoload 还没注册时编译报错
## （HUD 是 Phase 3 才加的，MapManager 先上线时不能硬引用这个标识符）。
func _set_hud_visible(v: bool) -> void:
	var hud := get_node_or_null("/root/HUD")
	if hud == null:
		return
	var fn := "show_hud" if v else "hide_hud"
	if hud.has_method(fn):
		hud.call(fn)

## 把当前地图交给 HUD 里的小地图绘制。
## 与 _set_hud_visible 同样用动态调用，避免硬引用（HUD 可能还没注册）。
func _set_minimap(map_root: Node, map_name: String) -> void:
	var hud := get_node_or_null("/root/HUD")
	if hud == null:
		return
	if hud.has_method("set_map"):
		hud.call("set_map", map_root, map_name)

func _id_of_path(path: String) -> String:
	for key in MAPS:
		if MAPS[key] == path:
			return key
	return ""
