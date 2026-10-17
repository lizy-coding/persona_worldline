import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persona_worldline/main.dart';
import 'package:persona_worldline/story_catalog.dart';

void main() {
  for (final viewport in [const Size(360, 640), const Size(620, 700)]) {
    testWidgets('目录在 $viewport 可滚动到第三条角色线并选择', (tester) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: StoryLibraryPage(
                stories: builtInStories,
                onSelect: (packId) async => selected = packId,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final household = find.text('桑田秋账·承受者');
      await tester.scrollUntilVisible(
        household,
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(household);
      await tester.pumpAndSettle();
      expect(selected, 'mulberry-household');
      expect(tester.takeException(), isNull);
    });
  }
}
