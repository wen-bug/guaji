# Mod 快速开始

## 前置条件

- Godot 4.7.x，与游戏主版本保持一致。
- Mod API 1。
- 唯一的反向域名 Mod ID，例如 `com.author.example`。

复制 `mod_sdk/example_mod/` 作为制作工程。所有运行时文件必须位于工程内的 `res://mods/<mod_id>/`，Manifest 的 `id` 必须与目录名一致。

## 第一个数据 Mod

1. 编辑 `manifest.json`，设置 ID、版本、游戏版本范围和 content 文件列表。
2. 在 `content/*.json` 使用 `add` 添加内容；本地 ID 会注册为 `<mod_id>:<local_id>`。
3. 在 Godot 中打开制作工程，让图片、场景和资源完成导入。
4. 使用示例 SDK 的 `build_mod.gd`，或使用编辑器的“导出 PCK/ZIP”。
5. 把 PCK 或 ZIP 放入游戏的 `user://mods/`，在 Mod 管理面板启用并重启游戏。

最小数据文件：

```json
{
  "schema_version": 1,
  "kind": "dialogue",
  "entries": [
    {
      "operation": "add",
      "local_id": "hello",
      "data": {
        "text": "今天也要稳稳修行。",
        "scenes": ["home"],
        "states": ["idle"],
        "weight": 1,
        "cooldown_seconds": 5
      }
    }
  ]
}
```

仓库内示例的构建命令：

```text
godot --headless --path . --script mod_sdk/example_mod/build_mod.gd -- example_mod.pck
```

含 `entry_script` 的 Mod 首次启用时必须确认代码权限。配置和加载顺序保存在 `user://mods.cfg`，运行中不会热重载。

## 调试

先查看 Mod 管理面板中的状态和首条错误，再查看 `user://logs/godot.log`。一个 Mod 的任意内容或代码注册失败时，该 Mod 的注册事务整体回滚。
