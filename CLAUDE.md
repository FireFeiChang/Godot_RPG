# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A 2D pixel-art action RPG built in **Godot 4.7 (Forward Plus renderer)**, adapted from Heartbeast's "Action RPG" tutorial and extended with dialogue, gathering/inventory, tasks, enemies, effects, save, and title-screen systems. The viewport is 320×180 (canvas_items stretch) upscaled to a 1280×720 window.

There is **no test suite, linter, or CLI build** — this is an editor-driven Godot project. Run/verify by opening the project in the Godot 4.7 editor (main scene `res://UI/main_menu.tscn`; the three playable maps are `res://world.tscn`, `res://maps/map_north.tscn`, `res://maps/map_east.tscn`). A live Godot editor with the `hasturoperationgd` bridge addon is expected to be running, so the project can be scripted through its HTTP API instead of a shell command.

> The editor process has **no autoloads** (`MapManager`, `HUD`, `PlayerStates`, … exist only at runtime), so editor-bridge checks must not reference them. Also note `ResourceLoader.load()` does **not** surface every compile error — verify scripts individually rather than trusting a load to succeed.

Detailed feature specs and asset manifests live in `PROJECT_INIT.md` (Chinese). Map layout conventions are in `地图布局参考.md` (Chinese). UI strings and most code comments are in Chinese.

## Codebase language note

Files, docs, and UI strings are primarily written in Chinese (e.g. `消灭蝙蝠`, `领取奖励`). Preserve this when editing existing strings; new content may use either language but should match the surrounding code.

## Flow / entry points

- `UI/main_menu.tscn` (main scene, `project.godot` `run/main_scene`) → Start deletes any save and calls `MapManager.begin_new_game(0)`, Continue calls `begin_new_game(1)`; both then `change_scene_to_file(MapManager.MAPS[MapManager.intended_map()])`. (`title_screen.tscn`/`.gd` are **dead code** — nothing references them.)
- **Three maps**, all registered in `maps/map_manager.gd` `MAPS`: `world` (`res://world.tscn`, village/fields), `north` (`res://maps/map_north.tscn`, mountain pass), `east` (`res://maps/map_east.tscn`, open plain camp). Each is one large `y_sort_enabled` map: tiled ground (Dirt/Cliff TileMaps), a sibling `Camera2D` (position-smoothed, per-map limits), the player, grouped Grass/Bush/Tree/Chests, enemies, and `Spawns`/`EdgeTriggers` nodes.
- **`Player` is instanced inside each map scene** (not autoloaded), and **must stay a direct child of the map root** — `save_manager._find_player()` and the `RemoteTransform2D` → `../../Camera2D` path both depend on it. Its gameplay "singletons" are autoloads referenced by name in `_ready` (`var state = PlayerStates` etc.).
- **Walking to a map edge transitions maps.** An `EdgeTrigger` (`maps/edge_trigger.gd`, `Area2D` with `collision_mask = 2`) calls `MapManager.goto_map()`. Named borders: `world` has `NorthPass`→north and `EastPass`→east; each new map has one border back to `world`. **Border names must match on both sides** (trigger `NorthPass` in one map ↔ `Spawns/NorthPass` marker in the other).
- **`Player._ready()` resets progress only on the first map entry of a session** (`MapManager.consume_fresh_start()`). Without this gate every map transition would wipe health/inventory/gold/tasks. `MapManager.install()` (called from `maps/world_map.gd` on each map root) repositions the player, snaps the camera, and applies any pending `load_game()`.
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
| `HUD` | `res://UI/hud.tscn` (+ `UI/hud.gd`) | **Shared HUD, one instance for all maps.** A `CanvasLayer` holding `Root/` → `HealthUI`, `Task_UI`, `ItemCounter`, `Toast_UI`, `inv_UI`, `GoldCounter`. `show_hud()`/`hide_hud()`; hidden outside maps (main menu). Map scenes must **not** contain their own HUD copy. |
| `MapManager` | `res://maps/map_manager.gd` | Multi-map registry + transitions. `MAPS` (id→path) / `DEFAULT_MAP` / `current_map_id`; `goto_map()` (called by `EdgeTrigger`), `install()` (called by each map root's `_ready` via `maps/world_map.gd`), `begin_new_game(slot)` / `consume_fresh_start()` / `intended_map()`. Owns the "first map entry of a session" flag that gates `Player._reset_new_game()`. |

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
- `save_manager.gd` writes `player_states`, `map_id`, `player_position`, `gold`, `inventory` (by `item_id` + amount), and `tasks` (id, status, objectives) as JSON to `user://saves/1_save_data.json`. `peek_map_id(slot)` reads only the map id (used by `MapManager.begin_new_game(1)` to pick the Continue destination); `_find_player()` resolves the player via `current_scene`.
- **`load_game()` must be called from `MapManager.install()`**, not from the main menu — at menu time `current_scene` is the menu, so `_find_player()` returns `null` and the position restore silently no-ops. `install()` calls it after the destination map is current.

## Adding a new map

1. Register the id in `MapManager.MAPS`.
2. Generate the scene with `tools/generate_maps.gd` (a dev tool driven through the editor bridge). It builds the skeleton, tiles the ground with `set_cells_terrain_connect()`, and packs the scene.
   - **Nodes you create need `owner = root`** before `PackedScene.pack()`, or `pack()` returns `OK` yet saves an **empty scene**. The generator registers them via `_new_node()` and assigns owners from that list.
   - **Never recurse into an instanced sub-scene's internals to set `owner`.** Sub-scene children already connect their own signals; stamping them into the parent copies those `[connection]` lines in, and loading then spams `Signal ... is already connected` (ERR_INVALID_PARAMETER) — the map transition "works" but errors on every switch. Instances themselves (`Player`, `Bat0`, …) DO need `owner = root`; their children must not be touched.
   - **A node added into an instanced node at build time cannot be saved by `pack()`** — verified: neither `owner = root` nor `owner = <instance>` persists it. That is why the camera's `RemoteTransform2D` is attached at runtime by `maps/world_map.gd::_ensure_camera_follow()` instead of being baked into generated scenes. (`world.tscn` is hand-edited and does have it inline; the function early-returns when it already exists.)
   - Use `set_cells_terrain_connect()`, never per-cell `set_cell()` — it picks the correct corner/edge tiles automatically. A gate is just omitting those cells from the list.
   - The cliff ring is **2 cells thick**; a gate must clear **both** rows/columns or a wall remains.
3. Keep the invariants: root is `Node2D` + `y_sort_enabled` + `maps/world_map.gd`; `Camera2D` a sibling of `Player`; camera follow via `Player/RemoteTransform2D` (runtime-attached by `world_map.gd`, path resolved with `rt.get_path_to(cam)` — **from the RT, not from the Player**); `Camera2D` limits must contain `Rect2i(0,0,320,180)`.
   - **Camera smoothing is deliberately OFF** (`position_smoothing_enabled = false` on every map's `Camera2D`; `world_map.gd::_ready` re-asserts it). `position_smoothing_speed` is in *pixels per second*, and Godot's default of `5.0` cannot track a 100 px/s player — the camera falls further behind the longer you walk. Hard-following is predictable and was the chosen fix. If you ever re-enable smoothing, set the speed well above 100 (e.g. 300).
   - Do **not** compute camera math from `Camera2D.get_viewport_rect()` — it returns the *current environment's* viewport (1920×1001 in the editor, not the game's 320×180). A wrong size inverts limit-clamp bounds and makes `clampf` return garbage.
   - **Set limits to `playable area ∓ half viewport`, not to the map size or the cliff-band centre.** The camera centre is clamped to `[limit_left + 160, limit_right − 160]`, so limits must be *wider* than the walkable area or the camera stops early while the player keeps walking — the "camera stops following after a while" bug. world: `-321, -90, 959, 698` for a walkable area of `x -161..799 y 0..608`. The generator computes this from `RING` and `HALF_VP`.
   - **`Sprite2D.region_rect.position` is a *texture* offset, not a world position.** The sprite always draws starting at the node's own `position`; `region_rect` only selects which part of the texture is sampled and how large the drawn area is. So to place the background, set the node's `position` and keep `region_rect.position` at `(0, 0)`. Writing world coordinates into `region_rect.position` silently draws only the region from the origin outward (world previously rendered only its bottom-right quadrant this way).
   - The background's drawn area must cover the **full camera range**. World: node `position = (-384, -128)`, `region_rect = Rect2(0, 0, 1344, 832)` → covers `x -384..960 y -128..704` ⊇ limits `x -321..959 y -90..698`. Keep `scale` at `(1, 1)` — a non-integer scale blurs the pixel art. Verify with `bg.get_rect()` (returns the *actual* drawn rect), not by reading `region_rect` alone.
   - **Keep the map root at `position = (0, 0)`** and give children coordinates relative to it. Moving the root shifts everything while the camera limits stay put, so the two silently drift apart: the camera stops covering the player on one side and the background stops covering the viewport. Verify with: `limit_left + 160 <= walkable.min` and `limit_right − 160 >= walkable.max` (same for Y), plus `background rect ⊇ camera limits`.
4. Add a `Spawns` marker and an `EdgeTriggers` area per border, **using the same name on both sides** (`NorthPass` etc. — don't name triggers after the origin map, or a map with two exits gets a name collision that silently renames the node to `@Name@2`).
5. Keep bats/acornbacks as **direct children of the map root** — `bat.gd`/`acornback.gd` add their death effect via `get_parent().add_child()`. Tidy them into a container and the effect dies with the enemy.
6. Do **not** add a HUD `CanvasLayer` to a map — `HUD` is an autoload and a per-map copy would render twice.

## Gotchas

- Scripts/scenes may reference each other by **UID string** (`uid://...`) in `.tscn`/`project.godot` — keep `.uid` sidecar files intact when renaming/moving scripts, or edit the references too.
- `.godot/` is cache. Raw source-art folders (`素材/原版/`, `素材/新增/`) have been deleted; every asset referenced by game code now lives in a stable project folder (e.g. `Effects/`, `UI/`, `inventory/`, `World/`, `Enemies/acornback/`). When adding new art, import it directly into its final folder — do not recreate a `素材/` dropbox.
- The `addons/dialogue_manager` and `addons/godot_mcp` folders are third-party plugins — do not refactor their internals. `addons/dialogue_manager` is what powers `NPC.Test.dialogue` via `DialogueManager.show_example_dialogue_balloon(...)`.
