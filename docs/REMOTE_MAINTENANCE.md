# 远端维护

维护入口为 https://github.com/lizy-coding/persona_worldline。使用任务分支和面向 master 的 PR，GitHub Actions 执行 Quality 检查。主分支合入后沿用原 Pages 工作流发布。

## 全新 checkout

```bash
git clone https://github.com/lizy-coding/persona_worldline.git
cd persona_worldline
bash tool/check.sh
flutter build web --release --no-pub
```

使用 Flutter 3.47.2 / Dart 3.13.2。共享检查入口通过 pub.dev 安装锁定依赖，并验证格式、静态分析、测试、所有剧情包与文档模板。CI 与 Pages 使用相同入口，修改工具链时同步更新两个工作流与本说明。

项目是客户端 Web 应用；普通维护不需要后端、密钥或个人 Agent 安装。本地 .hermes 计划、任务记录和个人技能保留在本机，不参与公开仓库的维护前置条件。

## Agent 入口与完成条件

先读根 AGENTS.md，再按任务读取具体文件。新增故事遵循 docs/ADDING_STORIES.md，不把剧情写入 Widget 或通用引擎。

完成任务时说明改动、检查结果、Web 构建和浏览器交互范围。源代码推送、PR CI、合入、Pages 部署和 Codex Cloud 环境启用分别记录。

提交和推送遵循当前任务授权；不自动合并 PR，不强推覆盖他人提交。仅有准备分支和 CI 通过时，不能报告主站已更新。

## Codex Cloud 准备

选择此 GitHub 仓库，准备 Flutter 3.47.2，使用 bash tool/check.sh 验证新环境。无需导入个人技能库或本地 Agent 状态。

环境准备、发布及新任务验证需在 Cloud 环境中实际完成。仓库规则和 CI 就绪不等于 Cloud 环境已启用。官方说明：[Cloud environments](https://learn.chatgpt.com/docs/environments/cloud-environments)。
