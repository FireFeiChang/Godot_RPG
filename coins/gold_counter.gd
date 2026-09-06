extends Control
## HUD 金币余额：右上角一枚金币图标 + 数字。
## 监听 Wallet.gold_changed 自动刷新。

@onready var value_label: Label = $Value

func _ready():
	Wallet.gold_changed.connect(_refresh)
	_refresh(Wallet.gold)

func _refresh(total: int):
	value_label.text = str(total)
