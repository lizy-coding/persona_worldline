import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'session.dart';

class AssetContentPackRepository implements ContentPackRepository {
  const AssetContentPackRepository(this.assetPaths);
  final Map<String, String> assetPaths;

  @override
  Future<GameContentPack> load(StoryDescriptor story) async {
    final assetPath = assetPaths[story.packId];
    if (assetPath == null) {
      throw StateError('故事线未配置本地内容资源: ${story.packId}');
    }
    final pack = GameContentPack.decode(await rootBundle.loadString(assetPath));
    if (pack.packId != story.packId) {
      throw FormatException(
        '故事目录 packId ${story.packId} 与内容包 ${pack.packId} 不一致',
      );
    }
    return pack;
  }
}

class LocalSaveRepository implements SaveRepository {
  static const _prefix = 'persona_worldline.save';

  String _key(String packId) => '$_prefix.$packId';

  @override
  Future<GameState?> load(String packId, String packVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(packId));
    if (raw == null) return null;
    try {
      final state = GameState.fromJson(jsonDecode(raw) as Json);
      if (state.contentPackVersion != packVersion) {
        await clear(packId);
        return null;
      }
      return state;
    } catch (_) {
      await clear(packId);
      return null;
    }
  }

  @override
  Future<void> save(String packId, GameState state) async {
    await (await SharedPreferences.getInstance()).setString(
      _key(packId),
      jsonEncode(state.toJson()),
    );
  }

  @override
  Future<void> clear(String packId) async {
    await (await SharedPreferences.getInstance()).remove(_key(packId));
  }
}
