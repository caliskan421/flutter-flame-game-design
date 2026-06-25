// ============================================================================
//  SharedPrefsSaveStore — SaveStore'un shared_preferences adaptörü (Faz H)
// ----------------------------------------------------------------------------
//  Ports & adapters: SaveStore portunun TEK somut implementasyonu; shared_
//  preferences'e dokunan YEGÂNE save dosyası. Tek anahtar (`scenario_save_v1`).
//  Input ayarları ayrı anahtar uzayında ('input.*') → çakışma yok (§H6).
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/save_repository.dart';

class SharedPrefsSaveStore implements SaveStore {
  static const String _key = 'scenario_save_v1';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String contents) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, contents);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
