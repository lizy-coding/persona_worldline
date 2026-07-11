import 'dart:convert';

typedef Json = Map<String, dynamic>;

enum ConditionType {
  flagEquals,
  scoreAtLeast,
  scoreAtMost,
  scoreHighest,
  all,
  any,
  atLeast,
  not,
}

enum EffectType { addScore, setFlag }

class GameCondition {
  const GameCondition({
    required this.type,
    this.key,
    this.value,
    this.conditions = const [],
    this.keys = const [],
    this.minimumMatches,
  });

  final ConditionType type;
  final String? key;
  final Object? value;
  final List<GameCondition> conditions;
  final List<String> keys;
  final int? minimumMatches;

  factory GameCondition.fromJson(Json json) {
    final type = switch (json['type']) {
      'flagEquals' => ConditionType.flagEquals,
      'scoreAtLeast' => ConditionType.scoreAtLeast,
      'scoreAtMost' => ConditionType.scoreAtMost,
      'scoreHighest' => ConditionType.scoreHighest,
      'all' => ConditionType.all,
      'any' => ConditionType.any,
      'atLeast' => ConditionType.atLeast,
      'not' => ConditionType.not,
      final value => throw FormatException('未知 condition type: $value'),
    };
    final nested = _list(json['conditions'], GameCondition.fromJson);
    if (type == ConditionType.not && nested.length != 1) {
      throw const FormatException('not 条件必须且只能包含一个子条件');
    }
    if ((type == ConditionType.all ||
            type == ConditionType.any ||
            type == ConditionType.atLeast) &&
        nested.isEmpty) {
      throw FormatException('${json['type']} 条件至少需要一个子条件');
    }
    final keys = List<String>.from(json['keys'] as List? ?? const []);
    final minimumMatches = json['minimumMatches'] as int?;
    if (type == ConditionType.atLeast &&
        (minimumMatches == null ||
            minimumMatches <= 0 ||
            minimumMatches > nested.length)) {
      throw const FormatException('atLeast 的 minimumMatches 超出子条件范围');
    }
    if (type == ConditionType.scoreHighest &&
        (json['key'] == null || keys.isEmpty)) {
      throw const FormatException('scoreHighest 需要 key 和非空 keys');
    }
    return GameCondition(
      type: type,
      key: json['key'] as String?,
      value: json['value'],
      conditions: nested,
      keys: keys,
      minimumMatches: minimumMatches,
    );
  }
}

class GameEffect {
  const GameEffect(this.type, this.key, this.value);

  final EffectType type;
  final String key;
  final Object value;

  factory GameEffect.fromJson(Json json) {
    final type = switch (json['type']) {
      'addScore' => EffectType.addScore,
      'setFlag' => EffectType.setFlag,
      final value => throw FormatException('未知 effect type: $value'),
    };
    return GameEffect(type, json['key'] as String, json['value'] as Object);
  }
}

class EventRoute {
  const EventRoute({
    required this.eventId,
    required this.weight,
    required this.conditions,
  });

  final String eventId;
  final int weight;
  final List<GameCondition> conditions;

  factory EventRoute.fromJson(Json json) => EventRoute(
    eventId: json['eventId'] as String,
    weight: json['weight'] as int? ?? 1,
    conditions: _list(json['conditions'], GameCondition.fromJson),
  );
}

class RandomRoute extends EventRoute {
  const RandomRoute({
    required super.eventId,
    required super.weight,
    required super.conditions,
    required this.minimumChoiceCount,
    required this.maximumChoiceCount,
  });

  final int minimumChoiceCount;
  final int maximumChoiceCount;

  factory RandomRoute.fromJson(Json json) => RandomRoute(
    eventId: json['eventId'] as String,
    weight: json['weight'] as int? ?? 1,
    conditions: _list(json['conditions'], GameCondition.fromJson),
    minimumChoiceCount: json['minimumChoiceCount'] as int,
    maximumChoiceCount: json['maximumChoiceCount'] as int,
  );
}

sealed class PlayerAction {
  const PlayerAction({required this.id, required this.text});

  final String id;
  final String text;

  factory PlayerAction.fromJson(Json json) {
    if (json['type'] != 'selectOption') {
      throw FormatException('未知 action type: ${json['type']}');
    }
    return SelectOptionAction(
      id: json['id'] as String,
      text: json['text'] as String,
      conditions: _list(json['conditions'], GameCondition.fromJson),
      effects: _list(json['effects'], GameEffect.fromJson),
      routes: _list(json['routes'], EventRoute.fromJson),
      endsStory: json['endsStory'] as bool? ?? false,
    );
  }
}

class SelectOptionAction extends PlayerAction {
  const SelectOptionAction({
    required super.id,
    required super.text,
    required this.conditions,
    required this.effects,
    required this.routes,
    required this.endsStory,
  });

  final List<GameCondition> conditions;
  final List<GameEffect> effects;
  final List<EventRoute> routes;
  final bool endsStory;
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.chapter,
    required this.title,
    required this.description,
    required this.conditions,
    required this.actions,
  });

  final String id;
  final int chapter;
  final String title;
  final String description;
  final List<GameCondition> conditions;
  final List<PlayerAction> actions;

  factory GameEvent.fromJson(Json json) => GameEvent(
    id: json['id'] as String,
    chapter: json['chapter'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    conditions: _list(json['conditions'], GameCondition.fromJson),
    actions: _list(json['actions'], PlayerAction.fromJson),
  );
}

class ScoreDimension {
  const ScoreDimension({
    required this.id,
    required this.label,
    required this.minimum,
    required this.maximum,
    required this.initialValue,
    required this.visible,
  });

  final String id;
  final String label;
  final int minimum;
  final int maximum;
  final int initialValue;
  final bool visible;

  factory ScoreDimension.fromJson(Json json) => ScoreDimension(
    id: json['id'] as String,
    label: json['label'] as String,
    minimum: json['minimum'] as int,
    maximum: json['maximum'] as int,
    initialValue: json['initialValue'] as int,
    visible: json['visible'] as bool? ?? true,
  );
}

class Archetype {
  const Archetype(this.id, this.name, this.description, this.weights);

  final String id;
  final String name;
  final String description;
  final Map<String, int> weights;

  factory Archetype.fromJson(Json json) => Archetype(
    json['id'] as String,
    json['name'] as String,
    json['description'] as String,
    Map<String, int>.from(json['weights'] as Map),
  );
}

class Ending {
  const Ending(this.id, this.title, this.summary);

  final String id;
  final String title;
  final String summary;

  factory Ending.fromJson(Json json) => Ending(
    json['id'] as String,
    json['title'] as String,
    json['summary'] as String,
  );
}

class EndingRule {
  const EndingRule({required this.endingId, required this.conditions});

  final String endingId;
  final List<GameCondition> conditions;

  factory EndingRule.fromJson(Json json) => EndingRule(
    endingId: json['endingId'] as String,
    conditions: _list(json['conditions'], GameCondition.fromJson),
  );
}

class StoryIntro {
  const StoryIntro({
    required this.title,
    required this.body,
    required this.buttonText,
  });

  final String title;
  final String body;
  final String buttonText;

  factory StoryIntro.fromJson(Json json) => StoryIntro(
    title: json['title'] as String,
    body: json['body'] as String,
    buttonText: json['buttonText'] as String,
  );
}

class StoryDescriptor {
  const StoryDescriptor({
    required this.packId,
    required this.title,
    required this.summary,
    required this.audienceTags,
  });

  final String packId;
  final String title;
  final String summary;
  final List<String> audienceTags;
}

class FlowRules {
  const FlowRules({
    required this.minimumChoiceCount,
    required this.maximumChoiceCount,
    required this.initialFlags,
    required this.endingRules,
    required this.randomRoutes,
  });

  final int minimumChoiceCount;
  final int maximumChoiceCount;
  final Map<String, bool> initialFlags;
  final List<EndingRule> endingRules;
  final List<RandomRoute> randomRoutes;

  factory FlowRules.fromJson(Json json) => FlowRules(
    minimumChoiceCount: json['minimumChoiceCount'] as int,
    maximumChoiceCount: json['maximumChoiceCount'] as int,
    initialFlags: Map<String, bool>.from(json['initialFlags'] as Map),
    endingRules: _list(json['endingRules'], EndingRule.fromJson),
    randomRoutes: _list(json['randomRoutes'], RandomRoute.fromJson),
  );
}

class GameContentPack {
  const GameContentPack({
    required this.schemaVersion,
    required this.packId,
    required this.version,
    required this.title,
    required this.summary,
    required this.intro,
    required this.flowRules,
    required this.startEventId,
    required this.dimensions,
    required this.archetypes,
    required this.events,
    required this.endings,
  });

  final int schemaVersion;
  final String packId;
  final String version;
  final String title;
  final String summary;
  final String startEventId;
  final StoryIntro intro;
  final FlowRules flowRules;
  final List<ScoreDimension> dimensions;
  final List<Archetype> archetypes;
  final Map<String, GameEvent> events;
  final Map<String, Ending> endings;

  factory GameContentPack.fromJson(Json json) {
    final dimensions = _list(json['dimensions'], ScoreDimension.fromJson);
    final archetypes = _list(json['archetypes'], Archetype.fromJson);
    final eventList = _list(json['events'], GameEvent.fromJson);
    final endingList = _list(json['endings'], Ending.fromJson);
    final pack = GameContentPack(
      schemaVersion: json['schemaVersion'] as int,
      packId: json['packId'] as String,
      version: json['version'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      intro: StoryIntro.fromJson(json['intro'] as Json),
      flowRules: FlowRules.fromJson(json['flowRules'] as Json),
      startEventId: json['startEventId'] as String,
      dimensions: dimensions,
      archetypes: archetypes,
      events: {for (final event in eventList) event.id: event},
      endings: {for (final ending in endingList) ending.id: ending},
    );
    pack.validate(
      dimensionCount: dimensions.length,
      archetypeCount: archetypes.length,
      eventCount: eventList.length,
      endingCount: endingList.length,
    );
    return pack;
  }

  factory GameContentPack.decode(String source) =>
      GameContentPack.fromJson(jsonDecode(source) as Json);

  Map<String, ScoreDimension> get dimensionsById => {
    for (final dimension in dimensions) dimension.id: dimension,
  };

  void validate({
    required int dimensionCount,
    required int archetypeCount,
    required int eventCount,
    required int endingCount,
  }) {
    if (schemaVersion != 3) {
      throw const FormatException('不支持的内容 schemaVersion');
    }
    if (flowRules.minimumChoiceCount <= 0 ||
        flowRules.maximumChoiceCount < flowRules.minimumChoiceCount) {
      throw const FormatException('故事选择次数范围无效');
    }
    if (dimensions.isEmpty || dimensionsById.length != dimensionCount) {
      throw const FormatException('评分维度为空或 ID 重复');
    }
    for (final dimension in dimensions) {
      if (dimension.minimum >= dimension.maximum ||
          dimension.initialValue < dimension.minimum ||
          dimension.initialValue > dimension.maximum) {
        throw FormatException('评分维度范围无效: ${dimension.id}');
      }
    }
    if (archetypes.isEmpty ||
        archetypes.map((item) => item.id).toSet().length != archetypeCount) {
      throw const FormatException('人格原型为空或 ID 重复');
    }
    if (events.length != eventCount || endings.length != endingCount) {
      throw const FormatException('事件或结局 ID 重复');
    }
    if (!events.containsKey(startEventId)) {
      throw FormatException('startEventId 不存在: $startEventId');
    }
    if (flowRules.endingRules.isEmpty ||
        flowRules.endingRules.last.conditions.isNotEmpty) {
      throw const FormatException('endingRules 最后一项必须是无条件兜底结局');
    }
    for (final rule in flowRules.endingRules) {
      if (!endings.containsKey(rule.endingId)) {
        throw FormatException('动态结局不存在: ${rule.endingId}');
      }
    }
    for (final route in flowRules.randomRoutes) {
      if (route.weight <= 0 ||
          route.minimumChoiceCount <= 0 ||
          route.maximumChoiceCount < route.minimumChoiceCount ||
          route.maximumChoiceCount >= flowRules.maximumChoiceCount) {
        throw FormatException('故事随机路由范围无效: ${route.eventId}');
      }
      if (!events.containsKey(route.eventId)) {
        throw FormatException('故事随机路由事件不存在: ${route.eventId}');
      }
    }
    final dimensionIds = dimensionsById.keys.toSet();
    for (final rule in flowRules.endingRules) {
      _validateConditions(rule.conditions, dimensionIds, '动态结局');
    }
    for (final route in flowRules.randomRoutes) {
      _validateConditions(route.conditions, dimensionIds, '故事随机路由');
    }
    for (final archetype in archetypes) {
      final unknown = archetype.weights.keys.where(
        (id) => !dimensionIds.contains(id),
      );
      if (unknown.isNotEmpty) {
        throw FormatException('人格原型引用未知维度: ${unknown.join(', ')}');
      }
    }
    _validateEvents(dimensionIds);
  }

  void _validateEvents(Set<String> dimensionIds) {
    final reachable = <String>{};

    void visit(String eventId) {
      if (!reachable.add(eventId)) return;
      final event = events[eventId]!;
      if (event.actions.isEmpty) {
        throw FormatException('事件没有行动: $eventId');
      }
      _validateConditions(event.conditions, dimensionIds, event.id);
      for (final action in event.actions.cast<SelectOptionAction>()) {
        if (action.endsStory == action.routes.isNotEmpty) {
          throw FormatException('${action.id} 必须选择结束故事或配置后继事件');
        }
        _validateConditions(action.conditions, dimensionIds, action.id);
        for (final effect in action.effects) {
          if (effect.type == EffectType.addScore &&
              !dimensionIds.contains(effect.key)) {
            throw FormatException('${action.id} 修改未知维度: ${effect.key}');
          }
        }
        for (final route in action.routes) {
          if (route.weight <= 0) {
            throw FormatException('${action.id} 路由权重必须大于 0');
          }
          if (!events.containsKey(route.eventId)) {
            throw FormatException('无效 eventId: ${route.eventId}');
          }
          _validateConditions(route.conditions, dimensionIds, action.id);
          visit(route.eventId);
        }
      }
    }

    visit(startEventId);
    final unreachable = events.keys.where((id) => !reachable.contains(id));
    if (unreachable.isNotEmpty) {
      throw FormatException('存在不可达事件: ${unreachable.join(', ')}');
    }
  }

  void _validateConditions(
    List<GameCondition> conditions,
    Set<String> dimensionIds,
    String context,
  ) {
    for (final condition in conditions) {
      if ((condition.type == ConditionType.scoreAtLeast ||
              condition.type == ConditionType.scoreAtMost ||
              condition.type == ConditionType.scoreHighest) &&
          !dimensionIds.contains(condition.key)) {
        throw FormatException('$context 引用未知评分维度: ${condition.key}');
      }
      final unknownKeys = condition.keys.where(
        (key) => !dimensionIds.contains(key),
      );
      if (unknownKeys.isNotEmpty) {
        throw FormatException('$context 引用未知评分维度: ${unknownKeys.join(', ')}');
      }
      _validateConditions(condition.conditions, dimensionIds, context);
    }
  }
}

List<T> _list<T>(Object? value, T Function(Json) parse) =>
    (value as List? ?? const []).map((item) => parse(item as Json)).toList();

class ChoiceRecord {
  const ChoiceRecord(this.eventId, this.actionId, this.text);

  final String eventId;
  final String actionId;
  final String text;

  Json toJson() => {'eventId': eventId, 'actionId': actionId, 'text': text};

  factory ChoiceRecord.fromJson(Json json) => ChoiceRecord(
    json['eventId'] as String,
    json['actionId'] as String,
    json['text'] as String,
  );
}

class GameState {
  const GameState({
    required this.currentEventId,
    required this.dimensionScores,
    required this.flags,
    required this.choiceHistory,
    required this.contentPackVersion,
    required this.randomState,
    required this.completed,
    this.endingId,
  });

  final String currentEventId;
  final Map<String, int> dimensionScores;
  final Map<String, bool> flags;
  final List<ChoiceRecord> choiceHistory;
  final String contentPackVersion;
  final int randomState;
  final bool completed;
  final String? endingId;

  Json toJson() => {
    'schemaVersion': 2,
    'currentEventId': currentEventId,
    'dimensionScores': dimensionScores,
    'flags': flags,
    'choiceHistory': choiceHistory.map((record) => record.toJson()).toList(),
    'contentPackVersion': contentPackVersion,
    'randomState': randomState,
    'completed': completed,
    'endingId': endingId,
  };

  factory GameState.fromJson(Json json) {
    if (json['schemaVersion'] != 2) {
      throw const FormatException('存档版本不兼容');
    }
    return GameState(
      currentEventId: json['currentEventId'] as String,
      dimensionScores: Map<String, int>.from(json['dimensionScores'] as Map),
      flags: Map<String, bool>.from(json['flags'] as Map),
      choiceHistory: _list(json['choiceHistory'], ChoiceRecord.fromJson),
      contentPackVersion: json['contentPackVersion'] as String,
      randomState: json['randomState'] as int,
      completed: json['completed'] as bool,
      endingId: json['endingId'] as String?,
    );
  }
}
