# 挂机家园

挂机家园是一个运行在 Windows 桌面上的 Godot 4.7 2D 在线挂机原型。当前版本为 `0.2.0`，包含角色招募、家园生产、自动历练、装备与技能成长、坊市经济和 Mod API 2。

## 开发环境

- Godot `4.7.x`，项目当前使用 `4.7.2`。
- Windows 10/11；其他平台不保证透明置顶和任务栏定位行为。
- 主场景：[main.tscn](main.tscn)。

使用编辑器打开项目：

```powershell
godot --editor --path .
```

直接运行：

```powershell
godot --path .
```

无界面启动检查：

```powershell
godot --headless --path . --quit-after 5
```

测试场景可以直接作为启动场景运行，例如：

```powershell
godot --headless --path . scripts/tests/core_loop_regression_test.tscn
godot --headless --path . scripts/tests/market_economy_test.tscn
```

Mod API 2 示例契约需要先构建 PCK，再执行测试：

```powershell
godot --headless --path . --script mod_sdk/example_mod/build_mod.gd -- artifacts/example_mod.pck
godot --headless --path . --script scripts/tests/mod_api_v2_contract_test.gd
```

## 项目入口

- [文档索引](docs/README.md)：架构、玩法、内容制作和 Mod 开发文档。
- [设计基线](docs/design.md)：产品定位、核心循环和验收边界。
- [项目结构](docs/project-structure.md)：子系统职责和主要代码入口。
- [内容数据表](docs/item-table.md)：当前物品、技能、装备、敌人和掉落索引。
- [开发路线](PLAN.md)：尚未完成的工作和后续方向。
- [Mod 快速开始](docs/modding/quick-start.md)：Mod API 2 制作流程。

## 核心目录

| 路径 | 用途 |
| --- | --- |
| `scripts/game/` | 游戏状态、数据、战斗、队伍、物品和生产逻辑 |
| `scripts/map/` | 家园、历练地图和遭遇生成 |
| `scripts/ui/` | HUD、面板和描述渲染 |
| `scripts/modding/` | Mod API、校验、加载和管理界面 |
| `resources/` | 物品、装备、技能和地图资源 |
| `scripts/tests/` | Godot 无界面测试场景 |
| `mod_sdk/example_mod/` | 可构建的 Mod API 2 示例 |

## 文档约定

运行时代码、资源和自动化测试是已实现行为的事实来源；文档负责解释这些行为。未落地设计必须明确标记为“规划”，不能混入“当前实现”。修改系统行为时，应同步更新对应主题文档和 [文档索引](docs/README.md) 中列出的维护关系。

## 许可

项目许可见 [LICENSE](LICENSE)，第三方资源署名见 [CREDITS.md](CREDITS.md) 和 [godot-ai-LICENSE.txt](godot-ai-LICENSE.txt)。
