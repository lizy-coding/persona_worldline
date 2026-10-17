# 星海抉择（Persona Worldline）

一个使用 Flutter 构建的多世界线互动叙事 Demo。玩家会以不同身份进入独立故事；选择、初始属性和带权重的随机事件共同改变剧情路径、人格与动态结局。

## 当前内容

- “星海抉择”：固定 7 次选择，包含 7 个事件与 3 个结局
- “执剑人交界”：4–8 次选择，包含 13 个事件与 10 个动态结局
- 由 JSON 内容包驱动初始属性、复合条件、效果、随机插曲与结局优先级
- 使用本地存储自动保存进度，刷新页面后可继续游戏
- 内容包结构、分支执行、结局与存档序列化测试
- 当前主要面向 Flutter Web，同时保留 Flutter 的跨平台扩展能力

## 桑田秋账

以明代江南桑稻争田为历史背景的原创虚构故事，共三条独立角色线：

- **施政者**：督办官陆承简，在财政、考成与保粮条款之间拟定办法。
- **执行者**：知县周守衡，在田界、县印、原契与领粮簿之间兑现或转嫁责任。
- **承受者**：佃户叶青娘，通过留田、做工、互助、留契与迁徙，维持一家人的生活。

每条线七次抉择、七种结局，共 24 个事件与 72 个选项。人物、县名、具体政令与数值均为虚构；三条线独立存档、平行推演。

[完整故事本、角色关系与历史背景](docs/stories/mulberry-autumn.md)。

## 技术栈

- Flutter / Dart
- Material 3
- Riverpod：界面状态与依赖管理
- shared_preferences：本地存档

## 开始使用

### 环境要求

- 已验证工具链：Flutter `3.47.2` / Dart `3.13.2`
- 支持 Flutter Web 的浏览器

确认环境可用：

```bash
flutter doctor
```

安装依赖并启动 Web 版本：

```bash
flutter pub get
flutter run -d chrome
```

也可以构建静态站点：

```bash
flutter build web
```

构建结果位于 `build/web/`。该目录是生成产物，不纳入版本控制。

## 质量检查

提交代码前建议运行：

```bash
bash tool/check.sh
```

## 一键发布到 GitHub Pages

项目包含 `.github/workflows/ci.yml`：面向 `master` 的 PR 先检查格式、分析、测试、内容包和 Web 构建。
`.github/workflows/deploy-pages.yml` 在推送 `master` 时自动校验并发布，
也可在 GitHub Actions 页面通过 `Run workflow` 手动发布。首次使用需在仓库
`Settings → Pages` 中将 Source 设置为 `GitHub Actions`。

预期访问地址：

```text
https://lizy-coding.github.io/persona_worldline/
```

完整说明见 [GitHub Pages 发布指南](docs/DEPLOY_GITHUB_PAGES.md)。

## 项目结构

```text
assets/content/core_pack.json  核心剧情、条件、效果、人格与结局数据
assets/content/santi.json      执剑人交界世界线及其动态路由规则
lib/game/models.dart           内容包与游戏状态模型、数据校验
lib/game/engine.dart           条件判断、效果执行、分支和人格匹配
lib/game/session.dart          故事协调、应用端口与游戏会话
lib/game/infrastructure.dart   Asset 内容加载与 Web 本地存档实现
lib/story_catalog.dart         可选故事线业务目录
lib/main.dart                  Flutter 界面、页面流转与状态接入
test/game_test.dart            内容包和核心引擎测试
web/                           Web 入口、图标与 PWA 清单
docs/ARCHITECTURE.md           架构边界、故事线切换与版本演进说明
AGENTS.md                      后续开发必须遵守的项目根级规则
```

详细的依赖方向、模块职责和多故事线扩展步骤见
[架构与演进说明](docs/ARCHITECTURE.md)。自动化开发工具及后续贡献者还必须遵守
[项目规则](AGENTS.md)，避免把故事专属逻辑写入通用引擎或页面。

## 内容包说明

每条故事线对应 `assets/content/` 下的一个完整内容包，并通过
`lib/story_catalog.dart` 登记业务元数据、在应用装配层登记 Asset 映射。内容包使用
`schemaVersion` 标记结构版本，由以下部分组成：

- `dimensions`：评分维度、初始值、上下限及展示设置
- `archetypes`：人格原型及其目标权重
- `events`：剧情事件和玩家行动
- `conditions`：行动、事件、路由和结局的类型化复合条件
- `effects`：分数或标记变更
- `endings`：可达成的结局
- `intro`：该故事线自己的序章展示内容
- `flowRules.minimumChoiceCount` / `maximumChoiceCount`：该角色允许的单局选择次数范围
- `flowRules.randomRoutes`：故事级、带条件和权重的随机插曲
- `flowRules.endingRules`：按顺序匹配并带兜底项的动态结局规则

每个行动必须选择配置 `routes` 或 `endsStory: true`。随机种子随存档保存，因此刷新后会继续同一局随机序列；到达最大选择次数时，运行时会根据当前状态强制解析动态结局。内容加载阶段会检查重复 ID、未知维度、无效路由和不支持的规则类型。

## 存档行为

游戏使用 `shared_preferences` 将当前状态保存在设备本地。内容包版本变化或存档结构无效时，旧存档会被自动清除。存档不包含账号、云同步或服务端数据。

## 版本控制约定

仓库只保留源码、剧情资产、测试、依赖锁文件和必要的项目配置。构建产物、依赖缓存、IDE 工作区、本地环境文件、日志、覆盖率及密钥文件均由 `.gitignore` 排除。请勿把真实凭据写入仓库；如后续需要环境变量，可提交不含敏感值的 `.env.example`。

## 远端开发与新增故事

后续日常维护通过 GitHub 分支和 PR 跟进；本地 checkout 用于复现与浏览器验收。

- [远端维护说明](docs/REMOTE_MAINTENANCE.md)：工具链、检查入口、PR 和发布边界。
- [新增故事指南](docs/ADDING_STORIES.md)：可验证的 JSON 模板、注册步骤与测试要求。
- `tool/validate_pack.dart`：单个内容包的命令行校验工具。

项目规则不依赖个人技能库或本地 Agent 状态。
