class_name MapEnemyClassPool
extends Resource

@export_enum("normal", "elite", "boss") var encounter_class := "normal"
@export var weight := 1.0
@export var enemy_ids: Array[String] = []
