extends Node
## 金币钱包（Autoload：Wallet）。独立货币，不占背包格。
## 敌人死亡调用 spawn_coin_drop 在世界里生成金币拾取物，玩家接触后入账。
## HUD 金币计数、存档/读档都从这里读余额。

signal gold_changed(new_total: int)

const CoinDropScene = preload("res://coins/coin_drop.tscn")

var gold: int = 0

func add_gold(amount: int):
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

## 花钱；余额不足返回 false 不扣款。
func spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

## 新开局清零（玩家 _reset_new_game 时调用）。
func reset():
	gold = 0
	gold_changed.emit(gold)

## 在 pos 处掉落 amount 枚金币（世界拾取物，敌人死亡回调里用 call_deferred 调用）。
func spawn_coin_drop(pos: Vector2, amount: int):
	var drop = CoinDropScene.instantiate()
	drop.amount = amount
	drop.global_position = pos
	get_tree().current_scene.add_child(drop)
