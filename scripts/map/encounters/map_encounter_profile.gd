class_name MapEncounterProfile
extends Resource

const MAX_SUPPORTED_ENEMIES := 8
const MapEncounterVariantScript = preload("res://scripts/map/encounters/map_encounter_variant.gd")
const MapEnemyClassPoolScript = preload("res://scripts/map/encounters/map_enemy_class_pool.gd")

@export var profile_id := "default"
@export var fallback_enemy_id := ""
@export_range(1, 8, 1) var enemies_per_party_member := 2
@export_range(1, 8, 1) var min_enemy_count := 1
@export_range(1, 8, 1) var max_enemy_count := 8
@export var variants: Array[Resource] = []


func roll_enemy_ids(party_size: int, _level: int, rng: RandomNumberGenerator) -> Array[String]:
	if rng == null:
		return _fallback_group("缺少随机数生成器")
	var usable_variants: Array[Dictionary] = []
	for resource in variants:
		var variant: Resource = resource if resource != null and resource.get_script() == MapEncounterVariantScript else null
		if variant == null or variant.weight <= 0.0:
			continue
		var prepared := _prepare_variant(variant)
		if prepared.is_empty():
			continue
		prepared["weight"] = variant.weight
		usable_variants.append(prepared)
	if usable_variants.is_empty():
		return _fallback_group("没有可用的遭遇方案")
	var chosen: Dictionary = _weighted_pick(usable_variants, rng)
	var fixed_ids: Array[String] = []
	fixed_ids.assign(chosen.get("fixed_enemy_ids", []))
	if not fixed_ids.is_empty():
		if fixed_ids.size() > MAX_SUPPORTED_ENEMIES:
			push_warning("地图遭遇配置 %s 的固定编队超过 %d，只保留前 %d 个" % [profile_id, MAX_SUPPORTED_ENEMIES, MAX_SUPPORTED_ENEMIES])
			fixed_ids.resize(MAX_SUPPORTED_ENEMIES)
		return fixed_ids
	var pools: Array[Dictionary] = chosen.get("pools", [])
	if pools.is_empty():
		return _fallback_group("选中的随机遭遇方案没有可用敌人池")
	var minimum := clampi(min_enemy_count, 1, MAX_SUPPORTED_ENEMIES)
	var maximum := clampi(max_enemy_count, minimum, MAX_SUPPORTED_ENEMIES)
	var enemy_count := clampi(maxi(1, party_size) * maxi(1, enemies_per_party_member), minimum, maximum)
	var result: Array[String] = []
	for _index in range(enemy_count):
		var pool: Dictionary = _weighted_pick(pools, rng)
		var pool_ids: Array[String] = []
		pool_ids.assign(pool.get("enemy_ids", []))
		result.append(pool_ids[rng.randi_range(0, pool_ids.size() - 1)])
	return result


func _prepare_variant(variant: Resource) -> Dictionary:
	if not variant.fixed_enemy_ids.is_empty():
		var fixed_ids := _valid_enemy_ids(variant.fixed_enemy_ids)
		return {"fixed_enemy_ids": fixed_ids} if not fixed_ids.is_empty() else {}
	var pools: Array[Dictionary] = []
	for resource in variant.class_pools:
		var pool: Resource = resource if resource != null and resource.get_script() == MapEnemyClassPoolScript else null
		if pool == null or pool.weight <= 0.0:
			continue
		var valid_ids: Array[String] = []
		for enemy_id in _valid_enemy_ids(pool.enemy_ids):
			var definition := DataTables.content_definition("enemy", enemy_id, DataTables.ENEMY_TEMPLATES.get(enemy_id, {}))
			var actual_class := str(definition.get("encounter_class", "normal"))
			if actual_class != pool.encounter_class:
				push_warning("地图遭遇配置 %s：敌人 %s 属于 %s，不能放入 %s 池" % [profile_id, enemy_id, actual_class, pool.encounter_class])
				continue
			valid_ids.append(enemy_id)
		if not valid_ids.is_empty():
			pools.append({"weight": pool.weight, "enemy_ids": valid_ids})
	return {"pools": pools} if not pools.is_empty() else {}


func _valid_enemy_ids(raw_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for raw_id in raw_ids:
		var enemy_id := str(raw_id)
		if enemy_id.is_empty() or not DataTables.content_has("enemy", enemy_id, DataTables.ENEMY_TEMPLATES):
			push_warning("地图遭遇配置 %s 引用了无效敌人：%s" % [profile_id, enemy_id])
			continue
		result.append(enemy_id)
	return result


func _weighted_pick(entries: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0.0
	for entry in entries:
		total_weight += maxf(0.0, float(entry.get("weight", 0.0)))
	var roll := rng.randf() * total_weight
	for entry in entries:
		roll -= maxf(0.0, float(entry.get("weight", 0.0)))
		if roll <= 0.0:
			return entry
	return entries.back()


func _fallback_group(reason: String) -> Array[String]:
	if not fallback_enemy_id.is_empty() and DataTables.content_has("enemy", fallback_enemy_id, DataTables.ENEMY_TEMPLATES):
		push_warning("地图遭遇配置 %s：%s，改用地图兜底敌人 %s" % [profile_id, reason, fallback_enemy_id])
		return [fallback_enemy_id]
	push_error("地图遭遇配置 %s：%s，且 fallback_enemy_id 无效" % [profile_id, reason])
	return []
