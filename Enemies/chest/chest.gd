@tool
extends StaticBody2D
## 宝箱：挥剑开启 → 播开箱动画 → 掉 1~3 件 RPG 道具（世界拾取物）。
## 外观统一使用 Silver 银箱（Enemies/chest/chest_silver.png 八帧开箱）；
## 等级(Tier)只决定掉落池，不影响画风。开完动画结束即销毁（掉落物已加进场景）。
## 帧图在运行时按格从竖条图切出；@tool 让编辑器里也能实时显示贴图。
## 注意：@tool 下 _ready 只做纯视觉搭建，不触碰玩法逻辑/场景树之外的资源。

enum Tier { CRAZY, GOLD, SILVER, KING }

const DropItemScene = preload("res://drop_item.tscn")

## 银箱开箱动画帧图竖条（8 格，每格 FRAME_W × FRAME_H）
const STRIP := preload("res://Enemies/chest/chest_silver.png")
const FRAME_COUNT := 8
const FRAME_W := 62
const FRAME_H := 56
## 开箱动画节奏（想再慢把 FRAME_DURATION 调大 / FRAME_FPS 调小）
const FRAME_DURATION := 1.5      # 每帧相对时长（2.0 ÷ fps10 = 0.2 秒/帧）
const FRAME_FPS := 10.0

## 精灵纵向偏移：把“箱底”对齐到节点原点(地面)。
const BASE_OFFSET_Y := -15.0

## 等级 → 掉落池（物品 id；在此增删即可）
const LOOT_POOLS := {
	Tier.CRAZY: ["bucket", "torch", "bedroll", "campfire", "signpost", "cooking_pot"],
	Tier.GOLD: ["torch", "campfire", "cooking_pot", "bucket", "bedroll", "backpack", "tent"],
	Tier.SILVER: ["map_rolled", "compass", "spyglass", "backpack", "tent", "cooking_pot", "coin_pouch", "grappling_hook"],
	Tier.KING: ["gemstone", "key_iron", "chest_closed", "coin_pouch", "grappling_hook", "map_rolled", "compass", "spyglass"],
}

@export var variant: Tier = Tier.GOLD
@export_range(1, 3) var drop_count_min: int = 1
@export_range(1, 3) var drop_count_max: int = 2
@export_range(0.3, 1.6, 0.05) var body_scale: float = 0.8

var opened := false
var _opening := false

@onready var animated: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: Area2D = $HurtBox
@onready var shadow: Sprite2D = $Shadow

func _ready():
	animated.scale = Vector2.ONE * body_scale
	animated.offset = Vector2(0, BASE_OFFSET_Y)
	_build_frames()          # 内部已切帧并停在盖帧
	# 地面阴影：略宽于箱体（LargeShadow 32×20，随 body_scale 微调宽度）
	shadow.scale = Vector2(body_scale * 1.5, body_scale * 0.75)

## 把银箱竖条切成 “Open” 动画（循环关、速度可调）。
## 帧由代码运行时重建（不写入 .tscn），时长/速度只能在此调整——
## 编辑器里直接改检查器不会生效（重载即被覆盖）。duration 是相对值：
## 绝对秒数 = duration / animation_fps，duration=2.0、fps=10 → 0.2 秒/帧，8 帧约 1.6 秒。
func _build_frames():
	var strip: Texture2D = STRIP
	var frames := SpriteFrames.new()
	frames.add_animation("Open")          # 空 SpriteFrames 需先建动画，才能 add_frame
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * FRAME_W, 0, FRAME_W, FRAME_H)
		frames.add_frame("Open", atlas, FRAME_DURATION)
	frames.set_animation_loop("Open", false)
	frames.set_animation_speed("Open", FRAME_FPS)
	animated.sprite_frames = frames
	animated.animation = "Open"
	animated.frame = 0
	animated.stop()          # 停在全盖帧，等待被攻击

func _on_hurt_box_area_entered(area):
	if opened or _opening:
		return
	# 只响应挥剑命中（脚本路径含 hit_box），其他 Area 忽略
	if area.get_script().resource_path.find("hit_box") == -1:
		return
	_open()

func _open():
	_opening = true
	hurt_box.set_deferred("monitoring", false)  # 开启过程不再响应
	animated.play("Open")
	# 广播开箱事件（在"开箱动作开始"这一刻记，而不是 loot 生成之后）。
	# 宝箱开完就 queue_free，所以这里不会被重复触发。
	TaskManager.notify_progress("open:chest")

func _on_open_finished():
	_spawn_loot()             # 掉落物在 current_scene 下生成，随宝箱销毁仍保留
	queue_free()              # 开完即消失（不再占用地面/碰撞）

## 从当前等级的掉落池抽 drop_count_min~max 件（不重复），散落在箱前拾取。
func _spawn_loot():
	var pool: Array = LOOT_POOLS.get(variant, [])
	if pool.is_empty():
		return
	var bag := pool.duplicate()
	bag.shuffle()
	var count := mini(randi_range(drop_count_min, drop_count_max), bag.size())
	for i in count:
		var item: InvItem = Inventory.get_item(bag[i])
		if item == null:
			continue
		var drop = DropItemScene.instantiate()
		drop.item = item
		drop.amount = 1
		# 扇形铺开在箱体下方(正前方)，落点偏 y>0 地面，避免重叠/卡箱体
		var spread := 16.0 + (i % 3) * 8.0
		var t := 0.5 if float(count) == 1.0 else float(i) / float(count - 1)
		var ang := deg_to_rad(lerpf(20.0, 160.0, t))   # 20°~160° 向下扇形
		drop.global_position = global_position + Vector2(cos(ang), sin(ang)) * spread
		drop.global_position.y += 8.0
		get_tree().current_scene.add_child(drop)
