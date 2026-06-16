# Combat Redesign Phase Plan

Bu dokuman, mevcut boss parry arena prototipini daha akici, risk/odul dengesi daha guclu ve uzun sure oynanabilir bir combat sistemine donusturmek icin sirali uygulama planidir.

Ana hedef: Oyuncunun `parry`, `dodge` ve `attack` araclarini ayri ayri dogru cevaplar gibi degil, birbirini besleyen bir dovus zinciri olarak kullanmasi.

## Mevcut Sistem Ozeti

Mevcut sistem `Beat` tabanli calisir. Her boss, `characters.dart` icinde tanimlanan sabit bir kombo desenini oynatir. `boss.dart` icindeki state machine su akisi izler:

```text
idle -> approach -> windup -> active -> recover -> gap
     -> endCombo -> staggered veya retreat -> idle
```

Savunma cozumlemesi `active` temas aninda yapilir:

```text
sinceParry <= beat.preWindow  -> parry basarili
sinceDodge <= beat.dodgePre   -> dodge basarili
aksi halde grace beklenir
grace de gecerse oyuncu hasar alir
```

Mevcut risk/odul problemi:

- Dodge penceresi parry'den daha genistir.
- Basarili dodge hemen `offBalance` acar.
- `offBalance` sirasinda `F` ile garanti hasar verilir.
- Tam parry zinciri boss'a otomatik hasar verir.
- Oyuncu saldirisi sadece boss acikken anlamlidir.
- Erken veya rastgele parry basmanin gercek cezasi yoktur.

Sonuc: Oyuncu, combat araclarini kombine etmek yerine en guvenli yol olan `dodge -> F` dongusune yonelir.

## Tasarim Ilkeleri

1. Boss HP hasari oyuncunun aktif saldirisindan gelmelidir.
2. Parry otomatik can azaltmamalidir; tempo, posture ve firsat uretmelidir.
3. Dodge hayatta kalma ve pozisyon aracidir; her zaman punish acmamalidir.
4. Saldiri riskli bir karar olmalidir; whiff ve greed cezalandirilmalidir.
5. Boss her combo sonunda eski yerine donmemelidir; baskiyi ve mesafe oyununu surdurmelidir.
6. Oyuncu tek bir dogru tusu ezberlememeli; boss'un saldiri tipini, ritmini ve mesafesini okumalidir.
7. Sistem once oynanis hissini duzeltmeli, sonra gorsel/efekt cilasina gidilmelidir.

## Faz 0 - Hemen Hissedilen Rebalance

### Amac

Mevcut mimariyi cok bozmadan `dodge -> F` spam'ini zayiflatmak ve parry'nin degerini artirmak.

Bu faz kalici nihai tasarim degil, yon duzeltme fazidir.

### Yapilacaklar

- `Boss._dodgeSuccess` davranisini degistir.
- Her basarili dodge artik otomatik `offBalance` acmayacak.
- `offBalance` sadece agir veya yuksek commitment saldirilarda acilacak.
- Hafif saldirilar dodge edilince boss komboya devam edebilecek.
- Tam parry sonunda otomatik HP hasari azaltilacak veya gecici olarak kaldirilacak.
- Parry basarisi oyuncuya daha belirgin tempo hissi verecek.
- `F` saldirisi boss acik degilken animasyon oynatmaya devam edecek, ancak whiff/recovery hissi daha net olacak.

### Teknik Dokunulacak Alanlar

- `lib/boss.dart`
  - `_dodgeSuccess`
  - `_parrySuccess`
  - `_endCombo`
  - `takePunish`
- `lib/game.dart`
  - `tryPlayerAttack`
- `lib/characters.dart`
  - `BeatKind.meleeHeavy` ve `BeatKind.meleeLight` ayrimina gore dodge odulu.

### Onerilen Kural

```text
light attack dodge  -> hasar yok, boss komboya devam eder
heavy attack dodge  -> kisa punish penceresi
feint dodge         -> hic odul yok
perfect parry chain -> boss posture/denge kirilmaya yaklasir, otomatik HP hasari yok
```

### Kabul Kriterleri

- Oyuncu sadece dodge spam yaparak boss'u kolayca bitirememeli.
- Parry yapmak hasar vermese bile oyuncuya daha iyi tempo hissi vermeli.
- Dodge hala degerli kalmali ama ana hasar uretim yolu olmamali.
- Mevcut testler gecmeli.

### Riskler

- Dodge bir anda cok zayif hissedebilir.
- Parry otomatik hasari kaldirilinca oyuncu "neden parry yapiyorum?" hissine dusebilir.
- Bu nedenle Faz 1'e hizli gecis planlanmali.

## Faz 1 - Denge/Posture Sistemi

### Amac

Combat'in omurgasini kurmak: Parry, boss'un dengesini bozar; denge kirilinca oyuncu aktif saldiriyla gercek hasari verir.

Bu faz, oyunun "gercek combat" hissine gecisidir.

### Yeni Kavramlar

```text
Boss HP       -> boss'un cani
Boss posture  -> parry, heavy attack ve ozel punish ile dolan/kirilan denge
Player stamina -> dodge, heavy attack ve panic aksiyonlari sinirlayan kaynak
Player tempo  -> basarili parry/dodge sonrasi kisa saldiri avantaji
```

### Yapilacaklar

- Boss'a `posture` ve `maxPosture` ekle.
- Parry HP hasari vermek yerine posture hasari verecek.
- Heavy saldirilar posture'a daha fazla etki edecek.
- Boss posture kirilinca `staggered` state'ine girecek.
- `staggered` sirasinda oyuncu `F` veya heavy attack ile gercek HP hasari verecek.
- Posture zamanla azalabilir veya boss recover sirasinda toparlanabilir.
- HUD'a boss posture bar eklenecek.
- Oyuncuya stamina eklenecek.
- Dodge stamina harcayacak.
- Stamina dusukken dodge mesafesi veya guvenligi azalacak.

### Teknik Dokunulacak Alanlar

- `lib/boss.dart`
  - `health` yanina `posture`, `maxPosture`
  - `_parrySuccess`
  - `_dodgeSuccess`
  - `_endCombo`
  - `takePunish`
  - yeni `applyPostureDamage`
  - yeni `breakPosture`
- `lib/player.dart`
  - `stamina`
  - `displayStamina`
  - dodge cost
  - attack cost
  - stamina regen
- `lib/hud.dart`
  - boss posture bar
  - player stamina bar
- `lib/characters.dart`
  - beat bazli posture degerleri.

### Onerilen Ilk Degerler

```text
boss maxPosture: 100
light parry posture damage: 18
heavy parry posture damage: 30
feint parry posture damage: 0
player light attack posture damage: 8
player heavy attack posture damage: 22
posture break duration: 1.1s
dodge stamina cost: 25
heavy attack stamina cost: 35
stamina max: 100
stamina regen: 22/s
```

### Kabul Kriterleri

- Boss'un cani, oyuncu saldirmadan anlamli sekilde azalmamali.
- Parry yapan oyuncu boss'u posture break'e goturebilmeli.
- Dodge yapan oyuncu hayatta kalabilmeli ama tek basina ana hasar uretmemeli.
- Oyuncu stamina'yi hesaba katmadan dodge spam yaptiginda zayif dusmeli.
- Boss posture kirilinca saldiri yapmak tatmin edici hissettirmeli.

### Riskler

- Posture cok cabuk kirilirsa oyun yine tek ritme doner.
- Posture cok yavas kirilirsa parry anlamsiz hissedilir.
- Stamina cok sert olursa oyuncu kendini kisitlanmis hisseder.

## Faz 2 - Oyuncu Saldiri Sistemi

### Amac

Oyuncuyu pasif savunma oyuncusundan aktif dovuscuye cevirmek. Hasar vermek sadece acik pencere yakalamak degil, riskli bir karar olmali.

### Yapilacaklar

- Tek `F` saldirisini genislet.
- Hafif saldiri ekle.
- Agir saldiri ekle.
- Parry sonrasi hizli counter avantaji ekle.
- Dodge sonrasi sadece uygun saldirilarda bonus counter ekle.
- Whiff recovery ekle.
- Boss acik degilken saldirmak tamamen bos olmamali; posture'a az etki edebilir ama riskli olmali.

### Onerilen Kontroller

```text
F              -> light attack
G veya hold F  -> heavy attack
SPACE          -> parry
SHIFT          -> dodge
```

### Saldiri Tipleri

```text
light attack
- hizli
- dusuk HP hasari
- dusuk posture hasari
- recovery kisa
- parry sonrasi daha guclu

heavy attack
- yavas
- yuksek HP/posture hasari
- stamina harcar
- whiff ederse boss punish edebilir
- posture break sirasinda ana hasar araci
```

### Teknik Dokunulacak Alanlar

- `lib/player.dart`
  - `PlayerState.attack` ayrilabilir: `lightAttack`, `heavyAttack`
  - attack windup/active/recover ayrimi
  - stamina cost
  - whiff lock
- `lib/game.dart`
  - `tryPlayerAttack`
  - yeni `tryPlayerHeavyAttack`
  - key input
- `lib/boss.dart`
  - boss'a oyuncu saldirisi isabet kontrolu
  - posture/HP hasari ayrimi.

### Kabul Kriterleri

- Oyuncu boss acikken hangi saldiriyi kullanacagina karar vermeli.
- Light attack guvenli, heavy attack tatmin edici ama riskli olmali.
- Savunma basarisi saldiriya donusmedikce boss HP'si hizla erimemeli.
- Whiff saldiri oyuncuya gercek risk hissettirmeli.

### Riskler

- Cok fazla tus erken asamada kontrol karmasasi yaratabilir.
- Heavy attack fazla guclu olursa posture sistemi baypas edilebilir.
- Light attack fazla guvenliyse spam dogabilir.

## Faz 3 - Beat Tipleri ve Mix-up Sistemi

### Amac

Parry ve dodge'u birbirinin yerine gecen secenekler olmaktan cikarmak. Her saldiri tipi farkli okuma ve farkli cevap istemeli.

### Yeni Beat Profili

`BeatKind` tek basina yetmeyebilir. Beat'e yeni bir savunma profili eklenmelidir:

```text
normal
- parry veya dodge ile savunulabilir

heavy
- dodge edilirse punish acar
- parry edilirse yuksek posture hasari verir ama risklidir

guardBreak
- parry/block cezalandirir
- dodge ister

tracking
- dodge'u yakalar
- parry ister

delayed
- windup uzun veya degisken
- erken basisi cezalandirir

feint
- erken parry/dodge'u bozar
- hasar vermeyebilir ama oyuncuyu recovery'ye sokabilir

ranged
- parry ile yansitilabilir
- dodge ile sadece kurtulunur
```

### Yapilacaklar

- `Beat` modeline `defenseProfile` ekle.
- `canParry`, `canDodge`, `punishOnDodge`, `parryPenalty`, `dodgePenalty` gibi alanlar eklenebilir.
- Erken parry whiff lock ekle.
- Erken dodge stamina cezasi veya recovery lock ekle.
- Feint saldirilar erken savunma yapan oyuncuyu cezalandirmali.
- Telegraph sistemi ekle.

### Telegraph Ilkesi

Saldiri tipi sadece UI rengiyle anlatilmamali. Oncelik sirasi:

1. Animasyon silueti
2. Ses cue
3. Kucuk efekt veya renk
4. HUD destek bilgisi

Oyuncu "renk gordum, tusa bastim" ezberine dusmemeli.

### Teknik Dokunulacak Alanlar

- `lib/characters.dart`
  - `DefenseProfile` enum
  - `Beat` alanlari
  - boss desenlerinin yeniden yazimi
- `lib/boss.dart`
  - `_resolveContact`
  - `_parrySuccess`
  - `_dodgeSuccess`
  - `_applyHit`
  - early input punish
- `lib/player.dart`
  - parry whiff state
  - dodge recovery
  - panic input cezasi
- `lib/hud.dart`
  - beat chip'lerinde yeni ikon/renk ayrimi.

### Kabul Kriterleri

- Tum saldirilar icin dodge spam calismamali.
- Tum saldirilar icin parry spam calismamali.
- Oyuncu boss animasyonunu okumaya baslamali.
- Yanlis savunma, sadece cooldown degil gercek tempo kaybi yaratmali.

### Riskler

- Cok fazla saldiri tipi erken asamada oyuncuya haksiz gelebilir.
- Telegraph yeterince net olmazsa oyuncu cezayi rastgele algilar.
- Bu faz mutlaka playtest ve sayi ayari ister.

## Faz 4 - Boss Pressure Loop ve AI Cesitliligi

### Amac

Boss'un "kombo bitti, eski yerine don, tekrar basla" davranisini kaldirmak. Boss, mesafeye ve oyuncu aliskanligina gore baskiyi surdurmeli.

### Yeni Boss Akisi

```text
idle/think
-> chooseIntent
-> approach / holdRange / reposition / attack
-> comboSegment
-> pressureDecision
-> chain / backstep / feint / gapClose / retreat
-> tekrar chooseIntent
```

### Yapilacaklar

- Sabit tek combo yerine kombo havuzu ekle.
- Boss her turda agirlikli secim yapsin.
- Boss mesafeyi okusun.
- Boss oyuncu davranis sayaclarini tutsun.
- Boss HP dustukce faz degistirsin.
- Boss her kombo sonunda zorunlu retreat yapmasin.

### Oyuncu Aliskanligi Takibi

```text
recentParryCount
recentDodgeCount
recentAttackCount
recentWhiffCount
playerDistance
playerStamina
bossPosture
bossHealthPhase
```

### Boss Tepki Ornekleri

```text
Oyuncu surekli dodge yapiyor
-> tracking attack veya gecikmeli saldiri sec

Oyuncu surekli parry yapiyor
-> feint veya guardBreak sec

Oyuncu saldiriya abaniyor
-> hizli interrupt veya backstep punish sec

Oyuncu cok uzak kaliyor
-> dash-in, projectile veya gap closer sec

Boss posture kirilmaya yakin
-> daha savunmaci reposition veya riskli all-in sec
```

### Teknik Dokunulacak Alanlar

- `lib/boss.dart`
  - state machine genisletme
  - `chooseIntent`
  - `chooseCombo`
  - `pressureDecision`
  - retreat zorunlulugunun kaldirilmasi
- `lib/characters.dart`
  - `ComboPattern` yerine veya yanina `ComboMove` havuzu
  - move agirliklari
  - faz bazli desenler
- `lib/game.dart`
  - mesafe yardimcilari
  - debug verisi.

### Kabul Kriterleri

- Boss her combo sonunda ayni yere donmemeli.
- Oyuncu ayni savunma aksiyonunu tekrar ettiginde boss buna cevap uretmeli.
- Boss davranisi tamamen rastgele degil, okunabilir ama canli hissettirmeli.
- Dusuk HP'de dovus temposu hissedilir sekilde degismeli.

### Riskler

- Cok adaptif boss haksiz ve yapay zeka "hile yapiyor" gibi hissedilebilir.
- Rastgelelik fazla olursa oyuncu ogrenme hissini kaybeder.
- Her boss icin kimlik farki korunmali.

## Faz 5 - Combat Feedback ve Game Feel

### Amac

Mekanik omurga oturduktan sonra temas hissini guclendirmek. Oyuncu her basarili veya hatali aksiyonu vucudunda hissetmeli.

### Yapilacaklar

- Hitstop ekle.
- Parry icin kisa freeze ve ekran impulse.
- Posture break icin daha belirgin efekt.
- Heavy attack isabetinde daha agir ses/ekran sarsintisi.
- Whiff icin hava kesme sesi.
- Dodge icin afterimage veya dust trail.
- Boss faz degisiminde kisa staging.
- Hasar popup'lari HP ve posture icin ayrismali.

### Feedback Haritasi

```text
perfect parry
-> metal ses, 60-90ms hitstop, kucuk spark, posture popup

late parry / block
-> daha tok ses, oyuncu geri itilir, stamina/posture kaybi

clean dodge
-> hizli whoosh, kisa afterimage, stamina azalir

bad dodge
-> yakalanma animasyonu, daha sert knockback

posture break
-> boss diz coker/hurt loop, buyuk ses, kisa ekran sarsintisi

heavy punish
-> uzun hitstop, daha buyuk knockback, net HP popup
```

### Teknik Dokunulacak Alanlar

- `lib/fx.dart`
  - spark, posture break, slash trail gibi yeni component'ler
- `lib/audio.dart`
  - yeni SFX havuzlari
- `lib/game.dart`
  - hitstop veya global timeScale benzeri kontrol
- `lib/boss.dart`
  - posture break efekt tetikleri
- `lib/player.dart`
  - attack trail ve whiff feedback.

### Kabul Kriterleri

- Basarili parry, dodge ve punish birbirinden ses/gorsel olarak ayrilmali.
- Posture break oyuncuya net "simdi vur" hissi vermeli.
- Heavy attack tatmin edici ama agir hissettirmeli.
- Efektler okunurlugu bozmamali.

### Riskler

- Fazla ekran sarsintisi veya popup okunurlugu dusurebilir.
- Hitstop fazla olursa akicilik bozulabilir.
- Efektler mekanik sorunlari maskelemek icin kullanilmamali.

## Faz 6 - Test, Tuning ve Debug Araclari

### Amac

Combat sisteminin tek optimal stratejiye kaymasini erken yakalamak. Sayilarla oynarken hissi ve dengeyi olculebilir hale getirmek.

### Yapilacaklar

- Debug combat overlay ekle.
- Son savunma aksiyonlarini kaydet.
- Parry/dodge/attack basari oranlarini takip et.
- Boss posture break suresini olc.
- Ortalama fight suresini olc.
- Hangi aksiyonun ne kadar HP/posture hasari urettigini goster.
- Basit deterministic combat unit testleri ekle.

### Debug Metrikleri

```text
fightDuration
playerDamageTaken
bossDamageTaken
bossPostureBreakCount
parryAttempts
parrySuccesses
dodgeAttempts
dodgeSuccesses
attackWhiffs
lightAttackHits
heavyAttackHits
damageFromPunish
damageFromPostureBreak
```

### Teknik Dokunulacak Alanlar

- `lib/game.dart`
  - combat metrics objesi
- `lib/boss.dart`
  - olay kayitlari
- `lib/player.dart`
  - input/action kayitlari
- `lib/hud.dart`
  - debug overlay veya dev panel
- `test/`
  - posture ve beat cozumleme testleri.

### Kabul Kriterleri

- Bir playtest sonrasi hangi aksiyonun baskin oldugu gorulebilmeli.
- Yeni beat profilleri icin unit test yazilabilmeli.
- Tuning yaparken sadece hisse degil, veriye de bakilabilmeli.

### Riskler

- Debug sistemi fazla zaman alabilir.
- Fakat uzun vadede combat tuning icin ciddi zaman kazandirir.

## Onerilen Uygulama Sirasi

```text
1. Faz 0 - Dodge spam'i kir, otomatik hasari azalt
2. Faz 1 - Boss posture ve player stamina ekle
3. Faz 2 - Light/heavy oyuncu saldirilarini ayir
4. Faz 3 - Beat defense profile ve yanlis savunma cezalarini ekle
5. Faz 4 - Boss pressure loop ve kombo havuzu kur
6. Faz 5 - Hitstop, efekt, ses ve game feel cilasi
7. Faz 6 - Debug metrikleri ve tuning testleri
```

## Ilk Sprint Icin Net Gorev Listesi

Ilk sprint, Faz 0 ve Faz 1'in cekirdegini kapsamalidir.

### Gorev 1 - Dodge Odulunu Daralt

- `BeatKind.meleeHeavy` dodge edilirse `offBalance` ac.
- `BeatKind.meleeLight` dodge edilirse boss komboya devam etsin.
- `BeatKind.feint` dodge edilirse odul verme.

### Gorev 2 - Otomatik HP Hasarini Kaldir

- `_parrySuccess` icindeki chip HP hasarini kaldir veya posture'a cevir.
- `_endCombo` icindeki otomatik `takeDamage(dmg)` davranisini kaldir.
- Tam parry zinciri boss posture'a buyuk hasar versin.

### Gorev 3 - Boss Posture Ekle

- `Boss.posture`
- `Boss.maxPosture`
- `Boss.displayPosture`
- `applyPostureDamage`
- `breakPosture`

### Gorev 4 - HUD Posture Bar Ekle

- Boss HP altina veya ustune posture bar koy.
- Posture break yaklasirken bar daha belirgin olsun.

### Gorev 5 - Player Stamina Ekle

- Dodge stamina harcasin.
- Stamina yoksa dodge baslamasin veya zayif dodge olsun.
- HUD'da stamina bar goster.

### Gorev 6 - Basit Testleri Yaz

- Light dodge `offBalance` acmaz.
- Heavy dodge `offBalance` acar.
- Parry HP hasari degil posture hasari verir.
- Posture dolunca boss `staggered` olur.

## Nihai Combat Dongusu

Hedeflenen temel oyuncu deneyimi:

```text
Boss saldirir
-> oyuncu saldiri tipini okur
-> dogru savunma/pozisyon karari verir
-> parry ise posture ve tempo kazanir
-> dodge ise hayatta kalir veya uygun saldirida punish firsati yakalar
-> oyuncu light/heavy saldiri ile riske girer
-> boss davranisi oyuncunun aliskanligina tepki verir
-> posture break veya temiz punish ile HP hasari gelir
-> dovus sabit dongu yerine baski ve karar akisi olarak surer
```

Bu planin basari olcutu, oyuncunun su soruyu surekli sormasidir:

```text
Simdi savunmali miyim, kacmali miyim, yoksa riske girip vurabilir miyim?
```

Eger oyuncu sadece "dogru anda dodge yap ve F'e bas" diyorsa sistem henuz hedefe ulasmamis demektir.
