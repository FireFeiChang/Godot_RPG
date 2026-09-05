# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A 2D pixel-art action RPG built in **Godot 4.7 (Forward Plus renderer)**, adapted from Heartbeast's "Action RPG" tutorial and extended with dialogue, gathering/inventory, tasks, enemies, effects, save, and title-screen systems. The viewport is 320×180 (canvas_items stretch) upscaled to a 1280×720 window.

There is **no test suite, linter, or CLI build** — this is an editor-driven Godot project. Run/verify by opening the project in the Godot 4.7 editor (main scene `res://title_screen.tscn`; the playable map is `res://world.tscn`). A live Godot editor with the `godot_mcp` addon is expected to be running in this environment, so scenes can be launched via the MCP scene tools (e.g. `scene_run.play_main` / `play_custom`) instead of a shell command.

Detailed feature specs and asset manifests live in `PROJECT_INIT.md` (Chinese). UI strings and most code comments are in Chinese.

## Codebase language note

Files, docs, and UI strings are primarily written in Chinese (e.g. `消灭蝙蝠`, `领取奖励`). Preserve this when editing existing strings; new content may use either language but should match the surrounding code.

## Flow / entry points

- `title_screen.tscn` (main scene) → Start button calls `SaveManager.load_game(1)` if a save exists, then swaps to `world.tscn` via `change_scene_to_file`.
- `world.tscn` is one large `y_sort_enabled` map: TileMap ground (Dirt/Cliff), a `Camera2D` (position-smoothed, hard-coded limits), the player, grouped Grass/Bush/Tree nodes, ~12 Bat instances, NPC, SteamVent, and a `CanvasLayer` hosting the HUD (`HealthUI`, `Task_UI`, `ItemCounter`). The player node carries a `RemoteTransform2D` that drives the camera.
- `Player` is instanced from the world scene (not autoloaded); its inventory `Inv` resource is exported on the node and also preloaded directly by UI scripts.

## Autoloads (`project.godot`)

| Name | Source | Purpose |
| --- | --- | --- |
| `PlayerStates` | `res://Player/player_states.tscn` (an instance of `states.tscn`, `max_health = 5`) | **Global player health node.** `health`/`max_health` with setters emitting `health_changed`/`max_health_changed`/`no_health`. Referenced by name from nearly every gameplay script. |
| `TaskManager` | `res://tasks/task_manager.tscn` | Task registry & objective tracking; emits `task_started`/`objective_updated`/`task_completed`/`task_rewarded`. Also spawns world drop-items via `spawn_drop_item`. |
| `SaveManager` | `res://save/save_manager.tscn` | JSON save/load to `user://saves/<slot>_save_data.json`; autosave every 60 s is triggered from `Player._physics_process`. |
| `DialogueManager` | Dialogue Manager addon | Third-party dialogue plugin. |
| `Dialog` | `res://Player/dialog.gd` | Bare `Node` flag holder (`del_player` deletes the player, set by dialogue lines). |

### Notable coupling patterns

- **Health**: `states.gd` (a `Node2D` with `max_health`/`health` + setter signals) is reused two ways: autoloaded globally for the player (`PlayerStates`) **and** instanced as a child node (`$States`) inside each bat scene. The HUD (`health_ui.gd`) subscribes to `PlayerStates` signals.
- **Player `state`/`dialog` fields are set at `_ready`** (`var state = PlayerStates; var dialog = Dialog`) — they are not `@onready` node refs.
- **Inventory resource sharing**: the single source of truth is `res://inventory/playerInv.tres` — an `Inv` Resource (script `res://inventory.gd`, `class_name Inv`) holding 12 `InvSlot`s. It is exported on the player scene and also `preload`ed directly by `inv_UI.gd` and `item_counter.gd`. Note `save_manager.gd` and `task_ui.gd` read it as `PlayerStates.inv`, but `states.gd` does **not** declare an `inv` property — this path is inconsistent with the direct-preload pattern and will fail at runtime.
- Items are data Resources (`class_name InvItem`, types `HEAL`/`MATERIAL`/`KEY`) defined as `.tres` files (`inventory/item/grass.tres`, `bat.tres`). Save/load re-finds items by name against a hard-coded path list in `SaveManager.find_item_by_name`.

## Combat & collision design

Physics layers (`project.godot` `[layer_names]`): 1 World, 2 Player, 3 PlayerHurtBox, 4 EnemyHurtBox, 5 Enemy, 6 SoftCollison, 7 NPC.

The `Boxes/` folder is a modular collision system, each box a small `Area2D` scene + script:
- `hit_box.gd` — data only: `@export damage` and `@export knockback_strength`. It is the attacker's active hitbox (e.g. player's `SwordHitBox`).
- `hurt_box.gd` — the receiver. Handles i-frames (`invincible` via a `Timer`), toggles `monitoring` with `set_deferred`, spawns `hit_effect`, and emits `invincible_started`/`invincible_ended` for blink animation. `collision_mask` selects what hurts it.
- `soft_collison.gd` — overlap-based push-apart used to stop enemies from stacking.

**Damage routing is by script-name string match, not layers/groups.** Every `_on_hurt_box_area_entered(area)` in `Player.gd`, `bat.gd`, and `grass.gd` begins with:

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
- On death it creates the death effect, may drop its exported `item` (`TaskManager.spawn_drop_item`), and **hard-codes** `TaskManager.add_objective_progress("kill_bats", 0, 1)` — task id is coupled by string here and in `Player._ready` (which loads and starts `kill_bats_task.tres` if absent).
- `World/grass.gd` is the collectible pattern: it has its own HurtBox (masked to player attacks) plus a separate player-proximity `Area2D`. On hit it spawns `grass_effect`, then `player.collect(item)` → `Inv.insert()`.

## Tasks, rewards, save

- `tasks/task.gd` (`class_name Task`): status enum `NOT_STARTED`→`IN_PROGRESS`→`COMPLETED`→`REWARDED`; `objectives: Array[Dictionary]`, each dict having `name`/`progress`/`target`; `rewards: Array[InvItem]` + parallel `reward_amounts`. `get_current_objective()` returns the first non-complete objective.
- `task_ui.gd` rebuilds its whole list from `TaskManager` signals; completed tasks render a **"领取奖励" (claim)** button that inserts reward items into the inventory and shows a 3 s completion toast.
- `save_manager.gd` writes `player_states`, `player_position`, `inventory` (by item name + amount), and `tasks` (id, status, objectives) as JSON to `user://saves/1_save_data.json`.

## Gotchas

- Scripts/scenes may reference each other by **UID string** (`uid://...`) in `.tscn`/`project.godot` — keep `.uid` sidecar files intact when renaming/moving scripts, or edit the references too.
- `.godot/` is cache; `素材/` holds raw imported art (referenced by some scenes, e.g. bat `white.png`).
- The `addons/dialogue_manager` and `addons/godot_mcp` folders are third-party plugins — do not refactor their internals. `addons/dialogue_manager` is what powers `NPC.Test.dialogue` via `DialogueManager.show_example_dialogue_balloon(...)`.
