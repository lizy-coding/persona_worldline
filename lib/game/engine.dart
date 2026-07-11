import 'models.dart';

class ConditionEvaluator {
  bool all(List<GameCondition> conditions, GameState state) => conditions.every(
    (c) => switch (c.type) {
      ConditionType.flagEquals => state.flags[c.key] == c.value,
      ConditionType.scoreAtLeast =>
        (state.dimensionScores[c.key] ?? 0) >= (c.value as num),
    },
  );
}

class EffectExecutor {
  GameState apply(GameState state, List<GameEffect> effects) {
    final scores = {...state.dimensionScores};
    final flags = {...state.flags};
    for (final effect in effects) {
      switch (effect.type) {
        case EffectType.addScore:
          scores[effect.key] =
              (scores[effect.key] ?? 0) + (effect.value as num).toInt();
        case EffectType.setFlag:
          flags[effect.key] = effect.value as bool;
      }
    }
    return GameState(
      currentEventId: state.currentEventId,
      dimensionScores: scores,
      flags: flags,
      choiceHistory: state.choiceHistory,
      contentPackVersion: state.contentPackVersion,
      completed: state.completed,
      endingId: state.endingId,
    );
  }
}

class GameRuntime {
  GameRuntime(
    this.pack, {
    ConditionEvaluator? evaluator,
    EffectExecutor? executor,
  }) : evaluator = evaluator ?? ConditionEvaluator(),
       executor = executor ?? EffectExecutor();
  final GameContentPack pack;
  final ConditionEvaluator evaluator;
  final EffectExecutor executor;

  GameState initialState() => GameState(
    currentEventId: pack.startEventId,
    dimensionScores: {for (final d in pack.dimensions) d: 0},
    flags: const {},
    choiceHistory: const [],
    contentPackVersion: pack.version,
    completed: false,
  );
  GameEvent currentEvent(GameState state) =>
      pack.events[state.currentEventId] ??
      (throw StateError('当前事件不存在: ${state.currentEventId}'));
  List<SelectOptionAction> availableActions(GameState state) =>
      currentEvent(state).actions
          .cast<SelectOptionAction>()
          .where((a) => evaluator.all(a.conditions, state))
          .toList();
  GameState execute(GameState state, String actionId) {
    if (state.completed) throw StateError('游戏已经结束');
    final event = currentEvent(state);
    final action = event.actions
        .cast<SelectOptionAction>()
        .where((a) => a.id == actionId)
        .firstOrNull;
    if (action == null || !evaluator.all(action.conditions, state)) {
      throw StateError('行动不存在或条件不满足: $actionId');
    }
    final changed = executor.apply(state, action.effects);
    return GameState(
      currentEventId: action.nextEventId ?? state.currentEventId,
      dimensionScores: changed.dimensionScores,
      flags: changed.flags,
      choiceHistory: [
        ...state.choiceHistory,
        ChoiceRecord(event.id, action.id, action.text),
      ],
      contentPackVersion: state.contentPackVersion,
      completed: action.endingId != null,
      endingId: action.endingId,
    );
  }
}

class TendencyProfile {
  const TendencyProfile(this.scores);
  final Map<String, int> scores;
}

class ArchetypeMatcher {
  Archetype match(TendencyProfile profile, List<Archetype> archetypes) {
    if (archetypes.isEmpty) throw StateError('没有人格原型');
    return archetypes.reduce(
      (best, next) =>
          _distance(profile, next) < _distance(profile, best) ? next : best,
    );
  }

  int _distance(TendencyProfile p, Archetype a) => a.weights.entries.fold(
    0,
    (sum, e) => sum + ((p.scores[e.key] ?? 0) - e.value).abs(),
  );
}

class EndingResolver {
  Ending resolve(GameState state, GameContentPack pack) =>
      pack.endings[state.endingId] ??
      (throw StateError('结局不存在: ${state.endingId}'));
}
