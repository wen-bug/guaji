class_name SkillProjectilePath
extends Node2D

## 抛物线顶点相对直线轨迹向上的像素高度。
@export var arc_height := 48.0
## 起点相对施法者效果锚点的偏移。
@export var start_offset := Vector2.ZERO
## 终点相对受击目标命中锚点的偏移。
@export var end_offset := Vector2.ZERO
## 由 AnimationPlayer 属性轨道从 0 动画到 1；代码只负责映射到抛物线位置。
@export_range(0.0, 1.0, 0.001) var flight_progress := 0.0:
	set(value):
		flight_progress = clampf(value, 0.0, 1.0)
		_update_position()

var _start_global := Vector2.ZERO
var _end_global := Vector2.ZERO
var _configured := false


func configure_path(start_global: Vector2, end_global: Vector2) -> void:
	_start_global = start_global + start_offset
	_end_global = end_global + end_offset
	_configured = true
	flight_progress = 0.0


func expected_global_position(progress: float) -> Vector2:
	var value := clampf(progress, 0.0, 1.0)
	var linear := _start_global.lerp(_end_global, value)
	return linear + Vector2(0.0, -4.0 * arc_height * value * (1.0 - value))


func _update_position() -> void:
	if _configured:
		global_position = expected_global_position(flight_progress)
