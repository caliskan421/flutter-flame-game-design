# FAZ G — RPG Dikey Kesit (Scenario / Encounter / Dialogue / Choice / Dice)

> **Durum:** ⬜ Başlamadı
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

- [ ] **G1 — ScenarioState + GameSession.** `ScenarioState`'i `GameSession`'a koy; `ChangeNotifier` ile değişiklik yayını. Combat bu flag'leri **okuyabilir** ama diyalog node'unu bilmez (§8.4 sınırı).
- [ ] **G2 — Seedli Rng + DiceService.** `core/rng.dart` tek seedli kaynak; `DiceService.roll(check, rng)` saf. UI yalnız sonucu animasyonla gösterir.
- [ ] **G3 — Encounter modeli + runner.** `EncounterDef`/`EncounterStepDef`/`EncounterRunner`. Runner adımları sırayla yürütür; `combat` adımında Faz E normal maçına geçer; maç biter bitmez `BossDefeated`/loss event'iyle akışa döner.
- [ ] **G4 — Diyalog & seçim overlay'leri.** `DialogueNodeDef`/`ChoiceDef`'i render eden overlay'ler; **mantık overlay'de değil** — overlay komut yollar, runner/session uygular (§14, ilke). `CombatIntroOverlay`'in Faz A'da veriye taşınan cue'larıyla aynı desen.
- [ ] **G5 — Zar check (hikayede).** Bir seçim `DiceCheckDef` tetikler; `1d20 + stat >= DC`. Başarı → bir flag set (`approached_silently`) → combat başlarken boss ilk fazda **daha geç agresifleşir** (boss/`ArenaActionSystem` parametresine ufak modifikatör; parry/dodge oranına dokunma).
- [ ] **G6 — Combat sonucu → flag/reward.** Maç win → `ScenarioEffect`: `boss_knight_1_defeated` flag + `honor +1` resource; reward adımı anlatısı; sonraki encounter placeholder. Loss → retry/menü (Faz E).
- [ ] **G7 — Ash Gate verisi.** `content/encounters/ash_gate.dart`: diyalog + 2-3 seçim + 1 zar + Knight 1 combat + reward, §15 akışına birebir.
- [ ] **G8 — Test + analyze + duman.** DiceService saf test; encounter akışı uçtan uca oynanır; test arena ve normal maç (Faz E) hâlâ ayrı ve sağlam.

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
