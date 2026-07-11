import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:persona_worldline/game/engine.dart';
import 'package:persona_worldline/game/models.dart';
import 'package:persona_worldline/game/session.dart';

void main() {
  late GameContentPack corePack;
  late GameContentPack santiPack;

  setUpAll(() {
    corePack = _loadPack('assets/content/core_pack.json');
    santiPack = _loadPack('assets/content/santi.json');
  });

  test('两条世界线均符合 schema v3 内容契约', () {
    expect(corePack.schemaVersion, 3);
    expect(corePack.events, hasLength(7));
    expect(corePack.flowRules.minimumChoiceCount, 7);
    expect(corePack.flowRules.maximumChoiceCount, 7);

    expect(santiPack.schemaVersion, 3);
    expect(santiPack.events, hasLength(13));
    expect(santiPack.endings, hasLength(10));
    expect(santiPack.flowRules.minimumChoiceCount, 4);
    expect(santiPack.flowRules.maximumChoiceCount, 8);
  });

  test('每条世界线从维度契约构造自己的初始分数和 flags', () {
    final coreState = GameRuntime(corePack).initialState(7);
    expect(coreState.dimensionScores['文明责任'], 0);

    final santiState = GameRuntime(santiPack).initialState(7);
    expect(santiState.dimensionScores['threatCredibility'], 50);
    expect(santiState.dimensionScores['lossRisk'], 30);
    expect(santiState.flags['autoProtocol'], isFalse);
    expect(santiState.flags['controlledLeak'], isFalse);
  });

  test('无效路由和不可达事件会被内容校验检测', () {
    final invalidRoute = _loadJson('assets/content/core_pack.json');
    final firstAction = (invalidRoute['events'] as List).first['actions'][0];
    firstAction['routes'][0]['eventId'] = 'missing';
    expect(() => GameContentPack.fromJson(invalidRoute), throwsFormatException);

    final unreachable = _loadJson('assets/content/core_pack.json');
    (unreachable['events'] as List).add({
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
          'routes': [],
          'endsStory': true,
        },
      ],
    });
    expect(
      () => GameContentPack.fromJson(unreachable),
      throwsA(predicate((error) => '$error'.contains('不可达事件'))),
    );
  });

  test('未知规则类型和错误复合条件会返回诊断错误', () {
    expect(
      () => PlayerAction.fromJson({'id': 'x', 'type': 'dice', 'text': 'x'}),
      throwsA(predicate((error) => '$error'.contains('未知 action type'))),
    );
    expect(
      () => GameCondition.fromJson({'type': 'mystery'}),
      throwsFormatException,
    );
    expect(
      () => GameCondition.fromJson({'type': 'not', 'conditions': []}),
      throwsFormatException,
    );
    expect(
      () => GameEffect.fromJson({'type': 'mystery', 'key': 'x', 'value': true}),
      throwsFormatException,
    );
  });

  test('固定种子可复现随机路由，不同种子可进入不同事件', () {
    final json = _loadJson('assets/content/core_pack.json');
    final firstAction = (json['events'] as List).first['actions'][0];
    firstAction['routes'] = [
      {'eventId': 'ark', 'weight': 1, 'conditions': []},
      {'eventId': 'colony', 'weight': 1, 'conditions': []},
    ];
    final pack = GameContentPack.fromJson(json);

    String routeFor(int seed) => GameRuntime(pack)
        .execute(GameRuntime(pack).initialState(seed), 'signal-study')
        .currentEventId;

    expect(routeFor(17), routeFor(17));
    expect({
      for (var seed = 1; seed <= 40; seed++) routeFor(seed),
    }, hasLength(2));
  });

  test('分数效果遵守维度上下限', () {
    final runtime = GameRuntime(santiPack);
    var state = runtime.initialState(9);
    for (var i = 0; i < 10; i++) {
      state = runtime.executor.apply(state, const [
        GameEffect(EffectType.addScore, 'threatCredibility', 30),
      ], santiPack.dimensionsById);
    }
    expect(state.dimensionScores['threatCredibility'], 100);
  });

  test('santi 的故事级随机插曲可改变路径且每局都在配置范围内结束', () {
    final visitedPaths = <String>{};
    for (var seed = 1; seed <= 30; seed++) {
      final runtime = GameRuntime(santiPack);
      var state = runtime.initialState(seed);
      final events = <String>[];
      while (!state.completed) {
        events.add(state.currentEventId);
        final actions = runtime.availableActions(state);
        expect(actions, isNotEmpty);
        state = runtime.execute(state, actions.first.id);
      }
      expect(
        state.choiceHistory.length,
        inInclusiveRange(
          santiPack.flowRules.minimumChoiceCount,
          santiPack.flowRules.maximumChoiceCount,
        ),
      );
      expect(state.endingId, isNotNull);
      visitedPaths.add(events.join('>'));
    }
    expect(visitedPaths.length, greaterThan(1));
  });

  test('core 固定七次选择后由状态规则动态解析结局', () {
    final runtime = GameRuntime(corePack);
    var state = runtime.initialState(11);
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
    expect(state.choiceHistory, hasLength(7));
    expect(state.endingId, 'dawn');
  });

  test('达到世界线最大选择次数时强制进入动态结局', () {
    final json = _loadJson('assets/content/core_pack.json');
    final rules = json['flowRules'] as Json;
    rules['minimumChoiceCount'] = 1;
    rules['maximumChoiceCount'] = 1;
    final pack = GameContentPack.fromJson(json);
    final runtime = GameRuntime(pack);
    final state = runtime.execute(runtime.initialState(5), 'signal-study');
    expect(state.completed, isTrue);
    expect(state.choiceHistory, hasLength(1));
    expect(state.endingId, 'embers');
  });

  test('复合条件支持 all、any、atLeast、not 和最高分匹配', () {
    final state = GameRuntime(santiPack).initialState(3);
    final evaluator = ConditionEvaluator();
    final condition = GameCondition.fromJson({
      'type': 'all',
      'conditions': [
        {'type': 'scoreAtLeast', 'key': 'humanityAnchor', 'value': 50},
        {
          'type': 'atLeast',
          'minimumMatches': 1,
          'conditions': [
            {'type': 'flagEquals', 'key': 'autoProtocol', 'value': true},
            {
              'type': 'not',
              'conditions': [
                {'type': 'flagEquals', 'key': 'controlledLeak', 'value': true},
              ],
            },
          ],
        },
      ],
    });
    expect(evaluator.evaluate(condition, state), isTrue);
  });

  test('存档往返保留随机状态并可继续同一条路线', () {
    final runtime = GameRuntime(corePack);
    final state = runtime.execute(runtime.initialState(123), 'signal-answer');
    final restored = GameState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Json,
    );
    expect(restored.toJson(), state.toJson());
    expect(
      runtime.execute(restored, 'ark-guide').toJson(),
      runtime.execute(state, 'ark-guide').toJson(),
    );
  });

  test('协调器按 packId 选择内容包、隔离存档并注入随机种子', () async {
    const story = StoryDescriptor(
      packId: 'silent-tide',
      title: '测试故事',
      summary: '测试',
      audienceTags: [],
    );
    final saves = _MemorySaveRepository();
    final coordinator = GameCoordinator(
      stories: const [story],
      contentRepository: _MemoryContentRepository(corePack),
      saveRepository: saves,
      seedGenerator: _FixedSeedGenerator(42),
    );
    final session = await coordinator.selectStory('silent-tide');
    expect(session.story, same(story));
    final started = await coordinator.newGame();
    expect(started.state!.randomState, 42);
    expect(saves.states.keys, contains('silent-tide'));
    expect(
      () => coordinator.selectStory('missing'),
      throwsA(isA<StateError>()),
    );
  });
}

GameContentPack _loadPack(String path) =>
    GameContentPack.decode(File(path).readAsStringSync());

Json _loadJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Json;

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

class _FixedSeedGenerator implements SeedGenerator {
  const _FixedSeedGenerator(this.seed);

  final int seed;

  @override
  int nextSeed() => seed;
}
