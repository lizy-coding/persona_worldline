import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:persona_worldline/game/engine.dart';
import 'package:persona_worldline/game/models.dart';
import 'package:persona_worldline/game/session.dart';
import 'package:persona_worldline/story_catalog.dart';

const _files = {
  'mulberry-policy': 'assets/content/mulberry_policy.json',
  'mulberry-county': 'assets/content/mulberry_county.json',
  'mulberry-household': 'assets/content/mulberry_household.json',
};

void main() {
  late Map<String, GameContentPack> packs;

  setUpAll(() {
    packs = {
      for (final entry in _files.entries)
        entry.key: GameContentPack.decode(File(entry.value).readAsStringSync()),
    };
  });

  test('三角色是独立注册的 schema v3 内容包，保留原有故事', () {
    final ids = builtInStories.map((story) => story.packId).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, containsAll(['silent-tide', 'santi', ..._files.keys]));
    for (final entry in packs.entries) {
      final pack = entry.value;
      expect(pack.packId, entry.key);
      expect(pack.schemaVersion, 3);
      expect(pack.events, hasLength(8));
      expect(pack.endings, hasLength(7));
      expect(pack.flowRules.minimumChoiceCount, 7);
      expect(pack.flowRules.maximumChoiceCount, 7);
    }
  });

  for (final packId in _files.keys) {
    test('$packId 所有合法选择都能在七次内结束，事件与结局均可达', () {
      final pack = packs[packId]!;
      final runtime = GameRuntime(pack);
      final seenEvents = <String>{};
      final seenEndings = <String>{};
      var completedPaths = 0;

      void visit(GameState state) {
        if (state.completed) {
          completedPaths++;
          expect(state.choiceHistory, hasLength(7));
          expect(pack.endings, contains(state.endingId));
          seenEndings.add(state.endingId!);
          return;
        }
        expect(state.choiceHistory.length, lessThan(7));
        seenEvents.add(state.currentEventId);
        final actions = runtime.availableActions(state);
        expect(actions, isNotEmpty, reason: state.currentEventId);
        for (final action in actions) {
          visit(runtime.execute(state, action.id));
        }
      }

      visit(runtime.initialState(17));
      expect(completedPaths, greaterThan(1000));
      expect(seenEvents, pack.events.keys.toSet());
      expect(seenEndings, pack.endings.keys.toSet());
    });
  }

  test('保粮与留田的代表路径抵达相应结局，且存档恢复不改写结果', () {
    final paths = {
      'mulberry-policy': [
        'order-floor',
        'reports-inspect',
        'field-petition',
        'flood-paddy',
        'testimony-open',
        'delivery-tax',
        'seal-truth',
      ],
      'mulberry-county': [
        'letters-reserve',
        'ledgers-copy',
        'measure-soil',
        'granary-open',
        'reply-exception',
        'witness-appeal',
        'inspection-truth',
      ],
      'mulberry-household': [
        'seed-half',
        'paper-copy',
        'old_mulberry-share',
        'rain-family',
        'rice-borrow',
        'questions-own',
        'fingerprint-verify',
      ],
    };
    final expected = {
      'mulberry-policy': 'mulberry-policy-grain_clause',
      'mulberry-county': 'mulberry-county-paddy_owner',
      'mulberry-household': 'mulberry-household-half_field',
    };
    for (final entry in paths.entries) {
      final runtime = GameRuntime(packs[entry.key]!);
      var direct = runtime.initialState(73);
      var restored = runtime.initialState(73);
      for (var i = 0; i < entry.value.length; i++) {
        final action = '${entry.key}-${entry.value[i]}';
        direct = runtime.execute(direct, action);
        restored = runtime.execute(restored, action);
        if (i == 2) {
          restored = GameState.fromJson(
            jsonDecode(jsonEncode(restored.toJson())) as Json,
          );
        }
      }
      expect(direct.endingId, expected[entry.key]);
      expect(restored.toJson(), direct.toJson());
    }
  });

  test('三角色切换不继承其他角色的选择、债务或存档', () async {
    final saves = _Saves();
    final coordinator = GameCoordinator(
      stories: builtInStories,
      contentRepository: _Packs(packs),
      saveRepository: saves,
      seedGenerator: _Seed(),
    );
    await coordinator.selectStory('mulberry-policy');
    await coordinator.newGame();
    final policy = await coordinator.choose('mulberry-policy-order-floor');
    await coordinator.selectStory('mulberry-county');
    final county = await coordinator.newGame();
    expect(county.state!.choiceHistory, isEmpty);
    await coordinator.choose('mulberry-county-letters-assign');
    final household = await coordinator.selectStory('mulberry-household');
    expect(household.state, isNull);
    final startedHousehold = await coordinator.newGame();
    expect(startedHousehold.state!.dimensionScores['debt'], 20);
    expect(startedHousehold.state!.choiceHistory, isEmpty);
    final resumed = await coordinator.selectStory('mulberry-policy');
    expect(resumed.state!.toJson(), policy.state!.toJson());
    expect(saves.states.keys.toSet(), _files.keys.toSet());
  });
}

class _Packs implements ContentPackRepository {
  _Packs(this.packs);
  final Map<String, GameContentPack> packs;
  @override
  Future<GameContentPack> load(StoryDescriptor story) async =>
      packs[story.packId]!;
}

class _Saves implements SaveRepository {
  final states = <String, GameState>{};
  @override
  Future<void> clear(String packId) async => states.remove(packId);
  @override
  Future<GameState?> load(String packId, String packVersion) async =>
      states[packId];
  @override
  Future<void> save(String packId, GameState state) async =>
      states[packId] = state;
}

class _Seed implements SeedGenerator {
  @override
  int nextSeed() => 17;
}
