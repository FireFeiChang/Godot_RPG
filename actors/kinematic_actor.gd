class_name KinematicActor
extends CharacterBody2D
## 可复用的匀速/加速度角色移动基类（2D）。
## 供需要"向目标点加速移动 + 摩擦减速"的敌人/单位继承，
## 通过 @export 在场景或子类中配置手感参数。

@export var ACCELERATION := 400.0
@export var FRICTION := 200.0
@export var MAX_SPEED := 100.0

## 朝目标点匀速加速移动（配合 move_and_slide() 使用，速度写入 velocity）。
func accelerate_towards_point(point: Vector2, delta: float) -> void:
	var direction := global_position.direction_to(point)
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)

## 朝任意方向向量加速移动（向量需先归一化）。
func accelerate_towards(direction: Vector2, delta: float) -> void:
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCELERATION * delta)

## 无输入时按摩擦减速到零。
func apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
