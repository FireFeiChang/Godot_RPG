extends Control
## 血量 HUD：心形条 + 数值。
##
## 心形图标每个 15px 宽，上限一高就会撑爆 320px 视口（50 滴血 = 750px），
## 所以心形条最多画 MAX_HEARTS 个，精确数值由下面的 "当前/上限" 文字承担。

## 心形条最多显示几个（防止高血量时撑爆屏幕）。
const MAX_HEARTS := 10
## 每个心形图标占的宽度（与原实现一致）。
const HEART_W := 15.0

var heart : int = 5 : set = set_heart
var max_heart : int = 5 : set = set_max_heart

@onready var heartUIEmpty = $HeartUIEmpty
@onready var heartUIFull = $HeartUIFull
@onready var healthText: Label = $HealthText

func set_heart(value):
	heart = clamp(value, 0, max_heart)
	_refresh()

func set_max_heart(value):
	max_heart = max(value, 1)
	self.heart = min(heart, max_heart)
	_refresh()

func _refresh():
	if healthText != null:
		healthText.text = "%d/%d" % [heart, max_heart]
	if heartUIEmpty == null or heartUIFull == null:
		return
	# 心形条按比例缩放：上限高于 MAX_HEARTS 时，每颗心代表更多血量
	var shown_max: int = mini(max_heart, MAX_HEARTS)
	var ratio: float = float(shown_max) / float(max_heart)
	var filled: int = int(round(float(heart) * ratio))
	heartUIEmpty.size.x = float(shown_max) * HEART_W
	heartUIFull.size.x = float(clampi(filled, 0, shown_max)) * HEART_W

func _ready():
	self.max_heart = PlayerStates.max_health
	self.heart = PlayerStates.health
	PlayerStates.connect("max_health_changed", set_max_heart)
	PlayerStates.connect("health_changed", set_heart)
	_refresh()
