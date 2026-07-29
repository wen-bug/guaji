extends Node

const VISUAL_ROOT := "res://scripts/actors/visuals/enemies"
const EXPECTED_SCALE := Vector2(0.28, 0.28)
const MONSTERS := {
	"bear": {"animations": {"idle": [8, true, 5.0], "run": [5, true, 5.0], "melee_attack": [9, false, 5.0]}},
	"gnome": {"animations": {"idle": [8, true, 5.0], "run": [6, true, 5.0], "melee_attack": [7, false, 5.0]}},
	"lancer": {"animations": {"idle": [7, true, 5.0], "run": [6, true, 5.0], "melee_attack": [8, false, 5.0]}},
	"lizard": {"animations": {"idle": [7, true, 5.0], "run": [6, true, 5.0], "melee_attack": [9, false, 5.0], "hurt": [2, false, 5.0]}},
	"minotaur": {"animations": {"idle": [16, true, 5.0], "walk": [8, true, 3.5], "melee_attack": [12, false, 5.0], "guard": [11, true, 5.0]}},
	"paddle_fish": {"animations": {"idle": [8, true, 5.0], "run": [6, true, 5.0], "melee_attack": [6, false, 5.0]}},
	"panda": {"animations": {"idle": [10, true, 5.0], "run": [6, true, 5.0], "melee_attack": [13, false, 5.0], "guard": [8, true, 5.0]}},
	"shaman": {"animations": {"idle": [8, true, 5.0], "run": [4, true, 5.0], "ranged_attack": [10, false, 5.0]}},
	"skull": {"animations": {"idle": [8, true, 5.0], "run": [6, true, 5.0], "melee_attack": [7, false, 5.0], "guard": [7, true, 5.0]}},
	"snake": {"animations": {"idle": [8, true, 5.0], "run": [8, true, 5.0], "melee_attack": [6, false, 5.0]}},
	"spider": {"animations": {"idle": [8, true, 5.0], "run": [5, true, 5.0], "melee_attack": [8, false, 5.0]}},
	"thief": {"animations": {"idle": [6, true, 5.0], "run": [6, true, 5.0], "melee_attack": [6, false, 5.0]}},
	"troll": {"animations": {"idle": [12, true, 5.0], "walk": [10, true, 3.5], "melee_attack": [6, false, 5.0], "windup": [5, false, 5.0], "recovery": [10, false, 5.0], "death": [10, false, 5.0]}},
	"turtle": {"animations": {"idle": [10, true, 5.0], "walk": [7, true, 3.5], "melee_attack": [10, false, 5.0], "guard_in": [6, false, 5.0], "guard_out": [3, false, 5.0]}},
}

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for visual_id in MONSTERS:
		_check_visual(str(visual_id), MONSTERS[visual_id])
	if failures.is_empty():
		print("MONSTER_VISUAL_SMOKE_PASS: %d scenes" % MONSTERS.size())
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _check_visual(visual_id: String, expected: Dictionary) -> void:
	var scene_path := "%s/%s.tscn" % [VISUAL_ROOT, visual_id]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail(visual_id, "scene failed to load")
		return
	var visual := packed.instantiate() as CombatVisual
	if visual == null:
		_fail(visual_id, "root is not CombatVisual")
		return
	add_child(visual)
	var contract_issue := visual.contract_error()
	if not contract_issue.is_empty():
		_fail(visual_id, "contract error: %s" % contract_issue)
	var sprite := visual.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		_fail(visual_id, "missing Sprite")
	else:
		if not sprite.scale.is_equal_approx(EXPECTED_SCALE):
			_fail(visual_id, "unexpected sprite scale: %s" % sprite.scale)
		if not sprite.flip_h:
			_fail(visual_id, "sprite must face left")
		_check_animations(visual_id, sprite.sprite_frames, expected.get("animations", {}))
	var appearance := DataTables.content_definition("appearance", visual_id)
	if str(appearance.get("kind", "")) != "enemy" or str(appearance.get("scene_path", "")) != scene_path:
		_fail(visual_id, "core appearance registration mismatch")
	if visual_id != "shaman" and visual.attack_hit_start_frame > visual.attack_hit_end_frame:
		_fail(visual_id, "invalid melee hit frame range")
	remove_child(visual)
	visual.free()


func _check_animations(visual_id: String, frames: SpriteFrames, expected: Dictionary) -> void:
	if frames == null:
		_fail(visual_id, "missing SpriteFrames")
		return
	for animation_name in expected:
		var animation_key := StringName(animation_name)
		var spec: Array = expected[animation_name]
		if not frames.has_animation(animation_key):
			_fail(visual_id, "missing animation: %s" % animation_name)
			continue
		if frames.get_frame_count(animation_key) != int(spec[0]):
			_fail(visual_id, "%s frame count mismatch" % animation_name)
		if frames.get_animation_loop(animation_key) != bool(spec[1]):
			_fail(visual_id, "%s loop mismatch" % animation_name)
		if not is_equal_approx(frames.get_animation_speed(animation_key), float(spec[2])):
			_fail(visual_id, "%s speed mismatch" % animation_name)


func _fail(visual_id: String, message: String) -> void:
	failures.append("%s: %s" % [visual_id, message])
