# FAZ B — Event Yolu + Saf Kural (CombatResolver ilk dilim)

> **Durum:** ✅ Bitti — EventBus + CombatEvent + CombatPresenter; boss.dart'taki tüm Sfx/spawnPopup/metrics/request* çağrıları event yayımına çevrildi (combat karar yolunda 0 doğrudan çağrı). CombatResolver parry/dodge araç+pencere kararını saf veriyor. analyze temiz, 73 test yeşil (event_bus + combat_resolver + combat_presenter yeni testleri dahil).
> **Bağımlılık:** **Faz A bitmiş olmalı** (TimeFx/metrics ayrı).
> **Tür:** Refactor + altyapı — davranış DEĞİŞMEZ; kural saf test edilebilir hale gelir.
> **Referans:** `doc/architecture.md` §3 (vuruş yaşam döngüsü), §6.4–6.5 (CombatResolver/CombatEvent), §4 (D3/D4), §16 (ilke 6).

---

## 0. Tek cümle
Combat kararının **doğrudan** `Sfx`/`game.spawnPopup`/`game.metrics` çağırması yerine **`CombatEvent` yaymasını** sağla; bir `EventBus` üzerinden sunum (FX/ses/metrik) ve domain (flag) bu event'lere abone olsun. `_resolveContact` ailesinin saf çekirdeğini `CombatResolver`'a taşımaya başla.

## 1. Neden (darboğaz kanıtı)
- `boss.dart` içinde **20 adet `Sfx.` + 150 adet `game.*`** çağrısı var: kural ile sunum iç içe (D3).
- Combat sonucuna abone olunabilecek bir olay kanalı yok → RPG combat çıktısına tepki veremez (D4).
- `_resolveContact / _parrySuccess / _dodgeSuccess / _applyHit` (boss.dart) hem karar verir hem popup/ses çalar → saf test edilemez.

## 2. Kapsam

**DAHİL:**
- `lib/core/event_bus.dart`: minik senkron yayın/abone (`EventBus`).
- `lib/combat/rules/combat_event.dart`: `sealed class CombatEvent` + alt tipler (§6.5).
- `boss.dart`'taki **sunum çağrılarını event yayımına çevir**: karar noktası event yayar; bir `CombatPresenter` aboneliği `Sfx`/`spawnPopup`/`metrics`/`requestSlowmo`'yu çağırır. Davranış aynı, yol farklı.
- `CombatResolver`'ın ilk saf dilimi: parry/dodge **araç doğruluğu + pencere** kararını saf fonksiyona çek (player'da zaten saf olan `parrySucceeds`/`dodgeInvulnerableAt` ile birleştir), sonuç olarak `CombatEvent` listesi/karar nesnesi dönsün.

**HARİÇ (bu fazda YAPMA):**
- Tüm `boss.dart` mantığını resolver'a taşımak → Faz F. (Bu fazda yalnız **temas çözümünün çekirdeği** + event yolu.)
- ActionTimeline / PlayerMoveDef → Faz C.
- Yeni event tüketicisi olarak RPG/flag → Faz G (ama bus hazır olacak, domain abone olabilecek).

## 3. Dokunulacak / eklenecek dosyalar

| Dosya | İş |
|---|---|
| `lib/core/event_bus.dart` (yeni) | `EventBus`: `subscribe`, `emit`. Senkron, sıralı, basit. |
| `lib/combat/rules/combat_event.dart` (yeni) | `sealed class CombatEvent` + `DamageApplied`, `PostureBroken`, `ParrySucceeded(perfect)`, `DodgeSucceeded`, `Deathblow(lethal)`, `PhaseChanged(phase)`, `BossDefeated(bossId)`, `HitstopRequested`, `PopupRequested(...)`, `SparkRequested(...)`, `SfxRequested(name)`. |
| `lib/combat/rules/combat_resolver.dart` (yeni) | Saf: girdi (beat/defense profili, oyuncu durumu, zamanlamalar) → karar + `List<CombatEvent>`. `Sfx`/Flame çağırmaz. |
| `lib/presentation/combat_presenter.dart` (yeni) | `EventBus`'a abone; event → `Sfx`/`game.spawnX`/`game.metrics`/`timeFx.requestSlowmo`. Tüm sunum yan etkisi burada toplanır. |
| `lib/boss.dart` | Karar noktalarında doğrudan `Sfx`/`spawnPopup`/`metrics` yerine `bus.emit(...)`. Çekirdek karar `CombatResolver`'a delege. |
| `lib/game.dart` | `EventBus` örneğini kur, `CombatPresenter`'ı ona bağla, `boss`/`player`'a referansını ver. |

### CombatEvent iskeleti (referans)
```dart
sealed class CombatEvent { const CombatEvent(); }

class DamageApplied    extends CombatEvent { final int amount; final bool toBoss; const DamageApplied(this.amount, {required this.toBoss}); }
class PostureBroken    extends CombatEvent { const PostureBroken(); }
class ParrySucceeded   extends CombatEvent { final bool perfect; const ParrySucceeded({required this.perfect}); }
class DodgeSucceeded   extends CombatEvent { const DodgeSucceeded(); }
class Deathblow        extends CombatEvent { final bool lethal; const Deathblow({required this.lethal}); }
class PhaseChanged     extends CombatEvent { final int phase; const PhaseChanged(this.phase); }
class BossDefeated     extends CombatEvent { final String bossId; const BossDefeated(this.bossId); }
// Sunum tetikleyicileri (geçiş döneminde; ileride çoğu PostureBroken vb.'den türetilebilir):
class HitstopRequested extends CombatEvent { final double seconds; const HitstopRequested(this.seconds); }
class PopupRequested   extends CombatEvent { final String text; /* konum/renk/boyut */ const PopupRequested(this.text); }
class SfxRequested     extends CombatEvent { final String name; const SfxRequested(this.name); }
```
> `sealed` + `switch` ile tüketicide eksik dal derleme hatası verir → güvenli genişleme. İlk aşamada `PopupRequested`/`SfxRequested` gibi "sunum komutu" event'leri kabul; olgunlaşınca semantik event'lerden (ParrySucceeded → sound+popup) türetilir.

## 4. Adım adım görevler

- [ ] **B1 — EventBus.** `core/event_bus.dart`: `void emit(CombatEvent e)`, `void Function() subscribe(void Function(CombatEvent) handler)`. Senkron, FIFO, exception-safe (bir abone patlarsa diğerleri çalışsın). Birim testi yaz.
- [ ] **B2 — CombatEvent.** `combat/rules/combat_event.dart`: yukarıdaki sealed hiyerarşi.
- [ ] **B3 — CombatPresenter.** `presentation/combat_presenter.dart`: bus'a abone; her event tipini bugünkü `Sfx`/`spawnPopup`/`metrics`/slow-mo çağrısına eşle. **Mevcut davranışın tam kopyası** olmalı (hangi event hangi sesi/popup'ı/sayaç artışını tetikliyor — `boss.dart`'taki mevcut çağrılardan birebir çıkar).
- [ ] **B4 — Boss yayımına geçir (en kritik nokta).** `boss.dart`'taki şu noktaları event'e çevir (satırlar yaklaşık, kod değişmiş olabilir — gerçeği teyit et):
  - `_parrySuccess` (~1032): `Sfx.parryPerfect/parryLate` + `metrics.parrySuccesses++` + spark/popup → `bus.emit(ParrySucceeded(perfect: ...))`.
  - `breakPosture` (~274): `metrics.bossPostureBreaks++` + `spawnPostureBreak` + `Sfx.postureBreak` → `bus.emit(PostureBroken())`.
  - hasar uygulama (`_applyHit` benzeri, ~736–745, ~1019–1023): `metrics.bossDamageTaken += ...` + `Sfx.hit` + `-X` popup → `bus.emit(DamageApplied(...))`.
  - deathblow (~768–788) + faz geçişi (`_enterPhaseTransition` ~703–722): slow-mo/vignette/sfx → `Deathblow` / `PhaseChanged`.
  - feint sonucu (~935–949): `metrics.feintBaited++` + whiff/spark/popup → uygun event.
  > **Kural:** event yayıldıktan sonra sunum yalnız `CombatPresenter`'da olur; `boss.dart` artık `Sfx.`/`spawnPopup`/`metrics.` çağırmaz (mümkün olduğunca sıfıra indir, kalanları yorum + TODO ile işaretle).
- [ ] **B5 — CombatResolver ilk dilim.** Parry/dodge **araç+pencere** kararını saf fonksiyona çek: girdi = (beat defense profili, `sinceContact`, `effectiveParryWindow`, dodge i-frame durumu, guard yönü); çıktı = `ResolveOutcome { events, playerGetsHit, postureDamage, ... }`. `player.dart`'taki `parrySucceeds`/`dodgeInvulnerableAt`/`decayParryWindow` static fn'lerini bu resolver'dan **kullan** (taşıma değil, çağırma). `boss.dart` çözümü buna delege etsin.
- [ ] **B6 — Wiring.** `game.dart`: tek `EventBus` örneği; `CombatPresenter(bus, this)` kur; `boss`/`player`'a bus referansı geç (constructor veya `HasGameReference` üzerinden `game.bus`).
- [ ] **B7 — Test + analyze + duman.** Saf resolver için yeni test; mevcut testler yeşil; oyunda parry/dodge/hit/posture/deathblow/feint **ses+popup+slow-mo birebir** eskisi gibi.

## 5. Kabul kriterleri
- `boss.dart` içindeki doğrudan `Sfx.`/`game.spawnPopup`/`game.metrics` çağrıları **belirgin azalır** (hedef: combat karar yollarında ~0; kalanlar gerekçeli).
- Tüm combat sunumu tek noktadan (`CombatPresenter`) event'le besleniyor.
- `CombatResolver`'ın parry/dodge çekirdeği **Flame/Sfx olmadan** unit test ediliyor.
- Davranış birebir korunuyor (sesler, popup'lar, slow-mo, sayaçlar aynı).
- D3 ve D4 kavramsal olarak çözülmüş: combat kararı sunumu bilmiyor; domain de aynı bus'a abone olabilir.

## 6. Test planı
- `test/event_bus_test.dart`: emit/subscribe sırası, çoklu abone, abone-içi exception izolasyonu.
- `test/combat_resolver_test.dart`: doğru araç+zamanında → ParrySucceeded; yanlış araç/geç → DamageApplied/stun; dodge i-frame içi/dışı; guard yönü eşleşmesi. (Mevcut `combat_rules_test.dart` ile çelişmemeli; o testler hâlâ geçmeli.)
- Elle: parry (perfect/late sesi), late blok, posture break şoku, deathblow sineması, faz geçişi, feint "ALDATMA/TUZAK" popup'ı — hepsi eskisiyle aynı.

## 7. Riskler & geri alma
- **Risk:** Bir sunum çağrısını event'e çevirirken atlamak → ses/popup kaybolur. **Önlem:** B4'te `boss.dart`'taki 20 `Sfx.` + ilgili `spawnX`/`metrics` çağrısını **liste halinde** çıkar, her birini bir event'e eşle, tek tek işaretle.
- **Risk:** Senkron bus'ta abone içinde tekrar emit → yeniden giriş. **Önlem:** presenter yalnız sunum yapsın, yeni combat event'i yaymasın.
- **Risk:** Event sırası ses/slow-mo zamanlamasını kaydırır. **Önlem:** emit sırası mevcut çağrı sırasıyla aynı tutulur.
- **Geri alma:** Faz B'yi A'dan ayrı commit serisinde tut; sorun olursa resolver dilimini geri al, event yolunu koru (veya tümünü revert).

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter test test/combat_resolver_test.dart test/event_bus_test.dart
flutter run   # parry/dodge/posture/deathblow/feint ses+FX birebir mi?
```
