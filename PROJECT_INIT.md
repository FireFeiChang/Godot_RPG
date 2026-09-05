# Test-ARPG 项目文档 v2.0

> **版本**: v2.0
> **更新日期**: 2026-07-09
> **引擎**: Godot Engine 4.7 (Forward Plus)
> **状态**: 功能完善，可正常游戏

---

## 更新日志

### v2.0 (2026-07-09)

- ✅ 完善任务系统：添加任务奖励机制（消灭蝙蝠任务奖励3个蝙蝠材料）
- ✅ 添加任务完成提示：任务完成时显示3秒提示文字
- ✅ 添加奖励领取功能：完成任务后可点击"领取奖励"按钮获得奖励
- ✅ 修复任务状态问题：任务添加时自动调用 start() 方法启动任务
- ✅ 实现物品类型系统：HEAL(治疗)、MATERIAL(材料)、KEY(钥匙)
- ✅ 实现治疗物品功能：草(grass)使用后恢复1点生命值
- ✅ 添加物品使用限制：只有治疗类物品可使用，生命值已满时无法使用
- ✅ 扩展地图：增加4个蝙蝠敌人(Bat9-Bat12)，分布在地图不同区域
- ✅ 增加环境装饰：新增5处草丛、4处灌木、2棵树、1个蒸汽通风口
- ✅ 完善保存系统：自动保存玩家当前位置，读取存档时恢复位置
- ✅ 添加物品计数器 UI：右上角显示已收集物品总数
- ✅ 优化物品计数器显示：字体颜色改为白色增强可见性
- ✅ 移除突兀的角色信息界面

### v1.0 (2026-07-09)

- ✅ 修复 DialogueCache null 引用错误 ([import_plugin.gd](file:///d:/GODOT/Test-ARPG-master/Test-ARPG-master/addons/dialogue_manager/import_plugin.gd))
- ✅ 更新操作逻辑为现代布局：WASD移动、J攻击、空格翻滚、B打开背包
- ✅ 修复背包空槽位点击报错 ([inv_ui_slot.gd](file:///d:/GODOT/Test-ARPG-master/Test-ARPG-master/inventory/inv_ui_slot.gd))
- ✅ 添加空槽位禁用按钮功能，提升用户体验
- ✅ 地图丰富：扩展相机边界、增加草丛/灌木/树木/敌人/蒸汽口
- ✅ 修复蝙蝠碰撞掉血 Bug：只有攻击碰撞盒才能造成伤害
- ✅ 实现攻击碰撞盒的击退向量功能 ([hit_box.gd](file:///d:/GODOT/Test-ARPG-master/Test-ARPG-master/Boxes/hit_box.gd))
- ✅ 创建游戏标题界面 ([title_screen.tscn](file:///d:/GODOT/Test-ARPG-master/Test-ARPG-master/title_screen.tscn))
- ✅ 创建音效设置界面：音量滑块控制
- ✅ 实现敌人掉落系统：蝙蝠死亡时 50% 概率掉落物品
- ✅ 实现任务系统基础框架：消灭蝙蝠任务
- ✅ 实现存档系统：自动保存（60秒）和读档功能
- ✅ 优化标题界面布局：缩小按钮尺寸
- ✅ 实现角色状态监测 UI（心电图）：实时显示玩家生命值和状态
- ✅ 实现任务显示 UI：右上角显示当前任务和进度

---

## 1. 项目概述

### 1.1 项目名称

**Test-ARPG**

### 1.2 项目类型

2D 动作角色扮演游戏 (Action Role-Playing Game)

### 1.3 引擎版本

Godot Engine 4.7 (Forward Plus 渲染管线)

### 1.4 目标平台

- PC 端 (窗口模式)
- 屏幕分辨率: 1280x720 (实际视口: 320x180)

---

## 2. 项目架构

### 2.1 目录结构

```
Test-ARPG/
├── .godot/                      # Godot 引擎缓存目录
├── Player/                      # 玩家系统
│   ├── Player.gd                # 玩家主逻辑
│   ├── player.tscn              # 玩家场景
│   ├── player_states.tscn       # 玩家状态管理(全局)
│   ├── player_hurt_sound.gd/tscn # 受伤音效
│   ├── sword_hit_box.gd         # 攻击碰撞盒
│   └── dialog.gd                # 对话状态管理(全局)
├── Enemies/                     # 敌人系统
│   ├── bat.gd/tscn              # 蝙蝠敌人
│   ├── player_detection.gd/tscn # 玩家检测
│   └── wander_controller.gd/tscn # 漫游控制
├── NPC/                         # NPC 系统
│   ├── npc.gd/tscn              # NPC 主逻辑
│   └── Test.dialogue            # 对话脚本
├── inventory/                   # 背包系统
│   ├── inv_UI.gd/tscn           # 背包界面
│   ├── inv_ui_slot.gd/tscn      # 背包格子(含物品使用)
│   ├── inventory_item.gd        # 物品资源类(含类型和效果)
│   ├── playerInv.tres           # 玩家背包数据
│   └── item/                    # 物品定义
│       ├── grass.tres           # 草药物品(治疗类)
│       └── bat.tres             # 蝙蝠掉落物品(材料类)
├── tasks/                       # 任务系统
│   ├── task.gd                  # 任务资源类(含奖励系统)
│   ├── task_manager.gd/tscn     # 任务管理器(全局)
│   └── kill_bats_task.tres      # 消灭蝙蝠任务定义
├── save/                        # 存档系统
│   ├── save_manager.gd/tscn     # 存档管理器(全局)
├── UI/                          # 用户界面
│   ├── health_ui.gd/tscn        # 生命值显示
│   ├── task_ui.gd/tscn          # 任务显示UI(含奖励领取)
│   ├── item_counter.gd/tscn     # 物品计数器UI(白色字体)
│   └── ecg_ui.gd/tscn           # 心电图状态监测UI
├── World/                       # 世界场景对象
│   ├── grass.gd/tscn            # 草丛(可采集)
│   ├── bush.gd/tscn             # 灌木
│   └── tree.tscn                # 树木
├── Boxes/                       # 碰撞盒系统
│   ├── hit_box.gd/tscn          # 攻击碰撞盒(含击退)
│   ├── hurt_box.gd/tscn         # 受伤碰撞盒(含无敌帧)
│   ├── soft_collison.gd/tscn    # 软碰撞(防止重叠)
│   └── speak_box.tscn           # 对话触发盒
├── Effects/                     # 特效系统
│   ├── effect.gd                # 特效基类
│   ├── hit_effect.tscn          # 击中特效
│   ├── grass_effect.tscn        # 草丛采集特效
│   └── enemy_death_effect.tscn  # 敌人死亡特效
├── addons/dialogue_manager/     # 对话管理器插件
├── states.gd/tscn               # 通用状态节点
├── Inv_slot.gd                  # 背包槽位资源类
├── drop_item.gd/tscn            # 掉落物场景
├── world.tscn                   # 主场景
├── title_screen.gd/tscn         # 标题界面
├── steam_vent.tscn              # 蒸汽通风口
└── project.godot                # 项目配置
```

### 2.2 核心系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      游戏主循环 (_physics_process)           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   玩家系统    │    │   敌人系统    │    │   NPC系统    │  │
│  │  Player.gd   │    │   bat.gd     │    │   npc.gd     │  │
│  │              │    │              │    │              │  │
│  │ • 移动状态机  │    │ • 行为状态机  │    │ • 对话触发    │  │
│  │ • 攻击系统    │    │ • 玩家检测    │    │ • 对话显示    │  │
│  │ • 翻滚闪避    │    │ • 漫游AI     │    │              │  │
│  │ • 受伤处理    │    │ • 受伤处理    │    │              │  │
│  └──────┬───────┘    └──────┬───────┘    └──────────────┘  │
│         │                   │                               │
│         ▼                   ▼                               │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │   碰撞系统    │◄───┤   碰撞系统    │                       │
│  │  HurtBox     │    │  HurtBox     │                       │
│  │  HitBox      │    │  HitBox      │                       │
│  │  SoftCol     │    │  SoftCol     │                       │
│  └──────┬───────┘    └──────────────┘                       │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │   状态管理    │    │   特效系统    │                       │
│  │  PlayerStates│    │   Effects    │                       │
│  │ • 生命值      │    │ • 击中特效    │                       │
│  │ • 死亡检测    │    │ • 死亡特效    │                       │
│  └──────┬───────┘    └──────────────┘                       │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │   UI系统      │    │   背包系统    │                       │
│  │  health_ui   │    │   Inventory  │                       │
│  │ • 血量显示    │    │ • 物品收集    │                       │
│  │              │    │ • 物品使用    │                       │
│  └──────────────┘    └──────────────┘                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 核心功能模块

### 3.0 主场景结构 (`world.tscn`)

```
world (Node2D)
├── Background (Sprite2D)          # 背景图
├── DirtPathTileMap (TileMap)      # 泥土路径瓦片地图
├── CliffTileMap (TileMap)         # 悬崖瓦片地图
├── Camera2D (Camera2D)            # 主摄像机(跟随玩家)
│   └── limit_left/top/right/bottom # 相机边界限制(-300/-300/800/600)
├── Player (CharacterBody2D)       # 玩家角色
│   └── RemoteTransform2D          # 摄像机跟随控制器
├── Grass (Node2D)                 # 草丛组(25个草丛)
├── Bushes (Node2D)                # 灌木组(12个灌木)
├── Tree (Node2D)                  # 树木组(7棵树)
├── Bat (12个实例)                 # 蝙蝠敌人
├── CanvasLayer (CanvasLayer)      # UI层
│   ├── HealthUI                   # 生命值显示(左上角)
│   ├── Task_UI                    # 任务显示UI(右上角)
│   └── ItemCounter                # 物品计数器(右上角)
├── NPC (CharacterBody2D)          # NPC角色
├── SteamVent (2个实例)            # 蒸汽通风口
└── drop_item (动态生成)           # 掉落物
```

### 3.1 玩家控制系统


| 功能     | 实现方式           | 按键/输入             |
| -------- | ------------------ | --------------------- |
| 移动     | 方向键/WASD        | ui_up/down/left/right |
| 攻击     | 动画触发攻击碰撞盒 | J 键 / 手柄按键2      |
| 翻滚     | 无敌帧移动         | 空格键 / 手柄按键0    |
| 打开背包 | 切换 UI 显示       | B 键 / 手柄按键6      |
| 使用物品 | 鼠标左键点击       | useItem 动作          |

**状态机设计**:

- `MOVE` - 正常移动状态
- `ROLL` - 翻滚闪避状态(无敌)
- `ATTACK` - 攻击状态(硬直)

### 3.2 敌人系统

**蝙蝠敌人 (Bat)** 具备以下行为:


| 状态   | 行为描述           |
| ------ | ------------------ |
| IDLE   | 静止不动，监听玩家 |
| WANDER | 随机漫游，监听玩家 |
| CHASE  | 追逐并攻击玩家     |

**AI 机制**:

- 玩家检测: 通过 `player_detection` 区域检测玩家进入
- 漫游控制: `wander_controller` 在指定范围内随机移动
- 软碰撞: `soft_collison` 防止敌人之间重叠

### 3.3 碰撞系统


| 碰撞类型      | 作用               | 物理层                       |
| ------------- | ------------------ | ---------------------------- |
| HitBox        | 攻击判定，造成伤害 | Player / Enemy               |
| HurtBox       | 受伤判定，接收伤害 | PlayerHurtBox / EnemyHurtBox |
| SoftCollision | 防止物体重叠       | SoftCollison                 |

**无敌帧机制**: 受伤后触发短暂无敌时间，期间闪烁动画并禁用碰撞检测

### 3.4 生命值系统

- **通用状态节点**: `states.gd` 提供生命值管理基类
- **信号机制**:
  - `health_changed` - 生命值变化通知 UI 更新
  - `max_health_changed` - 最大生命值变化通知
  - `no_health` - 死亡信号，触发销毁

### 3.5 背包系统

**数据结构**:

- `InvItem` - 物品资源类 (名称、纹理、类型、效果)
- `InvSlot` - 槽位资源类 (物品、数量)
- `playerInv.tres` - 玩家背包数据存储

**物品类型**:

| 类型      | 值 | 说明             |
| --------- | --- | ---------------- |
| HEAL      | 0   | 治疗类物品       |
| MATERIAL  | 1   | 材料类物品       |
| KEY       | 2   | 钥匙类物品       |

**功能**:

- 物品收集: 击败敌人或采集草丛获得
- 物品使用: 草药(grass)可恢复 1 点生命值
- 使用限制: 只有治疗类物品可使用，生命值已满时无法使用
- 背包界面: 滚动容器显示所有物品
- 物品计数器: 右上角显示已收集物品总数(白色字体)

### 3.6 任务系统

**数据结构**:

- `Task` - 任务资源类 (ID、名称、描述、状态、目标、奖励)
- `TaskManager` - 任务管理器(全局自动加载)

**任务状态**:

| 状态         | 值 | 说明             |
| ------------ | --- | ---------------- |
| NOT_STARTED  | 0   | 未开始           |
| IN_PROGRESS  | 1   | 进行中           |
| COMPLETED    | 2   | 已完成(待领奖)   |
| REWARDED     | 3   | 已领取奖励       |

**内置任务**:

| 任务ID      | 名称       | 目标                     | 奖励               |
| ----------- | ---------- | ------------------------ | ------------------ |
| kill_bats   | 消灭蝙蝠   | 消灭5只蝙蝠              | 3个蝙蝠材料        |

**功能**:

- 任务进度更新: 蝙蝠死亡时自动更新任务进度
- 任务完成提示: 任务完成时显示3秒提示文字
- 奖励领取: 完成任务后可点击"领取奖励"按钮获得奖励
- 任务UI: 右上角显示当前任务和进度

### 3.7 存档系统

**功能**:

- 自动保存: 每60秒自动保存游戏进度
- 手动保存: 通过代码调用 `SaveManager.save_game()` 保存
- 读取存档: 标题界面点击开始按钮自动读取存档
- 存档内容:
  - 玩家生命值和最大生命值
  - 玩家当前位置
  - 背包物品(物品名和数量)
  - 任务状态和进度

**存档路径**: `user://saves/1_save_data.json`

### 3.8 对话系统

- 使用 **Dialogue Manager** 插件管理对话
- NPC 靠近时按确认键触发对话
- 支持多分支对话选择

---

## 4. 技术实现要点

### 4.1 输入配置


| 动作名    | 绑定按键  | 用途       |
| --------- | --------- | ---------- |
| ui_accept | 空格/回车 | 确认、对话 |
| attack    | J 键      | 攻击       |
| roll      | 空格键    | 翻滚       |
| openInv   | B 键      | 打开背包   |
| useItem   | 鼠标左键  | 使用物品   |

### 4.2 物理层配置


| 层号 | 名称          | 用途         |
| ---- | ------------- | ------------ |
| 1    | World         | 世界场景碰撞 |
| 2    | Player        | 玩家碰撞     |
| 3    | PlayerHurtBox | 玩家受伤盒   |
| 4    | EnemyHurtBox  | 敌人受伤盒   |
| 5    | Enemy         | 敌人碰撞     |
| 6    | SoftCollison  | 软碰撞       |
| 7    | NPC           | NPC 碰撞     |

### 4.3 全局自动加载


| 资源            | 路径                                                | 用途             |
| --------------- | --------------------------------------------------- | ---------------- |
| PlayerStates    | `res://Player/player_states.tscn`                   | 玩家状态全局管理 |
| DialogueManager | `res://addons/dialogue_manager/dialogue_manager.gd` | 对话管理器       |
| Dialog          | `res://Player/dialog.gd`                            | 对话状态标志     |
| TaskManager     | `res://tasks/task_manager.tscn`                     | 任务管理器       |
| SaveManager     | `res://save/save_manager.tscn`                     | 存档管理器       |

---

## 5. 资源清单

### 5.1 图像资源


| 资源名                                             | 用途                   |
| -------------------------------------------------- | ---------------------- |
| Player.png                                         | 玩家角色精灵           |
| Bat.png/BatRes.png                                 | 蝙蝠敌人精灵           |
| NPC.png                                            | NPC 精灵               |
| villain.png                                        | 反派/BOSS 角色精灵     |
| HeartUIFull/HeartUIEmpty.png                       | 生命值 UI              |
| GUI.png/BagGui.png/ItemGui.png                     | 背包 UI                |
| HeadUI.png/RoleUI.png                              | 角色信息 UI            |
| TextUI.png/Timer.png                               | 文本和计时器 UI        |
| HitEffect.png/EnemyDeathEffect.png/GrassEffect.png | 特效                   |
| Grass.png/Bush.png/Tree.png                        | 场景对象               |
| GrassBackground.png/MapTopback.png                 | 背景图                 |
| DirtTileset.png/CliffTileset.png                   | 瓦片地图               |
| LargeShadow.png/MediumShadow.png/SmallShadow.png   | 阴影                   |
| Titleback.png                                      | 标题界面背景（待实现） |
| BOSSinfo.png                                       | BOSS 信息 UI（待实现） |
| 声音设置底图.png                                   | 音效设置界面（待实现） |
| 心电图仪器.png/心电图存活.png/心电图死亡.png       | 角色状态监测（待实现） |
| 身份码.png                                         | 身份系统（待实现）     |
| 气泡.png/气泡三角.png                              | 对话气泡（待实现）     |
| 通风口.png/steam_vent.tscn                         | 蒸汽通风口场景         |
| RPhone_01.png/RPhone_02.png                        | 道具手机（待实现）     |

### 5.2 音频资源


| 资源名                        | 用途         |
| ----------------------------- | ------------ |
| Hit.wav                       | 击中音效     |
| Hurt.wav                      | 受伤音效     |
| Evade.wav                     | 闪避音效     |
| EnemyDie.wav                  | 敌人死亡音效 |
| Menu Move.wav/Menu Select.wav | 菜单音效     |
| Music.mp3                     | 背景音乐     |

---

## 6. 项目状态评估

### 6.1 已完成功能

- [X]  玩家移动系统 (WASD)
- [X]  玩家攻击系统 (J键)
- [X]  玩家翻滚闪避 (空格键)
- [X]  蝙蝠敌人 AI (漫游/追逐)
- [X]  碰撞检测系统 (HitBox/HurtBox/SoftCollision)
- [X]  无敌帧机制
- [X]  生命值 UI 显示
- [X]  背包系统 (收集/使用/物品类型)
- [X]  任务系统 (进度/奖励/领取)
- [X]  存档系统 (自动保存/玩家位置/背包/任务)
- [X]  NPC 对话系统
- [X]  特效系统 (击中/死亡/草丛)
- [X]  音效系统
- [X]  标题界面 (开始/设置/退出)
- [X]  物品计数器 UI
- [X]  任务显示 UI
- [X]  心电图状态监测 UI

### 6.2 待完善功能

- [ ]  更多敌人类型
- [ ]  BOSS 战系统（已有资源：BOSSinfo.png）
- [ ]  身份系统（已有资源：身份码.png）
- [ ]  更多任务类型
- [ ]  物品合成系统
- [ ]  技能系统

---

## 7. 运行方式

### 7.1 开发环境

1. 安装 **Godot Engine 4.7**
2. 打开项目目录 `Test-ARPG`
3. 运行主场景 `world.tscn`

### 7.2 操作指南


| 操作        | 按键             |
| ----------- | ---------------- |
| 移动        | 方向键 / WASD    |
| 攻击        | J                |
| 翻滚        | 空格键           |
| 打开背包    | B                |
| 对话/确认   | 空格 / 回车      |
| 使用物品    | 鼠标左键点击物品 |

---

## 8. 项目亮点

1. **状态机架构**: 玩家和敌人都采用清晰的状态机设计，易于扩展
2. **碰撞系统模块化**: HitBox/HurtBox/SoftCollision 分离设计，职责清晰
3. **资源管理**: 使用 Godot Resource 系统管理物品数据，便于编辑器配置
4. **全局状态管理**: 通过 Autoload 实现跨场景状态共享
5. **对话插件集成**: 使用成熟的 Dialogue Manager 插件快速实现对话功能
6. **完整任务系统**: 支持任务进度追踪、完成提示和奖励领取
7. **物品类型系统**: 支持治疗、材料、钥匙等多种物品类型
8. **自动存档**: 支持玩家位置、背包、任务等完整状态保存
