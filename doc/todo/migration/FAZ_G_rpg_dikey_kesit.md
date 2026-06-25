# FAZ G — RPG Dikey Kesit (Scenario / Encounter / Dialogue / Choice / Dice)

> **Durum:** ✅ Bitti — Ash Gate encounter'ı uçtan uca oynanabilir. Saf çekirdek 16 birim testiyle; akış EncounterRunner'da (D6 çözüldü); zar yalnız hikayede (`bossOpeningDelay`). analyze temiz, 157 test yeşil. (Save/load Faz H; elle duman testi kullanıcıda.)
> **Bağımlılık:** **Faz E (gerçek maç akışı) + Faz F (temiz boss) bitmiş olmalı.** Faz B event yolu kullanılır.
> **Tür:** Yeni özellik — ilk gerçek oyun döngüsü (salt combat prototipinden çıkış).
> **Referans:** `doc/architecture.md` §8 (tümü), §15 (vertical slice tanımı), §16 (ilke 8,10), §14 (zar önce hikâyede).

---

## 0. Tek cümle
Combat'tan **bağımsız bir scenario katmanı** kur: tek bir encounter'ı uçtan uca oynat — kısa diyalog → 2-3 seçim → 1 zar check → normal combat → sonuç → flag/reward — ve combat sonucu (BossDefeated event'i) bu akışı beslesin.

## 1. Neden
- Bugün domain/model katmanı yok (D2); akış orkestratöre gömülü (D6).
- `architecture.md` §15: ilk somut ürün hedefi "Ash Gate encounter" — combat'ın tamamını beklemeden küçük ama gerçek bir oyun döngüsünü kanıtlamak (ilke 10).

## 2. Kapsam (architecture.md §8 + §15)

**DAHİL — ilk slice (Ash Gate):**
```text
Başlangıç menüsü
  -> Ash Gate encounter
     -> kısa diyalog
     -> 2-3 seçim
     -> 1 zar check (sessiz yaklaşma başarılıysa boss ilk fazda daha geç agresifleşir)
     -> Knight 1 normal combat (Faz E akışı)
     -> win/loss sonucu
     -> reward/flag (boss_knight_1_defeated, honor +1)
     -> sonraki encounter placeholder
```
- `ScenarioState` (flags/stats/resources/completedEncounters).
- `EncounterDef` + `EncounterStepKind { dialogue, choice, diceCheck, combat, reward }` + `EncounterRunner`.
- `DialogueNodeDef`, `ChoiceDef`, `DiceCheckDef`, `DiceService` (seedli, saf).
- `ScenarioEffect` (setFlag, giveResource, startCombat...).
- Zar **yalnız hikayede**: başarı → boss ilk fazda daha geç agresifleşir (combat'a **ufak modifikatör**, `ArenaActionSystem`/boss param üzerinden). Parry/dodge başarı oranına BAĞLANMAZ (§14, ilke 8).

**HARİÇ:**
- Save/load kalıcılığı → Faz H. (Bu fazda `ScenarioState` bellekte yaşar.)
- Çok-encounter harita/progresyon (placeholder yeter).
- Avantaj/dezavantaj/reroll/item bonusu (ilk slice: `1d20 + stat >= DC`).

## 3. Dokunulacak / eklenecek dosyalar

| Dosya | İş |
|---|---|
| `lib/domain/scenario_state.dart` (yeni) | `ScenarioState { flags, stats, resources, completedEncounters }` (§8.4). |
| `lib/core/rng.dart` (yeni/ortak) | Seedli `Rng` (zar + boss AI tek kaynak — ilke 9). |
| `lib/domain/dice_service.dart` (yeni) | `DiceService.roll(check, rng)` — saf, test edilebilir (§8.3). |
| `lib/app/flow/encounter_runner.dart` (yeni) | Adımları sırayla yürütür; `combat` adımı Faz E maçına geçer; `BossDefeated` event'i akışı besler (§8.1). |
| `lib/content/encounters/ash_gate.dart` (yeni) | İlk encounter verisi. |
| `lib/content/dialogues/...` (yeni) | `DialogueNodeDef` verileri. |
| `lib/domain/scenario_effect.dart` (yeni) | `ScenarioEffect` (setFlag/giveResource/startCombat...). |
| `lib/overlays.dart` | Diyalog/seçim/zar overlay'leri — veriyi render eder, mantık içermez (§8.2, ilke: overlay komut gönderir). |
| `lib/domain/game_session.dart` | `ScenarioState`'i taşır; overlay'ler buna `ValueListenableBuilder`/`ChangeNotifier` ile bağlanır (§12). |
| `lib/game.dart` | `EncounterRunner` ↔ combat köprüsü; `GamePhase` + string overlay yönetimini runner'a devret (D6). |

### İskeletler (§8.1–8.4)
```dart
enum EncounterStepKind { dialogue, choice, diceCheck, combat, reward }
class EncounterDef { final String id, title; final List<EncounterStepDef> steps; ... }

class DiceCheckDef { final String id, stat; final int difficulty; final DiceFormula dice;
  final List<ScenarioEffect> onSuccess, onFailure; }
// ilk slice: 1d20 + stat >= difficulty

class ScenarioState { final Set<String> flags; final Map<String,int> stats, resources;
  final List<String> completedEncounters; }
```

## 4. Adım adım görevler

- [x] **G1 — ScenarioState + GameSession.** ✅ `domain/scenario_state.dart` (flags/stats/resources/completedEncounters); `GameSession.scenario` + `setFlag/giveResource/setStat/markEncounterCompleted` notify eder. Combat flag okur (boss `approached_silently`→`bossOpeningDelay`), diyalog node bilmez. Test: scenario_state_test (6).
- [x] **G2 — Seedli Rng + DiceService.** ✅ `core/rng.dart` (seedlenebilir); `domain/dice_service.dart` saf `roll(check, rng, statBonus)` (1d20+stat>=DC), statBonus çağırandan → DiceService saf. Test: dice_service_test (6).
- [x] **G3 — Encounter modeli + runner.** ✅ `domain/encounter.dart` (EncounterDef/Step sealed) + `app/flow/encounter_runner.dart`. Runner soyut `EncounterHost` üzerinden komut yollar (Flame'siz, FakeHost ile test); combat adımı→host.startCombat; win→ödül, loss→host.onCombatLost. Test: encounter_runner_test (4).
- [x] **G4 — Diyalog & seçim overlay'leri.** ✅ overlays.dart'a EncounterDialogue/Choice/Dice/Reward overlay'leri (pixel stil); mantık yok, game'e komut yollar (dialogueAdvance/choicePick/diceAdvance/rewardAdvance). main.dart overlayBuilderMap'e eklendi.
- [x] **G5 — Zar check (hikayede).** ✅ Seçim stealth statını belirler; DiceCheckStep 1d20+stealth>=12; başarı→`approached_silently`. Combat başlarken `NormalActionSystem(bossOpeningDelay: silent? 2.2:0)`; boss reset'te ilk idle'a eklenir → ilk saldırı gecikir. Parry/dodge math'ine DOKUNULMADI (§14).
- [x] **G6 — Combat sonucu → flag/reward.** ✅ win→update() köprüsü `onCombatResult(true)`→RewardStep efektleri (`boss_knight_1_defeated` + `honor+1`)→placeholder (menü). loss→`onCombatLost`→EndOverlay; YENİDEN→retryCombat. `BossDefeated` event'i yayılıyor.
- [x] **G7 — Ash Gate verisi.** ✅ `content/encounters/ash_gate.dart`: 2 satır diyalog + 3 seçim + 1 zar + Knight 1 (knight_1) combat + zafer ödülü, §15 akışına birebir.
- [x] **G8 — Test + analyze + duman.** ✅ 3 saf test grubu (16 birim) + tüm mevcut testler yeşil (157 toplam); analyze temiz. Test arena + normal maç ayrık ve sağlam (encounterActive=false yolu değişmedi). Elle `flutter run` duman testi kullanıcıda.

## 5. Kabul kriterleri
- Ash Gate encounter **uçtan uca oynanabiliyor**: menü → diyalog → seçim → zar → Knight 1 combat → win/loss → reward/flag → placeholder.
- Zar **yalnız hikaye/encounter sonucunu** etkiliyor; parry/dodge başarı oranına bağlı değil.
- Combat sonucu `BossDefeated` event'iyle akışı besliyor; flag/resource üretiliyor.
- `DiceService` seedli + saf test edilebiliyor; `ScenarioState` combat'tan bağımsız.
- `GamePhase`+string overlay yönetimi büyük ölçüde `EncounterRunner`'a devredildi (D6 çözülüyor).
- Test arena + normal maç bozulmadı.

## 6. Test planı
- `test/dice_service_test.dart`: sabit seed'de `1d20+stat` sonucu deterministik; DC sınırı (>=) doğru; onSuccess/onFailure efektleri.
- `test/encounter_runner_test.dart`: adım sırası; `combat` adımı sonucu akışı doğru dallandırır (win→reward, loss→retry); flag/resource efektleri uygulanır.
- `test/scenario_state_test.dart`: flag/resource mutasyonları; combat flag okuyabilir, diyalog node'u bilmez.
- Elle: Ash Gate baştan sona; zar başarısı boss agresifliğini geç başlatıyor mu; reward flag'i set ediliyor mu.

## 7. Riskler & geri alma
- **Risk:** Zarı combat becerisine bağlama dürtüsü (§14 yasak). **Önlem:** zar etkisi yalnız encounter flag'i + boss faz zamanlaması modifikatörü; parry/dodge math'ine dokunma.
- **Risk:** Overlay'e oyun mantığı sızması. **Önlem:** overlay komut yollar; runner/session uygular; overlay yalnız `ScenarioState` render eder.
- **Risk:** Akış orkestratöre yeniden gömülürse D6 geri gelir. **Önlem:** akış tek otorite = `EncounterRunner`.
- **Geri alma:** RPG katmanı ayrı giriş; sorun olursa normal maç (Faz E) doğrudan oynanabilir kalır.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter test test/dice_service_test.dart test/encounter_runner_test.dart
flutter run   # Ash Gate uçtan uca + test arena/normal maç bozulmamış
```
