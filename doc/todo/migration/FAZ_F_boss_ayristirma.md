# FAZ F — `boss.dart` Ayrıştırma (God object'i böl)

> **Durum:** 🟡 Kısmi — F1 (PostureSystem), F2 (BossBrain), F6 (BossView) bitti; F3/F4/F5/F7 (bağlı çekirdek) kaldı. boss.dart 1681→1442 sat, analyze temiz, 141 test yeşil.
> **Bağımlılık:** **Faz B şart** (resolver + event yolu). C/D bitmiş olması `boss_view` ayrımını çok kolaylaştırır (önerilen: C/D sonrası).
> **Tür:** Saf refactor — davranış DEĞİŞMEZ. En büyük dosya tek tek bölünür.
> **Referans:** `doc/architecture.md` §9 (ayrıştırma haritası — bu fazın ana planı), §4 (D1), §10 (klasör).

---

## 0. Tek cümle
`boss.dart` (1627 satır) içindeki AI, kural, state machine, posture, deathblow ve render sorumluluklarını ayrı saf/odaklı birimlere taşı; `boss.dart` bunları koordine eden **~500 satırlık ince component** olarak kalsın.

## 1. Neden
- `boss.dart` 1627 satır: state machine + AI + kurallar + sunum + ses bir arada (D1). Her yeni boss özelliği bu dosyayı şişiriyor, regresyon riski yüksek.
- Faz B event yolu açtıktan sonra parçaları çıkarmak güvenli: ayrıştırılan birimler `Sfx`/`spawnPopup` çağırmaz, `CombatEvent` döner/yayar.

## 2. Kapsam (architecture.md §9 haritası birebir)

**DAHİL — çıkarılacak birimler:**

| Yeni birim | Taşınacak mevcut kod (boss.dart) | Tür |
|---|---|---|
| `combat/ai/boss_brain.dart` | `_pickCombo` (~528), `_adaptBeat` (~582), `_parryHabit/_dodgeHabit/_attackHabit` (~135,300), `_registerHabit` (~375), greed/guard-break karar mantığı | Saf Dart |
| `combat/rules/combat_resolver.dart` (Faz B'de başladı) | `_resolveContact`, `_tickPending` (~339), `_resolveFeint` (~935), `_guardMatches`, `_iFrameBeats`, `_parrySuccess` (~1032), `_dodgeSuccess`, `_applyHit` | Saf Dart → `CombatEvent` |
| `combat/sim/boss_state_machine.dart` | `_machine` (~386), `_enter` (~247), `_startBeat` (~559), `_beginNewCombo` (~512), `_endCombo` (~611), `_decidePressure` (~643) | Mantık + timer |
| `combat/sim/posture_system.dart` | `posture`/`displayPosture` (~61,297), `applyPostureDamage` (~267), `breakPosture` (~274), regen (`postureRegen`,~64,335) | Saf Dart |
| `combat/sim/deathblow_controller.dart` | `_performDeathblow`, `_resolveDeathblowImpact` (~372), `_maybePhaseTransition` (~688), `_enterPhaseTransition` (~703) | Mantık + event |
| `presentation/boss_view.dart` | `_frameFor`/`_frameFor`-benzeri render, `render`, `_renderTelegraph`, `_renderOpenMarker`, `phaseLabelTr` | Flame/Canvas |
| `boss.dart` (kalan) | Yukarıdakileri koordine eden ince component | Flame |

**HARİÇ:**
- Davranış değiştirmek / dengeyi ayarlamak (saf taşıma).
- `player.dart` ayrıştırması (bu hafif; static kural fn'leri zaten ayrık → istenirse `combat/rules/parry_rules.dart`'a, ayrı küçük iş).
- Yeni özellik.

## 3. Strateji (önemli — tek seferde değil)
Her birim **ayrı, küçük, derlenir-test-geçer commit** olarak çıkarılır. Önerilen sıra (en bağımsızdan en bağlıya):
1. `posture_system.dart` (en izole)
2. `boss_brain.dart` (saf AI; `Rng` enjekte edilebilir — seedli test)
3. `combat_resolver.dart` tamamlama (Faz B dilimini genişlet)
4. `deathblow_controller.dart`
5. `boss_state_machine.dart`
6. `boss_view.dart` (render ayrımı — C/D bittiyse en temizi)

## 4. Adım adım görevler

- [x] **F1 — PostureSystem.** ✅ `posture`/`displayPosture`/`maxPosture` artık boss'ta getter; durum+kurallar `lib/combat/sim/posture_system.dart`'ta (saf). `applyPostureDamage` → `_posture.applyDamage(...)` "kırıldı mı?" döner; kırılma EFEKTLERİ + `staggered` geçişi boss'ta kaldı (tek-yön). `forceFull`/`reset`/`tickRegen`/`tickDisplay` delege. Test: `test/posture_system_test.dart` (10).
- [x] **F2 — BossBrain.** ✅ `_pickCombo`/`_adaptBeat`/habit EMA/greed kararı → `lib/combat/ai/boss_brain.dart` (saf, yalnız `characters.dart`). **Rng enjekte:** boss tek `_rng`'i paylaşır, brain metodlarına param geçer → global çağrı sırası birebir; testte seedli `Random`. `adaptBeat` `BeatAdaptation?` döner (override + nonFeint azalt). guardBreak punish olasılıksız olduğundan boss'ta kaldı. Test: `test/boss_brain_test.dart` (12, seedli). NOT: action-system ayarları param olarak veriliyor (inComboAdaptChance/greedPunishChance).
- [ ] **F3 — CombatResolver tamamla.** Faz B'de başlayan resolver'a `_resolveFeint`/`_guardMatches`/`_iFrameBeats`/`_tickPending` çekirdeğini taşı; hepsi `CombatEvent` üretir, `Sfx`/`spawnPopup` çağırmaz.
- [ ] **F4 — DeathblowController.** `_performDeathblow`/`_resolveDeathblowImpact`/faz geçişi mantığını taşı; `Deathblow`/`PhaseChanged` event'leri yayar; slow-mo/vignette/sfx presenter'da.
- [ ] **F5 — BossStateMachine.** `_machine`/`_enter`/`_startBeat`/`_beginNewCombo`/`_endCombo`/`_decidePressure`'ı taşı; brain + resolver + posture + deathblow'u koordine et. Timer/state burada.
- [x] **F6 — BossView.** ✅ `_frameFor`/`render`/`_renderTelegraph`/`_renderOpenMarker`/`phaseLabelTr` → `lib/presentation/boss_view.dart`. View yalnız boss'u salt-okunur getter'larla (sprites/t/hurtT/timer/deathT/deathFrameTime/phaseTransitionHurtHold + mevcut public) okur, durumu değiştirmez. `Boss.render` (@override) ve `phaseLabelTr` delege eder. `AnimationBinding` (Faz D) view'da çözülür.
- [ ] **F7 — boss.dart ince component.** (Kalan) Hedef ~500 satır. Şu an 1442; F3/F4/F5 bağlı çekirdek çıkmadan ulaşılmaz.
- [ ] **F8 — Her adımda test + analyze + duman.** (Kısmen) F1/F2/F6 sonrası analyze temiz, 141 test yeşil; davranış-koruma yapısal incelemeyle doğrulandı. Elle duman testi kullanıcıya kaldı.

> **Kalan bağlı çekirdek (sonraki artış):** F3 (`_resolveFeint`/`_guardMatches`/`_iFrameBeats`/`_tickPending` → resolver), F4 (`_performDeathblow`/`_resolveDeathblowImpact`/faz geçişi → deathblow_controller), F5 (`_machine`/`_enter`/`_startBeat`/`_beginNewCombo`/`_endCombo`/`_decidePressure` → state machine). Bunlar ~30 ortak `_`-alan paylaşır; davranış-koruyan çıkarım için ya alanları açmak ya `part of` ile aynı kütüphanede bölmek gerekir — ayrı, dikkatli oturum.

## 5. Kabul kriterleri
- `boss.dart` ~500 satıra iner; AI/kural/posture/deathblow/render ayrı dosyalarda.
- Ayrıştırılan birimler **`Sfx`/`spawnPopup` çağırmaz** — event döner/yayar (00_INDEX §3 kural 5).
- `BossBrain` ve `PostureSystem` **Flame olmadan** unit test edilebilir; AI seedli Rng ile deterministik.
- Davranış birebir korunuyor: aynı kombo seçimi (aynı seed'de), aynı posture/deathblow/faz davranışı.
- Tüm mevcut testler + yeni birim testleri yeşil.

## 6. Test planı
- `test/posture_system_test.dart`: hasar→break eşiği, regen gecikmesi, clamp.
- `test/boss_brain_test.dart`: sabit seed'de `_pickCombo` belirli kombo döner; habit yükselince tracking/anti-parry ağırlığı artar (boss.dart:544–545 mantığı); greed/guardBreak kararları.
- `test/combat_resolver_test.dart` (Faz B'den genişler): feint/guard/iframe çözümleri.
- Mevcut `combat_rules_test.dart`/`action_system_test.dart` yeşil.
- Elle: bir normal maç boyunca AI/posture/deathblow/faz hissi eskisiyle aynı.

## 7. Riskler & geri alma
- **Risk:** State machine ↔ brain ↔ resolver arası gizli paylaşılan alanları taşırken bozmak. **Önlem:** birim birim çıkar, her adımda test; paylaşılan state'i açık parametre/dönüş değerine çevir.
- **Risk:** Rng kaynağını değiştirince AI deseni kayar. **Önlem:** mevcut rastgelelik çağrı sırasını koru; seedli `Rng` ile golden test.
- **Risk:** Render ayrımı görsel kayma. **Önlem:** `boss_view`'ı en son, C/D sonrası çıkar.
- **Geri alma:** her birim ayrı commit → tek tek revert mümkün.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
wc -l lib/boss.dart           # ~500 hedefi
flutter run                   # AI/posture/deathblow/faz birebir mi
```
