# CLAUDE.md（中文版）

本文件为 Claude Code (claude.ai/code) 在操作本仓库代码时提供指引。英文原版见 `CLAUDE.md`，两者内容一致。

## 项目概述

一款 2D 像素风动作角色扮演游戏（ARPG），使用 **Godot 4.7（Forward Plus 渲染管线）** 开发，改编自 Heartbeast 的 "Action RPG" 教程，并扩展了对话、采集/背包、任务、敌人、特效、存档、标题界面等系统。视口为 320×180（canvas_items 拉伸），放大至 1280×720 窗口显示。

**没有测试套件、linter 或 CLI 构建流程** —— 这是一个以编辑器为核心驱动的 Godot 工程。运行/验证方式：用 Godot 4.7 编辑器打开工程（主场景 `res://title_screen.tscn`，可玩地图为 `res://world.tscn`）。本环境预期有一个启用了 `godot_mcp` 插件的编辑器在运行，因此可直接用 MCP 场景工具（如 `scene_run.play_main` / `play_custom`）来启动场景，而无需命令行。

详细的功能规格与资源清单见 `PROJECT_INIT.md`（中文）。UI 字符串与大部分代码注释为中文。

## 代码语言说明

仓库中的文件、文档、UI 字符串以中文为主（例如"消灭蝙蝠"、"领取奖励"）。修改既有字符串时请保持中文；新增内容可用任一种语言，但应与周围代码保持一致。

## 流程 / 入口点

- `title_screen.tscn`（主场景）→ 点击"开始"按钮：若存在存档则调用 `SaveManager.load_game(1)`，随后用 `change_scene_to_file` 切换到 `world.tscn`。
- `world.tscn` 是一个开启 `y_sort_enabled` 的大型地图：TileMap 地面（Dirt/Cliff）、`Camera2D`（位置平滑跟随、写死的边界限制）、玩家、分组摆放的 Grass/Bush/Tree、约 12 个 Bat 实例、NPC、SteamVent，以及承载 HUD 的 `CanvasLayer`（`HealthUI`、`Task_UI`、`ItemCounter`）。玩家节点上带有一个 `RemoteTransform2D` 用于驱动相机。
- `Player` 由世界场景实例化（**不是** autoload）；其背包 `Inv` 资源在节点上通过 export 导出，同时被 UI 脚本直接 `preload`。

## Autoload（`project.godot`）

| 名称 | 来源 | 用途 |
| --- | --- | --- |
| `PlayerStates` | `res://Player/player_states.tscn`（`states.tscn` 的实例，`max_health = 5`） | **全局玩家生命值节点。** `health`/`max_health` 带 setter，发射 `health_changed`/`max_health_changed`/`no_health` 信号。几乎所有玩法脚本都直接按名字引用它。 |
| `TaskManager` | `res://tasks/task_manager.tscn` | 任务注册表与目标追踪；发射 `task_started`/`objective_updated`/`task_completed`/`task_rewarded`。同时通过 `spawn_drop_item` 在世界中生成掉落物。 |
| `SaveManager` | `res://save/save_manager.tscn` | JSON 存档/读档，路径 `user://saves/<槽位>_save_data.json`；60 秒自动存档由 `Player._physics_process` 触发。 |
| `DialogueManager` | Dialogue Manager 插件 | 第三方对话插件。 |
| `Dialog` | `res://Player/dialog.gd` | 极简 `Node` 标志位（`del_player` 为 true 时删除玩家，由对话行设置）。 |

### 需要注意的耦合模式

- **生命值**：`states.gd`（一个带 `max_health`/`health` 和 setter 信号的 `Node2D`）有两种复用方式：作为玩家时被 autoload 为全局节点（`PlayerStates`），**同时**又被实例化挂在每只蝙蝠场景内作为子节点 `$States`。HUD（`health_ui.gd`）订阅 `PlayerStates` 的信号。
- **玩家的 `state`/`dialog` 字段在 `_ready` 中赋值**（`var state = PlayerStates; var dialog = Dialog`）——它们不是 `@onready` 的节点引用。
- **背包资源共享**：唯一数据源是 `res://inventory/playerInv.tres` —— 一个 `Inv` 资源（脚本 `res://inventory.gd`，`class_name Inv`），内含 12 个 `InvSlot`。它既在玩家场景上被 export，也被 `inv_UI.gd` 和 `item_counter.gd` 直接 `preload`。注意：`save_manager.gd` 与 `task_ui.gd` 是通过 `PlayerStates.inv` 读取的，但 `states.gd` **并未**声明 `inv` 属性 —— 这条路径与直接 preload 的模式不一致，运行时会导致报错。
- 物品是数据型 Resource（`class_name InvItem`，类型 `HEAL`/`MATERIAL`/`KEY`），以 `.tres` 文件定义（`inventory/item/grass.tres`、`bat.tres`）。存档/读档通过 `SaveManager.find_item_by_name` 中硬编码的路径列表按名称重新查找物品。

## 战斗与碰撞设计

物理层（`project.godot` 的 `[layer_names]`）：1 World、2 Player、3 PlayerHurtBox、4 EnemyHurtBox、5 Enemy、6 SoftCollison、7 NPC。

`Boxes/` 目录是一套模块化的碰撞系统，每个 box 是一个小型的 `Area2D` 场景 + 脚本：

- `hit_box.gd` —— 纯数据：`@export damage` 与 `@export knockback_strength`。它是攻击方激活的判定盒（如玩家的 `SwordHitBox`）。
- `hurt_box.gd` —— 受击方。处理无敌帧（由 `Timer` 驱动的 `invincible`），用 `set_deferred` 开关 `monitoring`，生成 `hit_effect`，并发射 `invincible_started`/`invincible_ended` 供闪烁动画使用。`collision_mask` 决定哪些东西能伤到它。
- `soft_collison.gd` —— 基于重叠区的推开逻辑，用于防止敌人相互堆叠。

**伤害路由靠脚本文件名匹配字符串，而不是物理层/分组。** `Player.gd`、`bat.gd`、`grass.gd` 里的每个 `_on_hurt_box_area_entered(area)` 都以如下代码开头：

```gdscript
if area.get_script().resource_path.find("hit_box") == -1:
    return
```

因此，新增的伤害判定盒必须让脚本文件名里保留 `hit_box`（并且位于受击方 HurtBox mask 覆盖的层上）才能被识别。

其他值得保留的约定：

- 攻击/翻滚的硬直态结束，是靠 `.tscn` 动画末尾的 **`AnimationPlayer` 方法轨道回调**（`attack_animation_finished()`、`roll_animation_finished()`）解决的。玩家剑击 hitbox 的开启/关闭由动画关键帧控制 `CollisionShape2D:disabled`。
- **特效**（`Effects/effect.gd`，继承 `AnimatedSprite2D`）在 `animation_finished` 时自动 `queue_free()`。生成方把特效实例加到 `get_tree().current_scene` 下 —— 刻意**不**挂在攻击者父节点下，因为父节点即将被释放。
- 玩家的无敌帧由独立的 blink AnimationPlayer 驱动，通过切换 `Sprite2D.material:shader_parameter/active`（`white_color.gdshader` 材质）实现闪烁。

## AI / 实体结构

- `bat.gd`（`CharacterBody2D`）：在 `_physics_process` 中用一个枚举状态机（`IDLE`/`WANDER`/`CHASE`）驱动。子节点：`States`（生命值）、`PlayerDetection`（Area2D，把进入的 body 记为 `player`）、`SoftCollison`、`WanderController`、HurtBox，以及一个 `GPUParticles2D`。
- 死亡时生成死亡特效，可能掉落其 export 的 `item`（`TaskManager.spawn_drop_item`），并且 **写死** 了 `TaskManager.add_objective_progress("kill_bats", 0, 1)` —— 任务 id 通过字符串在此处及 `Player._ready`（若不存在则加载并启动 `kill_bats_task.tres`）中耦合。
- `World/grass.gd` 是可采集物范式：自带 HurtBox（mask 只覆盖玩家攻击），外加一个独立的玩家靠近用 `Area2D`。被击中时生成 `grass_effect`，随后 `player.collect(item)` → `Inv.insert()`。

## 任务、奖励、存档

- `tasks/task.gd`（`class_name Task`）：状态枚举 `NOT_STARTED`→`IN_PROGRESS`→`COMPLETED`→`REWARDED`；`objectives: Array[Dictionary]`，每个字典含 `name`/`progress`/`target`；`rewards: Array[InvItem]` 与并行的 `reward_amounts`。`get_current_objective()` 返回第一个未完成的目标。
- `task_ui.gd` 依据 `TaskManager` 的信号整体重建列表；已完成任务会渲染一个"领取奖励"按钮，把奖励物品插入背包，并显示 3 秒的完成提示。
- `save_manager.gd` 把 `player_states`、`player_position`、`inventory`（按物品名 + 数量）以及 `tasks`（id、status、objectives）写成 JSON 存到 `user://saves/1_save_data.json`。

## 常见坑

- 脚本/场景之间在 `.tscn`/`project.godot` 里常以 **UID 字符串**（`uid://...`）互相引用 —— 重命名/移动脚本时请保留 `.uid` 伴随文件，否则需同步修改引用。
- `.godot/` 是缓存目录；`素材/` 存放原始导入美术（部分场景会引用，例如蝙蝠的 `white.png`）。
- `addons/dialogue_manager` 与 `addons/godot_mcp` 是第三方插件 —— 不要重构其内部实现。其中 `addons/dialogue_manager` 通过 `DialogueManager.show_example_dialogue_balloon(...)` 驱动 `NPC.Test.dialogue`。
