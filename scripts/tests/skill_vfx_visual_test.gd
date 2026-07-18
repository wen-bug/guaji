extends Node2D

@onready var party_actors: Node2D = $PartyActors
@onready var combat: CombatController = $CombatController

var game_state := GameState.new()


func _ready() -> void:
	var candidate_id := str(game_state.recruit_candidates[0].get("candidate_id", ""))
	if not game_state.recruit_candidate(candidate_id):
		push_error("技能特效预览无法招募测试角色")
		return
	var member_id := game_state.default_party_member_id()
	var member: Dictionary = game_state.member_by_id(member_id)
	member["skills"] = [DataTables.create_skill("poison")]
	member.get("stats", {})["mp"] = 999
	var actor_scene := load("res://scripts/actors/actor.tscn") as PackedScene
	var actor := actor_scene.instantiate() as ActorController
	party_actors.add_child(actor)
	actor.configure_member(member, 0)
	combat.set_party_views({member_id: actor})
	combat.begin_encounter(game_state, null, "training_dummy", 1)
	combat.enemy["max_hp"] = 9999
	combat.enemy["hp"] = 9999
	combat.enemy["attack"] = 0
	combat.tick(1.0 / 60.0, game_state)
	var skill_scene: SkillSceneBase = combat._active_skill_scenes.get(member_id) as SkillSceneBase
	if skill_scene == null:
		push_error("技能特效预览未进入技能播放状态")
		return
	skill_scene._process(0.4)
	skill_scene.set_process(false)
