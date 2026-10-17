# GitHub Pages 发布

## 首次启用

1. 推送 `.github/workflows/deploy-pages.yml` 到 `master`。
2. 打开 GitHub 仓库 `Settings → Pages`。
3. 将 `Build and deployment → Source` 设置为 `GitHub Actions`。
4. 打开 `Actions → Deploy Flutter Web to GitHub Pages`。
5. 等待首次工作流完成。

发布地址：

```text
https://lizy-coding.github.io/persona_worldline/
```

## 一键发布

自动：已授权的 PR 合入或提交推送到 `master`。普通维护先在任务分支提交 PR，通过 Quality 检查后再按授权合入。

```bash
git push origin master
```

手动：GitHub 仓库 `Actions → Deploy Flutter Web to GitHub Pages → Run workflow`。

工作流按顺序执行依赖安装、格式检查、静态分析、测试、Release 构建和 Pages 部署；
任一检查失败时停止发布。`base-href` 根据仓库名称自动生成，无需手工修改。

## 查看结果

- 工作流首页显示当前发布状态。
- `deploy` Job 的 `environment` 链接指向实际站点。
- Pages 首次启用或缓存更新可能需要短暂等待。

## 回滚

回退产生问题的提交并推送 `master`，工作流会发布回退后的版本：

```bash
git revert <commit>
git push origin master
```



## PR 与发布验证

Quality 工作流对面向 master 的 PR 执行共享检查和 Web 构建；它不部署站点。Pages 的 Verify source and story contracts 步骤调用同一 tool/check.sh，工具链统一为 Flutter 3.47.2。

推送任务分支与打开 PR 后，应先报告 CI 状态。只有 master 对应部署实际成功后，才报告网站已更新。
