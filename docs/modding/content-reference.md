# 内容格式参考

内容文件统一包含 `schema_version`、`kind` 和 `entries`。完整信封见 `schemas/v1/content.schema.json`，每类 data 见同目录的 `<kind>.schema.json`。

- `add`：填写 `local_id` 和 `data`，得到完整 ID `<mod_id>:<local_id>`。
- `patch`：填写现有 `target_id` 和 `patch`，并在 Manifest 授权。
- Patch 使用 RFC 7396：对象递归合并，数组整体替换，null 删除字段；合并结果重新执行完整校验。

支持的 kind：

| kind | 最小必填 |
| --- | --- |
| item | name、type |
| equipment | name、slot |
| skill / basic_attack | name、scene_path |
| recipe | result_item_id、materials |
| trait | name、effects |
| enemy | name、visual_id、scene_path |
| enemy_rank | name |
| drop_table | 无 |
| appearance | kind、scene_path |
| dialogue | text |

## 字段与默认值

| kind | 主要字段 | 默认值与限制 |
| --- | --- | --- |
| item | name、type、description、stackable、usable、payload、icon_path | stackable=false、usable=false；技能书 payload.skill_id 必须存在 |
| equipment | name、slot、tier、base_attributes、effects | slot 必填；数值字段不能为负数 |
| skill | name、scene_path、type、target_scope、mp_cost、cooldown、effects | target_scope=single_enemy、mp_cost=0、cooldown=0 |
| basic_attack | 与 skill 相同，另有 attack_mode、range | mp_cost=0、cooldown=0 |
| recipe | result_item_id、result_count、materials | result_count=1；材料和产物必须存在 |
| trait | name、description、effects | effects=[] |
| enemy | name、visual_id、scene_path、skills、drops | skills=[]；形象和技能必须存在 |
| enemy_rank | name、stat_multiplier、reward_multiplier | 两个倍率默认 1.0 |
| drop_table | entries 或 categories | 空表允许；物品 ID 必须存在 |
| appearance | kind、scene_path、fallback_id、contract_version | kind=party/enemy，contract_version=1 |
| dialogue | text、scenes、states、weight、cooldown_seconds、custom_conditions | 数组=[]、weight=1、cooldown_seconds=0 |

可使用物品可声明 `payload.permanent_building_quality = {"building_id": "forge", "amount": 1}`。`building_id` 仅接受 `farm`、`forge`、`alchemy`，`amount` 必须为正整数；成功使用后消耗一个物品并永久累加账号建筑品质。当前只有 `forge` 品质参与产出计算。

`target_scope` 枚举为 `self`、`single_ally`、`all_allies`、`single_enemy`、`all_enemies`。appearance 的 `kind` 仅为 `party` 或 `enemy`。字段未写时由业务层使用上述默认值；兼容字段只会新增且必须带默认值。

## Patch

```json
{
  "schema_version": 1,
  "kind": "skill",
  "entries": [
    {
      "operation": "patch",
      "target_id": "heal",
      "patch": {
        "mp_cost": 4
      }
    }
  ]
}
```

技能、敌人、配方等引用使用完整内容 ID。Mod 可以引用硬依赖提供的内容 ID，但不能引用其私有资源路径。资源路径、配方材料、敌人技能、自定义 effect/condition 和场景存在性会在注册提交前统一检查，因此同一 Mod 内允许前向引用。形象 fallback 环会拒绝。

本体 ID 为兼容旧存档保持短 ID，例如 `heal`。Mod 新内容必须使用自动命名空间，不能伪造本体短 ID。
