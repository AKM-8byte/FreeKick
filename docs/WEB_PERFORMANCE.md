# Web performansı — temel ölçüm

13 Ekim 2026, Chrome 155.0.8059.40, Windows. WebGL gerçek renderer:
ANGLE Intel UHD Graphics / Direct3D11. Native Compatibility testi NVIDIA
GTX 1650 Ti kullandı; iki GPU'nun süreleri aynı donanım karşılaştırması
değildir. Fizik 120 Hz; single-thread Web export değişmedi.

`tests/performance_probe.tscn`, Godot Performance Monitors, duvar saati
kare aralıkları, draw call, primitive, node ve video memory toplar. Ablation
yalnız test sahnesinde; üretim fiziği / oyun ayarları değişmez.
`tools/web_performance.cjs` gerçek Chrome / yerel sunucu test aracıdır.

| Kontrollü masaüstü Web testi | Medyan ms | p95 ms | Draw call |
| --- | ---: | ---: | ---: |
| İlk hazırlık baseline | 31.2 | 34.8 | 368 |
| File görünmez | 29.5 | 31.6 | 367 |
| Rig güncellemeleri kapalı | 16.7 | 17.3 | 368 |
| Rig tekrar açık / baseline geri | 16.6 | 17.6 | 368 |
| Oyun fizik / AI / IK çağrısı kapalı | 16.6 | 17.5 | 368 |
| Gölgeler kapalı | 16.7 | 17.4 | 199 |

Rig tekrar açıldığında FPS düşüşü geri dönmedi. İlk hızlanma **kalıcı rig
darboğazının kanıtı değildir**; shader / sahne ısınması ve sıralama etkisi
vardır. Statik file görünmezken 46.712 primitive azalır, fakat ilk medyan
iyileşme küçüktür. Gölgeler 169 draw call ekler. Bu gözlemler hedefli
kalite / açılış optimizasyonuna gerekçe; cihazdan bağımsız FPS garantisi
değildir. Sıcak baseline yaklaşık 60 FPS, ilk sahne yaklaşık 32 FPS.

İlk engine + sahne görünümü yerel sunucuda yaklaşık 19.7 s;
sahne instantiate / ready yaklaşık 658 ms. Ağ indirme, WASM başlatma ve
shader ilk kullanım maliyetleri aynı süre değildir. Henüz ayrı dağılım
tamamlanmadı. İlk Native Compatibility scene ready yaklaşık 757 ms.

Mobil emülasyon aynı PC/GPU'da 844×390 dokunmatik Chrome bağlamıdır:
ilk 28.1 ms, sıcak 16.6 ms. Godot canvas stretch mantıksal viewport'u
1947×900 gösterdi; bu ekranın fiziksel render çözünürlüğü diye sunulmaz.
Video memory yaklaşık 43.5 MB, desktop yaklaşık 83.8 MB. Web MEMORY_STATIC
0 döndü; kullanılabilir ölçüm yok, sıfır bellek kullanımı değildir.
Gerçek telefon test edilmedi, bu sonuç mobil cihaz 30 FPS kabulü değildir.

Ham kayıtlar: `test-output/performance/native-baseline.json`,
`web-desktop-controlled.json`, `web-mobile-emulated-baseline.json`.
İki saniyelik örnek pencereleri kapsamlı benchmark değildir; shader
geçişlerinde Performance.TIME_PROCESS değerleri geçici sıçrar.

## Güncelleme — 14 Ekim 2026: file teması

Low / Medium / High profilleri, rig önbelleği, sabit file görsel yükleme kontrolü ve kaynak yükleme ekranı artık mevcut. Bu bölümün üstündeki Web ölçümleri önceki baseline kayıtlarıdır; yeni export için aynı sonuçlar varsayılmaz.

File etkinleşince her fizik adımında tüm üçgenlerin, temas düzeltmesinde ise birden fazla kez tarandığı saptandı. Bu sıcak yol için aynı Windows makinesinde Godot 4.7.2 headless mikro ölçümü yapıldı. Aynı 120 tekrar, bağlı parçacık sayısı ve solver iterasyonu kullanıldı; kalite azaltılmadı.

| İşlem | Önce (ms/adım) | Sonra (ms/adım) |
| --- | ---: | ---: |
| Cloth çözümü | 2.203 | 1.715 |
| Kaleye yaklaşırken süpürme | 2.443 | 0.042 |
| File yakınında süpürme | 5.022 | 0.172 |

Ölçüm `tests/net_performance_tests.gd` ile tekrar üretilebilir (`-- --before` öncesi etiketi yazar). Mikro ölçüm bütün kare süresi veya Web FPS ölçümü değildir. Yeni broad phase, güncel deformasyon zarfını kullanır ve kesin üçgen testini korur. Motor fiziğinin 120 Hz adımı düşürülmedi. Eski tüm üçgen kontrolüyle karşılaştırılan 360 geçerli kale içi süpürme eşleşti; ayrıca gerçek topun 130 m/s fileden kaçmaması test edildi.

Gerçek telefon performansı ölçülmedi. En düşük donanımlarda 60 FPS garantisi verilmez. Güncel Web başlangıç testi ve sınırlamalar `TEST_RESULTS.md` içindedir.
