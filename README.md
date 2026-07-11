# 星海抉择（Persona Worldline）

一个使用 Flutter 构建的短篇互动叙事 Demo。玩家将在“静默潮汐”引发的宇宙文明危机中连续作出抉择；选择会改变人格维度、剧情条件与最终结局，并生成对应的人格原型。

## 当前内容

- 约 3–5 分钟的单局体验，包含 7 个事件与 3 个结局
- 5 个人格倾向维度与 4 种人格原型
- 由 JSON 内容包驱动的事件、条件、效果和分支
- 使用本地存储自动保存进度，刷新页面后可继续游戏
- 内容包结构、分支执行、结局与存档序列化测试
- 当前主要面向 Flutter Web，同时保留 Flutter 的跨平台扩展能力

## 技术栈

- Flutter / Dart
- Material 3
- Riverpod：界面状态与依赖管理
- shared_preferences：本地存档

## 开始使用

### 环境要求

- Flutter SDK（项目当前要求 Dart `^3.11.5`）
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
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## 一键发布到 GitHub Pages

项目包含 `.github/workflows/deploy-pages.yml`：推送 `master` 时自动校验并发布，
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

- `dimensions`：人格评分维度
- `archetypes`：人格原型及其目标权重
- `events`：剧情事件和玩家行动
- `conditions`：行动显示条件
- `effects`：分数或标记变更
- `endings`：可达成的结局
- `intro`：该故事线自己的序章展示内容
- `expectedTaskCount`：用于通用进度展示的预期单局任务数

每个行动必须且只能指定一个 `nextEventId` 或 `endingId`。运行时加载内容包时会检查重复 ID、无效目的地和不支持的数据类型；修改内容后请运行测试，避免产生不可达或中断的分支。

## 存档行为

游戏使用 `shared_preferences` 将当前状态保存在设备本地。内容包版本变化或存档结构无效时，旧存档会被自动清除。存档不包含账号、云同步或服务端数据。

## 版本控制约定

仓库只保留源码、剧情资产、测试、依赖锁文件和必要的项目配置。构建产物、依赖缓存、IDE 工作区、本地环境文件、日志、覆盖率及密钥文件均由 `.gitignore` 排除。请勿把真实凭据写入仓库；如后续需要环境变量，可提交不含敏感值的 `.env.example`。
