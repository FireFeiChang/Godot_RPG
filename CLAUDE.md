# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A 2D pixel-art action RPG built in **Godot 4.7 (Forward Plus renderer)**, adapted from Heartbeast's "Action RPG" tutorial and extended with dialogue, gathering/inventory, tasks, enemies, effects, save, and title-screen systems. The viewport is 320×180 (canvas_items stretch) upscaled to a 1280×720 window.

There is **no test suite, linter, or CLI build** — this is an editor-driven Godot project. Run/verify by opening the project in the Godot 4.7 editor (main scene `res://title_screen.tscn`; the playable map is `res://world.tscn`). A live Godot editor with the `godot_mcp` addon is expected to be running in this environment, so scenes can be launched via the MCP scene tools (e.g. `scene_run.play_main` / `play_custom`) instead of a shell command.

Detailed feature specs and asset manifests live in `PROJECT_INIT.md` (Chinese). UI strings and most code comments are in Chinese.

## Codebase language note

Files, docs, and UI strings are primarily written in Chinese (e.g. `消灭蝙蝠`, `领取奖励`). Preserve this when editing existing strings; new content may use either language but should match the surrounding code.

## Flow / entry points

- `title_screen.tscn` (main scene) → Start button **deletes any save then** swaps to `world.tscn` via `change_scene_to_file` (every run is a fresh start; `world.gd`/`Player._reset_new_game` also resets autoloads — health/gold/inventory/tasks).
- `world.tscn` is one large `y_sort_enabled` map: TileMap ground (Dirt/Cliff), a `Camera2D` (position-smoothed, hard-coded limits), the player, plus grouped instances of Grass (43) / Bush (18) / Tree (25), 14 Bat, 3 Acornback, 6 Chest, NPC, 2 SteamVent, and a `CanvasLayer` hosting the HUD (`HealthUI`, `Task_UI`, `ItemCounter`, `gold_counter`). The player node carries a `RemoteTransform2D` that drives the camera.
- `Player` is instanced from the world scene (not autoloaded). Its gameplay "singletons" are autoloads referenced by name in `_ready` (`var state = PlayerStates` etc.), not node children.
- Chests/coin pickups are added to `get_tree().current_scene` by their spawners — deliberately not parented to a dying node.

## Autoloads (`project.godot`)

| Name | Source | Purpose |
| --- | --- | --- |
| `PlayerStates` | `res://Player/player_states.tscn` (an instance of `states.tscn`, `max_health = 5`) | **Global player health node.** `health`/`max_health` with setters emitting `health_changed`/`max_health_changed`/`no_health`. Referenced by name from nearly every gameplay script. |
| `TaskManager` | `res://tasks/task_manager.tscn` | Task registry & objective tracking; emits `task_started`/`objective_updated`/`task_completed`/`task_rewarded`. Also spawns world drop-items via `spawn_drop_item`. |
| `SaveManager` | `res://save/save_manager.tscn` | JSON save/load to `user://saves/<slot>_save_data.json`. Not used for the fresh-start flow (Start deletes save) but `save_game`/`load_game` still work — read/writes gold, health, player pos, inventory, tasks. |
| `Inventory` | `res://inventory/inventory_manager.gd` | **Global inventory + item registry**: holds `inv` (`Inv`, source of truth `playerInv.tres`, 30 slots) and `ITEM_REGISTRY` (id→path). `get_item(id)` / `get_item_by_name(name)`. |
| `Wallet` | `res://coins/wallet.gd` | Global coin balance (`gold`, `signal gold_changed`); `spawn_coin_drop(pos, amount)` for world pickups. |
| `DialogueManager` | Dialogue Manager addon | Third-party dialogue plugin. |
| `Dialog` | `res://Player/dialog.gd` | Bare `Node` flag holder (`del_player` deletes the player, set by dialogue lines). |

### Notable coupling patterns

- **Health**: `states.gd` (a `Node2D` with `max_health`/`health` + setter signals) is reused two ways: autoloaded globally for the player (`PlayerStates`) **and** instanced as a child node (`$States`) inside each bat scene. The HUD (`health_ui.gd`) subscribes to `PlayerStates` signals.
- **Player `state`/`dialog` fields are set at `_ready`** (`var state = PlayerStates; var dialog = Dialog`) — they are not `@onready` node refs.
- **Inventory sharing (single source of truth)**: `res://inventory/playerInv.tres` (an `Inv`, 30 `InvSlot`s) is loaded by the **`Inventory` autoload** (`inventory_manager.gd: var inv = preload(...)`). All scripts go through that autoload — e.g. `Inventory.inv.insert(...)`, `Inventory.get_item(id)`, `Wallet.spawn_coin_drop(...)`. Don't add a separate `inv` property to `states.gd`/`PlayerStates`.
- Items are data Resources (`class_name InvItem`, script `inventory/inventory_item.gd`, types `HEAL`/`MATERIAL`/`KEY`; fields `id`/`name`/`texture`) defined as `.tres` files (`inventory/item/`, e.g. `grass.tres`, plus 16 RPG items like `torch.tres`). Save writes `item_id`; load re-finds via `Inventory.get_item` against `ITEM_REGISTRY` (fallback by name).

## Combat & collision design

Physics layers (`project.godot` `[layer_names]`): 1 World, 2 Player, 3 PlayerHurtBox, 4 EnemyHurtBox, 5 Enemy, 6 SoftCollison, 7 NPC. The player's sword `SwordHitBox` sits on **layer 8** (unnamed); grass/chest HurtBoxes use `collision_mask = 8` to receive it.

The `Boxes/` folder is a modular collision system, each box a small `Area2D` scene + script:
- `hit_box.gd` — data only: `@export damage` and `@export knockback_strength`. It is the attacker's active hitbox (e.g. player's `SwordHitBox`, acornback's body-contact `HitBox`).
- `hurt_box.gd` — the receiver. Handles i-frames (`invincible` via a `Timer`), toggles `monitoring` with `set_deferred`, spawns `hit_effect`, and emits `invincible_started`/`invincible_ended` for blink animation. `collision_mask` selects what hurts it.
- `soft_collison.gd` — overlap-based push-apart used to stop enemies from stacking.

**Damage routing is by script-name string match, not layers/groups.** Every `_on_hurt_box_area_entered(area)` in `Player.gd`, `bat.gd`, `acornback.gd`, `grass.gd`, and `chest.gd` begins with:

```gdscript
if area.get_script().resource_path.find("hit_box") == -1:
    return
```

So a new damaging box must keep `hit_box` in its script filename (and sit on a layer the victim's HurtBox masks) to be recognized.

Other conventions worth keeping:
- Attack/roll hard-states are resolved by **`AnimationPlayer` method-track callbacks** (`attack_animation_finished()`, `roll_animation_finished()`) placed at the end of the corresponding `.tscn` animations. The player's sword hitbox is enabled/disabled by animation keyframes on `CollisionShape2D:disabled`.
- **Effects** (`Effects/effect.gd`, extends `AnimatedSprite2D`) auto `queue_free()` on `animation_finished`. Spawners add effect instances to `get_tree().current_scene` — deliberately NOT the attacker's parent, because the parent is about to be freed.
- Player i-frames are driven by a blink AnimationPlayer toggling `Sprite2D.material:shader_parameter/active` of the `white_color.gdshader` material.

## AI / entity structure

- `bat.gd` (`CharacterBody2D`): a `MOVE`-style enum state machine (`IDLE`/`WANDER`/`CHASE`) driven in `_physics_process`. Children: `States` (health), `PlayerDetection` (Area2D tracking the nearest body as `player`), `SoftCollison`, `WanderController`, HurtBox, and a `GPUParticles2D`.
- `acornback.gd` (extends `KinematicActor`): ground enemy with `IDLE`/`WANDER`/`ROLL`; on seeing the player it curls into a ball (`Roll_Attack`) and charges. The `Roll_Attack` sheet is **mirrored** vs Walk/Idle, so ROLL uses inverted-facing (`_face_toward(player, mirrored=true)`) to show its front. On death it sets `dead`, disables hurt/hit/collision, plays the non-looping `Death` anim, and only on `animation_finished` spawns the explosion + drops (`Wallet.spawn_coin_drop`, item) then `queue_free()`.
- `Enemies/chest/chest.gd` (`@tool`, `StaticBody2D`): a world treasure. Its sprite frames are assembled at runtime from the strip `chest_silver.png` (8 × 62×56 frames → `Open` anim; adjust timing via `FRAME_DURATION`/`FRAME_FPS`). `@tool` + building in `_ready` makes it visible in the editor too. On sword hit (hurt_box, `collision_mask=8`) it plays `Open`, then `_spawn_loot()` spawns `drop_item` world pickups into `current_scene` from the tier's `LOOT_POOLS` and `queue_free()`s itself.
- On death a bat/acornback creates the death effect, may drop its exported `item` (`TaskManager.spawn_drop_item`). Bat **hard-codes** `TaskManager.add_objective_progress("kill_bats", 0, 1)` — task id is coupled by string here and in `Player._ready` (which loads and starts `kill_bats_task.tres` if absent).
- `mob.gd` (extends `KinematicActor`): generic ground-enemy base shared by **Goblin / Mimic / Slime**. `IDLE`/`WANDER`/`CHASE` state machine; on `_ready` it builds its `SpriteFrames` at runtime by slicing the `@export` sheet textures (`sheet_idle/walk/attack/death/hurt` + optional `disguise_sheet`) into 64px-wide cells (`_add_strip`; auto-locates sheets by scene-file basename in `Enemies/mobs/<name>/` if exports are unset). Mimic uses `disguised` — it idles playing `Disguise` until the player enters detection range, then wakes and chases. Death sets `dead`, disables hurt/hit/body collision, plays non-looping `Death`, and on `animation_finished` spawns the explosion + drops (`Wallet.spawn_coin_drop`, optional item) then `queue_free()`. Per-enemy tuning (health/speed/ranges/particle color) is done by overriding the `acornback.tscn`-derived scene (`goblin.tscn` / `mimic.tscn` / `slime.tscn`); contact damage is via the常驻 `HitBox` (layer 4, the player's HurtBox masks layer 4).
- `World/grass.gd` is the collectible pattern: it has its own HurtBox (masked to player attacks) plus a separate player-proximity `Area2D`. On hit it spawns `grass_effect`, then `player.collect(item)` → `Inv.insert()`.

## Tasks, rewards, save

- `tasks/task.gd` (`class_name Task`): status enum `NOT_STARTED`→`IN_PROGRESS`→`COMPLETED`→`REWARDED`; `objectives: Array[Dictionary]`, each dict having `name`/`progress`/`target`; `rewards: Array[InvItem]` + parallel `reward_amounts`. `get_current_objective()` returns the first non-complete objective.
- `task_ui.gd` (弹层 UI, `UI/task_ui.gd`) rebuilds its whole list from `TaskManager` signals; completed tasks show a "回村长处交付" hint (rewards are granted by the chief NPC's dialogue, **not** claimed in the UI). It never touches inventory directly.
- `save_manager.gd` writes `player_states`, `player_position`, `gold`, `inventory` (by `item_id` + amount), and `tasks` (id, status, objectives) as JSON to `user://saves/1_save_data.json`.

## Gotchas

- Scripts/scenes may reference each other by **UID string** (`uid://...`) in `.tscn`/`project.godot` — keep `.uid` sidecar files intact when renaming/moving scripts, or edit the references too.
- `.godot/` is cache. Raw source-art folders (`素材/原版/`, `素材/新增/`) have been deleted; every asset referenced by game code now lives in a stable project folder (e.g. `Effects/`, `UI/`, `inventory/`, `World/`, `Enemies/acornback/`). When adding new art, import it directly into its final folder — do not recreate a `素材/` dropbox.
- The `addons/dialogue_manager` and `addons/godot_mcp` folders are third-party plugins — do not refactor their internals. `addons/dialogue_manager` is what powers `NPC.Test.dialogue` via `DialogueManager.show_example_dialogue_balloon(...)`.
