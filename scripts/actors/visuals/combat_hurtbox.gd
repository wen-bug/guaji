class_name CombatHurtbox
extends Area2D

const TEAM_PARTY := "party"
const TEAM_ENEMY := "enemy"
const PARTY_LAYER := 2
const ENEMY_LAYER := 4

var actor_id := ""
var team := ""


func configure_identity(value_actor_id: String, value_team: String) -> void:
	actor_id = value_actor_id
	team = value_team
	monitoring = false
	monitorable = false
	collision_mask = 0
	collision_layer = 0
