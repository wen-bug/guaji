class_name ZoneManager
extends RefCounted

var blocks := {}
var zones := {}


func _init() -> void:
	blocks = {
		"home": {
			"id": "home",
			"display_name": "家园",
			"bounds": Rect2(16, 72, 708, 82),
			"color": Color(0.16, 0.48, 0.38, 0.16),
		},
		"adventure": {
			"id": "adventure",
			"display_name": "历练",
			"bounds": Rect2(744, 72, 196, 82),
			"color": Color(0.58, 0.17, 0.16, 0.16),
		},
	}
	zones = {
		"meditate": {
			"id": "meditate",
			"block": "home",
			"task_type": GameDefs.TaskType.MEDITATE,
			"anchor_position": Vector2(86, 132),
			"bounds": Rect2(28, 88, 118, 58),
			"display_name": "打坐",
			"color": Color(0.20, 0.45, 0.95, 0.20),
		},
		"farm": {
			"id": "farm",
			"block": "home",
			"task_type": GameDefs.TaskType.FARM,
			"anchor_position": Vector2(245, 132),
			"bounds": Rect2(176, 88, 138, 58),
			"display_name": "农田",
			"color": Color(0.25, 0.75, 0.35, 0.22),
		},
		"forge": {
			"id": "forge",
			"block": "home",
			"task_type": GameDefs.TaskType.FORGE,
			"anchor_position": Vector2(425, 132),
			"bounds": Rect2(354, 88, 142, 58),
			"display_name": "炼器",
			"color": Color(0.88, 0.46, 0.18, 0.22),
		},
		"alchemy": {
			"id": "alchemy",
			"block": "home",
			"task_type": GameDefs.TaskType.ALCHEMY,
			"anchor_position": Vector2(615, 132),
			"bounds": Rect2(540, 88, 146, 58),
			"display_name": "炼丹",
			"color": Color(0.72, 0.38, 0.82, 0.22),
		},
		"fight": {
			"id": "fight",
			"block": "adventure",
			"task_type": GameDefs.TaskType.FIGHT,
			"anchor_position": Vector2(805, 132),
			"bounds": Rect2(764, 88, 152, 58),
			"display_name": "打怪",
			"color": Color(0.9, 0.18, 0.18, 0.20),
		},
	}


func get_zone_for_task(task_type: int) -> Dictionary:
	return zones[DataTables.task_zone_id(task_type)]


func get_all_zones() -> Array:
	return zones.values()


func get_all_blocks() -> Array:
	return blocks.values()
