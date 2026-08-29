# Mod 快速开始

当前游戏版本为 `0.2.0`，只加载 Manifest/内容 Schema 2 和 Mod API 2。API 1 包不会被兼容加载。

## 前置条件

- Godot `4.7.x`，建议与项目使用的 `4.7.2` 保持一致。
- 唯一的反向域名 Mod ID，例如 `com.author.example`。
- 所有运行时文件位于 `res://mods/<mod_id>/`，Manifest 的 `id` 与目录名一致。

可以复制[示例 Mod](../../mod_sdk/example_mod/README.md)作为制作工程。

## 第一个数据 Mod

1. 创建 `manifest.json`，声明 Schema 2、API 2、游戏版本范围和内容文件。
2. 在 `content/*.json` 使用 `add` 添加内容；本地 ID 注册为 `<mod_id>:<local_id>`。
3. 在 Godot 中打开制作工程，让场景、资源和图片完成导入。
4. 导出 PCK/ZIP，放入游戏的 `user://mods/`。
5. 在 Mod 管理面板启用；包含 `entry_script` 时确认代码权限，然后重启。

最小内容文件：

```json
{
  "schema_version": 2,
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

仓库示例构建命令：

```powershell
godot --headless --path . --script mod_sdk/example_mod/build_mod.gd -- artifacts/example_mod.pck
```

## 下一步

- [包格式](package-format.md)
- [内容格式参考](content-reference.md)
- [技能](skills.md)
- [GDScript API 2](scripting-api.md)

## 调试

先查看 Mod 管理面板中的状态和首条错误，再查看 `user://logs/godot.log`。任意内容、引用、资源契约或代码注册失败时，该 Mod 的注册事务整体回滚。运行中不支持热加载或热卸载。
