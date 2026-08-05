class_name MapEnemyClassPool
extends Resource

@export_group("敌人类别池")
## 池中敌人的遭遇类别；enemy 定义必须与这里一致。
@export_enum("normal", "elite", "boss") var encounter_class := "normal"
## 此池相对同方案其他池的抽取权重；小于等于 0 时不会被抽中。
@export var weight := 1.0
## 可从本池随机选择的敌人稳定 ID 列表。
@export var enemy_ids: Array[String] = []
