# Freekick / Lab

Godot 4.7 için klavye ve fareyle oynanan, prosedürel 3B serbest vuruş antrenmanı.

## Başlatma

Detaylı karakterlerle ayrı oynanabilir sahne: `scenes/detailed_training.tscn`; Godot'ta açıp **F6** ile çalıştırılabilir. Ana sahne de aynı güncellenmiş karakterleri kullanır. Blender'da üretilen dokuz parça `assets/models/football_parts.glb` üzerinden mevcut IK'ye bağlanır; düzenlenebilir kaynak `assets/models/source/football_parts.blend` dosyasındadır.

Godot **4.7.2** ile `project.godot` dosyasını açıp **F5** tuşuna basın. Başlangıç sahnesi `scenes/loading.tscn` üzerinden yüklenir; ilk kullanımda etkileşimli tanıtım, sonraki kullanımlarda ana menü açılır. Bilgisayar dili Türkçeyse Türkçe, diğer dillerde İngilizce kullanılır; menüden dil değiştirilebilir. Oynatmak için Blender kurulumu gerekmez. Düzenlenebilir `.blend` kaynakları `.gdignore` içeren kaynak klasörlerinde tutulur; oyunda GLB ve PNG dosyaları kullanılır.

Açılış ekranı **Created by Ahmet Kayra** yazısını gösterir. Web indirme/motor başlatma ekranı özel animasyonlu HTML shell kullanır; native boot splash özel PNG, motor açılınca yükleme ekranı animasyonludur. Godot logosu yerine bu ekran kullanılır. Sonraki sahne geçişlerinde açılış yazısı tekrarlanmaz.

## GitHub için kaynak paket

`python tools/prepare_source.py` komutu `build/FreeKick-Source.zip` oluşturur. ZIP kökünde `project.godot` bulunur. Motor dosyaları, yerel kayıtlar, şifreler, derlemeler ve test çıktıları pakete alınmaz. GitHub'a klasörleri yüklerken bu ZIP'i açarak kaynak dosyalarını yükleyin. Hiçbir commit, push veya yayınlama otomatik yapılmaz.

`.godot/`, `.tools/`, `test-output/` ve `build/` Git tarafından yok sayılır. `.gd`, `.tscn`, `.tres`, `.uid`, `.import` dosyalarını ve oyun assetlerini saklayın. Windows x64/x86 presetleri korunur; çıktı yolları `build/windows/` altındadır. Web hazırlığı: [WEB_EXPORT.md](WEB_EXPORT.md).

## Kontroller

- **Kaleye veya direklerin yanına tıkla / sürükle:** vuruş yönünü değiştir. Falso için kalenin dışına da nişan alınabilir.
- **Sahadaki topa tıkla / sürükle:** beyaz köşelerin içindeki top üzerinde temas noktasını seç. Yan temas falsoyu, alt/üst temas çıkış açısını değiştirir.
- **Vuruş biçimi otomatik:** sadece yön, temas noktası ve güç seçilir. Sağ ayağın açılması/kapanması, yön ve temasla sürekli değişir; ayrı bir tür menüsü yoktur.
- **Boşluk basılı tut / bırak:** gücü artır, bırakınca vur. Ekrandaki vuruş düğmesi de basılı tutularak kullanılır.
- **R / TEKRAR:** gol olmayan şutlarda mevcut ayarlarla yeniden dene; gol sonrası rastgele seçilmiş yeni konuma geç. Golün tekrarını izlemek için eski konum sonuç ekranında korunur.
- **Tab / ANTRENMAN:** kale çizgisine 17–30 m uzaklık, ±25 m yatay konum, 1–5 baraj oyuncusu ve **Kolay / Dengeli / Zor** kaleci. Dengeli varsayılandır. Değişiklikler yeni denemeyi hazırlar. Kamera seçimi top odaklı veya oyuncunun arkasında ve üstünde olabilir.
- **Esc:** tekrar sırasında sonuç ekranına, normal oyunda ana menüye dön.
- **İlk açılış tanıtımı:** nişan alma, güç, falso ve serbest deneme adımlarını etkileşimli olarak öğretir; gol zorunlu değildir. Atlanabilir ve ana menüden yeniden açılabilir. Hazırlık sırasında **?** kısa kontrol rehberini açar.
- **Uçuş izi:** görünürlüğü şut sırasında da değiştirilebilir.
- **GOL! kutusu / GOLÜ İZLE:** golü yedi farklı açıdan sinematik olarak izle. **← / →** ile açı değiştir. Her açının tamamı ×0,25 ağır çekimdir. Altta gerçek çıkış hızı, kaydedilen anlık hız, falso yönü, dönüş (tur/sn) ve vuruş gücü gösterilir. Değerler yavaşlatılmış ekran hızını değil gerçek şutu anlatır. **Esc / GERİ DÖN** aynı sonuç ekranına döner; **R** yeni denemeyi hazırlar.

Topun **altına** temas etmek çıkışı yükseltir, **üstüne** temas etmek alçaltır. Alt temas yüksekliğe ek etki kattığı için yön işaretini doğrudan üst köşeye koymak topu kalenin üzerine gönderebilir. Baraj üstü bir deneme için 21 metrede alt bölümden yaklaşık %65 temas, barajın arkasındaki köşeye doğru alçak bir yön işareti ve **%35–45 güç** kullanılabilir. 16 metrede daha az güç, 30 metrede daha hafif alt temas gerekir. Güç önerisi mesafe ve temasla değişir.

**Ölü yaprak:** topun merkezinin biraz altına, yaklaşık yarıçapın %20'si kadar aşağıya temas seçin. Ekranda `ÖLÜ YAPRAK BÖLGESİ` yazısı çıkar. 21 metrede yaklaşık **%60–70 güç** deneyin. Ayrı vuruş türü seçilmez: bu temas ve yeterli hız, dönüşü azaltıp hava izindeki düzensiz kuvvetleri etkinleştirir. Top sağa/sola ve yukarı/aşağı beklenmedik küçük sapmalar yapabilir; her deneme farklıdır. Ok, rastgele hava hareketini önceden göstermez. Çok zayıf vuruşlarda bu etki azalır; yana veya daha aşağıya temas normal falso/loft üretir.

Dengeli kaleci sıradan açık köşe şutlarını kurtarabilir. Alıştırma için Kolay seçilebilir. **Sağ yan temas sola**, **sol yan temas sağa** kıvrılma verir. 21 metrede %75 yan temas ve yaklaşık %55 güçle top yaklaşık 1,6–1,9 metre falso yapabilir; barajın iki kenarından dönüp kaleye girmek mümkündür. Güç ve uzaklık da uçuşu etkiler. Baraj yakın direği, kaleci açık tarafı kapatır.

Camgöbeği ok vuruştan önce yön, temas ve güçle şekillenir. İlk birkaç metrenin yükselme ve kıvrılma eğilimini gösterir; ok ucu çizginin son yönünü izler. Tam uçuş veya kaleye ulaşma tahmini gösterilmez. Yön işareti nötr, merkez temaslı vuruşun yaklaşımını belirler; alt/üst temas ve falso bu uçuşu değiştirir. Temasın etkisini geri alan bir hedef telafisi yapılmaz. Köşeye girmek için yön ve temas birlikte ayarlanır; topa uçuş sırasında hedefe gitme kuvveti uygulanmaz.

Kamera topun 8 metre arkasında, 1,7 metre yüksekte ve hafif sağdadır. 26° sabit görüş açısı mesafe arttıkça barajı büyüten zoom'u önler; kale, baraj ve saha derinliği birlikte görünür. Futbolcu hazırlıkta kadrajı kapatmaz; vuruş sırasında soldan girer ve vuruş sonrası sola çekilir. Ayarlar açılır menüdedir; top üzerinde temas seçimi, güç önerisi ve mesafe bilgisi sahada görünür.

Baraj oyuncuları yaklaşık **1,72 m** boyundadır; model ve fizik engelleri birlikte ölçeklenir. Antrenman yerleşiminde topla yakın direk arasındaki mesafenin %60'ına, en az **9,15 m** uzağa yerleşirler. Böylece uzun mesafeli şutlarda baraj da toptan uzaklaşır. Merkezden 16/21/30 m şutlarda baraj uzaklığı yaklaşık 9,7/12,7/18,1 m olur. Gerçek mesafe antrenman menüsünde görünür. Sıçrama yüksekliği yaklaşık 24 cm'dir.

## Hareket ve fizik

Her gol sonrası yeni konum bağımsız iki seçimle belirlenir: %70 olasılıkla 17–24 m, %30 olasılıkla 24 m üzeri–30 m; yatayda %70 olasılıkla −10…+10 m, %30 olasılıkla dış yan bölgeler. Konumlar tam metre olduğundan ortak 24 m sınırı ilk gruptadır; yan dış bölgeler ±11…25 m'dir. Önceki konum tekrar seçilmez. Uzaklık kaydırıcısı kale çizgisine dik mesafedir; HUD'daki mesafe gerçek çapraz uzaklıktır. Topun tamamı ceza sahasının 16,5 m sınırının dışında kalır; hatalı girdiler de güvenli aralığa sıkıştırılır. ±25 m konumlar için saha genişliği 68 m'ye çıkarıldı.

Kaleci baş takibi artık yerel gövde eksenlerinde en fazla ±65° yana, 35° aşağı ve 25° yukarı döner; açılar sınırlı hızla ilerler. Top arkaya geçtiğinde boyun 180° dönmez. Kaleci ayakta ve topu tutmuyorken topa bütün gövdesiyle yumuşakça dönebilir. İtişten önce kollarını toplar, atlayışta yakın bacağı daha fazla büker, inişte dizleriyle darbeyi emer. Blender krampon/ayak modeli top temas noktasını ve mevcut ayak IK hedeflerini korur.

**GELİŞMİŞ ÖZELLİKLER** düğmesi sağ panelde top fiziğini açar. Kütle, vuruş kuvveti, yerçekimi, hava direnci, falso, sekme, zemin sürtünmesi ve ölü yaprak etkisi ayarlanabilir. Panel kaydırılarak alt ayarlara ulaşılır. Değişiklik yeni denemeyi hazırlar; uçuşta ayarlar kilitlidir. **FİZİĞİ VARSAYILANA DÖNDÜR** bütün değerleri birlikte geri alır. Varsayılan kütle 0,46 kg, vuruş kuvveti ×0,98, hava direnci ×1,10, falso ×0,80, sekme 0,32 ve sürtünme 0,72'dir. Kütle arttığında aynı ayak itkisinin çıkış hızı azalır. Nişan, yön oku, kalecinin okuması ve gerçek uçuş aynı ayarları kullanır.

Kalecinin yüksek yan dalışında üst el topa uzanırken diğer kol denge kurar ve bacaklar daha açık kalır. Alçak dalışta öndeki el topa gider, diğer kol gövdeyi dengeler; orta yükseklikte iki elle tutuş korunur. İtişten sonra vücut hafif öne taşınır; yan inişte darbe emme ve toparlanma devam eder. Blender klibi gerekmeyen prosedürel IK tercih edildi. Referanslar: [FIFA — yüksek dalış](https://www.fifatrainingcentre.com/en/environment/fifa-goalkeeper-training/goalkeeping-fundamentals/learning-to-dive-high.php), [FIFA — dalış temelleri](https://www.fifatrainingcentre.com/en/environment/fifa-goalkeeper-training/goalkeeping-fundamentals/learning-to-dive.php), [kaleci dalışının eklem biyomekaniği](https://pmc.ncbi.nlm.nih.gov/articles/PMC7739716/).

Karakterler basit geometriden oluşur. Hazır animasyon klibi, AnimationPlayer veya önceden kaydedilmiş top yörüngesi kullanılmaz. Her fizik adımında bacak ve kol hedefleri üretilir; iki kemikli analitik IK eklem konumlarını hesaplar. Vuruş sırasında destek ayağı dünya konumuna sabitlenir.

Topa yaklaşma dört dönüşümlü adımdan oluşur. Basılı ayak dünya konumunda tutulur; diğer ayak bir sonraki basışa yumuşak bir yay çizerek taşınır ve uçuşta kramponun açısı değişir. Son sol basış doğrudan destek ayağı olur, sağ ayak gerçek son basışından geriye açılır. Koşudan vuruşa geçişte ayak hedefi sıçratılmaz. Gövde yük aktarımı, omuz açılması ve kol dengesi mevcut IK hareketleriyle birleşir.

Sahada eklenen `texture/grass/Grass005_1K-PNG` renk, OpenGL normal ve pürüzlülük haritaları dünya koordinatlarında tekrar edilerek kullanılır; biçme şeritleri korunur. Tribün çatısı ve destek kirişleri, ışık kuleleri, koltuk sırtlıkları, yedek kulübeleri ve köşe bayrakları çevreyi tamamlar. Karakterlerde yaka, forma şeritleri, arma, boyun, yüz, diz/dirsek, şort paçaları, çorap bantları, krampon tabanı/bağcığı ve kaleci eldiveni detayları vardır. Modeller stilize prosedürel geometri olarak kalır. Vuruşta koşu kol salınımı, geriye omuz açılması, temas boyunca gövde dönüşü, karşı kol dengesi ve sınırlı baş takibi üretilir; bu gövde dönüşü tekrar kaydına da alınır.

Kalecinin tahmini alçak toplarda zemin sekmesini ve yuvarlanmayı hesaba katar. Alçak dalış daha geç başlar, gövde yere yaklaşır ve yerdeki temas penceresi uzar. Gövdenin zemine girmesini önleyen düzeltmeden sonra eldiven hedefi yeniden çözülür; bu düzeltmenin elleri toptan yukarı kaçırması önlenir. Dengeli kaleci dönüşün %82'sini, Zor %96'sını okur. Atlayıştan sonra gövde yönünü değiştirmez; gözlediği son hareketle ellere sınırlı düzeltme yapabilir. İyi yerleştirilmiş sert uzak köşeler gol olmaya devam edebilir.

Ayak ucu seçilen top yüzeyine ulaştığında tek bir itki uygulanır. Ayak yolu Hermite eğrisiyle oluşturulur; temas anındaki yol türevi vuruş hızını belirler. İtkinin temas merkezinden uzaklığı ve ayak biçiminin sürtünme etkisi topun dönüşünü oluşturur. Fizik, 120 Hz sabit adımda Jolt ile çalışır; uçuş boyunca hava direnci ve Magnus kuvveti uygulanır.

Baraj ve kaleci fiziksel engeldir. Kaleci Kolay/Dengeli/Zor için sırasıyla 300/190/100 ms tepki gecikmesiyle topun hareketinden tahmin üretir. Falsoyu kısmen okur, kısa aralıklarla kararını günceller; ayaklarını sabitleyip çömelir ve itişten sonra yönünü kilitler. Pelvis etrafında yana uzanma, yüksek toplara dik sıçrama, dizleri toplama, başla topu izleme, yere iniş ve kollarından destek alarak ayağa kalkış anlık IK hedefleriyle oluşturulur. Eldiven ve baş çarpışmaları görsel uzuvları izler. Zorluk; reaksiyon, yan adım, sıçrama hızı ve falso okuma becerisini değiştirir. Gol kontrolü topun tamamının kale düzlemini geçmesini ve iç direk sınırlarına sığmasını gerektirir. Ağ çarpışması topun enerjisini emer.

Şut dönüşü en fazla 110 rad/s olur. Jolt açısal hız sınırı 125 rad/s olarak ayarlıdır; motorun dönüşü erken kesmesi önlenir. Yan temastaki sürtünme aktarımı belirgin falso, alt/üst temas ise daha sınırlı dikey dönüş üretir. Magnus kuvveti tüm eksenlerde aynı çapraz çarpım yasasını kullanır.

Kale filesi artık gerçek zamanlı **PBD cloth** benzetimi kullanır: 411 parçacık, 2330 yapısal/çapraz/bükülme bağlantısı, Verlet adımları, yerçekimi ve sönüm. Ön çerçeve, zemin kenarı ve üst arka bağlantı sabittir. Yan/arka/üst paneller ortak düğümlerle dikilidir; serbest dikey birleşimler komşu panelleri çekebilir. Topun kuvveti temas çevresindeki düğümlere aktarılır; topa karşı kuvvet de file düğümlerinin mevcut konum ve hızından hesaplanır. Temas, sarkan ve hareket eden panel üzerinde bulunur; yerel temas kısıtları topun çevresinde dışarı uzanan bir cep oluşturur. Sert şut denemelerinde esneme yaklaşık 65–85 cm'ye ulaşabilir; gerilim ve sönüm ardından ağı geri toplar. İnce örgü simülasyon düğümlerini izler ve temas eden top yüzeyinden dışarı itilir; hazır dalga animasyonu kullanılmaz. File kendi üzerine çarpışma ve yırtılma içermez. CPU çözümü yalnızca gol sırasında/sonrasında çalışır; topun önceki ve mevcut konumu arasında hareketli file üçgenleri üzerinde sürekli küre teması kontrol edilir. Arka, yan, üst ve birleşimlerdeki hızlı geçişler düzeltilip enerji fileye aktarılır; uzak yedek engeller de korunur.

Kaleci ilk itişte ayağını yere basar, havada bacaklarını farklı miktarlarda toplar; yere inişte gövde darbeyi emer ve kısa bir kayma oluşur. Gerçek el temasında yavaş, iki elle ulaşılabilen topu tutup elleriyle taşır. Sert veya tek elle temas edilen topları saha içine ve yana çeler; gövde temasında fiziksel blok olur. Kaleci gelecekteki ölü yaprak dalgalanmasını bilmez. Karakterler hâlâ prosedürel IK kullanır; tam vücut ragdoll değildir.

Ölü yaprak modeli düşük dönüşte etkinleşen, şut başına rastgele fakat sabit tohumla üretilen, zaman içinde yumuşak değişen hava kuvvetleri kullanır. Aynı tohum aynı fizik adımlarında aynı uçuşu üretir; kare başına rastgele hız/konum eklenmez. Kuvvet 2 N ile sınırlıdır ve hızlı dönüşte bastırılır. Bu, hava akışının tam CFD çözümü değil, araştırmalardan esinlenen oynanış yaklaşımıdır. Kaynaklar: [Hong & Asai — Unsteady aerodynamic force on a knuckle ball in soccer](https://www.jstage.jst.go.jp/article/jjpehss/advpub/0/advpub_09053/_article/-char/en), [Müller ve diğerleri — Position Based Dynamics](https://doi.org/10.2312/PE/vriphys/vriphys06/071-080).

Tekrar sistemi gerçek şut sırasında top dönüşümünü, karakterlerin IK hedeflerini ve file parçacıklarını 60 Hz'de kaydeder. Yedi kamera bu kaydı gösterir; fizik yeniden hesaplanmaz. Böylece rastgele ölü yaprak şutu ve file esnemesi her tekrar açısında aynıdır. Canlı top donmuş halde tutulur; tekrar bitince mevcut sonuç, kamera ve file hareketi geri yüklenir. Yeni deneme kaydı, kalecinin tuttuğu topu ve file tepkisini birlikte temizler.

## Magnus ve geliştirici ayarları

Gelişmiş top ayarlarında **Magnus etkisi** anahtarı spin kaynaklı hava kuvvetini açar/kapatır. **Magnus şiddeti** sayı kutusuna 0,00–1,50 arası değer girilebilir; kaydırıcı ve sayı kutusu aynı gerçek fizik parametresini değiştirir. Godot içindeki **FreeKick Lab → Top fiziği** panelinde de aynı anahtar ve **Magnus şiddeti** alanı bulunur; ayrı bir fizik modu yoktur. Ayarlar uçuş sırasında kilitlenir.

## Ses

`assets/audio` klasöründeki yedi özgün WAV dosyası bu oyun için sentezlendi: çim adımı, vuruş, zemin/oyuncu çarpması, direk, file, gol tepkisi ve tribün uğultusu. Harici kayıt indirilmedi; üretim kaynağı `tools/generate_audio.py` ve açıklamalar `assets/audio/README.md` içindedir. Adım sesi basışta, vuruş sesi gerçek ayak temasında çalar. Efektler sahadaki konumlarından duyulur; tribün uğultusu düşük seviyede döner. Tekrar kaydı ses olaylarının zamanlarını da saklar ve ağır çekimde daha düşük perdeden yeniden oynatır. Açı değiştirme ve yeniden başlatma bekleyen efektleri durdurur.

## Doğrulama

```powershell
godot --headless --path . --script tests/game_tests.gd
godot --headless --path . --script tests/playability_tests.gd
godot --headless --path . --script tests/cinematic_tests.gd
godot --headless --path . --script tests/cloth_knuckle_tests.gd
godot --headless --path . --script tests/physics_settings_tests.gd
godot --headless --path . --script tests/keeper_upgrade_tests.gd
godot --headless --path . --script tests/presentation_tests.gd
godot --headless --path . --script tests/menu_training_tests.gd
godot --headless --path . --script tests/extreme_shot_tests.gd
```

Testler temas/spin ilişkisini, IK kemik uzunluklarını, dönen ayak ucunun seçilen noktaya ulaşmasını, temas öncesi sabit topu, tek itkiyi, destek ayağını, fizik çarpışmalarını, gol sınırlarını, sıfırlamayı ve 30/144 FPS karşılaştırmasını kontrol eder. Oynanabilirlik testleri aynı yön/güçte alt/merkez/üst temasın gerçek uçuş sıralamasını, 16/21/30 m baraj yerleşimini ve baraj üstünden golleri, baş yüksekliğinin altında barajın sağ/sol kenarından dönerek golleri ve kalecinin kurtarış/iniş/toparlanma aşamalarını doğrular.

Sinematik testleri gerçek gol, file teması, ok şekli, yedi açı, skorun korunması, Esc ve tekrar sırasında sıfırlamayı kontrol eder. Cloth/ölü yaprak testleri sabit kenarlar, darbenin yayılması, uzama sınırı, çözüm süresi, düşük dönüş, değişen hava kuvvetleri, aynı tohumla 30/144 FPS uçuş ve gerçek iki elle tutuşu doğrular. Görüntü kontrolü için `test-output` klasörünü oluşturup aşağıdaki komutu çalıştırın. Gerçek fare girdisi, iki pencere boyutu, ayarlar, gol kutusu, yedi tekrar açısı, cloth teması, ölü yaprak bölgesi ve kalecinin uzanma/iniş/toparlanma/tutuş kareleri PNG olarak kaydedilir:

Gelişmiş fizik testleri kütle/kuvvet/yerçekimi/direnç ayarlarının gerçek şutta hedef hesabıyla uyumunu, sıfırlamayı, ayar kilidini, falso ve sekme kontrolünü doğrular. Arka/yan/üst file ve panel birleşimleri için tek adımda yüzey geçişi denenir; canlı 130 m/s topların file içinde kalması ayrıca kontrol edilir.

```powershell
New-Item -ItemType Directory -Path test-output -Force | Out-Null
godot --path . --script tests/visual_check.gd
```


