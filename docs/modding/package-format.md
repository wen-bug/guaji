# Mod 包格式

## 目录结构

一个 PCK/ZIP 只能提供一个 `res://mods/<mod_id>/manifest.json`。路径不能包含 `..`，数据引用的资源必须位于当前 Mod 目录，资源包不能覆盖本体路径。

```text
res://mods/com.author.example/
├── manifest.json
├── content/
├── scripts/
├── scenes/
├── resources/
└── assets/
```

- Mod ID：`^[a-z0-9][a-z0-9._-]{2,63}$`。
- 本地内容 ID：`^[a-z0-9][a-z0-9_-]{0,63}$`。
- JSON 使用 UTF-8 严格语法，不支持注释、尾逗号、`NaN` 或 `Infinity`。

## Manifest 2

规范文件为 [manifest.schema.json](schemas/v2/manifest.schema.json)。`schema_version` 和 `mod_api_version` 当前都固定为 `2`。

```json
{
  "schema_version": 2,
  "id": "com.author.example",
  "name": "示例 Mod",
  "version": "1.0.0",
  "description": "Mod API 2 示例",
  "authors": ["Author"],
  "mod_api_version": 2,
  "game_version": {
    "min": "0.2.0",
    "max_exclusive": "0.3.0"
  },
  "dependencies": [],
  "conflicts": [],
  "load_after": [],
  "content": [
    "res://mods/com.author.example/content/dialogues.json"
  ],
  "entry_script": "res://mods/com.author.example/scripts/main.gd",
  "overrides": []
}
```

版本使用三段 SemVer。`game_version.max_exclusive` 是不包含的上界。依赖先于依赖方加载；硬依赖缺失或版本不匹配会禁用依赖方，可选依赖只影响顺序。循环依赖禁用整个环。

`overrides` 使用 `<kind>:<target_id>`。只有 Manifest 授权的 `patch` 可以覆盖已有定义；重复 `add` 不会自动变为覆盖。

## 分发

PCK 和 ZIP 必须包含 Godot 导入后的资源。发布代码 Mod 新版本后，玩家需要重新确认该版本的代码权限。启停、排序和授权写入 `user://mods.cfg`，修改后必须重启游戏。
