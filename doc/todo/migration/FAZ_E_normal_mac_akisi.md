# FAZ E — Normal Maç Akışı (gerçek/ölümlü mod)

> **Durum:** ⬜ Başlamadı
> **Bağımlılık:** **Faz A + B bitmiş olmalı.** C/D ile paralel gidebilir.
> **Tür:** Yeni davranış — ilk gerçek (ölümlü) maç. Test sandbox AYNEN korunur.
> **Referans:** `doc/architecture.md` §13 (Faz E), §2.3 (NormalActionSystem "hiçbir akış kullanmıyor"), §14 (test ≠ normal).

---

## 0. Tek cümle
`NormalActionSystem`'i gerçek bir maça bağla: boss seçimi → ölümlü combat → win/loss → retry/next; test arena (eğitim) modu hiç bozulmadan ayrı kalsın.

## 1. Neden
- `NormalActionSystem` tüm getter'ları override etmiş (`playerCanDie=true`, `bossCanDie=true`, knockback'ler vb. — normal_action_system.dart) **ama hiçbir akış onu kullanmıyor** (§2.3, doc/todo/10).
- Bugün her giriş `TestActionSystem`'e gidiyor (game.dart:62, `chooseTestAttack`, `startMovementMechanics`, `startCombatScenarioIntro`).

## 2. Kapsam

**DAHİL:**
- Mod seçimi: "Eğitim (test arena)" vs "Maç (normal)" girişini ayır.
- Normal modda `actionSystem = NormalActionSystem()` ile gerçek combat: oyuncu ve boss **ölebilir** (`playerCanDie/bossCanDie`).
- Boss seçimi (roster'dan: `kOpponents`) + maça başlama akışı.
- Win/Loss tespiti normal modda gerçek sonuca (HP 0) bağlı; `GamePhase.won/lost` + retry/next.
- Akışı `GameSession` (Faz A iskeleti) üzerinden tut: seçilen boss, sonuç.

**HARİÇ:**
- Tam EncounterRunner / diyalog / zar → Faz G. (Bu fazda **sadece combat akışı**: seç → dövüş → sonuç → tekrar/sonraki.)
- Save/load → Faz H.
- Test arena davranışını değiştirmek (dokunma).

## 3. Dokunulacak / eklenecek dosyalar

| Dosya | İş |
|---|---|
| `lib/game.dart` | Normal mod giriş yolu: `startNormalMatch(CharacterDef boss)` benzeri; `actionSystem = NormalActionSystem()`; win/loss → `won/lost`; `restart`/next. |
| `lib/overlays.dart` | Mod seçim ekranına "Maç (normal)" girişi; boss seçim overlay'i; win/loss ekranlarında retry/next. |
| `lib/normal_action_system.dart` | Gerekirse eksik getter'ları tamamla (gerçek maç dengesi); ama mevcut override'lar temel. |
| `lib/domain/game_session.dart` | Seçilen boss + maç sonucu + (varsa) sıradaki boss durumu. |
| `lib/characters.dart` | `kOpponentIds`/roster sırası (doc/todo/10) — normal modun boss listesi. |
| `test/` | Normal mod akış/kural testleri. |

## 4. Adım adım görevler

- [ ] **E1 — Giriş ayrımı.** Mod seçim ekranında iki net yol: **Eğitim (test arena, mevcut)** ve **Maç (normal)**. Mevcut test akışı (`chooseTestAttack`/`startMovementMechanics`/`startCombatScenarioIntro`) bozulmadan kalır.
- [ ] **E2 — Boss seçimi.** Normal modda `kOpponents`'tan boss seç (basit liste overlay'i yeter). Seçim `GameSession`'a yazılır.
- [ ] **E3 — Normal maç başlat.** `startNormalMatch(boss)`: `actionSystem = const NormalActionSystem()`; `Boss(boss)` kur; `phase = playing`. Sandbox bayrakları (ölümsüzlük/yerinde döngü) bu yolda **kapalı** (NormalActionSystem zaten `playerCanDie/bossCanDie=true`, `lockBossToBaseX=false` veriyor).
- [ ] **E4 — Win/Loss.** `update`'teki kazan/kaybet tespiti (game.dart:~881) normal modda gerçek HP'ye bağlı çalışsın: boss HP 0 → `won`; oyuncu HP 0 → `lost`. (Test sandbox'ta minHealth=1 koruması sürer.)
- [ ] **E5 — Sonuç akışı.** Won/Lost overlay'lerinde **retry** (aynı boss) + **next/menüye dön**. Sonuç `GameSession`'da tutulur (Faz G flag'lerine zemin).
- [ ] **E6 — Test + analyze + duman.** Normal modda boss ve oyuncu **gerçekten ölebiliyor**; test arena hâlâ ölümsüz/yerinde döngü; iki mod birbirine sızmıyor.

## 5. Kabul kriterleri
- Normal modda tam bir maç oynanabiliyor: seç → dövüş → win **veya** loss → retry/next.
- `NormalActionSystem` gerçekten kullanılıyor (önceki "kullanılmıyor" durumu çözüldü).
- **Test arena birebir korunuyor:** sınırsız stamina, ölümsüzlük, yerinde döngü, deterministik pratik (AI okuma/feint sandbox'ta kapalı — action_system_test:105 ile uyumlu).
- Win/loss `GamePhase` ile düzgün; takılma yok.

## 6. Test planı
- `test/normal_flow_test.dart`: NormalActionSystem'de `playerCanDie/bossCanDie=true`, minHealth=0; TestActionSystem(realMatch=false)'da minHealth=1 ve ölümsüzlük. (Mevcut `action_system_test.dart` ile çelişmez.)
- `test/`: boss seçiminin geçerli roster'dan geldiği; oyuncunun roster'da olmadığı (characters_test:46 deseni).
- Elle: normal maçta boss'u öldür (win), oyuncuyu öldürt (loss), retry ve next çalışır; test arena değişmemiş.

## 7. Riskler & geri alma
- **Risk:** Normal mod kuralları test sandbox'a sızar (ölümsüzlük kalkar). **Önlem:** mod seçimi `actionSystem`'i set eden **tek yer**; sandbox yolu `TestActionSystem` kalsın; testle iki modu ayrı doğrula.
- **Risk:** Win/loss tespiti her iki modda farklı eşik. **Önlem:** eşikler `actionSystem.minPlayerHealth/minBossHealth`'ten okunur (action_system.dart:17–18), hard-code edilmez.
- **Geri alma:** Normal mod ayrı giriş; sorun olursa o giriş gizlenir, test arena etkilenmez.

## 8. Doğrulama komutları
```bash
flutter analyze
flutter test
flutter run   # normal maç win+loss+retry; ardından test arena bozulmamış mı
```
