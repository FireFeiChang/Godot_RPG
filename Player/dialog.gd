extends Node

## 对话相关全局标记（autoload：Dialog）。
## 由 NPC / 对话系统读写，Player 每帧读取以切换行为。

## 兼容旧对话：置 true 会删除玩家（不建议再使用）。
var del_player : bool = false

## 对话进行中是否锁定玩家移动/动作。NPC 打开对话时置 true，对话结束置 false。
var freeze_player : bool = false

## 对话内玩家选择"接取任务"时由 .dialogue 的 set 突变填入任务 id；
## NPC 每帧消费该请求后执行真正的接取逻辑，再清空。
var task_accept_request: String = ""

## 对话内玩家确认"交付任务"时由 .dialogue 的 set 突变填入任务 id；
## NPC 每帧消费该请求后执行交付/发奖，再清空。
var task_turnin_request: String = ""
