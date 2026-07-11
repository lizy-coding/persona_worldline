import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game/engine.dart';
import 'game/infrastructure.dart';
import 'game/models.dart';
import 'game/session.dart';
import 'story_catalog.dart';

final repositoryProvider = Provider<SaveRepository>(
  (ref) => LocalSaveRepository(),
);
final contentRepositoryProvider = Provider<ContentPackRepository>(
  (ref) => const AssetContentPackRepository({
    'silent-tide': 'assets/content/core_pack.json',
  }),
);
final gameProvider = AsyncNotifierProvider<GameNotifier, GameSession?>(
  GameNotifier.new,
);

class GameNotifier extends AsyncNotifier<GameSession?> {
  late GameCoordinator coordinator;
  @override
  Future<GameSession?> build() async {
    coordinator = GameCoordinator(
      stories: builtInStories,
      contentRepository: ref.read(contentRepositoryProvider),
      saveRepository: ref.read(repositoryProvider),
    );
    return null;
  }

  Future<void> selectStory(String packId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => coordinator.selectStory(packId));
  }

  Future<void> newGame() async =>
      state = AsyncData(await coordinator.newGame());
  Future<void> choose(String id) async =>
      state = await AsyncValue.guard(() => coordinator.choose(id));

  void leaveStory() => state = const AsyncData(null);
}

void main() => runApp(const ProviderScope(child: WorldlineApp()));

class WorldlineApp extends StatelessWidget {
  const WorldlineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '人格世界线',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff4157a5),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff0c1020),
    ),
    home: const GameShell(),
  );
}

enum Screen { library, home, intro, game }

class GameShell extends ConsumerStatefulWidget {
  const GameShell({super.key});
  @override
  ConsumerState<GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<GameShell> {
  Screen screen = Screen.library;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ref
                .watch(gameProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorView(
                    message: '内容加载失败\n$e',
                    retry: () => ref.invalidate(gameProvider),
                  ),
                  data: _content,
                ),
          ),
        ),
      ),
    ),
  );

  Widget _content(GameSession? session) {
    if (session == null || screen == Screen.library) {
      return StoryLibraryPage(
        stories: builtInStories,
        onSelect: (packId) async {
          await ref.read(gameProvider.notifier).selectStory(packId);
          if (mounted && ref.read(gameProvider).hasValue) {
            setState(() => screen = Screen.home);
          }
        },
      );
    }
    if (screen == Screen.home) {
      return HomePage(
        session: session,
        onStart: () async {
          await ref.read(gameProvider.notifier).newGame();
          if (mounted) setState(() => screen = Screen.intro);
        },
        onContinue: session.state != null && !session.state!.completed
            ? () => setState(() => screen = Screen.game)
            : null,
        onChangeStory: () {
          ref.read(gameProvider.notifier).leaveStory();
          setState(() => screen = Screen.library);
        },
      );
    }
    if (screen == Screen.intro) {
      return IntroPage(
        session: session,
        onContinue: () => setState(() => screen = Screen.game),
        onBack: () => setState(() => screen = Screen.home),
      );
    }
    final state = session.state!;
    if (state.completed) {
      return ResultPage(
        session: session,
        onRestart: () async {
          await ref.read(gameProvider.notifier).newGame();
          if (mounted) setState(() => screen = Screen.intro);
        },
      );
    }
    return EventPage(
      session: session,
      onChoose: (id) => ref.read(gameProvider.notifier).choose(id),
      onHome: () => setState(() => screen = Screen.home),
    );
  }
}

class StoryLibraryPage extends StatelessWidget {
  const StoryLibraryPage({
    super.key,
    required this.stories,
    required this.onSelect,
  });
  final List<StoryDescriptor> stories;
  final Future<void> Function(String) onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Text('选择一条世界线', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('每条故事线拥有独立内容、人格规则和本地进度。'),
      const SizedBox(height: 24),
      for (final story in stories)
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelect(story.packId),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(story.summary),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: story.audienceTags
                        .map((tag) => Chip(label: Text(tag)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onStart,
    required this.onChangeStory,
    this.onContinue,
  });
  final GameSession session;
  final VoidCallback onStart;
  final VoidCallback onChangeStory;
  final VoidCallback? onContinue;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: onChangeStory,
        icon: const Icon(Icons.grid_view_outlined),
        label: const Text('切换故事线'),
        style: TextButton.styleFrom(alignment: Alignment.centerLeft),
      ),
      const Spacer(),
      Icon(
        Icons.public,
        size: 72,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 28),
      Text(
        session.pack.title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 12),
      Text(session.pack.summary, textAlign: TextAlign.center),
      const SizedBox(height: 40),
      if (onContinue != null) ...[
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.play_arrow),
          label: const Text('继续游戏'),
        ),
        const SizedBox(height: 12),
      ],
      OutlinedButton(
        onPressed: onStart,
        child: Text(onContinue == null ? '开始游戏' : '重新开始'),
      ),
      const Spacer(),
    ],
  );
}

class IntroPage extends StatelessWidget {
  const IntroPage({
    super.key,
    required this.session,
    required this.onContinue,
    required this.onBack,
  });
  final GameSession session;
  final VoidCallback onContinue, onBack;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: const Text('返回'),
        style: TextButton.styleFrom(alignment: Alignment.centerLeft),
      ),
      const Spacer(),
      Text(
        session.pack.intro.title,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 20),
      Text(
        session.pack.intro.body,
        style: const TextStyle(height: 1.7, fontSize: 16),
      ),
      const Spacer(),
      FilledButton(
        onPressed: onContinue,
        child: Text(session.pack.intro.buttonText),
      ),
    ],
  );
}

class EventPage extends StatelessWidget {
  const EventPage({
    super.key,
    required this.session,
    required this.onChoose,
    required this.onHome,
  });
  final GameSession session;
  final Future<void> Function(String) onChoose;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) {
    final state = session.state!;
    final event = session.runtime.currentEvent(state);
    final actions = session.runtime.availableActions(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '第 ${event.chapter} 章',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            IconButton(
              onPressed: onHome,
              tooltip: '返回首页',
              icon: const Icon(Icons.home_outlined),
            ),
          ],
        ),
        LinearProgressIndicator(
          value:
              ((state.choiceHistory.length + 1) /
                      session.pack.expectedTaskCount)
                  .clamp(0, 1),
        ),
        const SizedBox(height: 28),
        Text(event.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              event.description,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ),
        ),
        if (session.saveError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              session.saveError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton.tonal(
              onPressed: () => onChoose(action.id),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
              child: Text(action.text, textAlign: TextAlign.center),
            ),
          ),
        if (actions.isEmpty) const Text('没有满足条件的行动。内容包可能存在逻辑错误。'),
      ],
    );
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.session, required this.onRestart});
  final GameSession session;
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) {
    final state = session.state!;
    final ending = EndingResolver().resolve(state, session.pack);
    final archetype = ArchetypeMatcher().match(
      TendencyProfile(state.dimensionScores),
      session.pack.archetypes,
    );
    return ListView(
      children: [
        const Icon(Icons.auto_awesome, size: 56),
        const SizedBox(height: 20),
        Text(
          ending.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(ending.summary, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Text(
          '你是「${archetype.name}」',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(archetype.description),
        const SizedBox(height: 24),
        Text('人格倾向', style: Theme.of(context).textTheme.titleMedium),
        for (final e in state.dimensionScores.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(e.key)),
                Expanded(
                  child: LinearProgressIndicator(value: (e.value + 6) / 12),
                ),
                const SizedBox(width: 12),
                Text(e.value >= 0 ? '+${e.value}' : '${e.value}'),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('关键选择', style: Theme.of(context).textTheme.titleMedium),
        ...state.choiceHistory.map(
          (e) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chevron_right),
            title: Text(e.text),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onRestart, child: const Text('重新开始')),
      ],
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 52),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: retry, child: const Text('重试')),
      ],
    ),
  );
}
