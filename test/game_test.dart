import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:persona_worldline/game/engine.dart';
import 'package:persona_worldline/game/models.dart';
import 'package:persona_worldline/game/session.dart';

void main() {
  late GameContentPack pack;
  setUpAll(() {
    final source = File('assets/content/core_pack.json').readAsStringSync();
    pack = GameContentPack.decode(source);
  });

  test('内容包成功解析且结构完整', () {
    expect(pack.events, hasLength(7));
    expect(pack.endings.length, greaterThanOrEqualTo(2));
    expect(pack.dimensions, hasLength(5));
    expect(pack.intro.title, isNotEmpty);
    expect(pack.schemaVersion, 2);
    expect(pack.flowRules.requiredChoiceCount, 7);
    expect(pack.flowRules.enforceEqualPathLength, isTrue);
  });

  test('无效 nextEventId 会被检测', () {
    final json =
        jsonDecode(File('assets/content/core_pack.json').readAsStringSync())
            as Json;
    (json['events'] as List).first['actions'][0]['nextEventId'] = 'missing';
    expect(() => GameContentPack.fromJson(json), throwsFormatException);
  });

  test('不可达事件会被图结构校验检测', () {
    final json =
        jsonDecode(File('assets/content/core_pack.json').readAsStringSync())
            as Json;
    (json['events'] as List).add({
      'id': 'orphan',
      'chapter': 9,
      'title': '孤立事件',
      'description': '无法抵达',
      'conditions': [],
      'actions': [
        {
          'id': 'orphan-end',
          'type': 'selectOption',
          'text': '结束',
          'conditions': [],
          'effects': [],
          'endingId': 'dawn',
        },
      ],
    });
    expect(
      () => GameContentPack.fromJson(json),
      throwsA(predicate((error) => '$error'.contains('不可达事件'))),
    );
  });

  test('配置的选择次数与所有结局路径一致', () {
    final json =
        jsonDecode(File('assets/content/core_pack.json').readAsStringSync())
            as Json;
    (json['flowRules'] as Json)['requiredChoiceCount'] = 6;
    expect(
      () => GameContentPack.fromJson(json),
      throwsA(predicate((error) => '$error'.contains('选择次数不符合'))),
    );
  });

  test('未知行动、条件和效果类型返回诊断错误', () {
    expect(
      () => PlayerAction.fromJson({'id': 'x', 'type': 'dice', 'text': 'x'}),
      throwsA(predicate((e) => '$e'.contains('未知 action type'))),
    );
    expect(
      () => GameCondition.fromJson({
        'type': 'mystery',
        'key': 'x',
        'value': true,
      }),
      throwsFormatException,
    );
    expect(
      () => GameEffect.fromJson({'type': 'mystery', 'key': 'x', 'value': true}),
      throwsFormatException,
    );
  });

  test('选择正确修改维度和 flags，条件控制路径', () {
    final runtime = GameRuntime(pack);
    var state = runtime.initialState();
    expect(
      runtime.availableActions(state).map((e) => e.id),
      isNot(contains('probe-window')),
    );
    state = runtime.execute(state, 'signal-study');
    expect(state.dimensionScores['理性决策'], 2);
    expect(state.flags['decoded'], isTrue);
    state = runtime.execute(state, 'ark-guide');
    state = runtime.execute(state, 'colony-open');
    expect(
      runtime.availableActions(state).map((e) => e.id),
      contains('probe-window'),
    );
  });

  test('固定路径到达结局且人格匹配可重复', () {
    final runtime = GameRuntime(pack);
    var state = runtime.initialState();
    for (final action in [
      'signal-study',
      'ark-save',
      'colony-open',
      'probe-window',
      'visitor-share',
      'council-shield',
      'final-unite',
    ]) {
      state = runtime.execute(state, action);
    }
    expect(state.completed, isTrue);
    expect(state.endingId, 'dawn');
    final matcher = ArchetypeMatcher();
    final profile = TendencyProfile(state.dimensionScores);
    expect(
      matcher.match(profile, pack.archetypes).id,
      matcher.match(profile, pack.archetypes).id,
    );
  });

  test('存档序列化与反序列化一致', () {
    final state = GameRuntime(
      pack,
    ).execute(GameRuntime(pack).initialState(), 'signal-answer');
    final restored = GameState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Json,
    );
    expect(restored.toJson(), state.toJson());
  });

  test('协调器按 packId 选择内容包并隔离存档', () async {
    const story = StoryDescriptor(
      packId: 'silent-tide',
      title: '测试故事',
      summary: '测试',
      audienceTags: [],
    );
    final saves = _MemorySaveRepository();
    final coordinator = GameCoordinator(
      stories: const [story],
      contentRepository: _MemoryContentRepository(pack),
      saveRepository: saves,
    );
    final session = await coordinator.selectStory('silent-tide');
    expect(session.story, same(story));
    await coordinator.newGame();
    expect(saves.states.keys, contains('silent-tide'));
    expect(
      () => coordinator.selectStory('missing'),
      throwsA(isA<StateError>()),
    );
  });
}

class _MemoryContentRepository implements ContentPackRepository {
  _MemoryContentRepository(this.pack);
  final GameContentPack pack;
  @override
  Future<GameContentPack> load(StoryDescriptor story) async => pack;
}

class _MemorySaveRepository implements SaveRepository {
  final states = <String, GameState>{};
  @override
  Future<void> clear(String packId) async => states.remove(packId);
  @override
  Future<GameState?> load(String packId, String packVersion) async =>
      states[packId];
  @override
  Future<void> save(String packId, GameState state) async {
    states[packId] = state;
  }
}
