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

自动：提交并推送到 `master`。

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

