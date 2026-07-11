import 'models.dart';

class ConditionEvaluator {
  bool all(List<GameCondition> conditions, GameState state) =>
      conditions.every((condition) => evaluate(condition, state));

  bool evaluate(
    GameCondition condition,
    GameState state,
  ) => switch (condition.type) {
    ConditionType.flagEquals => state.flags[condition.key] == condition.value,
    ConditionType.scoreAtLeast =>
      (state.dimensionScores[condition.key] ?? 0) >= (condition.value as num),
    ConditionType.scoreAtMost =>
      (state.dimensionScores[condition.key] ?? 0) <= (condition.value as num),
    ConditionType.scoreHighest => condition.keys.every(
      (key) =>
          (state.dimensionScores[condition.key] ?? 0) >=
          (state.dimensionScores[key] ?? 0),
    ),
    ConditionType.all => all(condition.conditions, state),
    ConditionType.any => condition.conditions.any(
      (nested) => evaluate(nested, state),
    ),
    ConditionType.atLeast =>
      condition.conditions.where((nested) => evaluate(nested, state)).length >=
          condition.minimumMatches!,
    ConditionType.not => !evaluate(condition.conditions.single, state),
  };
}

class EffectExecutor {
  GameState apply(
    GameState state,
    List<GameEffect> effects,
    Map<String, ScoreDimension> dimensions,
  ) {
    final scores = {...state.dimensionScores};
    final flags = {...state.flags};
    for (final effect in effects) {
      switch (effect.type) {
        case EffectType.addScore:
          final dimension = dimensions[effect.key]!;
          scores[effect.key] =
              ((scores[effect.key] ?? 0) + (effect.value as num).toInt()).clamp(
                dimension.minimum,
                dimension.maximum,
              );
        case EffectType.setFlag:
          flags[effect.key] = effect.value as bool;
      }
    }
    return _copyState(state, dimensionScores: scores, flags: flags);
  }
}

class EndingResolver {
  EndingResolver(this.evaluator);

  final ConditionEvaluator evaluator;

  String resolveId(GameState state, GameContentPack pack) => pack
      .flowRules
      .endingRules
      .firstWhere((rule) => evaluator.all(rule.conditions, state))
      .endingId;

  Ending resolve(GameState state, GameContentPack pack) =>
      pack.endings[state.endingId] ??
      (throw StateError('结局不存在: ${state.endingId}'));
}

class GameRuntime {
  GameRuntime(
    this.pack, {
    ConditionEvaluator? evaluator,
    EffectExecutor? executor,
  }) : evaluator = evaluator ?? ConditionEvaluator(),
       executor = executor ?? EffectExecutor() {
    endingResolver = EndingResolver(this.evaluator);
  }

  final GameContentPack pack;
  final ConditionEvaluator evaluator;
  final EffectExecutor executor;
  late final EndingResolver endingResolver;

  GameState initialState(int seed) => GameState(
    currentEventId: pack.startEventId,
    dimensionScores: {
      for (final dimension in pack.dimensions)
        dimension.id: dimension.initialValue,
    },
    flags: {...pack.flowRules.initialFlags},
    choiceHistory: const [],
    contentPackVersion: pack.version,
    randomState: _normalizeSeed(seed),
    completed: false,
  );

  GameEvent currentEvent(GameState state) =>
      pack.events[state.currentEventId] ??
      (throw StateError('当前事件不存在: ${state.currentEventId}'));

  List<SelectOptionAction> availableActions(GameState state) {
    final nextChoiceCount = state.choiceHistory.length + 1;
    return currentEvent(state).actions.cast<SelectOptionAction>().where((
      action,
    ) {
      if (!evaluator.all(action.conditions, state)) return false;
      if (action.endsStory &&
          nextChoiceCount < pack.flowRules.minimumChoiceCount) {
        return false;
      }
      return true;
    }).toList();
  }

  GameState execute(GameState state, String actionId) {
    if (state.completed) throw StateError('游戏已经结束');
    final event = currentEvent(state);
    final action = availableActions(
      state,
    ).where((candidate) => candidate.id == actionId).firstOrNull;
    if (action == null) {
      throw StateError('行动不存在或条件不满足: $actionId');
    }

    final changed = executor.apply(state, action.effects, pack.dimensionsById);
    var next = _copyState(
      changed,
      choiceHistory: [
        ...state.choiceHistory,
        ChoiceRecord(event.id, action.id, action.text),
      ],
    );
    final mustEnd =
        action.endsStory ||
        next.choiceHistory.length >= pack.flowRules.maximumChoiceCount;
    if (mustEnd) {
      final endingId = endingResolver.resolveId(next, pack);
      return _copyState(next, completed: true, endingId: endingId);
    }

    final choiceCount = next.choiceHistory.length;
    final eligibleRoutes = <EventRoute>[
      ...action.routes.where((route) => _routeAvailable(route, next)),
      ...pack.flowRules.randomRoutes.where(
        (route) =>
            choiceCount >= route.minimumChoiceCount &&
            choiceCount <= route.maximumChoiceCount &&
            route.eventId != event.id &&
            _routeAvailable(route, next),
      ),
    ];
    if (eligibleRoutes.isEmpty) {
      throw StateError('行动没有满足条件的后继事件: ${action.id}');
    }
    final selection = _selectRoute(eligibleRoutes, next.randomState);
    return _copyState(
      next,
      currentEventId: selection.route.eventId,
      randomState: selection.randomState,
    );
  }

  bool _routeAvailable(EventRoute route, GameState state) =>
      evaluator.all(route.conditions, state) &&
      evaluator.all(pack.events[route.eventId]!.conditions, state);

  _RouteSelection _selectRoute(List<EventRoute> routes, int state) {
    final nextState = _nextRandomState(state);
    final totalWeight = routes.fold<int>(0, (sum, route) => sum + route.weight);
    var value = nextState % totalWeight;
    for (final route in routes) {
      if (value < route.weight) {
        return _RouteSelection(route, nextState);
      }
      value -= route.weight;
    }
    throw StateError('随机路由选择失败');
  }
}

class _RouteSelection {
  const _RouteSelection(this.route, this.randomState);

  final EventRoute route;
  final int randomState;
}

int _normalizeSeed(int seed) {
  final normalized = seed & 0x7fffffff;
  return normalized == 0 ? 0x6d2b79f5 : normalized;
}

int _nextRandomState(int state) {
  var value = state & 0xffffffff;
  value ^= (value << 13) & 0xffffffff;
  value ^= value >> 17;
  value ^= (value << 5) & 0xffffffff;
  return value & 0x7fffffff;
}

GameState _copyState(
  GameState state, {
  String? currentEventId,
  Map<String, int>? dimensionScores,
  Map<String, bool>? flags,
  List<ChoiceRecord>? choiceHistory,
  int? randomState,
  bool? completed,
  String? endingId,
}) => GameState(
  currentEventId: currentEventId ?? state.currentEventId,
  dimensionScores: dimensionScores ?? state.dimensionScores,
  flags: flags ?? state.flags,
  choiceHistory: choiceHistory ?? state.choiceHistory,
  contentPackVersion: state.contentPackVersion,
  randomState: randomState ?? state.randomState,
  completed: completed ?? state.completed,
  endingId: endingId ?? state.endingId,
);

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

  int _distance(TendencyProfile profile, Archetype archetype) =>
      archetype.weights.entries.fold(
        0,
        (sum, entry) =>
            sum + ((profile.scores[entry.key] ?? 0) - entry.value).abs(),
      );
}
