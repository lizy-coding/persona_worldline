import 'dart:convert';

typedef Json = Map<String, dynamic>;

enum ConditionType { flagEquals, scoreAtLeast }

enum EffectType { addScore, setFlag }

class GameCondition {
  const GameCondition(this.type, this.key, this.value);
  final ConditionType type;
  final String key;
  final Object value;

  factory GameCondition.fromJson(Json json) {
    final type = switch (json['type']) {
      'flagEquals' => ConditionType.flagEquals,
      'scoreAtLeast' => ConditionType.scoreAtLeast,
      final value => throw FormatException('未知 condition type: $value'),
    };
    return GameCondition(type, json['key'] as String, json['value'] as Object);
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
      nextEventId: json['nextEventId'] as String?,
      endingId: json['endingId'] as String?,
    );
  }
}

class SelectOptionAction extends PlayerAction {
  const SelectOptionAction({
    required super.id,
    required super.text,
    required this.conditions,
    required this.effects,
    this.nextEventId,
    this.endingId,
  });
  final List<GameCondition> conditions;
  final List<GameEffect> effects;
  final String? nextEventId;
  final String? endingId;
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

  factory GameEvent.fromJson(Json j) => GameEvent(
    id: j['id'] as String,
    chapter: j['chapter'] as int,
    title: j['title'] as String,
    description: j['description'] as String,
    conditions: _list(j['conditions'], GameCondition.fromJson),
    actions: _list(j['actions'], PlayerAction.fromJson),
  );
}

class Archetype {
  const Archetype(this.id, this.name, this.description, this.weights);
  final String id;
  final String name;
  final String description;
  final Map<String, int> weights;
  factory Archetype.fromJson(Json j) => Archetype(
    j['id'] as String,
    j['name'] as String,
    j['description'] as String,
    Map<String, int>.from(j['weights'] as Map),
  );
}

class Ending {
  const Ending(this.id, this.title, this.summary);
  final String id;
  final String title;
  final String summary;
  factory Ending.fromJson(Json j) =>
      Ending(j['id'] as String, j['title'] as String, j['summary'] as String);
}

class GameContentPack {
  const GameContentPack({
    required this.schemaVersion,
    required this.packId,
    required this.version,
    required this.title,
    required this.startEventId,
    required this.dimensions,
    required this.archetypes,
    required this.events,
    required this.endings,
  });
  final int schemaVersion;
  final String packId, version, title, startEventId;
  final List<String> dimensions;
  final List<Archetype> archetypes;
  final Map<String, GameEvent> events;
  final Map<String, Ending> endings;

  factory GameContentPack.fromJson(Json j) {
    final eventList = _list(j['events'], GameEvent.fromJson);
    final endingList = _list(j['endings'], Ending.fromJson);
    final pack = GameContentPack(
      schemaVersion: j['schemaVersion'] as int,
      packId: j['packId'] as String,
      version: j['version'] as String,
      title: j['title'] as String,
      startEventId: j['startEventId'] as String,
      dimensions: List<String>.from(j['dimensions'] as List),
      archetypes: _list(j['archetypes'], Archetype.fromJson),
      events: {for (final e in eventList) e.id: e},
      endings: {for (final e in endingList) e.id: e},
    );
    pack.validate(eventList.length, endingList.length);
    return pack;
  }

  factory GameContentPack.decode(String source) =>
      GameContentPack.fromJson(jsonDecode(source) as Json);

  void validate(int eventCount, int endingCount) {
    if (schemaVersion != 1) throw const FormatException('不支持的内容 schemaVersion');
    if (events.length != eventCount || endings.length != endingCount) {
      throw const FormatException('事件或结局 ID 重复');
    }
    if (!events.containsKey(startEventId)) {
      throw FormatException('startEventId 不存在: $startEventId');
    }
    final ids = <String>{...events.keys, ...endings.keys};
    if (ids.length != events.length + endings.length) {
      throw const FormatException('ID 必须全局唯一');
    }
    for (final event in events.values) {
      for (final action in event.actions.cast<SelectOptionAction>()) {
        final destinations = [
          action.nextEventId,
          action.endingId,
        ].whereType<String>().toList();
        if (destinations.length != 1) {
          throw FormatException('${action.id} 必须且只能有一个目的地');
        }
        if (action.nextEventId != null &&
            !events.containsKey(action.nextEventId)) {
          throw FormatException('无效 nextEventId: ${action.nextEventId}');
        }
        if (action.endingId != null && !endings.containsKey(action.endingId)) {
          throw FormatException('无效 endingId: ${action.endingId}');
        }
      }
    }
  }
}

List<T> _list<T>(Object? value, T Function(Json) parse) =>
    (value as List? ?? const []).map((e) => parse(e as Json)).toList();

class ChoiceRecord {
  const ChoiceRecord(this.eventId, this.actionId, this.text);
  final String eventId, actionId, text;
  Json toJson() => {'eventId': eventId, 'actionId': actionId, 'text': text};
  factory ChoiceRecord.fromJson(Json j) => ChoiceRecord(
    j['eventId'] as String,
    j['actionId'] as String,
    j['text'] as String,
  );
}

class GameState {
  const GameState({
    required this.currentEventId,
    required this.dimensionScores,
    required this.flags,
    required this.choiceHistory,
    required this.contentPackVersion,
    required this.completed,
    this.endingId,
  });
  final String currentEventId;
  final Map<String, int> dimensionScores;
  final Map<String, bool> flags;
  final List<ChoiceRecord> choiceHistory;
  final String contentPackVersion;
  final bool completed;
  final String? endingId;

  Json toJson() => {
    'schemaVersion': 1,
    'currentEventId': currentEventId,
    'dimensionScores': dimensionScores,
    'flags': flags,
    'choiceHistory': choiceHistory.map((e) => e.toJson()).toList(),
    'contentPackVersion': contentPackVersion,
    'completed': completed,
    'endingId': endingId,
  };
  factory GameState.fromJson(Json j) {
    if (j['schemaVersion'] != 1) throw const FormatException('存档版本不兼容');
    return GameState(
      currentEventId: j['currentEventId'] as String,
      dimensionScores: Map<String, int>.from(j['dimensionScores'] as Map),
      flags: Map<String, bool>.from(j['flags'] as Map),
      choiceHistory: _list(j['choiceHistory'], ChoiceRecord.fromJson),
      contentPackVersion: j['contentPackVersion'] as String,
      completed: j['completed'] as bool,
      endingId: j['endingId'] as String?,
    );
  }
}
