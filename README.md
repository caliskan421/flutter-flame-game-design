## 1. Parry (Mükemmel Savuşturma)

Sekiro mekaniğinin kalbidir. 2D'de parry, sadece hasardan kaçınmak değil, **savunmadayken bile agresif kalabilmenin** yoludur.

* **Teknik Detay (Hitbox & Frame Data):**
* **Active Frames (Aktif Kareler):** Oyuncu parry tuşuna bastığında, karakterin önünde çok kısa süreli (örn. 60 FPS bir oyunda 4 ila 8 frame, yani ~0.1 saniye) aktif bir "parry hitbox'ı" oluşmalıdır.
* **Window Decay (Pencere Aşınması):** Oyuncu panikleyip tuşa ardı ardına basarsa (spamming), aktif kare süresi kısalmalı veya tamamen kapanmalıdır. Sekiro bunu harika yapar; spam yaparsan mükemmel parry penceren daralır.


* **Oyuncu Tarafındaki Haz (Juice):**
* Görsel olarak iki kılıcın çarpışmasından doğan **büyük, parlak sarı/turuncu kıvılcımlar**.
* İşitsel olarak tok, metalik bir **"ŞING!"** sesi (normal blok sesinden çok farklı olmalı).
* **Hit Stop (Ekran Donması):** Başarılı bir parry anında oyun dünyası 1-3 kareliğine (0.05 saniye) tamamen donmalıdır. Bu, oyuncunun beynine "Harika bir iş başardın" sinyali verir.



## 2. Dodge (Sıyrılma / Atılma)

Sekiro’da "Mikiri Counter" veya zıplama neyse, 2D'de de doğru yönlendirilmiş bir sıyrılma odur. Dodge, parry'nin alternatifi değil, **parry edilemeyen saldırıların panzehiri** olmalıdır.

* **Teknik Detay:**
* **Invincibility Frames (i-Frames / Dokunulmazlık Kareleri):** Karakterin animasyonunun tam ortasında, düşman hitbox'larının içinden geçebileceği 10-15 framelik bir dokunulmazlık penceresi olmalıdır.
* **Recovery Frames (İyileşme Kareleri):** Sıyrılma bittiğinde karakterin hemen saldıramadığı çok kısa bir duraksama süresi olmalı ki oyuncu her saniye kontrolsüzce sağa sola atılmasın.


* **Oyuncu Tarafındaki Haz:**
* Düşmanın arkasına geçildiğinde oluşan o "Rüzgar gibi geçtim" hissi. Hareketin arkasında hafif bir ghosting (gölge/iz bırakma) efekti harika çalışır.
* Eğer düşmanın parry edilemeyen (kırmızı sembollü) bir saldırısından kusursuz sıyrılınırsa, düşmanın arkasında **büyük bir açık (punish window)** oluşmalıdır.



## 3. Hafif ve Ağır Saldırı (Light & Heavy Attack)

Bu iki saldırı tipi arasındaki fark sadece "hasar barı" değil, **ritim ve taahhüt (commitment)** farkıdır.

* **Teknik Detay:**
* **Light Attack:** Başlama (Startup) süresi çok kısadır, kombolar arası iptal edilebilir (animation canceling). Oyuncunun düşmanın defansını test ettiği, ritmi başlattığı araçtır.
* **Heavy Attack (Animation Lock):** Yüksek hasar ve durdurma (stagger) gücüne sahiptir ancak oyuncuyu animasyona kilitler. Bastığın an geri dönüşü yoktur. Düşmanın dengesi sarsıldığında veya parry sonrası açılan pencerelerde kullanılmalıdır.


* **Oyuncu Tarafındaki Haz:**
* Hafif saldırılarda seri kılıç savurma sesleri (*vınn, vınn*).
* Ağır saldırılarda ise karakterin tüm gövdesiyle ileri atılması, ekranın hafifçe sallanması (screen shake) ve düşmanın geriye doğru savrulması (knockback).



## 4. Savunma / Blok (Guard)

Eğer Sekiro tarzı bir tat istiyorsan, düz blok yapmak oyuncu için **en son çare ve cezalandırıcı** bir eylem olmalıdır.

* **Teknik Detay (Denge / Posture Sistemi):**
* Oyunda mutlaka bir **Denge (Posture/Stagger) Barı** olmalı. Normal blok yapmak oyuncunun canını korur ama denge barını hızla doldurur. Bar dolunca karakter "Stun" (sersemleme) durumuna düşer.
* Düşmanların da bir denge barı olmalı ve bu bar sadece hasarla değil, oyuncunun yaptığı **başarılı parry'ler ve agresif hafif saldırılarla** dolmalı.


* **Oyuncu Tarafındaki Haz:**
* Düz blok yapıldığında donuk, sönük bir metal sesi gelmeli ve karakter hafifçe geriye itilmelidir. Bu, oyuncuya "Güvendesin ama pasif kalıyorsun, ritmi kaçırıyorsun" mesajını net bir şekilde iletir.



---

## Gerçek Haz Ne Zaman Ortaya Çıkar? (Altın Kurallar)

Sekiro’yu başyapıt yapan şey, oyuncuya sunduğu **"Risk Ödül Dengesi"** ve **"Dans Etme"** hissiyatıdır. 2D oyununda gerçek hazzı şu anlarda yakalarsın:

### 1. "Sıra Bende" Geçişi (The Turn-Around)

Düşman size 4 vuruşluk çılgın bir kombo yapıyordur. Oyuncu: *Parry (çın) -> Parry (çın) -> Parry (çın) -> Mükemmel Parry (ŞING!).* İşte o son büyük parry'den sonra, düşman hafifçe sersemler ve kombo sırası **anında ve kesintisiz** oyuncuya geçer. Oyuncu savunmadan saldırıya pürüzsüzce geçtiği an dopamin patlaması yaşar.

### 2. Görsel ve İşitsel Kontrast

Savaşın ritmini oyuncuya gözleriyle değil, kulaklarıyla ve refleksleriyle hissettirmelisin. Normal vuruşlar, bloklar ve mükemmel parry'ler arasındaki ses ve efekt farkı o kadar keskin olmalı ki, oyuncu gözü kapalı bile dövüşün nasıl gittiğini anlayabilmeli.

### 3. Ölümcül Darbe (Deathblow / Execution)

Düşmanın canı hala %80 olabilir, ancak oyuncu o kadar kusursuz parry ve ağır saldırı yapmıştır ki düşmanın **Denge Barı (Posture)** patlar. Ekran kırmızıya bürünür, zaman yavaşlar ve tek bir tuşla düşmanı infaz etme şansı doğar. Can barını eritmek sabır işidir; dengeyi patlatmak ise yetenek işidir. Oyuncuyu yeteneği için ödüllendirdiğin o an, oyununun zirve noktasıdır.

**Özetle teknik formül:** Kısa aktif kareler (Active frames) + Doğru ekrandan donma süreleri (Hit stop) + Tok ses efektleri + Denge barı odaklı bir dövüş döngüsü = 2D Sekiro hazzı.