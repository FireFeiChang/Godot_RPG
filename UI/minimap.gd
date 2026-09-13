extends Control
## 小地图（HUD 的一部分，挂在 HUD/Root/Minimap 下）。
##
## 由 MapManager.install() 经 HUD.set_map() 注入当前地图根节点，然后**实时**从地图里
## 读几何信息来画：
##   - CliffTileMap    的格子 → 地图轮廓（崖壁环就是地图边界）
##   - DirtPathTileMap 的格子 → 泥路（2 个泥路格 = 1 个小地图像素）
##   - EdgeTriggers/*  的碰撞盒 → 关口标记（顺便解决"玩家不知道能走出地图"的缺口）
##   - Player          的位置   → 玩家方点，每帧跟随
##
## 为什么不预烘焙一张小地图贴图：地图是生成器产出的，烘焙的贴图会随地图改动过期。
## 而读格子只做一次（进图时），之后每帧只重画玩家点。
##
## 代价：地图必须有一个叫 CliffTileMap 的 TileMap（三张地图都满足）。
## 没有的话自己藏起来，不报错。

const CELL_SIZE := 32.0   ## 崖壁格的边长（世界像素）
const CELL_PX := 2        ## 1 个崖壁格在小地图上占几像素
const FRAME := 4          ## 木框厚度
const TITLE_H := 11       ## 底部地图名条高度
const MARGIN_RIGHT := 6.0 ## 距屏幕右边缘
## 距屏幕上边缘。金币计数器已挪去左下角，右上角整块让给小地图，所以贴边放。
## （toast 浮条的底板在 y 22..46、x 10..310，会被小地图压住；
##   但 toast 文字最长只到 x≈218，钻不到小地图下面，实测确认。）
const MARGIN_TOP := 6.0

# —— 配色：灰暗的崖壁 / 明亮的可行走区，对比拉开才好认 ——
const C_GRASS := Color(0.32, 0.50, 0.26)  ## 可行走草地
const C_ROAD := Color(0.64, 0.50, 0.32)   ## 泥路
const C_CLIFF := Color(0.22, 0.15, 0.12)  ## 崖壁
const C_GATE := Color(1.00, 0.78, 0.25)   ## 关口
const C_ME := Color(0.98, 0.98, 0.94)     ## 玩家
const C_ME_OUT := Color(0.10, 0.08, 0.06) ## 玩家描边

# —— 木框 ——
const C_RIM := Color(0.11, 0.07, 0.05)    ## 最外描边 / 内缝
const C_WOOD := Color(0.36, 0.22, 0.13)   ## 木框主体
const C_BEVEL := Color(0.56, 0.37, 0.21)  ## 左上受光面
const C_RIVET := Color(0.85, 0.68, 0.30)  ## 四角铆钉

var _tex: ImageTexture = null             ## 静态部分（草地+崖壁+泥路）的 1px/格 贴图
var _ready_map := false
var _cols := 0
var _rows := 0
var _origin_world := Vector2.ZERO         ## 崖壁包围盒左上角在世界里的坐标
var _view := Rect2()                      ## 地图绘制区（本 Control 的局部坐标）
var _gates: Array[Vector2i] = []          ## 关口所在的小地图格
var _player: Node2D = null
var _player_px := Vector2.ZERO            ## 玩家在小地图上的像素点（_view 内相对坐标）

@onready var _name_label: Label = get_node_or_null("NameLabel")

func _ready() -> void:
	# 显式指定最近邻，避免 2 倍放大时像素画发虚
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 进图前（主菜单）不显示；set_map() 成功后才亮出来
	visible = false

## 由 HUD.set_map() 调用。map_root 为 null 表示离开地图。
func set_map(map_root: Node, map_name: String) -> void:
	_tex = null
	_player = null
	_gates.clear()
	_ready_map = false

	if _name_label != null:
		_name_label.text = map_name

	# 显式声明类型，不靠 := 推断 —— 这个项目里跨 autoload/三元表达式推断踩过坑
	var cliff: TileMap = null
	if map_root != null:
		cliff = map_root.get_node_or_null("CliffTileMap") as TileMap
	if cliff == null:
		visible = false
		return
	var cells := cliff.get_used_cells(0)
	if cells.is_empty():
		visible = false
		return

	# 1) 崖壁包围盒 = 整张地图的范围
	var mn := cells[0]
	var mx := cells[0]
	for c in cells:
		mn.x = mini(mn.x, c.x)
		mn.y = mini(mn.y, c.y)
		mx.x = maxi(mx.x, c.x)
		mx.y = maxi(mx.y, c.y)
	_cols = mx.x - mn.x + 1
	_rows = mx.y - mn.y + 1

	# 2) 包围盒左上角的世界坐标。
	#    用 TileMap 自己的变换算，不假设它在 (0,0) —— 三张图的 CliffTileMap 都在 (-1,0)。
	#    map_to_local(格) 给的是格子**中心**，减去 map_to_local(0,0)（即半格）就得到左上角。
	_origin_world = cliff.to_global(cliff.map_to_local(mn)) - cliff.map_to_local(Vector2i.ZERO)

	# 3) 铺静态底图：先整块草地，再压崖壁，最后铺泥路（不覆盖崖壁）
	var img := Image.create_empty(_cols, _rows, false, Image.FORMAT_RGBA8)
	img.fill(C_GRASS)
	var cliff_set := {}
	for c in cells:
		var idx := c - mn
		cliff_set[idx] = true
		img.set_pixelv(idx, C_CLIFF)

	var dirt: TileMap = null
	if map_root != null:
		dirt = map_root.get_node_or_null("DirtPathTileMap") as TileMap
	if dirt != null:
		for dc in dirt.get_used_cells(0):
			var di := _world_to_index(dirt.to_global(dirt.map_to_local(dc)))
			if _in_bounds(di) and not cliff_set.has(di):
				img.set_pixelv(di, C_ROAD)

	_tex = ImageTexture.create_from_image(img)

	# 4) 关口标记
	var triggers := map_root.get_node_or_null("EdgeTriggers")
	if triggers != null:
		for t in triggers.get_children():
			var gi := _world_to_index(_trigger_world_pos(t))
			if _in_bounds(gi):
				_gates.append(gi)

	# 5) 玩家
	_player = map_root.get_node_or_null("Player") as Node2D

	# 6) 定位：右上角，锚在右边缘，面板宽度由地图决定（各图长宽不同）
	var vw := _cols * CELL_PX
	var vh := _rows * CELL_PX
	_view = Rect2(FRAME, FRAME, vw, vh)
	var total := Vector2(vw + FRAME * 2, vh + FRAME * 2 + TITLE_H)

	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -MARGIN_RIGHT - total.x
	offset_right = -MARGIN_RIGHT
	offset_top = MARGIN_TOP
	offset_bottom = MARGIN_TOP + total.y
	custom_minimum_size = total

	_ready_map = true
	visible = true
	_update_player_px()
	queue_redraw()

func _process(_delta: float) -> void:
	# 主菜单里 HUD 整体隐藏；地图被释放后 _player 会失效 —— 两种情况都不用画。
	if not _ready_map or not is_visible_in_tree():
		return
	if _player == null or not is_instance_valid(_player):
		return
	var before := _player_px
	_update_player_px()
	# 只有玩家跨到新的小地图像素才重画，静止时不做无用功
	if before != _player_px:
		queue_redraw()

func _draw() -> void:
	if not _ready_map:
		return
	var w := size.x
	var h := size.y

	# 木框：外描边 → 木体 → 左上受光
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), C_RIM)
	draw_rect(Rect2(Vector2(1, 1), Vector2(w - 2, h - 2)), C_WOOD)
	draw_rect(Rect2(Vector2(1, 1), Vector2(w - 2, 1)), C_BEVEL)
	draw_rect(Rect2(Vector2(1, 1), Vector2(1, h - 2)), C_BEVEL)

	# 地图本体（1px/格 贴图拉伸到 _view，整数倍缩放 + 最近邻 = 锐利）
	if _tex != null:
		draw_texture_rect(_tex, _view, false)
	draw_rect(_view.grow(1), C_RIM, false)

	# 关口
	for g in _gates:
		draw_rect(Rect2(_view.position + Vector2(g.x, g.y) * CELL_PX, Vector2(CELL_PX, CELL_PX)), C_GATE)

	# 玩家：5×5 深色底 + 3×3 亮芯，在这么小的图上最醒目
	if _player != null and is_instance_valid(_player):
		var c := _view.position + _player_px
		draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), C_ME_OUT)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), C_ME)

	# 四角铆钉，和游戏里的木箱/篝火一个质感
	for corner in [Vector2(2, 2), Vector2(w - 3, 2), Vector2(2, h - 3), Vector2(w - 3, h - 3)]:
		draw_rect(Rect2(corner, Vector2(1, 1)), C_RIVET)

func _update_player_px() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var rel := (_player.global_position - _origin_world) / CELL_SIZE * CELL_PX
	# 取整：像素画不该出现半像素的方点
	_player_px = Vector2(roundf(rel.x), roundf(rel.y))

## 世界坐标 → 小地图格。用 floori 而不是 roundi：格子按左上角归属。
func _world_to_index(world: Vector2) -> Vector2i:
	var rel := (world - _origin_world) / CELL_SIZE
	return Vector2i(floori(rel.x), floori(rel.y))

func _in_bounds(idx: Vector2i) -> bool:
	return idx.x >= 0 and idx.y >= 0 and idx.x < _cols and idx.y < _rows

## 边缘触发器的位置在它的 CollisionShape2D 上（触发器自己摆在 (0,0)）。
func _trigger_world_pos(t: Node) -> Vector2:
	for ch in t.get_children():
		if ch is CollisionShape2D:
			return (ch as CollisionShape2D).global_position
	return (t as Node2D).global_position if t is Node2D else Vector2.ZERO
