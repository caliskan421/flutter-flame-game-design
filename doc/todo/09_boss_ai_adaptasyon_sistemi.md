# 09 — Boss AI & Adaptasyon / Aldatma Sistemi

> **Özet:** Boss zaten alışkanlık EMA'larıyla (`_parryHabit/_dodgeHabit/_attackHabit`)
> kombo seçimini ağırlıklandırıyor ve pressure loop'la baskı sürdürüyor. Ancak
> `feint` yalnız kozmetik, `delayed` hiç işlenmiyor, oyuncunun greed/recovery'sini
> okuyup punish etme yok ve adaptasyon yalnız kombo seçimine etki ediyor (gerçek
> zamanlı zihin oyunu zayıf). Bu dosya boss'u "okuyan ve aldatan" bir rakibe taşır.

## Mevcut Durum

- `_registerHabit` + EMA sönümü; `_pickCombo` bu EMA'lara göre tracking/anti-parry
  kombolarını öne çıkarır.
- `_decidePressure`: chain / reposition / retreat; faza göre agresiflik.
- `feint` beat: `_parrySuccess`/`_dodgeSuccess` içinde yalnız "ALDATMA" yazar,
  gerçek ceza yok.
- `delayed` profili `_resolveContact`'ta `normal` gibi davranıyor.
- Boss, oyuncunun **saldırı recovery'sini** veya guard break'ini okuyup punish etmiyor.

## Eksikler / Sorunlar

- Aldatma (feint) işlevsiz: erken basanı cezalandırmadığı için "tuzak" değil.
- `delayed` (değişken windup) yok → boss ritim kıramıyor, oyuncu metronom gibi parry'liyor.
- Adaptasyon yalnız kombo seçiminde; aynı kombo *içinde* anlık karar yok (örn.
  "oyuncu hep erken parry'liyor → bu beat'i feint'e çevir").
- Oyuncunun açıkları (heavy whiff recovery, guard break, boş dodge) cezalandırılmıyor.

## Eklenebilecekler (Tam Tasarım)

### Aldatmayı işlevsel kıl
- Feint beat'i: telegraf başlar ama vuruş gelmez; **erken savunan** oyuncu
  recovery'ye girer (kısa kilit / cooldown) → boss gerçek vuruşla bunu punish eder.
- Feint sıklığı `_parryHabit` ile artar (çok parry'leyene daha çok tuzak).

### Delayed (ritim kırma)
- `delayed` beat: windup'u runtime'da `±jitter` ile değiştir; sabit ritme alışan
  oyuncuyu kaçırt. Erken basış `punishesEarly` → recovery.

### Anlık (in-combo) adaptasyon
- Kombo sırasında oyuncunun son N cevabını izle; eğilime göre **bir sonraki beat'i**
  dinamik seç (feint'e çevir, guardBreak ekle, tracking'e geç). Şu an seçim yalnız
  kombo başında.

### Greed / recovery punish
- Oyuncu boss açık değilken saldırırsa (`05`'teki greed) boss recovery penceresini
  okuyup hızlı bir punish beat başlatır.
- Guard break (bkz. `02`) yiyince boss garanti punish yapar.

### Tempo/mesafe okuma
- Oyuncu sürekli geri dodge'luyorsa (mesafe açıyorsa) boss `reposition`/ranged ile
  mesafeyi kapatır; sürekli yapışıyorsa knockback'li beat seçer (bkz. `13`).

### Zorluk-ayarlı agresiflik
- AI agresifliği `14_zorluk_erisilebilirlik` ile ölçeklenebilir (tepki gecikmesi,
  feint sıklığı, punish hızı).

## Teknik Dokunulacak Alanlar

- `lib/boss.dart`
  - `_resolveContact`/`_tickPending`: `feint` ve `delayed` için gerçek erken-basış
    cezası (recovery'ye sok).
  - kombo *içinde* sonraki beat'i seçen bir ara katman (`_nextBeatAdaptive`).
  - `receivePlayerAttack`/yeni hook: oyuncu greed/guard-break punish.
  - `delayed` için windup jitter.
- `lib/characters.dart`: `feint`/`delayed` beat'lerini gerçek kombolara serpiştir.
- `lib/player.dart`: greed/recovery durumunun boss tarafından okunabilir olması
  (`isInAttackRecovery` gibi getter).
- `lib/game.dart` `CombatMetrics`: feint-baited, greed-punished sayaçları.

## Kabul Kriterleri

- Feint gerçek bir tuzak: erken savunanı cezalandırır, sıklığı oyuncuya uyarlanır.
- Delayed beat'ler ritmi kırar; metronom parry artık güvenli değil.
- Boss, oyuncunun greed/guard-break açıklarını cezalandırır.
- Adaptasyon kombo içinde de hissedilir (statik desen ezberlenemez).

## Bağlı Sistemler
- `03_parry_pencere_dinamigi` (erken basış cezası), `05` (greed),
  `02` (guard break punish), `08` (faz bazlı agresiflik), `14`, `16`.

## Öncelik
**Yüksek** — "tek doğru tuşu ezberleme" sorununu çözen ana sistem.
