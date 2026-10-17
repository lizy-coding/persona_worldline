import 'game/models.dart';

/// 应用内置故事目录。未来可由本地目录 JSON 构造同一组描述对象。
const builtInStories = <StoryDescriptor>[
  StoryDescriptor(
    packId: 'silent-tide',
    title: '星海抉择',
    summary: '在宇宙文明危机中连续决策，观察你最终抵达的人格世界线。',
    audienceTags: ['科幻', '文明抉择', '3–5 分钟'],
  ),
  StoryDescriptor(
    packId: 'santi',
    title: '执剑人交界：未央评估',
    summary: '在执剑人交接危机中评估威慑、人性与文明存续的边界。',
    audienceTags: ['科幻', '动态结局', '4–8 次选择'],
  ),
  StoryDescriptor(
    packId: 'mulberry-policy',
    title: '桑田秋账·施政者',
    summary: '督办官陆承简：在解银考成与一县口粮之间，决定政策如何落地。',
    audienceTags: ['明代背景·虚构', '政策施行层', '7 次抉择'],
  ),
  StoryDescriptor(
    packId: 'mulberry-county',
    title: '桑田秋账·执行者',
    summary: '知县周守衡：让田册、粮册与银册对上，也为自己用过的印负责。',
    audienceTags: ['明代背景·虚构', '地方执行层', '7 次抉择'],
  ),
  StoryDescriptor(
    packId: 'mulberry-household',
    title: '桑田秋账·承受者',
    summary: '佃户叶青娘：在改桑、借粮与画押之间，为一家人留下选择余地。',
    audienceTags: ['明代背景·虚构', '被执行层', '7 次抉择'],
  ),
];
