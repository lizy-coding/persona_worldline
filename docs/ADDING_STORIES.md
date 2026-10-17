# 新增故事线

故事内容通过 schema v3 JSON 表达，复用既有游戏引擎、状态协调与页面。开始前读取根 AGENTS.md 的内容契约与模块边界。

## 创建内容包

从项目根目录运行：

```bash
cp docs/templates/story_pack.json assets/content/my_story.json
dart run tool/validate_pack.dart assets/content/my_story.json
```

模板本身是可以通过校验的单事件、单结局示例，没有注册到游戏目录。复制后修改 packId、版本、标题、事件、行动、维度和结局，再逐步增加内容。

所有引用 ID 必须有效；行动配置非空 routes 或 endsStory=true，不能同时使用。结束规则按顺序匹配，最后保留无条件 fallback。选择次数上限保证循环路径最终结束。未知规则类型应产生诊断，不能静默忽略。

`tool/validate_pack.dart` 对无效内容返回非零退出码；调用方必须保留失败状态。

## 注册与测试

1. 在 lib/story_catalog.dart 的 builtInStories 中添加 StoryDescriptor，不放资源路径。
2. 在 lib/main.dart 的 AssetContentPackRepository 映射中登记 packId 和资源路径。
3. 检查 pubspec.yaml 的 assets/content/ 声明覆盖新文件。
4. 在 test/game_test.dart 中验证内容包解析、固定种子的已知路径和结局解析；涉及存档时补充版本与故事隔离验证。

普通剧情扩展不修改引擎或页面。只有明确需要新条件或效果类型时，才按根规则同时调整类型模型、解析诊断、执行逻辑与测试。

## 验证与提交

```bash
bash tool/check.sh
flutter build web --release --no-pub
```

在浏览器中检查故事选择、行动、结局、刷新续玩和重新开始。PR 中记录验证范围；通过构建不能代替浏览器交互验收。
