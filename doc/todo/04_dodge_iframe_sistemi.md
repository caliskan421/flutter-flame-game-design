# 04 — Dodge, i-Frame ve Mikiri Counter

> **Özet:** README dodge'u "i-frame'li sıyrılma" ve "parry edilemeyen saldırıların
> panzehiri" olarak tanımlar; Sekiro'nun Mikiri Counter'ına denk bir özel karşılık
> önerir. Mevcut dodge **gerçek i-frame** taşımaz (beat çözümünde `sinceDodge<=dodgePre`
> ile değerlendirilir), yönlü değildir ve recovery hissi zayıftır. Bu dosya dodge'u
> derinleştirir: gerçek dokunulmazlık penceresi, perfect dodge ödülü, yön ve mikiri.

## Mevcut Durum

- `Player.dodgeWindowDuration = 0.20`, `dodgeCooldownDuration = 0.42`.
- Boss `_resolveContact`: dodge başarısı `p.sinceDodge <= beat.dodgePre` ile;
  `guardBreak` → dodge doğru, `tracking` → dodge yakalanır (`KAÇILMAZ`).
- `punishOnDodge=true` (ağır/committed) beat dodge'lanınca `offBalance` (punish) açılır;
  hafifte yalnız "SIYRILDIN".
- Görsel: `_dodgeVisualOffset` ile yana kayma + streak; ses `Sfx.dodge`.

## Eksikler / Sorunlar

- **Genel i-frame yok:** dodge yalnız çözülmekte olan beat'e karşı işe yarar; eşzamanlı
  ikinci bir hitbox/mermi modeli yok (tek beat akışı olduğu için şimdilik sorun değil
  ama çoklu mermi/AOE eklenince kritik olur).
- **Yön yok:** ileri/geri/yana dodge ayrımı yok; pozisyon oyununa katkısı sınırlı.
- **Perfect dodge ödülü zayıf:** yalnız `offBalance`; "tam anında sıyrıldım → slow-mo
  punish" hissi yok.
- **Mikiri yok:** thrust/delici saldırıya basıp-üstüne-basma tarzı özel karşılık yok
  (guardBreak+dodge bunun yerini kısmen tutuyor ama jenerik).
- **Recovery hissi az:** README "sıyrılma sonrası kısa duraksama" ister; mevcut
  `_dodgeDur` küçük, ardışık atılma serbest (stamina yok → `01` ile bağlanmalı).

## Eklenebilecekler (Tam Tasarım)

### Gerçek i-frame penceresi
- Dodge animasyonunun ortasında net bir `invulnFrom..invulnTo` aralığı tanımla.
- Bu aralıkta **her** hasar kaynağı (melee beat, mermi, AOE) geçersiz.
- Aralık dışında dodge başlamış olsa bile saldırı isabet eder (greed cezası).

### Perfect dodge (just-dodge)
- i-frame aralığının ilk ~6 frame'i "perfect": kısa **slow-mo / hitstop** + boss'ta
  daha uzun `offBalance` + tempo penceresi.
- Geç dodge: yalnız hayatta kalma, punish yok (mevcut "SIYRILDIN" hissi).

### Yönlü dodge
- Geri dodge (mesafe aç), yana/içeri dodge (boss arkasına geç → backstab fırsatı,
  bkz. `13_konum_mesafe_sistemi`).
- Yön girdisi yoksa varsayılan geri-dodge.

### Mikiri-tarzı counter
- Yeni `DefenseProfile.thrust` (delici): doğru anda **ileri-dodge/aşağı-bas** ile
  bastırılır → boss anında büyük açık. Yanlış cevap (parry) cezalandırılır.
- Telegraf: kırmızıdan ayrı bir sembol (örn. mor/ok işareti) ile okunabilir olmalı.

## Teknik Dokunulacak Alanlar

- `lib/player.dart`
  - dodge state'ine `invulnFrom/invulnTo` ve `isInvulnerable` getter.
  - perfect dodge tespiti + tempo verme.
  - yön parametresi (`tryDodge(DodgeDir dir)`).
- `lib/boss.dart`
  - `_resolveContact`/`_tickPending`: i-frame'i hasar uygulamadan önce kontrol et.
  - perfect dodge'a daha uzun `punishWindow`.
  - `thrust` profili için yeni dal + telegraf.
- `lib/characters.dart`: `DefenseProfile.thrust` ekle; bazı kombolara thrust beat'i.
- `lib/projectile.dart`: i-frame sırasında mermi temasının geçersiz sayılması.
- `lib/fx.dart`: afterimage/dust trail (perfect dodge için belirgin).
- `lib/input_settings.dart`: yönlü dodge için ek binding (opsiyonel).

## Kabul Kriterleri

- Dodge gerçek bir dokunulmazlık penceresi taşır; pencere dışı greed cezalanır.
- Perfect dodge net bir ödül (slow-mo + punish) verir; geç dodge yalnız kurtarır.
- Mikiri/thrust karşılığı çalışır ve telegrafı kırmızıdan ayrışır.
- Stamina (`01`) ile birlikte ardışık dodge spam'i sınırlanır.

## Bağlı Sistemler
- `01_stamina_kaynak_sistemi`, `03_parry_pencere_dinamigi`,
  `13_konum_mesafe_sistemi` (backstab), `11_game_feel_feedback_sistemi` (afterimage,
  slow-mo).

## Öncelik
**Orta-Yüksek** — parry derinleştikten sonra ikinci savunma katmanını tamamlar.
