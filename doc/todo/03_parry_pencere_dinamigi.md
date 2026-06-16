# 03 — Parry Penceresi & Window Decay

> **Özet:** README, parry'nin kalbinin "kısa aktif kareler" ve **spam yapınca
> daralan pencere (window decay)** olduğunu söyler. Mevcut kodda parry penceresi
> sabittir ve spam'in gerçek cezası yoktur; `delayed` profili de uygulanmaz. Bu
> dosya parry penceresini Sekiro-vari hale getirir: spam cezası, perfect/late
> ayrımı, erken-basış (feint/delayed) cezası ve görsel/işitsel kontrast.

## Mevcut Durum

- `Player.parryWindowDuration = 0.13`, `lowParryWindowDuration = 0.18`,
  `parryCooldownDuration = 0.34` (sabit).
- Boss `_resolveContact`: `pressedParry = sinceParry <= beat.preWindow`; başarı
  `_guardMatches` ile. Pencere **daralmıyor**, spam serbest (yalnız cooldown sınırlar).
- `_freshPress = 0.045` ile temas-sonrası tolerans var (`_tickPending`).
- `DefenseProfile.delayed` ve `Beat.punishesEarly` **tanımlı ama
  `_resolveContact`'ta `normal` gibi** ele alınıyor → erken basış cezası yok.
- Perfect vs late parry ayrımı yok: pencere içindeyse hep "tam parry".

## Eksikler / Sorunlar

- Panik spam cezasız: oyuncu sürekli SPACE'e basıp şanslı parry yakalayabilir.
- `delayed` saldırılarda erken basanı cezalandırma yok → boss'un "ritim kırma"
  aracı işlevsiz.
- Tüm başarılı parry'ler eşit; "kıl payı kurtardım" ile "mükemmel zamanladım"
  arasında fark yok (juice eksik).

## Eklenebilecekler (Tam Tasarım)

### Window decay (spam aşınması)
- Her parry basışı kısa süre içinde tekrarlanırsa pencere küçülür:
  ```
  ardışık basış sayacı arttıkça parryWindow *= 0.7^(spamCount)
  basışlar arası > 0.5s ise sayaç sıfırlanır
  ```
- Spam sırasında daralan pencere HUD'da/karakterde görünür (parry halkası küçülür).

### Perfect / Late / Whiff ayrımı
- Pencerenin ilk ~%40'ı **perfect**: ekstra posture hasarı + tam hitstop + parlak
  sarı/turuncu spark + "ŞING".
- Geri kalan kısım **late/normal parry**: daha tok ses, az posture, hitstop yok.
- Pencere dışı + cooldown'a takılı basış **whiff**: kısa kilit/recovery (panik cezası).

### Erken-basış cezası (feint & delayed)
- `delayed` beat: windup süresi değişken; pencereden önce basan oyuncu
  recovery'ye düşer (kısa kilit) → boss devam eder.
- `feint` beat: hiç vuruş yok; erken parry/dodge basışı boşa düşer ve cooldown'a sokar.
- Bunun için `_resolveContact`'a `delayed` ve `feint` için "erken basış" dalları eklenmeli.

### İşitsel/görsel kontrast (README "Altın Kural 2")
- Perfect parry, late parry, blok ve düz vuruş **birbirinden net ayrı** ses/efekt
  almalı → oyuncu gözü kapalı dövüşü anlayabilmeli.

## Teknik Dokunulacak Alanlar

- `lib/player.dart`
  - `tryParry` içinde spam sayacı + dinamik `_parryWindowMax`.
  - parry sonucunu perfect/late ayıran bir alan (`lastParryQuality`).
  - whiff/erken-basış için kısa recovery durumu.
- `lib/boss.dart`
  - `_resolveContact` ve `_tickPending`: `delayed`/`feint` erken basış dalları;
    perfect/late'e göre `applyPostureDamage` ve hitstop farkı.
  - `_parrySuccess`: kaliteye göre popup/spark/ses.
- `lib/characters.dart`: `delayed` beat'leri gerçek karakter kombolarına ekle
  (şu an havuzda kullanılmıyor).
- `lib/audio.dart`: `parryPerfect()` / `parryLate()` ayrı SFX.
- `lib/fx.dart`: perfect parry için daha büyük/parlak spark varyantı.

## Kabul Kriterleri

- SPACE spam'i artık pencereyi daraltır ve sonunda cezalandırır.
- Perfect parry, late parry'den ölçülebilir biçimde daha ödüllü (posture + juice).
- `delayed`/`feint` beat'lerde erken basan oyuncu cezalanır; doğru bekleyen ödüllenir.
- Mevcut deterministik testler güncellenip geçer.

## Bağlı Sistemler
- `01` (perfect parry stamina iadesi), `02` (tek-tuş deflect varyantı),
  `09_boss_ai_adaptasyon_sistemi` (feint/delayed AI kullanımı),
  `11_game_feel_feedback_sistemi` (kontrast).

## Öncelik
**Yüksek** — parry oyunun çekirdek fiili; derinliği buradan gelir.
