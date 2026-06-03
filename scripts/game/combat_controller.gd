class_name CombatController
extends Node2D

signal log_added(message: String)

var active := false
var finished := false
var enemy := {}
var attack_timer := 0.0
var enemy_timer := 0.0
var skill_cooldowns := {}
var enemy_position := Vector2(866, 126)
var enemy_visual: Node2D
var hp_fill: ColorRect


func _ready() -> void:
	_bind_scene_nodes()
	_update_enemy_visual()


func begin_encounter(game_state) -> void:
	_bind_scene_nodes()
	enemy = DataTables.create_enemy(game_state.stats["level"], game_state.rng)
	active = true
	finished = false
	attack_timer = 0.0
	enemy_timer = 0.8
	skill_cooldowns.clear()
	log_added.emit("遭遇%s，弱%s" % [enemy["name"], DataTables.element_name(enemy["weak_element"])])
	_update_enemy_visual()


func tick(delta: float, game_state) -> void:
	if not active or finished:
		return

	attack_timer -= delta
	enemy_timer -= delta
	_tick_skill_cooldowns(delta)

	if attack_timer <= 0.0:
		attack_timer = 1.1
		_damage_enemy(_player_damage(game_state, game_state.total_attack()))

	_try_cast_skill(game_state)

	if enemy["hp"] <= 0:
		_finish_victory(game_state)
		return

	if enemy_timer <= 0.0:
		enemy_timer = 1.4
		var damage_to_player: int = int(enemy["attack"])
		var element_id := ""
		if game_state.rng.randf() < float(enemy.get("element_attack_ratio", 0.0)):
			element_id = enemy.get("element", "")
		game_state.take_damage(damage_to_player, element_id)
		if game_state.stats["hp"] <= 0:
			_finish_defeat(game_state)

	_update_enemy_visual()


func is_finished() -> bool:
	return finished


func clear() -> void:
	active = false
	finished = false
	enemy = {}
	_update_enemy_visual()


func _player_damage(game_state, base_damage: int, attack_element := "") -> int:
	var damage: int = max(1, int(base_damage - enemy["defense"]))
	var element_id: String = attack_element
	if element_id.is_empty():
		element_id = game_state.dominant_element()
	damage += game_state.element_damage_bonus(element_id)
	if element_id == enemy["weak_element"]:
		damage += max(1, int(base_damage * 0.25)) + game_state.elements.get(element_id, 0)
	return damage


func _tick_skill_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0.0, float(skill_cooldowns[skill_id]) - delta)


func _try_cast_skill(game_state) -> void:
	if game_state.skills.is_empty():
		return

	for skill in game_state.skills:
		var skill_id: String = skill["id"]
		if float(skill_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		if not game_state.spend_mp(int(skill["mp_cost"])):
			continue

		skill_cooldowns[skill_id] = float(skill["cooldown"])
		var damage := int(game_state.total_attack() * float(skill["damage_multiplier"]))
		_damage_enemy(_player_damage(game_state, damage, skill.get("element", "")))
		log_added.emit("释放%s" % skill["name"])
		return


func _damage_enemy(amount: int) -> void:
	enemy["hp"] = max(0, enemy["hp"] - amount)
	_update_enemy_visual()


func _finish_victory(game_state) -> void:
	finished = true
	active = false
	game_state.add_exp(enemy["exp"])
	_resolve_drops(game_state)
	if game_state.rng.randf() > 0.65:
		game_state.add_equipment(DataTables.create_equipment(int(enemy.get("level", game_state.stats["level"])), game_state.rng, game_state.craft_bonus()))
	log_added.emit("击败%s" % enemy["name"])
	_update_enemy_visual()


func _resolve_drops(game_state) -> void:
	var drops: Dictionary = enemy.get("drops", {})
	for item_id in drops.keys():
		var drop_def: Dictionary = drops[item_id]
		if game_state.rng.randf() > float(drop_def.get("chance", 1.0)):
			continue
		var min_amount := int(drop_def.get("min", 1))
		var max_amount := int(drop_def.get("max", min_amount))
		game_state.gain_resource(item_id, game_state.rng.randi_range(min_amount, max_amount))


func _finish_defeat(game_state) -> void:
	finished = true
	active = false
	game_state.stats["hp"] = 1
	game_state.stats["mp"] = 0
	log_added.emit("战斗失败，需要打坐恢复")
	_update_enemy_visual()


func _bind_scene_nodes() -> void:
	if enemy_visual == null:
		enemy_visual = $EnemyVisual
	if hp_fill == null:
		hp_fill = $EnemyVisual/HPBack/HPFill


func _update_enemy_visual() -> void:
	_bind_scene_nodes()
	var should_show := active and not enemy.is_empty()
	enemy_visual.visible = should_show
	if not should_show:
		return
	enemy_visual.position = enemy_position
	var ratio: float = clamp(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
	hp_fill.size.x = 48.0 * ratio
