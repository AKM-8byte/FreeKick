# Godot geliştirici paneli

Proje açıldığında etkin `addons/freekick_tools` eklentisi **FreeKick Lab** dock'unu oluşturur. Bu, oyunun geliştirme aracıdır; oyun içindeki gelişmiş ayar paneli ayrıca korunur.

- **Top fiziği:** sahne profili veya varsayılan referans; kütle, yarıçap, kuvvet, yerçekimi, direnç, **Magnus etkisi** aç/kapat, **Magnus şiddeti**, sekme, sürtünme ve ölü yaprak.
- **Kaleci/baraj:** gecikmeler, hızlar, ivmeler, algı hataları, uzanış sınırları ve zorluk dizileri.
- **Animasyon/IK:** uzuv uzunlukları, pelvis, diz yönü ve görsel rig sıklığı.
- **Grafik/file:** Low/Medium/High kaynakları, gölgeler, render ölçeği, çim, file yoğunluğu ve cloth ayarları.
- **Oynanış/kamera** ve **Tutorial:** gerçek sahne düğümü ve merkezi kaynak alanları.

Alanlar mevcut Resource/düğümlerden yansıtılır; paralel bağımsız değer deposu yoktur. Arama, birimler, açıklamalar, varsayılanlar, slider/sayısal giriş, checkbox, açılır menü ve Ctrl+Z desteği vardır. Kaydet/Yükle `.tres` profili oluşturur. Fizik ve kalite profillerini ana oyun sahnesine bağlamak için ilgili düğmeyi kullanıp sahneyi kaydedin.

**Çalışan oyuna gönder** native Godot debug bağlantısı üzerinden çalışır. Uçuş/tekrar sırasında düzenlemeler sıraya alınır; hazırlıkta uygulanır. Performans monitörü debug oturumunda FPS, fizik zamanı ve çizim maliyetlerini gösterir. Tarayıcıdaki oyuna bu native debug bağlantısı varmış gibi davranılmaz.

## Sayısal Magnus ve açılış ekranı

Oyun içindeki gelişmiş panelde **Magnus şiddeti** SpinBox alanı 0,00–1,50 aralığında, 0,01 adımlarla düzenlenir. Aynı `curl` değeri kaydırıcıya, uçuş modeline ve Godot geliştirici dock'una yansır. Uçuş sırasında sayı alanı da kilitlenir; ayrı veri kaynağı yoktur.

`web/shell.html`, WASM motoru indirilirken bile **Created by Ahmet Kayra** metnini animasyonlu gösterir. Progress gerçek engine indirmesine bağlıdır; hatalar görünür kalır. Shell, Web preset'inin `html/custom_html_shell` alanına bağlıdır.

`assets/ui/creator_splash.png` native Godot boot ekranının özel görselidir. Motor öncesi boot splash statiktir; GDScript henüz çalışamaz. Motor başladığında `scripts/loading_screen.gd` aynı yapımcı yazısını fade animasyonuyla ve gerçek kaynak ilerlemesiyle gösterir. Bu, ayrı bir tanıtım ekranı değil açılış yükleme ekranıdır. Sonraki geçişlerde normal FreeKick yükleme görünümü kullanılır.
