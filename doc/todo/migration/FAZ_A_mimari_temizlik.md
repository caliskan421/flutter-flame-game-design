# FAZ A — Mimari Temizlik (davranış DEĞİŞMEZ)

> **Durum:** ✅ Bitti
> **Bağımlılık:** Yok (ilk faz).
> **Tür:** Saf refactor — oyuncunun gördüğü hiçbir şey değişmez.
> **Referans:** `doc/architecture.md` §13 (Faz A), §4 (D1/D2 darboğazları), §10 (klasör), `00_INDEX.md` §3 (global değişmezler).

---

## 0. Tek cümle
`game.dart`'ın taşıdığı sunum-dışı sorumlulukları (metrikler, zaman/FX yardımcıları, intro cue verisi) ayrı birimlere taşı ve paylaşılan durum için boş bir `GameSession` iskeleti aç — **davranışı bir kare bile değiştirmeden.**

## 1. Neden (darboğaz kanıtı)
- `game.dart` 1110 satır: faz makinesi + input + FX + kazan/kaybet + metrikler + intro cue'ları **bir arada** (D1).
- Paylaşılan/RPG durumu için bir ev yok (D2).
- `CombatIntroOverlay` cue'ları kodun içinde hard-coded (D6'nın tohumu).

## 2. Kapsam

**DAHİL:**
- `CombatMetrics`'i `game.dart`'tan ayrı dosyaya taşımak (sınıf aynen, sadece konum).
- Zaman/FX yardımcılarını (`_hitstop`, slow-mo, screen-shake; `requestSlowmo`, shake tetikleyiciler) bir `TimeFx`/`FxController` birimine toplamak — `game.dart` ona delege eder.
- Boş `GameSession` iskeleti (`ChangeNotifier`) — henüz kimse bağlanmaz.
- `CombatIntroOverlay`'deki hard-coded cue'ları bir veri sınıfına (`DialogueCueDef` / `IntroSequenceDef`) taşımak; overlay veriyi render eder.

**HARİÇ (bu fazda YAPMA):**
- EventBus, CombatResolver, saf kural çıkarımı → **Faz B**.
- `boss.dart`/`player.dart` ayrıştırması → Faz F.
- Yeni oyun davranışı / yeni özellik.
- Klasör taşımasını zorunlu kılma (opsiyonel; istersen `core/` + `domain/` aç).

## 3. Dokunulacak dosyalar (mevcut → hedef)

| Mevcut | İş | Hedef konum (öneri) |
|---|---|---|
| `lib/game.dart` (`CombatMetrics`, ~961. satır civarı) | Sınıfı kes, ayrı dosyaya taşı, import et | `lib/domain/combat_metrics.dart` (veya `lib/combat_metrics.dart`) |
| `lib/game.dart` (`_hitstop`, `_shakeT/_shakeDur/_shakeAmp`, slow-mo alanları ~87–95; `requestSlowmo` ~722) | Zaman/FX state + metotlarını sınıfa topla; `game.dart` delege eder | `lib/core/time_fx.dart` (`TimeFx`/`FxController`) |
| `lib/overlays.dart` (`CombatIntroOverlay`, hard-coded `_cues`) | Cue listesini veri sınıfına çıkar | `lib/content/intro_sequence.dart` (`DialogueCueDef`, `IntroSequenceDef`) |
| (yeni) | Boş paylaşılan durum iskeleti | `lib/domain/game_session.dart` (`GameSession extends ChangeNotifier`) |

> Not: `game.dart`'taki FX **spawn** metotları (`spawnPopup`, `spawnSpark`, `spawnPostureBreak`, `spawnVignette`) Flame component'i eklediği için `game.dart`'ta kalabilir; bu fazda yalnız **zaman ölçeği/shake/slow-mo** mantığı `TimeFx`'e taşınır.

## 4. Adım adım görevler

- [ ] **A1 — CombatMetrics taşı.** `game.dart` içindeki `CombatMetrics` sınıfını birebir yeni dosyaya taşı. `game.dart`'a `import` ekle. `final CombatMetrics metrics = CombatMetrics();` (game.dart:99) aynen kalsın. Hiçbir alan/sayaç adı değişmesin (`parrySuccesses`, `bossDamageTaken`, `feintBaited`, `greedPunished`, `guardBreakPunished`, `bossPostureBreaks`, `staminaEmptyDenials` vb. — `boss.dart`/`player.dart` bunlara `game.metrics.X` ile erişiyor, kırma).
- [ ] **A2 — TimeFx çıkar.** `_hitstop`, slow-mo (ayrı ölçek), screen-shake (`_shakeT/_shakeDur/_shakeAmp`) state'ini ve bunların `update`'teki sönümleme mantığını + `requestSlowmo(...)` API'sini bir `TimeFx` sınıfına al. `game.dart` bu sınıfı bir alan olarak tutsun ve `update(dt)`'te `timeFx.update(dt)` çağırsın; efektif zaman ölçeğini ondan okusun. **Davranış birebir:** aynı süreler, aynı sönümleme eğrisi.
- [ ] **A3 — GameSession iskeleti.** `domain/game_session.dart`: `class GameSession extends ChangeNotifier {}` — şimdilik boş veya yalnız placeholder alanlar. `main.dart`/`game.dart`'a henüz **bağlama**; sadece derlenebilir iskelet (Faz E/G dolduracak).
- [ ] **A4 — Intro cue verisi.** `CombatIntroOverlay` içindeki hard-coded replik/cue listesini `IntroSequenceDef`/`DialogueCueDef` veri sınıfına taşı (metin, süre, opsiyonel ses/portre alanları). Overlay artık bu listeyi parametre/sabit olarak alıp **yalnızca render** etsin. Görsel sonuç aynı kalmalı.
- [ ] **A5 — Analyze + test.** `flutter analyze` temiz; `flutter test` yeşil. Mevcut `action_system_test`/`combat_rules_test`/`characters_test` bozulmamalı.
- [ ] **A6 — Duman testi.** Oyunu çalıştır; test arena (combo + attack1/2/3 + movement) ve combat intro birebir eskisi gibi mi? Slow-mo/shake/hitstop hissi aynı mı?

## 5. Kabul kriterleri (Definition of Done)
- `game.dart` satır sayısı belirgin düşer; metrik + zaman/FX mantığı ayrı dosyalarda.
- `CombatMetrics` ve `requestSlowmo`/shake **aynı isim ve aynı davranışla** erişilebilir (çağıran kod değişmeden derlenir).
- `GameSession` iskeleti var ama hiçbir davranışı etkilemiyor.
- Intro cue'ları veri olarak duruyor; overlay onları render ediyor.
- `00_INDEX.md` §3 global değişmezlerin hepsi sağlanıyor (özellikle: davranış birebir aynı).

## 6. Test planı
- Mevcut testler aynen geçer (taşıma testleri kırmamalı).
- (Opsiyonel) `test/intro_sequence_test.dart`: cue verisinin beklenen replik sayısı/sırasını doğrular.
- Elle: hitstop/slow-mo/shake'in tetiklendiği anlar (parry, posture break, deathblow, faz geçişi) görsel olarak eskisiyle aynı.

## 7. Riskler & geri alma
- **Risk:** Zaman ölçeği mantığını taşırken sönümleme katsayısını/sırasını kaydırmak → his değişir. **Önlem:** sayısal sabitleri **kopyala, yeniden türetme**; `update` çağrı sırasını koru.
- **Risk:** `CombatMetrics` alan adı değişirse `boss.dart`/`player.dart` derlenmez. **Önlem:** salt taşıma, ad değişikliği yok.
- **Geri alma:** Faz tek/az commit; sorun çıkarsa `git revert`.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter run   # test arena + intro elle kontrol
```
