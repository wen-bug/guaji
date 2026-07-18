# Mod 包格式

## 根目录

一个 PCK/ZIP 只能提供一个 `res://mods/<mod_id>/manifest.json`。路径不能包含 `..`，数据文件中引用的 `*_path` 必须位于同一 Mod 目录；不能用资源包覆盖本体路径。

```text
res://mods/com.author.example/
├── manifest.json
├── content/
│   ├── skills.json
│   ├── appearances.json
│   └── dialogues.json
├── scripts/
│   └── main.gd
├── scenes/
├── resources/
└── assets/
```

Mod ID：`^[a-z0-9][a-z0-9._-]{2,63}$`。本地内容 ID：`^[a-z0-9][a-z0-9_-]{0,63}$`。JSON 使用 UTF-8 严格语法，不支持注释、尾逗号、NaN 或 Infinity。

## Manifest

规范文件为 `schemas/v1/manifest.schema.json`。当前固定 `schema_version=1`、`mod_api_version=1`。版本是三段 SemVer；范围只使用 `min` 与不包含上界的 `max_exclusive`。

```json
{
  "schema_version": 1,
  "id": "com.author.example",
  "name": "示例 Mod",
  "version": "1.0.0",
  "description": "Mod API 1 示例",
  "authors": ["Author"],
  "mod_api_version": 1,
  "game_version": {
    "min": "0.1.0",
    "max_exclusive": "0.2.0"
  },
  "dependencies": [],
  "conflicts": [],
  "load_after": [],
  "content": [
    "res://mods/com.author.example/content/skills.json"
  ],
  "entry_script": "res://mods/com.author.example/scripts/main.gd",
  "overrides": []
}
```

依赖先于依赖方加载。硬依赖缺失或版本不匹配会禁用依赖方；可选依赖只影响顺序，不能用于跨 Mod 内容引用。循环依赖禁用整个环。conflicts 同时启用时保留用户顺序中优先级更高者。顺序从低到高应用，后加载的显式覆盖胜出。

`overrides` 使用 `<kind>:<target_id>`。未列入 Manifest 的 patch 会拒绝；重复 add 不会自动变成覆盖。

## 分发

PCK 和 ZIP 都必须包含 Godot 导入后的资源。直接压缩 PNG、GDScript 或场景源文件但缺少导入产物，可能在导出游戏中无法加载。每次发布代码 Mod 新版本后，玩家需要重新确认该版本的代码权限。

包放入 `user://mods/` 后，在 Mod 管理器中启用、授权代码并重启。启停、排序和授权写入 `user://mods.cfg`；API 1 不支持热加载、热卸载或运行时更改注册表。
