# Mod 内容格式参考

内容文件统一使用 Schema 2 信封。完整定义见 [content.schema.json](schemas/v2/content.schema.json) 和同目录的各类 Schema。

```json
{
  "schema_version": 2,
  "kind": "dialogue",
  "entries": []
}
```

- `add`：提供 `local_id` 和 `data`，注册为 `<mod_id>:<local_id>`。
- `patch`：提供现有 `target_id` 和 RFC 7396 `patch`，并在 Manifest 的 `overrides` 中授权。
- Patch 对象递归合并、数组整体替换、`null` 删除字段；合并后重新执行完整校验。

## 内容类型

| kind | 新增时最小内容 |
| --- | --- |
| `item` | `name`、`type` |
| `equipment` | `name`、`slot` |
| `skill` | `scene_path`；定义从场景绑定的 `SkillDef` 读取 |
| `basic_attack` | `name`、`effects` |
| `recipe` | `result_item_id`、`materials` |
| `trait` | `name`、`effects` |
| `enemy` | `name`、`visual_id`、`scene_path` |
| `enemy_rank` | `name` |
| `drop_table` | 无必填字段 |
| `appearance` | `kind`、`scene_path` |
| `dialogue` | `text` |

技能、敌人、配方等引用使用完整内容 ID。本体 ID 为兼容存档保持短 ID；Mod 新内容必须使用自动命名空间。Mod 只能引用自身或硬依赖提供的逻辑 ID，不能引用其他 Mod 的私有资源路径。

## 关键约束

- `target_scope`：`self`、`single_ally`、`all_allies`、`single_enemy`、`all_enemies`。
- `target_mode`：`single` 或 `aoe`；技能不按距离判断可用性。
- 敌人类别：`normal`、`elite`、`boss`。
- 形象类别：`party`、`enemy`；`contract_version` 当前固定为 `1`。
- 配方 `unlock_building_level` 为 `1-10`。
- 资源路径、场景、配方材料、敌人技能、自定义处理器和 fallback 环会在提交前校验。

可使用物品可以声明永久属性强化：

```json
{
  "permanent_attribute_enhance": {
    "tier_id": "t1",
    "effects": [
      {"stat": "attack", "amount": 1}
    ]
  }
}
```

`tier_id` 当前只接受 `t1`。`effects` 不能为空，属性只能使用攻击、防御、生命、法力、根骨和五行属性，同一物品中不能重复；`amount` 必须为正整数，省略时为 `1`。

## Patch 示例

```json
{
  "schema_version": 2,
  "kind": "skill",
  "entries": [
    {
      "operation": "patch",
      "target_id": "heal",
      "patch": {"mp_cost": 4}
    }
  ]
}
```

技能 `id` 是稳定标识，不能 patch。替换 `scene_path` 时，新场景必须继续提供相同技能 ID 并满足 API 2 技能场景契约。
