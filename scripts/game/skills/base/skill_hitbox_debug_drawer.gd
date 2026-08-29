class_name SkillHitboxDebugDrawer
extends Node2D

const ENEMY_FILL := Color(0.95, 0.16, 0.18, 0.3)
const ENEMY_BORDER := Color(1.0, 0.34, 0.25, 0.95)
const ALLY_FILL := Color(0.08, 0.85, 0.72, 0.28)
const ALLY_BORDER := Color(0.2, 1.0, 0.86, 0.95)
const CURVE_SEGMENTS := 32

var hitbox: Area2D
var targets_allies := false


func setup(value_hitbox: Area2D, value_targets_allies: bool) -> void:
	hitbox = value_hitbox
	targets_allies = value_targets_allies
	z_index = 100
	queue_redraw()


func _draw() -> void:
	if hitbox == null or not is_instance_valid(hitbox):
		return
	var fill := ALLY_FILL if targets_allies else ENEMY_FILL
	var border := ALLY_BORDER if targets_allies else ENEMY_BORDER
	for child in hitbox.get_children():
		if not (child is CollisionShape2D):
			continue
		var collision_shape := child as CollisionShape2D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		var points := _shape_points(collision_shape.shape)
		if points.size() < 3:
			continue
		var transformed := PackedVector2Array()
		for point in points:
			transformed.append(to_local(collision_shape.to_global(point)))
		draw_colored_polygon(transformed, fill)
		var outline := transformed.duplicate()
		outline.append(transformed[0])
		draw_polyline(outline, border, 2.0, true)


func _shape_points(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var half_size := (shape as RectangleShape2D).size * 0.5
		return PackedVector2Array([
			Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y),
		])
	if shape is CircleShape2D:
		return _ellipse_points((shape as CircleShape2D).radius, (shape as CircleShape2D).radius)
	if shape is CapsuleShape2D:
		return _capsule_points(shape as CapsuleShape2D)
	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points
	return PackedVector2Array()


func _ellipse_points(radius_x: float, radius_y: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(CURVE_SEGMENTS):
		var angle := TAU * float(index) / float(CURVE_SEGMENTS)
		result.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return result


func _capsule_points(shape: CapsuleShape2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	var radius: float = shape.width * 0.5
	var straight_half: float = maxf(0.0, shape.height * 0.5 - radius)
	var semicircle_segments := CURVE_SEGMENTS >> 1
	for index in range(semicircle_segments + 1):
		var angle := PI + PI * float(index) / float(semicircle_segments)
		result.append(Vector2(cos(angle) * radius, -straight_half + sin(angle) * radius))
	for index in range(semicircle_segments + 1):
		var angle := PI * float(index) / float(semicircle_segments)
		result.append(Vector2(cos(angle) * radius, straight_half + sin(angle) * radius))
	return result
