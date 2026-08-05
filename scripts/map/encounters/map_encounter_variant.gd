class_name MapEncounterVariant
extends Resource

@export_group("遭遇方案")
## 方案在当前 Profile 内的稳定 ID，便于日志和人工识别。
@export var id := "default"
## 此方案相对其他方案的抽取权重；小于等于 0 时不会被抽中。
@export var weight := 1.0
## 固定敌人编队；非空时忽略 class_pools。
@export var fixed_enemy_ids: Array[String] = []
## 随机编队使用的 MapEnemyClassPool 资源列表。
@export var class_pools: Array[Resource] = []
