import 'engine.dart';
import 'models.dart';

abstract interface class ContentPackRepository {
  Future<GameContentPack> load(StoryDescriptor story);
}

abstract interface class SaveRepository {
  Future<GameState?> load(String packId, String packVersion);
  Future<void> save(String packId, GameState state);
  Future<void> clear(String packId);
}

abstract interface class SeedGenerator {
  int nextSeed();
}

class GameSession {
  const GameSession({
    required this.story,
    required this.pack,
    required this.runtime,
    this.state,
    this.saveError,
  });
  final StoryDescriptor story;
  final GameContentPack pack;
  final GameRuntime runtime;
  final GameState? state;
  final String? saveError;

  GameSession copyWith({
    GameState? state,
    String? saveError,
    bool clearError = false,
  }) => GameSession(
    story: story,
    pack: pack,
    runtime: runtime,
    state: state ?? this.state,
    saveError: clearError ? null : saveError ?? this.saveError,
  );
}

class GameController {
  GameController(this.repository, this.seedGenerator);
  final SaveRepository repository;
  final SeedGenerator seedGenerator;
  late GameSession session;

  Future<GameSession> initialize(
    StoryDescriptor story,
    GameContentPack pack,
  ) async {
    final runtime = GameRuntime(pack);
    session = GameSession(
      story: story,
      pack: pack,
      runtime: runtime,
      state: await repository.load(pack.packId, pack.version),
    );
    return session;
  }

  Future<GameSession> newGame() async {
    await repository.clear(session.pack.packId);
    final state = session.runtime.initialState(seedGenerator.nextSeed());
    await _save(state);
    return session = session.copyWith(state: state, clearError: true);
  }

  Future<GameSession> choose(String id) async {
    final state = session.runtime.execute(session.state!, id);
    await _save(state);
    return session = session.copyWith(state: state);
  }

  Future<void> _save(GameState state) async {
    try {
      await repository.save(session.pack.packId, state);
    } catch (e) {
      session = session.copyWith(saveError: '进度暂时无法保存：$e');
    }
  }
}

class GameCoordinator {
  GameCoordinator({
    required this.stories,
    required this.contentRepository,
    required this.saveRepository,
    required this.seedGenerator,
  });
  final List<StoryDescriptor> stories;
  final ContentPackRepository contentRepository;
  final SaveRepository saveRepository;
  final SeedGenerator seedGenerator;
  GameController? _controller;

  Future<GameSession> selectStory(String packId) async {
    final story = stories.where((item) => item.packId == packId).firstOrNull;
    if (story == null) throw StateError('故事线不存在: $packId');
    final pack = await contentRepository.load(story);
    final controller = GameController(saveRepository, seedGenerator);
    _controller = controller;
    return controller.initialize(story, pack);
  }

  Future<GameSession> newGame() => _requireController().newGame();
  Future<GameSession> choose(String actionId) =>
      _requireController().choose(actionId);

  GameController _requireController() =>
      _controller ?? (throw StateError('尚未选择故事线'));
}
