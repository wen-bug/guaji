class_name SkillCastContext
extends RefCounted

## 施法者的战斗状态；技能场景只读取身份、位置和队伍信息。
var caster: CombatActorStatus
## AI 或战斗控制器预先选中的目标；没有 SkillHitbox 时直接使用。
var selected_targets: Array = []
## 技能表现锚点；有限 AOE 使用截取范围的第一个目标。
var anchor_target: CombatActorStatus
## 水平表现方向：玩家为 1，敌人为 -1。
var facing_direction := 1
## 本次施法允许命中的稳定顺序候选列表；碰撞结果按此顺序过滤。
var ordered_candidates: Array = []
## 从当前注册定义解析出的技能数据，包含有序 effects。
var skill_data: Dictionary = {}
## 统一效果解析器，由技能执行器使用。
var effect_resolver: CombatEffectResolver
## 战斗共用随机源；自定义效果不得自行创建不可复现的随机源。
var rng: RandomNumberGenerator


static func create(
	skill_caster: CombatActorStatus,
	preselected_targets: Array,
	candidates: Array,
	definition: Dictionary,
	resolver: CombatEffectResolver,
	random_source: RandomNumberGenerator = null,
	visual_anchor: CombatActorStatus = null,
	visual_direction: int = 1
) -> SkillCastContext:
	var context := SkillCastContext.new()
	context.caster = skill_caster
	context.selected_targets = preselected_targets.duplicate()
	context.anchor_target = visual_anchor if visual_anchor != null else (preselected_targets[0] as CombatActorStatus if not preselected_targets.is_empty() else null)
	context.facing_direction = -1 if visual_direction < 0 else 1
	context.ordered_candidates = candidates.duplicate()
	context.skill_data = definition.duplicate(true)
	context.effect_resolver = resolver
	context.rng = random_source
	return context
