# Editörden düzenleme

F5 ana menüyü, `scenes/detailed_training.tscn` üzerinde F6 antrenmanı açar.
`main.tscn` oynanabilir temel sahnedir. Saha, arayüz, top ve karakterler
artık kaydedilmiş sahne düğümleridir.

| Düzenleme | Sahne / Inspector öğesi |
| --- | --- |
| Ana menü ve sabit yazılar | `scenes/main_menu.tscn` |
| Arayüz, paneller, fontlar, renkler, butonlar | `scenes/ui/game_hud.tscn` |
| Başlangıç uzaklığı, yatay konum, baraj sayısı, zorluk | `main.tscn` → HUD |
| Top fiziğinin varsayılanları | `settings/ball_physics.tres` |
| Nişan, güç doldurma süresi, iki kamera açısı / uzaklığı | Freekick → Shot and Camera |
| Yaklaşma mesafesi, koşu / geriye açılma süresi, adım yüksekliği | Freekick → Procedural Run-up |
| Yeşil zamanlama güç / isabet katkısı | Freekick → Optional Shot Timing |
| Zamanlama bölgeleri ve renkleri | `scenes/ui/timing_bar.tscn` → Orange Start / Green Start |
| Zamanlama barı / teklifin ekrandaki konumu | `game_hud.tscn` → Root / TimingBar, DifficultyOffer |
| Üç gol sonrası teklifin yerleşimi | `scenes/ui/difficulty_offer.tscn` |
| Ağır çekim hızı | Freekick → Replay Speed; 0.25 dört kat yavaş |
| Kaleci tepkisi, koşusu, atlayışı, falso okuması | Defenders → Keeper Difficulty |
| Baraj aralığı, boy ölçeği, mesafe | Defenders → Wall |
| Oyuncu, kaleci, baraj model / malzemeleri | `scenes/characters/` altındaki sahneler |
| IK uzuv uzunlukları, diz yönü, ayakta pelvis yüksekliği | Karakter sahnesinin kökü → Procedural IK |
| Top modeli ve renkleri | `scenes/ball.tscn` |
| Zemin, çim shaderı, tribün, ışık, gökyüzü, kale | `scenes/world/stadium.tscn` |
| File rengi, ip kalınlığı, sönümleme, iterasyon sayısı | GoalNet → Cloth |
| Ses dosyaları, ses seviyeleri, ortam sesi | Audio → Sound Files / Mix |

Alt sahneyi doğrudan düzenlemek bütün örnekleri günceller. Tek örneği
düzenlemek için **Editable Children**, ortak malzeme / mesh'i ayırmak için
**Make Unique** kullan.

Kaleci dizilerinin sırası **Kolay, Dengeli, Zor**; üç değer bırak.
Tepki gecikmesi saniye, koşu / atlayış hızı metre/saniyedir.
Spin Readings 0–1 arasındadır; düşük değer daha az falso okumasıdır.

Fizik panelindeki varsayılanlara dön düğmesi editörde kaydedilmiş fizik
profilini geri yükler. Oyun içindeki ayarlar diskteki kaynağı değiştirmez.

`Scene Bindings` alanları düğüm yollarıdır. Düğümü yeniden adlandırır veya
taşırsan ilgili yolu da güncelle. Yerleşim, font, boyut, renk ve malzeme
değişikliklerinde gerekmez. Canlı uzaklık / güç / hız / sonuç yazıları
oyun tarafından güncellenir. Kaydırıcı başlığı `Metadata → title` alanındadır.
Yeni Türkçe yazıya İngilizce karşılık `scripts/localization.gd` içinden eklenir.

Karakter sahnelerindeki **VisualRig**, görünen ve skin ağırlıklarıyla
iskelete bağlı modeldir. **Editable Children** ile onun mesh malzemelerini
düzenleyebilirsin. Gizli Torso, Boot vb. düğümler IK / fizik hedefleridir;
onların mesh'ini değiştirmek görünen rigli modeli değiştirmez.

Üç özgün karakterin düzenlenebilir Blender kaynağı
`assets/models/source/original_players.blend` içindedir. Cobalt şutçu,
Amber kaleci ve Graphite baraj oyuncusudur. Şekil / detay düzenlemelerini
bu dosyada yap; ilgili karakterin gövde ve armature nesnelerini seçerek
aynı adlı GLB'ye export et (Y Up, skin açık, animasyon export kapalı).
Kemik isimlerini ve rest pozunu koru. Blender kaynak dosyası oyuna
paketlenmez. Kaynakta üç karakter yan yana durur; export öncesinde seçili
karakterin rig kökünün X konumunu 0 yap (export sonrasında geri alabilirsin).
`tools/build_original_players.py` modelleri baştan üretir;
elle yaptığın model düzenlemelerini korumak için bunu tekrar çalıştırma.

IK uzuv pozlarını her fizik adımında günceller ve Skeleton3D rigini sürer;
hazır animasyon klibi kullanılmaz. Geçici kemik / hedef konumları kalıcı
animasyon düzenlemesi değildir. Hareketi Inspector'daki IK ve koşu
ayarlarıyla düzenle. `Rig Rest Parts`, IK–rig eşleşmesinin bind pozudur;
modelin bind pozunu değiştirmedikçe bu alanı değiştirme.
Kaleci ve baraj sıfırlamalarda korunur; kullanılmayan baraj oyuncuları
görünmez ve çarpışmaz.

File editörde küçük bir önizleme gösterir; oyun başlayınca aynı düğüme
fizik parçacıklarına bağlı detaylı ip mesh'i gelir. Fileyi Cloth ayarlarından
düzenle. Kale ölçüleri, top yarıçapı ve gol düzlemi mevcut fizik hesabının
parçasıdır; yalnız direğin görselini taşımak gol alanını değiştirmez.
Görsel ve çarpışma düğümlerini birlikte düzenle.

`tests/editor_authoring_tests.gd`, düzenlemelerin oyuna uygulanmasını,
sıfırlamada korunmasını ve arayüz bağlantılarını denetler.

İkinci Boşluk / Vur basışı isteğe bağlıdır: yaklaşma sırasında alttaki
barın kırmızı bölgesi zayıf ve sapmalı, turuncu bölgesi normal, yeşil
bölgesi %8 güçlü ve daha isabetli şut verir. Basılmazsa normal şut olur.
Her seviyedeki üçüncü gol bir üst seviyeyi teklif eder; kabul edilene
kadar kaleci seviyesi değişmez. Zor seviyede yeni teklif çıkmaz.

Web paketini yenilemek için:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_web.ps1
```
