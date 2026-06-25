// ============================================================================
//  SaveRepository + SaveStore portu — kalıcılık orkestrasyonu (Faz H)
// ----------------------------------------------------------------------------
//  Ports & adapters: SaveRepository SAF kalır (JSON encode/decode + sürüm/bozukluk
//  koruması) ve soyut `SaveStore` portuna bağımlıdır. Somut depolama (shared_
//  preferences) `core/shared_prefs_save_store.dart` adaptöründedir. Böylece
//  repository, sahte (in-memory) store ile Flutter olmadan test edilebilir.
//
//  Tek-yön bağımlılık: bu dosya Flame/Flutter plugin'i import ETMEZ.
// ============================================================================

import 'dart:convert';

import 'save_state.dart';

/// Depolama portu — repository'nin ihtiyaç duyduğu soyutlama (domain tanımlar,
/// infra/core implemente eder → bağımlılık tersine çevrimi).
abstract class SaveStore {
  Future<String?> read();
  Future<void> write(String contents);
  Future<void> clear();
}

class SaveRepository {
  SaveRepository(this._store);

  final SaveStore _store;

  /// Kaydı yükle. Yoksa/boşsa/bozuksa/sürüm uyumsuzsa güvenli `null` (yeni oyun).
  Future<SaveState?> load() async {
    try {
      final raw = await _store.read();
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final state = SaveState.fromJson(decoded.cast<String, Object?>());
      if (state.version != SaveState.currentVersion) {
        // Şema uyumsuz → güvenli sıfırla (ileride migrasyon eklenebilir).
        return null;
      }
      return state;
    } catch (_) {
      // Bozuk JSON / beklenmeyen biçim → çökme yok, yeni oyuna düş.
      return null;
    }
  }

  /// Anlık görüntüyü yaz. Hata yutulur (kalıcılık opsiyonel katman — oyun sürer).
  Future<void> save(SaveState state) async {
    try {
      await _store.write(jsonEncode(state.toJson()));
    } catch (_) {
      // I/O hatası → sessizce geç; bellekteki durum bozulmaz.
    }
  }

  Future<void> clear() async {
    try {
      await _store.clear();
    } catch (_) {}
  }
}
