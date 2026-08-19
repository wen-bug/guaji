# Mod 条件对白

`dialogue` 支持 `text`、`scenes`、`states`、`member_ids`、`visual_ids`、`trait_ids_any`、`min_level`、`max_level`、`weight`、`cooldown_seconds` 和 `custom_conditions`。

```json
{
  "schema_version": 2,
  "kind": "dialogue",
  "entries": [
    {
      "operation": "add",
      "local_id": "meditation_line",
      "data": {
        "text": "灵台清明，正宜修行。",
        "scenes": ["home"],
        "states": ["idle"],
        "min_level": 2,
        "weight": 2,
        "cooldown_seconds": 8
      }
    }
  ]
}
```

数组为空表示不限制；所有内置条件必须同时满足，`trait_ids_any` 中任一命格满足即可。候选按 `weight` 加权随机，单条冷却只在本次运行中计时。

自定义条件通过 `register_dialogue_condition()` 注册，签名为 `(context, definition) -> bool`。回调收到深拷贝，只能决定该对白是否进入候选，不得 `await` 或修改核心存档。
