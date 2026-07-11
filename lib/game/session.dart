import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'engine.dart';
import 'models.dart';

class ContentPackLoader {
  const ContentPackLoader();
  Future<GameContentPack> load() async => GameContentPack.decode(
    await rootBundle.loadString('assets/content/core_pack.json'),
  );
}

abstract interface class SaveRepository {
  Future<GameState?> load(String packVersion);
  Future<void> save(GameState state);
  Future<void> clear();
}

class LocalSaveRepository implements SaveRepository {
  static const _key = 'persona_worldline_save';
  @override
  Future<GameState?> load(String packVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final state = GameState.fromJson(jsonDecode(raw) as Json);
      if (state.contentPackVersion != packVersion) {
        await clear();
        return null;
      }
      return state;
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(GameState state) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(state.toJson()),
      );
  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

class GameSession {
  const GameSession({
    required this.pack,
    required this.runtime,
    this.state,
    this.saveError,
  });
  final GameContentPack pack;
  final GameRuntime runtime;
  final GameState? state;
  final String? saveError;
  GameSession copyWith({
    GameState? state,
    String? saveError,
    bool clearError = false,
  }) => GameSession(
    pack: pack,
    runtime: runtime,
    state: state ?? this.state,
    saveError: clearError ? null : saveError ?? this.saveError,
  );
}

class GameController {
  GameController(this.repository);
  final SaveRepository repository;
  late GameSession session;
  Future<GameSession> initialize(GameContentPack pack) async {
    final runtime = GameRuntime(pack);
    session = GameSession(
      pack: pack,
      runtime: runtime,
      state: await repository.load(pack.version),
    );
    return session;
  }

  Future<GameSession> newGame() async {
    await repository.clear();
    final state = session.runtime.initialState();
    await _save(state);
    return session = session.copyWith(state: state, clearError: true);
  }

  Future<GameSession> continueGame() async => session;
  Future<GameSession> choose(String id) async {
    final state = session.runtime.execute(session.state!, id);
    await _save(state);
    return session = session.copyWith(state: state);
  }

  Future<void> _save(GameState state) async {
    try {
      await repository.save(state);
    } catch (e) {
      session = session.copyWith(saveError: '进度暂时无法保存：$e');
    }
  }
}
