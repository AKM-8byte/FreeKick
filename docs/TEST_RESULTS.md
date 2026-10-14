# Güncel test sonuçları

14 Ekim 2026 — Godot 4.7.2, Windows. Simulation modu kaldırılmış güncel kod üzerinde:

| Test | Geçen kontrol | Kapsam |
| --- | ---: | --- |
| game_tests | 75 | Vuruş, IK, temas, gol, reset |
| playability_tests | 77 | Baraj, falso, alt/üst temas, kaleci |
| physics_settings_tests | 34 | Gerçek fizik ayarları ve 130 m/s file CCD |
| cloth_knuckle_tests | 22 | Cloth, sabit kenarlar, ölü yaprak ve tutuş |
| net_broadphase_tests | 360 | Deforme file / kale içi geçerli süpürmeler, tam üçgen taramasıyla karşılaştırma |
| developer_tools_tests | 37 | Tek fizik profili, canlı ayarlar, kalite, laboratuvar |
| magnus_intro_tests | 18 | Magnus anahtarı, kuvvet, profil kaydı, kilit, İngilizce yazı ve fade |
| cinematic_tests | 40 | Gol, file ve sinematik tekrar |
| presentation_tests | 26 | Sunum ve kamera |
| keeper_perception_tests | 43 | Gecikmeli gözlem, sınırlı düzeltme, tekrarlanabilirlik |
| flow_tutorial_tests | 24 | Yükleme, giriş eşlemeleri, etkileşimli tutorial ve kayıt |

Tüm listelenen kontrol grupları sıfır başarısız assertion ile tamamlandı. Tutorial testinin native threaded yükleme sonrasında kapanışında **13 ObjectDB referans sızıntısı uyarısı** sürüyor; bu uyarı giderilmiş sayılmıyor. Üretim oyununun Windows standalone export'u yeniden derlenmedi; Windows Godot runtime kullanıldı. Gerçek kontrolcü donanımı ve gerçek telefon test edilmedi.

Godot EditorPlugin QA gerçek editör sürecinde geçti: 12 fizik alanı, arama, doğrulama, undo/redo ve profil kaydı. Native OpenGL / GTX 1650 Ti üzerinde yapımcı yazısı ve Magnus paneli görüntüleri kaydedilip incelendi (`tests/release_visual_check.gd`).

File temas CPU karşılaştırması ve sınırları `WEB_PERFORMANCE.md` içindedir. Headless CPU süreleri Web FPS sonucu olarak sunulmaz. Eski Simulation testleri, kaldırılan özellik oldukları için güncel kabul listesinde bulunmaz.

## Web ve teslimat

Güncel tek iş parçacıklı release export Chrome 155.0.8059.40 içinde gerçek WebGL 2.0 ile açıldı. İngilizce tutorial'a erişildi; JavaScript/GDScript/WebGL/HTTP hata kaydı yoktu. Bu kısa başlangıç kontrolü yeni sürümde bütün şutların, sesin veya mobil FPS'nin tarayıcıda tekrar test edildiği anlamına gelmez. Gerçek telefon / itch.io test edilmedi.

Web ZIP: dokuz dosya, `index.html` kökte, CRC sağlam; yaklaşık 17,81 MiB. GitHub kaynak ZIP'i ayrıca hazırlanır; motor, kullanıcı kaydı, test çıktısı ve geliştirme asistanı talimat dosyaları içermez. En büyük kaynak dosyası 5,62 MiB; 100 MiB üstü dosya yok.

GitHub kaynak arşivi yeni, önbelleksiz `.tools/source-verify-clean` klasörüne açıldı. Godot ilk importu script/resource hatası olmadan tamamlandı; buradaki oyun sahnesinde 13 Magnus/intro kontrolü de geçti. Kapanışta iki ObjectDB referans uyarısı görüldü. Çim `.blend` kaynağı import dışı kaynak klasörüne taşındı; bu temiz importta Blender kurulumu gerekmedi.

Sayısal Magnus kontrolü ve gerçek açılış yükleme ekranına geçiş sonrası 18 Magnus/başlangıç ve 24 yükleme/tutorial kontrolü yeniden geçti. Native panel görüntüsü incelendi; Windows motor öncesi splash özel görsel ve statik, motor sonrası animasyon GDScript tarafından üretilir.

Güncel özel HTML shell Chrome içinde açıldı; motor başlamadan önce İngilizce kredi başlığı ve CSS animasyonu doğrulandı, ardından oyun yüklendi. Yaklaşık 20,28 MiB Web ZIP ve güncellenen kaynak ZIP yeniden hazırlanır. Açılış görüntüsünü yakalamak için QA aracı WASM indirmesine 1,8 s gecikme ekler; bu süre performans ölçümü değildir.
