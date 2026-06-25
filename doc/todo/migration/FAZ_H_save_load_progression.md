# FAZ H — Save/Load & Progression (kalıcılık)

> **Durum:** ✅ Bitti — ScenarioState kalıcılığı (shared_preferences) ports&adapters ile; GameSession tek persist otoritesi; açılışta yükle + Yeni oyun (onaylı) sıfırla; ödül bir kez. Input ayarları ayrı. analyze temiz, 177 test yeşil. (Elle duman testi kullanıcıda.)
> **Bağımlılık:** **Faz G bitmiş olmalı** (kaydedilecek `ScenarioState` orada doğar).
> **Tür:** Yeni özellik — seçimler/ilerleme kalıcı olur.
> **Referans:** `doc/architecture.md` §13 (Faz H), §8.4 (ScenarioState), §12 (state management).

---

## 0. Tek cümle
`ScenarioState` + ilerlemeyi (tamamlanan encounter / flag / resource) JSON olarak `shared_preferences`'e kaydet ve açılışta geri yükle; input ayarları zaten kalıcı olan `InputSettings`'ten **ayrı** tutulur.

## 1. Neden
- `architecture.md` §13 Faz H: "Seçimler kalıcı." RPG dikey kesiti (Faz G) bellekte yaşıyor; kapanınca kayboluyor.
- `shared_preferences` **zaten pubspec'te bağımlı** (`^2.5.5`) ve `InputSettings` deseni mevcut (input_settings.dart `ChangeNotifier`, kalıcı) — aynı yaklaşımı domain'e uygula.

## 2. Kapsam

**DAHİL:**
- `lib/domain/save_state.dart`: `SaveState` — `ScenarioState`'i JSON'a serialize/deserialize.
- `shared_preferences` ile kaydet/yükle/temizle.
- Açılışta yükleme; encounter tamamlanınca / reward alınınca otomatik kaydetme.
- "Devam et" / "Yeni oyun (sıfırla)" girişi.
- Kalıcı domain durumu (flag/resource/completedEncounters) ile **input/kontrol ayarlarının ayrı** tutulması.

**HARİÇ:**
- Bulut kayıt / çoklu slot (ilk sürüm: tek slot yeter).
- Combat içi anlık durumun kaydı (yalnız encounter/flag/resource sınırı — savaş ortası kayıt yok).
- Şema migrasyonu altyapısı (ama `version` alanı eklenir, ileриye dönük).

## 3. Dokunulacak / eklenecek dosyalar

| Dosya | İş |
|---|---|
| `lib/domain/save_state.dart` (yeni) | `SaveState.toJson/fromJson`; `version` alanı; `ScenarioState` ↔ JSON. |
| `lib/domain/save_repository.dart` (yeni) | `shared_preferences` okuma/yazma/temizleme (tek anahtar, örn. `scenario_save_v1`). |
| `lib/domain/game_session.dart` | Yükle/kaydet hook'ları; `ScenarioState` değişince (Faz G `ChangeNotifier`) kaydetme tetiği. |
| `lib/overlays.dart` / menü | "Devam et" (kayıt varsa) + "Yeni oyun" girişleri. |
| `lib/app/flow/encounter_runner.dart` | Encounter tamamlanınca / reward sonrası kaydet. |
| `test/` | Serialize round-trip + repository testleri. |

### İskelet
```dart
class SaveState {
  final int version;                 // şema sürümü (başlangıç: 1)
  final Set<String> flags;
  final Map<String,int> stats, resources;
  final List<String> completedEncounters;
  Map<String,Object?> toJson() => {...};
  factory SaveState.fromJson(Map<String,Object?> j) => ...;
}
```

## 4. Adım adım görevler

- [x] **H1 — Serialize.** ✅ `domain/save_state.dart`: `SaveState` (saf) ↔ JSON; `version:1`; `fromScenario`/`applyTo`; savunmacı `fromJson` (Set↔List, yanlış-tip→varsayılan). Round-trip testli.
- [x] **H2 — Repository.** ✅ `domain/save_repository.dart`: saf `SaveRepository` + soyut `SaveStore` portu; `core/shared_prefs_save_store.dart` tek somut adaptör (anahtar `scenario_save_v1`). Bozuk/JSON-değil/sürüm-uyumsuz → güvenli `null`; I/O hatası yutulur.
- [x] **H3 — Otomatik kaydet.** ✅ `GameSession` TEK persist otoritesi: tüm mutator'lar `_scenarioChanged`→persist; EncounterRunner direkt ScenarioState mutasyonu için `onStateChanged` kancası game.dart'ta `session.persist`'e bağlı (runner GameSession'a bağımlı değil). Fire-and-forget.
- [x] **H4 — Açılışta yükle.** ✅ main.dart `await session.attachPersistence(SaveRepository(SharedPrefsSaveStore()))` → kayıt varsa ScenarioState'e uygulanır; menüde ilerleme satırı + "DEVAM ET" (yalnız kayıt varken).
- [x] **H5 — Yeni oyun / sıfırla.** ✅ "YENİ OYUN (SIFIRLA)" (yalnız kayıt varken) → ConfirmResetOverlay (onay) → `session.resetProgress()` (bellek + disk temizler).
- [x] **H6 — Input ayrımı.** ✅ Save yalnız senaryo verisi; `scenario_save_v1` anahtarı `input.*` uzayından ayrı. Test: clear sonrası `input.bindings.version` korunur. InputSettings'e dokunulmadı.
- [x] **H7 — Test + analyze + duman.** ✅ save_state (5) + save_repository (8, fake store + shared_preferences mock) + game_session_persistence (3) + encounter_runner ödül-bir-kez/onStateChanged (2). analyze temiz, 177 test yeşil. Elle `flutter run` duman testi kullanıcıda.

## 5. Kabul kriterleri
- Encounter tamamlandıktan sonra oyun kapatılıp açıldığında **flag/resource/completedEncounters korunuyor**.
- "Devam et" yalnız kayıt varken; "Yeni oyun" kaydı temizliyor (onaylı).
- Bozuk kayıt çökme yapmaz; güvenli yeni oyuna düşer.
- Domain save ile input ayarları ayrı; biri diğerini bozmaz.
- `version` alanı var (ileride şema migrasyonu için).

## 6. Test planı
- `test/save_state_test.dart`: `toJson/fromJson` round-trip kayıpsız; eksik alan → varsayılan; bilinmeyen alan → tolere; `version` korunur.
- `test/save_repository_test.dart`: `shared_preferences` mock (`SharedPreferences.setMockInitialValues`) ile save→load→clear.
- Elle: encounter bitir → kapat → aç → "Devam et" → durum aynı; "Yeni oyun" → sıfır.

## 7. Riskler & geri alma
- **Risk:** Set/Map JSON dönüşümünde tip kaybı → yükleme çökmesi. **Önlem:** round-trip testi; `fromJson`'da defensive parse + try/catch → yeni oyun.
- **Risk:** Şema değişince eski kayıt patlar. **Önlem:** `version` alanı; uyuşmazsa güvenli sıfırla (ileride migrasyon).
- **Risk:** Çok sık kayıt I/O. **Önlem:** anlamlı noktalarda kaydet (encounter/reward); gerekirse debounce.
- **Geri alma:** kalıcılık opsiyonel katman; `SaveRepository` devre dışı → oyun bellekte (Faz G) çalışmaya devam eder.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter test test/save_state_test.dart test/save_repository_test.dart
flutter run   # encounter bitir → kapat/aç → durum korunuyor mu; yeni oyun sıfırlıyor mu
```
