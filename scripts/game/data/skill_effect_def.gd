class_name SkillEffectDef
extends Resource

@export_group("基础效果")
## 同一技能内稳定且可读的效果 ID，用于事件追踪和调试。
@export var effect_id := "impact"
## 效果类型：伤害、治疗、状态或冷却修正。
@export_enum("damage", "heal", "status", "cooldown") var kind := "damage"
## 效果目标来源；hit_targets 只包含前序伤害实际命中的目标。
@export_enum("skill_targets", "caster", "primary_target", "hit_targets") var target := "skill_targets"
## 由技能动画中的同名 impact 标记触发；旧技能保持默认 impact。
@export var impact_id := "impact"
## 不依赖属性的固定基础数值。
@export var base_amount := 0
## 施法者对应五行属性的倍率，最终数值向下取整。
@export var attribute_multiplier := 0.0
## 效果自身五行；为空时继承技能五行。
@export var element := ""
## 伤害是否可被护盾吸收；直伤通常开启，DOT 通常关闭。
@export var shieldable := true
## 本次伤害无视的防御数值。
@export var defense_ignore := 0
## 按最终伤害恢复施法者生命的比例，范围为 0 到 1。
@export_range(0.0, 1.0, 0.01) var leech_ratio := 0.0
## 是否只有前序效果命中后才执行，常用于命中后附加状态。
@export var requires_hit := false
## 冷却效果使用的乘数，例如 0.8 表示本技能冷却缩短 20%。
@export var cooldown_multiplier := 1.0

@export_group("状态参数")
## 状态的稳定 ID；刷新、叠层和状态表现都通过它识别同一状态。
@export var status_id := ""
## 状态类型：持续伤害、持续治疗、护盾、属性增益或属性减益。
@export_enum("dot", "hot", "shield", "buff_stat", "debuff_stat") var status_kind := "dot"
## buff_stat 或 debuff_stat 修改的属性 ID，例如 attack 或 defense。
@export var stat := ""
## 持续的目标自身回合数；DOT/HOT 在目标回合开始触发。
@export var duration_turns := 1
## 同 ID 状态重复施加时刷新，或增加层数并刷新持续时间。
@export_enum("refresh", "stack") var stack_mode := "refresh"
## stack 模式允许的最大层数；refresh 模式保持为 1。
@export var max_stacks := 1
## 挂载到目标 EffectSocket 的持续状态表现场景；在 Inspector 中直接选择共享状态场景。
@export var status_visual_scene: PackedScene
## 状态栏专用图标路径；为空时使用来源技能图标。
@export_file("*.png", "*.webp", "*.svg") var icon_path := ""


func to_dictionary() -> Dictionary:
	var result := {
		"effect_id": effect_id,
		"kind": kind,
		"target": target,
		"impact_id": impact_id,
	}
	match kind:
		"damage":
			result.merge({"base_amount": base_amount, "attribute_multiplier": attribute_multiplier, "element": element, "shieldable": shieldable, "defense_ignore": defense_ignore, "leech_ratio": leech_ratio}, true)
		"heal":
			result.merge({"base_amount": base_amount, "attribute_multiplier": attribute_multiplier, "element": element}, true)
		"status":
			var status_scene_path := status_visual_scene.resource_path if status_visual_scene != null else ""
			result.merge({
				"status_id": status_id,
				"status_kind": status_kind,
				"base_amount": base_amount,
				"attribute_multiplier": attribute_multiplier,
				"element": element,
				"stat": stat,
				"duration_turns": duration_turns,
				"stack_mode": stack_mode,
				"max_stacks": max_stacks,
				"requires_hit": requires_hit,
				"status_scene_path": status_scene_path,
				"icon_path": icon_path,
			}, true)
		"cooldown":
			result["multiplier"] = cooldown_multiplier
	return result
