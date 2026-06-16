# 02 — Oyuncu Blok / Guard Sistemi

> **Özet:** README'de savaşın dört direğinden biri "Savunma / Blok (Guard)" olarak
> tanımlanır ve "en son çare, cezalandırıcı" bir eylem olması istenir. Oyuncuda
> şu an **tutulan (hold) blok yok**: yalnız anlık parry, dodge ve saldırı var.
> Blok, parry'yi kaçıran oyuncuya "hayatta kal ama tempoyu kaybet" seçeneği sunar
> ve posture sisteminin asıl gerilimini yaratır. Bu dosya guard mekaniğini tasarlar.

## Mevcut Durum

- `Player` durumları: `idle, parry, counter, riposte, dodge, attack, hurt, stunned, dead`.
  **`block`/`guard` yok.**
- Parry anlık bir penceredir (`parryWindowDuration = 0.13s`); basılı tutma davranışı yok.
- Boss `_shieldLightBlock`/`_shieldHeavyPunish` yalnız **boss'un** kalkanını modeller
  (test guard modu); oyuncunun bloğu yok.
- Oyuncu posture (`posture = 100`) var ama yalnız yanlış-araç/blok cezasıyla düşer —
  oysa aktif bir blok kaynağı yok.

## Eksikler / Sorunlar

- Parry'yi kaçıran oyuncunun tek alternatifi tam isabet yemek; "güvenli ama pasif"
  ara seçenek yok.
- README'nin "düz blok → donuk metal sesi, geri itilme, posture dolar" hissi yok.
- Posture barı oyuncu için neredeyse hiç anlam taşımıyor.

## Eklenebilecekler (Tam Tasarım)

### Hold-block durumu
- Yeni durum: `PlayerState.block` (tuş basılı tutulurken aktif).
- Blokta gelen saldırı **HP yemez** ama:
  - oyuncu posture'ı doldurur (örn. light `+18`, heavy `+34`),
  - stamina tüketir (bkz. `01`),
  - karakter geriye itilir (knockback), donuk metalik ses çalar.
- Posture dolarsa oyuncu **guard break** → `getStunned` (zaten mevcut) ile sersemler;
  bu Sekiro'daki "denge bozulması" hissidir.

### Blok ↔ parry ilişkisi (timing affordance)
- Parry, "blok tuşuna doğru anda basma" olarak modellenebilir: blok tuşuna basışın
  ilk `0.13s`'i = perfect parry penceresi, sonrası = düz blok.
- Bu, tek tuşla "geç kalırsan blok, tam anında basarsan parry" hissini verir
  (Sekiro deflect mantığı). Alternatif: parry ve blok ayrı tuşlar kalsın.

### Yönlü blok
- `GuardDirection` zaten var (high/low/any). Blok da yönlü olabilir: yanlış yön
  bloğu HP'nin bir kısmını geçirir (chip damage) + daha çok posture doldurur.

### Guard break sonrası
- Oyuncu guard break yiyince boss'a garanti punish penceresi açılır → boss tarafı
  `receivePlayerAttack`/AI bunu okumalı (boss bir "açık punish" yapar).

## Teknik Dokunulacak Alanlar

- `lib/player.dart`
  - yeni `PlayerState.block`; `tryBlockStart`/`tryBlockEnd` (tuş down/up).
  - `takeHit` yerine blok aktifken `takeBlockedHit(beat)` yolu.
  - `breakPosture`/`getStunned` zaten var → guard break'e bağla.
- `lib/boss.dart` `_resolveContact`: oyuncu blok durumundaysa dalı ekle
  (parry/dodge'dan ayrı: blok → hasarsız ama posture+stamina maliyeti).
- `lib/input_settings.dart` + `ArenaInputAction`: `block` aksiyonu (basılı-tutma
  destekleyen bir binding; keydown/keyup ayrımı gerekebilir).
- `lib/game.dart` `_handleInputAction`: block aksiyonunun yönlendirilmesi.
- `lib/hud.dart`: oyuncu posture barının blok sırasında belirginleşmesi.
- `lib/audio.dart`: ayrışmış `block()` sesi (şu an `_parry` çalıyor, ayrı SFX iyi olur).

## Kabul Kriterleri

- Oyuncu saldırıyı bloklayabilir: HP korunur, posture dolar, stamina düşer.
- Posture dolunca oyuncu sersemler ve boss punish penceresi yakalar.
- Parry'nin değeri korunur: blok güvenli ama tempo/kaynak kaybettirir (pasif kalır).
- Blok sesi parry sesinden net biçimde ayrışır.

## Bağlı Sistemler
- `01_stamina_kaynak_sistemi`, `03_parry_pencere_dinamigi` (tek-tuş deflect varyantı),
  `11_game_feel_feedback_sistemi` (blok feedback'i), `09_boss_ai_adaptasyon_sistemi`
  (guard break punish).

## Öncelik
**Yüksek** — posture gerilimini ve "son çare" katmanını tamamlar.
