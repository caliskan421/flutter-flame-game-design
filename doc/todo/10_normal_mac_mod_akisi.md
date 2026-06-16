# 10 — Normal Maç / Arena Akışı

> **Özet:** `NormalActionSystem` yazılmış (gerçek knockback, ölüm, mesafe oyunu,
> serbest boss konumu) ama **hiçbir akış onu kullanmıyor**: oyun tamamen test
> arenası (`TestActionSystem`) üzerinden ilerliyor. Tam bir oyun için "gerçek maç"
> modunun bağlanması, boss seçim/ilerleme akışı ve kazan/kaybet döngüsünün bu mod
> üzerinden kurulması gerekir. Bu dosya savaş-mod kabuğunu tasarlar.

## Mevcut Durum

- `BossArenaGame.actionSystem` varsayılan `TestActionSystem`; tüm `chooseTestAttack*`
  akışları test modunu kuruyor.
- `NormalActionSystem` (`lib/normal_action_system.dart`) tanımlı: `playerCanDie`,
  gerçek knockback impulse'ları, `bossBasePosition` arenanın %74'ünde, serbest X,
  yürüyerek yaklaşma — ama **çağrılmıyor**.
- `kOpponentIds = ['knight_2','knight_3']` ve `kOpponents` tanımlı ama gerçek maç
  seçim akışına bağlı değil (test `kTestOpponent` = knight_1 kullanıyor).
- Faz akışı: `testSelect → intro → playing → won/lost` (hepsi test bağlamında).

## Eksikler / Sorunlar

- Gerçek (ölümlü, mesafeli, yürüyen boss) maç oynanamıyor.
- Boss seçimi / sıralı boss ilerleyişi (arena turnuvası) yok.
- Mesafe oyunu (`standGap`, approach/retreat) yalnız normal modda anlamlı ama mod kapalı.
- README'deki "SOL=oyuncu, SAĞ=boss" gerçek dövüş sahnesi yalnız test parametreleriyle çalışıyor.

## Eklenebilecekler (Tam Tasarım)

### Gerçek maç modu bağlama
- Menüde "Gerçek Maç" seçeneği → `actionSystem = NormalActionSystem()`.
- Boss yürüyerek yaklaşır (`bossStartsBeatInPlace=false`), serbest X, knockback aktif,
  her iki taraf ölebilir.
- `beginMatch`/`reset` akışlarının normal modu desteklemesi (zaten parametrik;
  yalnız `actionSystem` set edilmeli).

### Boss seçim & ilerleme
- Boss seçim ekranı (mevcut `testSelect` UI'ı temel alınabilir): `kOpponents` listesi.
- **Arena turu**: bir boss yenilince sıradakine geç; araya kısa dinlenme/iyileşme
  (bkz. `12`). Sonunda "tüm arena temizlendi" zaferi.
- Her boss için intro (mevcut `combatIntro` overlay yeniden kullanılabilir).

### Maç sonu döngüsü
- Win → sıradaki boss veya zafer ekranı; Lost → retry / arena başına dön.
- Skor/zaman/metrik özeti (bkz. `16`).

### Test ↔ Normal ayrımı
- Test modu eğitim/sandbox olarak korunur (ölümsüzlük, yerinde döngü).
- Normal mod gerçek kurallar. İkisi tek `ArenaActionSystem` arayüzü üzerinden;
  yeni özellikler (stamina/blok/status) iki modda da çalışmalı.

## Teknik Dokunulacak Alanlar

- `lib/game.dart`
  - normal mod başlatan akış: `startNormalMatch(CharacterDef boss)`.
  - boss ilerleme durumu (`currentBossIndex`), win → next.
  - `beginMatch`/`restart`/`backToModeSelect`'in normal modu da kapsaması.
- `lib/overlays.dart`: boss seçim ekranı, normal mod intro/win/lost varyantları.
- `lib/action_system.dart` + `NormalActionSystem`: yeni sistemlerin (stamina/blok)
  gerektirdiği ayar alanlarının normal mod değerleri.
- `lib/hud.dart`: normal modda mesafe/yaklaşma ipuçları (telegraflar zaten var).
- `lib/characters.dart`: gerçek maç roster düzeni (opponents + sıralama).

## Kabul Kriterleri

- Oyuncu gerçek (ölümlü, mesafeli) bir maç oynayabilir.
- Birden çok boss sırayla yenilebilir (arena ilerleyişi).
- Test modu eğitim aracı olarak bozulmadan kalır.
- Yeni savaş sistemleri her iki modda tutarlı çalışır.

## Bağlı Sistemler
- Tüm savaş sistemleri bu kabuğun içinde yaşar; özellikle `12` (turlar arası
  iyileşme), `13` (mesafe), `14` (zorluk), `15` (ilerleme/unlock), `16` (sonuç metrikleri).

## Öncelik
**Yüksek** — "oyun" olabilmenin kabuğu; test sandbox'ı tek başına oyun değil.
