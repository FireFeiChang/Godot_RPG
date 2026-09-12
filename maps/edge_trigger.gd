extends Area2D
## 地图边缘触发器：玩家走进来就切到相邻地图，并在对方地图的同名 Spawns 标记处出现。
##
## 命名约定 —— 按「关口」命名，同一个关口在两侧用同一个名字：
##   world 里的 EdgeTriggers/NorthPass (target_map = "north")
##   north  里的 Spawns/NorthPass        ← 玩家从 world 过来时出现在这
## 关口名在每张地图内天然唯一，所以不会有重名冲突（不能按"来源地图"命名：
## world 有 north / east 两个出口，都叫 FromWorld 会撞名，Godot 会把第二个
## 改名成 @FromWorld@2，出生点就找不到了）。
## 名字请以字母开头（Godot 会把数字开头的名字改成 @123）。
##
## 节点配置要求：
##   collision_layer = 0
##   collision_mask  = 2   （只探玩家所在的 layer 2）
## body_entered 的掩码是单向的，玩家自己的 mask 是多少都无所谓。
## 不要用 mask = 1 —— 那会对树/灌木/宝箱/篝火等所有 StaticBody2D 触发。

@export var target_map: String = ""

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not body.has_method("player"):
		return
	if target_map == "":
		push_warning("EdgeTrigger %s 没有设置 target_map" % name)
		return
	MapManager.goto_map(target_map, String(name).trim_prefix("@"))
