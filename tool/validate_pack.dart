// Standalone CLI validator for persona_worldline story packs.
// Usage: dart run tool/validate_pack.dart assets/content/<pack>.json
// Exit: 0 if valid, 1 with diagnostics if invalid.

import 'dart:io';

import 'package:persona_worldline/game/models.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/validate_pack.dart <path-to-pack.json>',
    );
    exit(1);
  }

  final path = args.first;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('ERROR: File not found: $path');
    exit(1);
  }

  GameContentPack pack;
  try {
    final source = file.readAsStringSync();
    pack = GameContentPack.decode(source);
  } on FormatException catch (e) {
    stderr.writeln('VALIDATION FAILED');
    stderr.writeln('  File: $path');
    stderr.writeln('  Error: $e');
    exit(1);
  } catch (e) {
    stderr.writeln('PARSE ERROR');
    stderr.writeln('  File: $path');
    stderr.writeln('  Error: $e');
    exit(1);
  }

  // Pack parsed and validated — print diagnostics
  stdout.writeln('VALID: $path');
  stdout.writeln('  packId:      ${pack.packId}');
  stdout.writeln('  title:       ${pack.title}');
  stdout.writeln(
    '  version:     ${pack.version} (schema v${pack.schemaVersion})',
  );
  stdout.writeln('  events:      ${pack.events.length}');
  stdout.writeln('  endings:     ${pack.endings.length}');
  stdout.writeln('  dimensions:  ${pack.dimensions.length}');
  stdout.writeln('  archetypes:  ${pack.archetypes.length}');
  stdout.writeln(
    '  choices:     ${pack.flowRules.minimumChoiceCount}–${pack.flowRules.maximumChoiceCount}',
  );
  stdout.writeln('  randomRoutes: ${pack.flowRules.randomRoutes.length}');
  stdout.writeln('  startEvent:  ${pack.startEventId}');

  exit(0);
}
