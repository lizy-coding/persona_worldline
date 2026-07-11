import 'game/models.dart';

/// 应用内置故事目录。未来可由本地目录 JSON 构造同一组描述对象。
const builtInStories = <StoryDescriptor>[
  StoryDescriptor(
    packId: 'silent-tide',
    title: '星海抉择',
    summary: '在宇宙文明危机中连续决策，观察你最终抵达的人格世界线。',
    audienceTags: ['科幻', '文明抉择', '3–5 分钟'],
  ),
];
