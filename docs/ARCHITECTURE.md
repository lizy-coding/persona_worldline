# 架构与演进说明

## 目标

当前架构围绕一个稳定核心设计：游戏引擎只认识内容包和游戏状态，不认识具体故事、
页面或存储方式。因此替换故事线应当是“加载另一个合法内容包”，而不是复制一套应用。

## 运行链路

```text
rootBundle JSON
      │
      ▼
StoryDescriptor → ContentPackRepository ──解析/校验──▶ GameContentPack
                                      │
                                      ▼
Home / Intro / Event / Result ◀── GameSession
              │                       │
              ▼                       ▼
        GameCoordinator → GameController ─────────▶ GameRuntime
              │              条件、效果、加权路由、动态结局
              ▼
        SaveRepository
```

`GameContentPack` 是内容与程序之间唯一的正式契约。`GameState` 是运行时与存档之间的
正式契约。保持这两个边界稳定，就可以独立演进故事内容、规则实现、UI 和存储实现。

## 运行规则

schema v3 把每条世界线的节奏和随机性放在内容包内：

- 评分维度声明初始值、上下限和是否展示，角色可以拥有完全不同的初始状态。
- `minimumChoiceCount` 与 `maximumChoiceCount` 定义单局长度；到达上限必然结算。
- 行动的 `routes` 描述主线后继，多个合格目标按权重确定性抽取。
- `flowRules.randomRoutes` 集中声明可复用的随机插曲，避免在每个行动内复制规则。
- `endingRules` 按顺序匹配当前状态，最后一项必须是无条件兜底结局。
- 随机状态保存在 `GameState`，相同内容、状态和种子必然产生相同后继事件。

事件图允许循环，以支持回访、插曲和事件池；`maximumChoiceCount` 是保证每局终止的硬边界。

## 目录职责

| 路径 | 职责 | 常见修改场景 |
|---|---|---|
| `assets/content/` | 完整故事线内容包 | 新事件、文案、数值、分支、原型、结局 |
| `lib/game/models.dart` | JSON 契约、强类型模型、结构校验 | 新增受控规则类型或升级 schema |
| `lib/game/engine.dart` | 无 UI 的规则执行与结果计算 | 实现新的 condition/effect/action |
| `lib/game/session.dart` | 应用端口、故事协调、会话推进 | 改变故事选择与会话生命周期 |
| `lib/game/infrastructure.dart` | Asset 内容仓库、本地存档实现 | 更换资源或存储技术 |
| `lib/story_catalog.dart` | 内置故事目录 | 登记或调整可选故事线 |
| `lib/main.dart` | Provider 装配与通用页面 | 调整展示和导航体验 |
| `test/` | 契约和闭环回归 | 每次规则、状态或内容变化 |

## 新增故事线

第二条故事线应包含自己的 `packId`、`version`、维度、原型、事件和结局。推荐流程：

1. 复制内容包的结构而不是业务代码。
2. 配置角色初始维度、选择次数范围、路由和动态结局规则。
3. 为该内容包增加解析测试、固定种子路径测试和结局规则测试。
4. 在装配层登记资源映射，由 `ContentPackRepository` 加载选择结果。
5. 按 `packId` 隔离存档，防止不同故事线互相覆盖。

如果新故事只需要现有的选择、flag、复合条件、加权路由和评分能力，到这里不应修改任何引擎代码。

## 何时扩展引擎

只有内容无法用现有受控类型表达时才扩展引擎。例如真正加入骰子行动时，应新增
`DiceAction`，而不是把骰子参数塞入 `SelectOptionAction`，也不能在 JSON 中执行表达式。
每种新类型都需要解析失败诊断、确定性测试以及对存档重放影响的评估。

## 版本语义

- `schemaVersion`：数据结构版本。当前不提供旧内容协议兼容层。
- `version`：单个内容包的内容版本。当前策略是不兼容时清除该包旧存档。
- 应用版本：发布版本，不替代以上两个字段。

未来若需要存档迁移，应在 SaveRepository 边界新增显式迁移器；不要在 Widget 或
`GameState.fromJson` 中散落版本特判。
