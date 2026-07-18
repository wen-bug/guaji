# Mod 条件对白

dialogue 支持 text、scenes、states、member_ids、visual_ids、trait_ids_any、min_level、max_level、weight、cooldown_seconds、custom_conditions。

```json
{
  "schema_version": 1,
  "kind": "dialogue",
  "entries": [
    {
      "operation": "add",
      "local_id": "meditation_line",
      "data": {
        "text": "灵台清明，正宜修行。",
        "scenes": ["home"],
        "states": ["idle"],
        "visual_ids": ["com.author.example:disciple"],
        "min_level": 2,
        "weight": 2,
        "cooldown_seconds": 8,
        "custom_conditions": ["com.author.example:level_two"]
      }
    }
  ]
}
```

数组为空表示不限制。所有内置条件必须同时满足；trait_ids_any 中任一命格满足即可。候选按 weight 加权随机，单条 cooldown_seconds 使用单次运行内的毫秒计时。全局仍只允许一名家园角色显示气泡。

自定义条件通过 `register_dialogue_condition` 注册，签名为 `(context, definition) -> bool`。JSON 的 custom_conditions 使用完整 ID。首版不支持选项、分支节点、剧情指令或修改存档的对白动作。

`context` 包含当前场景、角色状态、成员 ID、形象 ID、等级和命格 ID 列表。回调收到深拷贝，返回值只决定该条对白是否进入候选，不得 `await`。
