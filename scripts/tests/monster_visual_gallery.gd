extends Node2D


func _ready() -> void:
	show_phase(0)


func show_phase(phase: int) -> void:
	for child in get_children():
		var visual := child as CombatVisual
		if visual == null:
			continue
		match phase:
			1:
				visual.play_run()
			2:
				if child.name == "ShamanVisual":
					visual.play_ranged_attack(1)
				else:
					visual.play_melee_attack(1)
			_:
				visual.play_idle()
