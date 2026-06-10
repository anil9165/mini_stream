import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const userBox = 'userBox';
  static const streamBox = 'streamBox';
  static const settingsBox = 'settingsBox';
  static const cacheBox = 'cacheBox';

  Future<void> initialize() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(userBox),
      Hive.openBox<dynamic>(streamBox),
      Hive.openBox<dynamic>(settingsBox),
      Hive.openBox<dynamic>(cacheBox),
    ]);
  }

  Future<void> saveDraftLive(Map<String, dynamic> draft) =>
      Hive.box<dynamic>(streamBox).put('draftLive', draft);

  Map<String, dynamic>? getDraftLive() {
    final value = Hive.box<dynamic>(streamBox).get('draftLive');
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> saveLastRtmpConfig(Map<String, dynamic> value) =>
      Hive.box<dynamic>(settingsBox).put('lastRtmpConfig', value);
}
