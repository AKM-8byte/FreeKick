# FreeKick — Web export ve itch.io

## Güncel paketler

- `build/web/`: oynanabilir Web release; giriş `index.html`.
- `build/FreeKick-Web.zip`: itch.io oyun paketi. 9 dosya, `index.html` kökte, yaklaşık **20,28 MiB**. WASM 37,68 MiB; oyun PCK'sı 10,27 MiB.
- `build/FreeKick-Source.zip`: GitHub için kaynaklar; oynanabilir Web ZIP'i yerine yüklenmez. Bunu açıp kaynak dosyalarını GitHub deposuna yükleyin.

Godot **4.7.2 stable**, GDScript, Compatibility / WebGL 2.0, yerleşik Jolt, 120 Hz fizik kullanılır. **Web** preset'i tek iş parçacıklıdır; GDExtension/Thread Support kapalıdır. Çapraz origin izolasyonu gerektirmez. Windows x64/x86 presetleri korunur; export yolları artık makineye özel mutlak yollar yerine `build/windows/` altındadır. Projenin güncel renderer'ı Compatibility'dir.

Testler, araçlar, Blender kaynakları ve kullanılmayan texture varyantları Web paketinden dışlanır. Oynanabilir karakter GLB dosyaları, çim dokusu ve WAV sesleri korunur. Kalite seçimi oynanış fiziğinin sabit zaman adımını değiştirmez. Simulation modu kaldırılmıştır.

Web başlangıcında varsayılan Godot yükleme görünümü yerine `web/shell.html` kullanılır: animasyonlu **Created by Ahmet Kayra** ve gerçek indirme ilerlemesi. Motor başladıktan sonra aynı yazı kaynak yükleme ekranında kalır.

## Yeniden export

Godot 4.7.2 ve aynı sürümün Export Templates paketi gerekir. Godot GUI: **Project → Export → Web**. Çıktı `build/web/index.html` olmalıdır. PowerShell:

```powershell
./tools/build_web.ps1 -GodotPath 'Godot konsol çalıştırılabilir dosyasının yolu'
```

Betik şablon/import/export başarısızsa hata verir; eksik derleme başarılı ZIP gibi sunulmaz. Yerel `.tools` Godot kopyası mevcutsa parametre verilmeden kullanılabilir. Windows presetleri silinmez. Git commit, push veya yayınlama yapılmaz.

## itch.io'ya yükleme

1. Oyun türünü **HTML** seçin.
2. `build/FreeKick-Web.zip` yükleyin; **This file will be played in the browser** seçeneğini açın.
3. Başlangıç boyutunu 1440×900 veya aynı oranlı bir pencere seçin; fullscreen desteğini açın.
4. Taslağı tarayıcıda açın. İlk tanıtımı geçip oyun, ses ve fullscreen'i kendi cihazınızda kontrol edin; ardından isteğinize göre yayımlayın.

ZIP'i açıp yeniden klasör içinde ZIP'lemeyin: `index.html` doğrudan ZIP kökünde kalmalıdır. Tarayıcı güvenliği nedeniyle `file://` üzerinden çalıştırmak yerine yerel HTTP sunucu veya itch.io kullanın. Sesin başlaması için kullanıcı etkileşimi gerekebilir.

## Doğrulama ve sınırlar

Güncel üretim paketi gerçek Chrome 155 / WebGL 2.0 içinde açıldı; İngilizce etkileşimli tutorial'a ulaşıldı ve konsol hata kaydı yoktu. Native Godot'ta şut, file, Magnus, tekrar, tutorial ve geliştirici paneli kontrolleri geçti. Güncel testlerin ayrıntıları ve bilinen native test kapanış uyarısı `docs/TEST_RESULTS.md` içindedir. File CPU iyileştirmesi `docs/WEB_PERFORMANCE.md` içinde ölçülüdür; Web FPS garantisi değildir.

Bu yeni paket için gerçek telefon, Safari/Firefox, itch.io sayfası, bütün ses/kontrol/fullscreen senaryoları ve tam native–WASM fizik eşliği yeniden doğrulanmadı. Önceki sürümün kapsamlı tarayıcı sonuçları yeni sürüme mal edilmez.

Node.js, Playwright ve Chrome ile kısa başlangıç kontrolü:

```powershell
node tools/web_release_check.cjs
```

Sonuçlar `test-output/web-release/` altında tutulur; dağıtım ve GitHub kaynak ZIP'ine alınmaz. Oyun oyuncusunun Node.js veya Python kurması gerekmez.
