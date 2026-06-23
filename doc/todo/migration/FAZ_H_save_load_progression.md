# FAZ H — Save/Load & Progression (kalıcılık)

> **Durum:** ⬜ Başlamadı
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

- [ ] **H1 — Serialize.** `ScenarioState` ↔ `SaveState` ↔ JSON. `version: 1` alanı ekle. Round-trip kayıpsız olmalı (Set→List dönüşümü vb. dikkat).
- [ ] **H2 — Repository.** `SaveRepository` (`shared_preferences`): `save(json)`, `load()`, `clear()`. Tek anahtar. Bozuk/eksik JSON → güvenli `null`/yeni oyun (çökme yok).
- [ ] **H3 — Otomatik kaydet.** Encounter tamamlanınca + reward/flag set olunca (Faz G `ScenarioEffect` uygulandığında) `GameSession` kaydetsin. Sık ama ucuz; debounce gerekmiyorsa düz kaydet.
- [ ] **H4 — Açılışta yükle.** Uygulama açılışında kayıt varsa `ScenarioState`'e yükle; menüde **"Devam et"** görünür.
- [ ] **H5 — Yeni oyun / sıfırla.** "Yeni oyun" → `clear()` + boş `ScenarioState`. Onay sor (kayıt silme — geri alınamaz).
- [ ] **H6 — Input ayrımı.** `InputSettings`'in kendi kalıcılığı ayrı kalsın; domain save'i kontrol ayarlarını **içermez** (sorumluluk ayrımı).
- [ ] **H7 — Test + analyze + duman.** Round-trip testleri; oyunu kapat-aç → flag/resource/tamamlanan encounter korunuyor; "Yeni oyun" sıfırlıyor.

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
