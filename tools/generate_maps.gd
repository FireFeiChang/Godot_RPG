extends RefCounted
## 开发工具（不参与游戏运行）：程序化生成 map_north / map_east 两张地图。
##
## 用法：通过 Godot 编辑器的 MCP 执行桥调用 run()。
##
## 重要约束（都是实测踩过的坑）：
## 1. 崖壁/泥路必须用 set_cells_terrain_connect()，不能逐格 set_cell ——
##    前者会自动选出正确的转角/边缘图块。开口 = 从 cell 列表里剔除那几格。
## 2. 每个节点都要设 owner，否则 PackedScene.pack() 返回 OK 但存出空场景。
## 3. 绝不能引用 autoload（编辑器里没有 autoload）。
## 4. 蝙蝠/橡子甲虫必须是地图根的**直接子节点** —— 它们死后用
##    get_parent().add_child() 生成特效，塞进容器会跟着一起被释放。
## 5. 边界格数：开口必须把 2 格厚的崖壁**整条挖穿**（只挖一行仍是一堵墙）。

const CLIFF_TILESET := "res://World/CliffTileset.tres"
const DIRT_TILESET := "res://World/DirtTileset.tres"
const GRASS_BG := "res://World/GrassBackground.png"
const PLAYER_SCENE := "res://Player/player.tscn"

const S_GRASS := "res://World/grass.tscn"
const S_BUSH := "res://World/bush.tscn"
const S_TREE := "res://World/tree.tscn"
const S_CAMPFIRE := "res://World/campfire/campfire.tscn"
const S_VENT := "res://steam_vent.tscn"
const S_BAT := "res://Enemies/bat.tscn"
const S_ACORNBACK := "res://Enemies/acornback.tscn"
const S_GOBLIN := "res://Enemies/goblin.tscn"
const S_SLIME := "res://Enemies/slime.tscn"
const S_MIMIC := "res://Enemies/mimic.tscn"
const S_CHEST := "res://Enemies/chest/chest.tscn"
const S_ADVENTURER := "res://NPC/female_adventurer.tscn"

const TS := 32  # 崖壁格边长
## 崖壁环厚度（2 格）。
const RING := 64
## 游戏视口的一半（320x180）。相机边界按它外扩，保证相机总能居中玩家。
const HALF_VP := Vector2(160, 90)

## 本生成器自己 new 出来的节点（不含任何实例化子场景的内部节点）。
## pack() 前只给这些节点设 owner —— 实例内部节点归它们自己的场景管，
## 强行设 owner 会把子场景的 [connection] 复制进父场景，加载时报
## "Signal ... is already connected"。
var _own: Array = []


func _new_node(n: Node) -> Node:
	_own.append(n)
	return n


func run() -> Array:
	var out: Array = []
	out.append(_build_north())
	out.append(_build_east())
	return out


# ---------------------------------------------------------------- north
#
# 布局规范照抄 world.tscn（见 地图布局参考.md）：
#   一条贯通的主干道 + 若干条长度/宽度各异的垂直岔路，部分岔路末端展宽成广场；
#   敌人不是均匀撒点，而是「几处怪群 + 若干散兵」。
# 坐标说明：泥路是 16px 格（地图 96x50 格），崖壁是 32px 格（48x25 格）。
# 崖壁环厚 2 格 = 4 个泥路格，所以泥路只放在 x/y 5..90 / 5..45 内。

func _build_north() -> String:
	# --- 泥路：主干道 + 6 条岔路（长度/宽度各异，两条末端有广场）---
	var road := {}
	_road(road, 6, 22, 90, 23)          # 主干道（横贯）
	_road(road, 20, 22, 21, 44)         # 入口竖路（对准底部关口 px336）
	_road(road, 10, 6, 11, 22)          # 岔路A：北上最长，通到顶端
	_road(road, 34, 13, 35, 22)         # 岔路B：北上中等
	_road(road, 48, 9, 51, 22)          # 岔路C：北上较宽(4格)
	_road(road, 45, 5, 54, 9)           #   └ 末端广场
	_road(road, 8, 23, 9, 44)           # 岔路D：南下长
	_road(road, 66, 23, 67, 32)         # 岔路E：南下
	_road(road, 60, 33, 73, 40)         #   └ 末端院子（较宽，放宝箱）

	# --- 敌人：3 处怪群 + 5 只散兵（大群混搭兵种）---
	var foes := _cluster(1200, 200, [
		["bat", 5], ["acornback", 2], ["slime", 1]])          # 大怪群 8 只
	foes = _merge_foes(foes, _cluster(500, 250, [["bat", 3], ["acornback", 1]]))   # 中怪群 4 只
	foes = _merge_foes(foes, _cluster(860, 500, [["bat", 2]]))                     # 小怪群 2 只
	_add_foe(foes, "bat", Vector2(200, 620))                  # 散兵 ×5
	_add_foe(foes, "acornback", Vector2(850, 120))
	_add_foe(foes, "slime", Vector2(340, 420))
	_add_foe(foes, "goblin", Vector2(1380, 620))
	_add_foe(foes, "bat", Vector2(980, 300))

	var spec := {
		"id": "north",
		"path": "res://maps/map_north.tscn",
		"px_w": 1536,
		"px_h": 800,
		"tw": 48,
		"th": 25,
		# 开口：底部 x=9..11（对应 world 顶部开口 px 288..384，中心 336）
		"gates": [{"side": "bottom", "from": 9, "to": 11}],
		# 不加内部崖壁 —— 主世界 world.tscn 的崖壁是**纯外环**（内部格数 = 0），
		# 照它做才能保证图块接缝干净。
		"dirt": road.keys(),
		"player_start": Vector2(336, 700),
		# 关口名必须和 world 那侧的一致（world 用的是 NorthPass）
		"spawns": {"NorthPass": Vector2(336, 720)},
		"triggers": [{"name": "NorthPass", "target": "world", "size": Vector2(96, 64), "at": Vector2(336, 784)}],
		"campfire": [Vector2(200, 320)],
		"vents": [Vector2(1300, 560), Vector2(1420, 300)],
		"grass": _scatter_open(40, 120, 100, 1410, 700, road),
		"bush": _scatter_open(20, 120, 130, 1400, 690, road),
		"tree": _scatter_open(28, 100, 100, 1430, 690, road),
		"chests": [
			{"pos": Vector2(720, 112), "variant": 2},      # C 岔路末端广场
			{"pos": Vector2(1000, 590), "variant": 1},     # E 岔路院子
			{"pos": Vector2(1280, 380), "variant": 3},     # 东侧空地
		],
		"npc": [],
	}
	_apply_foes(spec, foes)
	return _generate(spec)


# ---------------------------------------------------------------- east
#
# 主题是开阔草原营地：主干道更宽(3格)、岔路更少、崖壁体量更小，敌人最多。

func _build_east() -> String:
	var road := {}
	_road(road, 6, 19, 90, 21)          # 主干道（横贯，3 格宽）
	_road(road, 14, 5, 16, 19)          # 岔路A：北上，3 格宽
	_road(road, 38, 11, 39, 19)         # 岔路B：北上
	_road(road, 64, 10, 68, 19)         # 岔路C：北上宽(5格)
	_road(road, 58, 5, 72, 10)          #   └ 营地广场
	_road(road, 24, 21, 25, 44)         # 岔路D：南下
	_road(road, 50, 21, 51, 44)         # 岔路E：南下最长
	_road(road, 76, 21, 78, 32)         # 岔路F：南下
	_road(road, 70, 33, 84, 42)         #   └ 末端大院子

	var foes := _cluster(1150, 230, [
		["bat", 5], ["goblin", 2], ["slime", 2], ["acornback", 1]])   # 大怪群 10 只
	foes = _merge_foes(foes, _cluster(420, 500, [["bat", 3], ["slime", 2]]))       # 中怪群 5 只
	foes = _merge_foes(foes, _cluster(900, 550, [["acornback", 2], ["goblin", 2]])) # 中怪群 4 只
	foes = _merge_foes(foes, _cluster(620, 180, [["bat", 3]]))                     # 小怪群 3 只
	_add_foe(foes, "bat", Vector2(250, 700))                  # 散兵 ×7
	_add_foe(foes, "acornback", Vector2(1350, 200))
	_add_foe(foes, "slime", Vector2(800, 700))
	_add_foe(foes, "goblin", Vector2(1200, 300))
	_add_foe(foes, "bat", Vector2(350, 300))
	_add_foe(foes, "slime", Vector2(1050, 620))
	_add_foe(foes, "mimic", Vector2(600, 400))
	var mimics := _cluster(880, 640, [["mimic", 1]])
	foes = _merge_foes(foes, mimics)

	var spec := {
		"id": "east",
		"path": "res://maps/map_east.tscn",
		"px_w": 1536,
		"px_h": 800,
		"tw": 48,
		"th": 25,
		# 开口：左侧 y=8..10（对应 world 右侧开口 px 256..352，中心 304）
		"gates": [{"side": "left", "from": 8, "to": 10}],
		# 同上：不加内部崖壁，与主世界保持一致
		"dirt": road.keys(),
		"player_start": Vector2(160, 328),
		# 关口名必须和 world 那侧的一致（world 用的是 EastPass）
		"spawns": {"EastPass": Vector2(110, 328)},
		"triggers": [{"name": "EastPass", "target": "world", "size": Vector2(64, 96), "at": Vector2(16, 328)}],
		"campfire": [Vector2(1120, 200)],
		"vents": [Vector2(1420, 620), Vector2(700, 120)],
		"grass": _scatter_open(55, 110, 100, 1440, 700, road),
		"bush": _scatter_open(26, 110, 110, 1430, 690, road),
		"tree": _scatter_open(34, 100, 620, 1450, 710, road) + _scatter_open(6, 200, 120, 700, 290, road),
		"chests": [
			{"pos": Vector2(1160, 150), "variant": 2},     # 营地
			{"pos": Vector2(1400, 150), "variant": 3},     # 东北角
			{"pos": Vector2(760, 600), "variant": 1},      # 平原中
			{"pos": Vector2(330, 690), "variant": 0},      # 南侧
		],
		# 东原冒险者 =「东原探险线」发布者。
		# 键名必须与 female_adventurer.gd 的 @export 一致（是 task_ids 复数，
		# 且是 PackedStringArray）。这里的配置要与 map_east.tscn 里的手工值保持一致，
		# 否则重跑生成器会把场景覆盖回去、任务链丢失。
		"npc": [{
			"pos": Vector2(1180, 300),
			"dialogue_path": "res://NPC/TestAdventurer.dialogue",
			"task_ids": PackedStringArray(["east_slimes", "east_goblins", "east_chests"]),
			"all_done_title": "all_done",
		}],
	}
	_apply_foes(spec, foes)
	return _generate(spec)


## 把怪群字典写进 spec 的各兵种数组（缺的补空数组）。
func _apply_foes(spec: Dictionary, foes: Dictionary) -> void:
	spec["bats"] = foes.get("bat", [])
	spec["acornbacks"] = foes.get("acornback", [])
	spec["slimes"] = foes.get("slime", [])
	spec["goblins"] = foes.get("goblin", [])
	spec["mimics"] = foes.get("mimic", [])


## 铺一段矩形泥路（16px 格，闭合区间），写进 road 集合去重。
func _road(road: Dictionary, x0: int, y0: int, x1: int, y1: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			road[Vector2i(x, y)] = true


## 在范围内散布 n 个点，但避开泥路（至少留 1 格边距，免得道具压在路面上）。
## 用黄金角螺旋 —— 确定性可复现，且比均匀网格自然。
func _scatter_open(n: int, x0: int, y0: int, x1: int, y1: int, road: Dictionary) -> Array:
	var out := []
	var placed := 0
	var i := 0
	var tries := 0
	while placed < n and tries < n * 40:
		tries += 1
		var ang := float(i) * 2.399963
		var t := float(i) / float(max(1, n))
		var r := sqrt(t) * 0.5
		var px := float(x0 + x1) * 0.5 + cos(ang) * r * float(x1 - x0)
		var py := float(y0 + y1) * 0.5 + sin(ang) * r * float(y1 - y0)
		i += 1
		if px < x0 or px > x1 or py < y0 or py > y1:
			continue
		# 避开泥路（16px 格，留 1 格边距）
		var gx := int(floor(px / 16.0))
		var gy := int(floor(py / 16.0))
		var on_road := false
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if road.has(Vector2i(gx + dx, gy + dy)):
					on_road = true
		if on_road:
			continue
		out.append(Vector2(px, py))
		placed += 1
	return out


## 生成一团怪群：以 (cx,cy) 为中心、半径内混搭多种兵种。
## 返回 {"bat": [Vector2...], "goblin": [...]} 形式的字典。
## 用黄金角螺旋散布 —— 确定性、不需要随机数（生成器要求可复现）。
func _cluster(cx: int, cy: int, mix: Array) -> Dictionary:
	var out := {}
	var total := 0
	for m in mix:
		total += int(m[1])
	var i := 0
	var radius := 74.0
	for m in mix:
		var arr := []
		for _k in range(int(m[1])):
			var ang := float(i) * 2.399963        # 黄金角，分布均匀不结块
			var r := radius * sqrt(float(i + 1) / float(max(1, total)))
			arr.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r * 0.72))
			i += 1
		out[String(m[0])] = arr
	return out


## 把两团怪群合并（同兵种追加）。
func _merge_foes(a: Dictionary, b: Dictionary) -> Dictionary:
	for k in b:
		if a.has(k):
			a[k].append_array(b[k])
		else:
			a[k] = b[k].duplicate()
	return a


## 往怪群字典里追加一只散兵。
func _add_foe(foes: Dictionary, kind: String, pos: Vector2) -> void:
	if not foes.has(kind):
		foes[kind] = []
	foes[kind].append(pos)



# ---------------------------------------------------------------- 核心生成

func _generate(spec: Dictionary) -> String:
	_own.clear()   # 同一个实例会连跑两张图，每张都要从空列表开始
	var root := Node2D.new()
	root.name = spec["id"]
	root.y_sort_enabled = true
	root.set_script(load("res://maps/world_map.gd"))

	# --- 相机边界 ---
	# 相机中心被钳在 [limit_left+半视口, limit_right-半视口]。要让相机能一直把玩家
	# 摆在画面正中，边界必须放宽到「玩家可达范围 ± 半个视口」。
	# 玩家可达范围 = 崖壁环内沿，即 [RING, px - RING]。
	# 只把边界设成地图尺寸会让玩家走到边缘时相机先一步停住 —— 表现为"走一段就不跟随"。
	var play_min_x := float(RING)
	var play_max_x := float(spec["px_w"] - RING)
	var play_min_y := float(RING)
	var play_max_y := float(spec["px_h"] - RING)
	var lim_left := play_min_x - HALF_VP.x
	var lim_right := play_max_x + HALF_VP.x
	var lim_top := play_min_y - HALF_VP.y
	var lim_bottom := play_max_y + HALF_VP.y

	# --- 背景 ---
	# 铺满整个相机可见范围（1:1 平铺，不做缩放 —— 缩放像素画会发虚）。
	# 64px 对齐可避免边缘出现半块草地。
	#
	# ⚠️ region_rect 的 position 是**纹理偏移**，不是世界坐标定位：
	# 它只决定从纹理的哪一点开始采样，绘制起点永远是节点自身的 position。
	# 所以"把区域挪到世界某处"必须靠 position，region_rect 的 position 恒为 0。
	# （早先把世界坐标写进 region_rect.position，结果只画出了第四象限。）
	var bg_x0 := floorf(lim_left / 64.0) * 64.0
	var bg_y0 := floorf(lim_top / 64.0) * 64.0
	var bg_x1 := ceilf(lim_right / 64.0) * 64.0
	var bg_y1 := ceilf(lim_bottom / 64.0) * 64.0
	var bg := _new_node(Sprite2D.new()) as Sprite2D
	bg.name = "Background"
	bg.y_sort_enabled = true
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.texture = load(GRASS_BG)
	bg.centered = false
	bg.position = Vector2(bg_x0, bg_y0)
	bg.region_enabled = true
	bg.region_rect = Rect2(0, 0, bg_x1 - bg_x0, bg_y1 - bg_y0)
	root.add_child(bg)

	# --- 泥路 ---
	var dirt := _new_node(TileMap.new()) as TileMap
	dirt.name = "DirtPathTileMap"
	dirt.tile_set = load(DIRT_TILESET)
	dirt.format = 2
	root.add_child(dirt)
	dirt.set_cells_terrain_connect(0, spec["dirt"], 0, 0)

	# --- 崖壁 ---
	# 用与主世界完全一致的显式图块规则（见 _place_cliff_tiles），
	# 不要用 set_cells_terrain_connect —— 见该函数注释说明原因。
	var cliff := _new_node(TileMap.new()) as TileMap
	cliff.name = "CliffTileMap"
	cliff.position = Vector2(-1, 0)
	cliff.tile_set = load(CLIFF_TILESET)
	cliff.format = 2
	root.add_child(cliff)
	_place_cliff_tiles(cliff, _cliff_cells(spec))

	# --- 相机 ---
	var cam := _new_node(Camera2D.new()) as Camera2D
	cam.name = "Camera2D"
	cam.position = spec["player_start"]
	cam.limit_left = int(lim_left)
	cam.limit_top = int(lim_top)
	cam.limit_right = int(lim_right)
	cam.limit_bottom = int(lim_bottom)
	# 不开位置平滑：Camera2D.position_smoothing_speed 单位是「像素/秒」，
	# 默认 5.0 远低于玩家 100 px/秒的移动速度，相机会永远追不上。
	# 关掉后硬跟随，行为可预测（world_map.gd 里也会再确保一次）。
	cam.position_smoothing_enabled = false
	root.add_child(cam)

	# --- 玩家 ---
	# 相机跟随用的 RemoteTransform2D 故意不在这里建：
	# Godot 的 PackedScene.pack() 无法序列化"加到实例化节点内部的子节点"
	# （实测：不管 owner 设成 root 还是实例根，都会被丢弃），
	# 所以改由 maps/world_map.gd 在 _ready() 里补挂，见该脚本。
	var player: Node2D = load(PLAYER_SCENE).instantiate()
	player.name = "Player"
	player.y_sort_enabled = true
	player.position = spec["player_start"]
	root.add_child(player)
	_own.append(player)   # Player 是实例，但它本身是地图根的直接子节点，必须设 owner 才会被存下

	# --- 出生点 ---
	var spawns := _new_node(Node2D.new()) as Node2D
	spawns.name = "Spawns"
	root.add_child(spawns)
	var spawn_dict: Dictionary = spec["spawns"]
	for k in spawn_dict:
		var m := _new_node(Marker2D.new()) as Marker2D
		m.name = k
		m.position = spawn_dict[k]
		spawns.add_child(m)

	# --- 道具 ---
	_add_props(root, "Grass", S_GRASS, spec["grass"])
	_add_props(root, "Bushes", S_BUSH, spec["bush"])
	_add_props(root, "Tree", S_TREE, spec["tree"])
	_add_props(root, "Campfires", S_CAMPFIRE, spec["campfire"])
	_add_props(root, "SteamVents", S_VENT, spec["vents"])

	# --- 敌人：必须是地图根的直接子节点（见文件头第 4 条） ---
	_add_props(root, "", S_BAT, spec["bats"], "Bat")
	_add_props(root, "", S_ACORNBACK, spec["acornbacks"], "Acornback")
	_add_props(root, "", S_SLIME, spec["slimes"], "Slime")
	_add_props(root, "", S_GOBLIN, spec["goblins"], "Goblin")
	_add_props(root, "", S_MIMIC, spec["mimics"], "Mimic")

	# --- 宝箱 ---
	var chests := _new_node(Node2D.new()) as Node2D
	chests.name = "Chests"
	chests.y_sort_enabled = true
	root.add_child(chests)
	var ci := 0
	for c in spec["chests"]:
		var inst: Node2D = load(S_CHEST).instantiate()
		inst.name = "Chest%d" % ci
		inst.position = c["pos"]
		inst.set("variant", c["variant"])
		chests.add_child(inst)
		inst.owner = root
		ci += 1

	# --- NPC ---
	var ni := 0
	for n in spec["npc"]:
		var inst: Node2D = load(S_ADVENTURER).instantiate()
		inst.name = "Adventurer%d" % ni
		inst.position = n["pos"]
		# spec 里除 pos 之外的键全部按 @export 属性名写入。
		# 用循环而不是逐个 set()：属性名拼错、或脚本改了导出名（task_id -> task_ids）
		# 时不会静默失效 —— set() 对不存在的属性会直接报错，比"看起来生成了但没接上"好查。
		for key in n:
			if key != "pos":
				inst.set(key, n[key])
		root.add_child(inst)
		inst.owner = root
		ni += 1

	# --- 边缘触发器 ---
	var trigs := _new_node(Node2D.new()) as Node2D
	trigs.name = "EdgeTriggers"
	root.add_child(trigs)
	for t in spec["triggers"]:
		var area := _new_node(Area2D.new()) as Area2D
		area.name = t["name"]
		area.set_script(load("res://maps/edge_trigger.gd"))
		area.set("target_map", t["target"])
		area.collision_layer = 0
		area.collision_mask = 2  # 只探玩家层，不要用 1（会对所有装饰物触发）
		var cs := _new_node(CollisionShape2D.new()) as CollisionShape2D
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = t["size"]
		cs.shape = rect
		cs.position = t["at"]
		area.add_child(cs)
		trigs.add_child(area)

	# --- 关键：所有后代都要有 owner，否则存出空场景 ---
	_own_all(root)

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	if perr != OK:
		root.free()
		return "%s: pack 失败 %d" % [spec["id"], perr]
	var serr := ResourceSaver.save(packed, spec["path"])
	var n := root.get_child_count()
	root.free()
	if serr != OK:
		return "%s: 保存失败 %d" % [spec["id"], serr]
	return "%s: OK (%d 个子节点)" % [spec["id"], n]


## 给"本生成器自己 new 出来的节点"设 owner。
##
## 关键：owner 只能设给本场景自建的节点。绝不能递归进实例化子场景的内部
## （Player/Grass/Bat 等的子孙）—— 那样 pack() 会把子场景内部的 [connection]
## 一并烙进父场景，而子场景自己已经连过一遍，加载时就会刷
## "Signal ... is already connected"，切图直接报一屏错。
##
## 用显式登记（_new_node）而不是靠 scene_file_path 判断：Player 是实例，
## 但我们往它身上**加**了一个 RemoteTransform2D，那个是我们建的，必须设 owner，
## 否则会被 pack() 丢掉，相机就不再跟随玩家。
func _own_all(root: Node) -> void:
	for n in _own:
		if is_instance_valid(n):
			n.owner = root


## 实例化一组道具/敌人到容器（container_name 为空则挂到根下）。
func _add_props(root: Node, container_name: String, scene_path: String, positions: Array, prefix: String = "") -> void:
	if positions.is_empty():
		return
	var parent: Node = root
	if container_name != "":
		parent = _new_node(Node2D.new())
		parent.name = container_name
		parent.y_sort_enabled = true
		root.add_child(parent)
	var base := prefix if prefix != "" else container_name.trim_suffix("s")
	var i := 0
	for p in positions:
		var inst: Node2D = load(scene_path).instantiate()
		inst.name = "%s%d" % [base, i]
		inst.position = p
		parent.add_child(inst)
		inst.owner = root
		i += 1


## 组装崖壁 cell 列表：外圈 2 格厚环 + 内部体量，再挖掉开口。
func _cliff_cells(spec: Dictionary) -> Array:
	var tw: int = spec["tw"]
	var th: int = spec["th"]
	var cells := {}

	# 外圈：上下各 2 行、左右各 2 列
	for x in range(tw):
		for y in [0, 1, th - 2, th - 1]:
			cells[Vector2i(x, y)] = true
	for y in range(th):
		for x in [0, 1, tw - 2, tw - 1]:
			cells[Vector2i(x, y)] = true

	# 开口：整条挖穿（2 格厚）
	for g in spec["gates"]:
		var a: int = g["from"]
		var b: int = g["to"]
		match g["side"]:
			"bottom":
				for x in range(a, b + 1):
					cells.erase(Vector2i(x, th - 1))
					cells.erase(Vector2i(x, th - 2))
			"top":
				for x in range(a, b + 1):
					cells.erase(Vector2i(x, 0))
					cells.erase(Vector2i(x, 1))
			"left":
				for y in range(a, b + 1):
					cells.erase(Vector2i(0, y))
					cells.erase(Vector2i(1, y))
			"right":
				for y in range(a, b + 1):
					cells.erase(Vector2i(tw - 1, y))
					cells.erase(Vector2i(tw - 2, y))

	return cells.keys()


## 按**主世界 world.tscn 的实际用法**逐格指定崖壁图块。
##
## 为什么不用 set_cells_terrain_connect()：
##   这个图集虽然定义了 terrain，但 peering bits 不自洽 —— 实测把一个**纯外环**
##   喂给 terrain_connect，它会选出 (5,1)(6,1)(5,2)(6,2)(4,1)(8,1)(9,1)(5,4) 等
##   十几种"碎石/立柱"图块，拼出来是一段段**断开的墙**，到处是缺口。
##   （world.tscn 是手工摆的，只用下面这 12 种，所以干净连续。）
##
## 下面的规则是**从 world.tscn 逐格逆向出来并全部验证过**的：
##   以闭环范围 X0..X1 × Y0..Y1 为基准，2 格厚：
##     顶外层 y=Y0       → (1,0) 面；(0,0)/(2,0) 两端
##     顶内层 y=Y0+1     → (1,2) 面；(0,1)/(2,1) 两侧；(1,1) 两个内转角
##     底外层 y=Y1       → (1,2) 面；(0,2)/(2,2) 两端
##     底内层 y=Y1-1     → (1,0) 面；(0,1)/(2,1) 两侧；(5,2)/(6,2) 两个内转角
##     左外层 x=X0       → (0,1) 面；(0,0)/(0,2) 两端
##     左内层 x=X0+1     → (2,1) 面；(1,0)/(1,2) 两端；(1,1)/(5,2) 转角
##     右外层 x=X1       → (2,1) 面；(2,0)/(2,2) 两端
##     右内层 x=X1-1     → (0,1) 面；(1,0)/(1,2) 两端；(1,1)/(6,2) 转角
##   开口处的断口靠"邻居缺失"判定，自动补端头：(2,0)/(2,2)/(0,0)/(0,2) 等。
func _place_cliff_tiles(cliff: TileMap, cells: Array) -> void:
	var SRC := 1
	var in_ring := {}
	for c in cells:
		in_ring[c] = true

	var minx := 999999
	var maxx := -999999
	var miny := 999999
	var maxy := -999999
	for c in cells:
		minx = mini(minx, c.x)
		maxx = maxi(maxx, c.x)
		miny = mini(miny, c.y)
		maxy = maxi(maxy, c.y)

	for c in cells:
		var x: int = c.x
		var y: int = c.y
		var on_top_outer := y == miny
		var on_top_inner := y == miny + 1
		var on_bot_outer := y == maxy
		var on_bot_inner := y == maxy - 1
		var on_left_outer := x == minx
		var on_left_inner := x == minx + 1
		var on_right_outer := x == maxx
		var on_right_inner := x == maxx - 1
		# 断口判定：该方向的邻居是否还在环里
		var no_left := not in_ring.has(Vector2i(x - 1, y))
		var no_right := not in_ring.has(Vector2i(x + 1, y))
		var no_up := not in_ring.has(Vector2i(x, y - 1))
		var no_down := not in_ring.has(Vector2i(x, y + 1))
		var tile := Vector2i(1, 0)

		if on_top_outer:
			if on_left_outer:
				tile = Vector2i(0, 0)
			elif on_right_outer:
				tile = Vector2i(2, 0)
			elif no_right:
				tile = Vector2i(2, 0)
			elif no_left:
				tile = Vector2i(0, 0)
			else:
				tile = Vector2i(1, 0)
		elif on_top_inner:
			if on_left_outer:
				tile = Vector2i(0, 1)
			elif on_right_outer:
				tile = Vector2i(2, 1)
			elif on_left_inner or on_right_inner:
				tile = Vector2i(1, 1)
			elif no_right:
				tile = Vector2i(2, 2)
			elif no_left:
				tile = Vector2i(0, 2)
			else:
				tile = Vector2i(1, 2)
		elif on_bot_outer:
			if on_left_outer:
				tile = Vector2i(0, 2)
			elif on_right_outer:
				tile = Vector2i(2, 2)
			else:
				tile = Vector2i(1, 2)
		elif on_bot_inner:
			if on_left_outer:
				tile = Vector2i(0, 1)
			elif on_right_outer:
				tile = Vector2i(2, 1)
			elif on_left_inner:
				tile = Vector2i(5, 2)
			elif on_right_inner:
				tile = Vector2i(6, 2)
			else:
				tile = Vector2i(1, 0)
		elif on_left_outer:
			tile = Vector2i(0, 1)
		elif on_right_outer:
			if no_up:
				tile = Vector2i(2, 2)
			elif no_down:
				tile = Vector2i(2, 0)
			else:
				tile = Vector2i(2, 1)
		elif on_left_inner:
			if no_up:
				tile = Vector2i(0, 2)
			elif no_down:
				tile = Vector2i(0, 0)
			else:
				tile = Vector2i(2, 1)
		elif on_right_inner:
			if no_up:
				tile = Vector2i(0, 2)
			elif no_down:
				tile = Vector2i(0, 0)
			else:
				tile = Vector2i(0, 1)
		else:
			tile = Vector2i(1, 0)

		cliff.set_cell(0, Vector2i(x, y), SRC, tile, 0)


## 生成一个矩形区域的格（闭区间）。
func _rect_cells(x0: int, y0: int, x1: int, y1: int) -> Array:
	var out := []
	for x in range(min(x0, x1), max(x0, x1) + 1):
		for y in range(min(y0, y1), max(y0, y1) + 1):
			out.append(Vector2i(x, y))
	return out
