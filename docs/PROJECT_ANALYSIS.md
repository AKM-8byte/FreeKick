> Güncel durum (14 Ekim 2026): Simulation modu kullanıcı isteğiyle kaldırıldı. Bu belgedeki o modele ilişkin araştırma ve öneriler tarihsel kayıttır; oyunda uygulanmış güncel özellik olarak okunmamalıdır. Oyun mevcut Arcade fiziğini kullanır.

# Mevcut sistem incelemesi — 13 Ekim 2026

Bu inceleme kod ve sahne kaynaklarına dayanır. Performans nedenleri ölçüm
tamamlanıncaya kadar adaydır; kullanıcının cihazındaki FPS ölçülmüş değildir.

## Fizik akışı

1. `shot_model.gd` hedef için nötr yaklaşmayı iteratif tahmin eder; temas
   ofsetinden itki, açısal hız ve ölü yaprak isteği üretir.
2. `game.gd::_physics_process` 120 Hz'de koşu / iki kemikli IK hedeflerini
   ilerletir. `animate_kick` gerçek ayak temasında tek `ball.strike` çağırır.
3. `ball.gd` RigidBody3D ve Jolt kullanır. `strike` merkezi itki verir;
   spin açısal hıza atanır. Reset bekliyorsa aynı başlangıç koşulları
   `_integrate_forces` doğrudan gövde durumuna aktarılır.
4. `_integrate_forces`: reset / elde tutma → kaleci yanıtı → file sönümü →
   `flight_model.gd` sürükleme / Magnus → `knuckle_flight.gd` → file.
   `custom_integrator=false`; yerçekimini ve çarpışmaları motor uygular.
   Eski `angular_damp=0.22` spin kaybını motor üzerinden verir.
5. Kale düzlemi `game.gd::check_flight` içinde tam top geçişiyle ölçülür.
   Direk / saha / baraj / kaleci fizik gövdeleridir. File ayrıca parçacık
   solverı, kuvvet ve yüksek hızlı geçiş koruması kullanır.

## Doğrudan müdahaleler ve gerçekçilik

Reset/replay/kalecide tutulan topun transform'u bilinçli atanır. File
`contain_sweep` ile konum ve hızı düzeltir; normal oyun uçuşunu yönetmez.
Kaleci kurtarışında hız değişimi ve filede doğrudan hız sönümü vardır.
Bunlar daha sonra enerji kaybı / çift çarpışma açısından ayrı test edilecek.

Eski `DRAG=0.0013 * drag` SI açısından N/(m/s)² boyutlu bir katsayıdır;
Cd değildir. Re, hava yoğunluğu, çap ve yüzey etkisi kullanılmaz. Magnus
`0.0018 * omega×v` ve 4.8 N sınırıyla çalışır: hız / spin bağımlılığı var,
ancak fiziksel lift coefficient modeli yoktur. Ölü yaprak tohumu
tekrarlanabilir sinüs dalgaları kullanır; Re / yüzey / dinamik basınçla
ölçeklenmez. Şut spininde `I=0.4mr²` dolu küre yaklaşımı vardır; futbol
topu için ince kabuk yaklaşımı daha uygundur. Alt/üst temas yönü doğru.

Kütle, kuvvet, yerçekimi, drag, curl, bounce, friction, knuckle:
`physics_settings.gd` runtime API, `ball_physics_profile.gd` Resource ve
`settings/ball_physics.tres` editör kaynağı. Kaynak knuckle varsayılanı
1.50, legacy tablo 0.80: oyun sahnesi ile çıplak test sahnesi aynı profil
olmadığı için farklı davranabilir. Yeni modlar bu farkı açık kaydedecek.

## Ölçek, AI, animasyon

Top yarıçapı 0.11 m, kale 7.32×2.44 m, baraj 9.15 m referansı metreyle
tutarlı. 0.46 kg legacy kütlesi resmî maç aralığının üzerindedir; Arcade'de
saklanacak, Simulation 0.43 kg kullanacak. Çarpışma şekli ve görünür
mesh çapı aynı; değişebilir yarıçap iki tarafa birlikte uygulanmalı.

`defenders.gd` durumları READY → READING → SET → DIVE → LAND → RECOVER.
Tepki gecikmesi ve ivmelenme mevcut. Her 0.10 s tam top durumu ile aynı
uçuş modelinden tahmin alınır; dalışta her 0.06 s el düzeltmesi yapılır.
Bu algılama hatasını ihmal eder ve fiziği modelleyen kaleci fazla isabetli
olabilir. Kalça dalıştan sonra balistiktir; bu doğru sınırlama korunacak.

`procedural_player.gd` iki kemikli bacak / kol IK çözer. 15 kontrol kemiği
Blender skin rigine her render karesinde aktarılır. Hazır klip yoktur.
Fizik çarpışma şekilleri IK hedeflerinden her fizik adımında güncellenir;
görsel rig frekansını azaltmak çarpışma çözümünü değiştirmemelidir.

## Performans adayları

- Koşul olmadan her kare tüm kemik global override'ları, sözlük üretimi,
  inverse / rest transform okumaları; görünmez oyuncularda da çalışıyor.
- Kaleci hazırlıkta 120 Hz'de iki kez `update_pose` çağırıyor.
- File shaderı her rope vertex için dört displacement texture okuması
  ve dört temas döngüsü yapıyor; statik file de aynı shaderı çalıştırıyor.
- File uniform dizileri hiçbir temas yokken de her kare gönderiliyor.
- File mesh'i açılışta script ile üretiliyor; cloth 48 settle adımı var.
- Çim fragment shaderında üç texture ve noise hesapları, büyük ekran
  alanı; Compatibility/MSAA ve gölgeler ayrıca ölçülecek.
- Replay cloth dizilerini 60 Hz kopyalar; yalnız şut sırasında etkin.
- Hedef yardımcı hesabı 12×600'e kadar tahmin adımı yapabilir; başlangıç
  ve güç değişimlerinde ana iş parçacığı maliyeti ölçülecek.
- Ana menü `change_scene_to_file` ile ağır sahneyi senkron açıyor.

## Uygulama sırası ve açık işler

Analiz / ölçüm → kaynak araştırması → ortak profilli fizik laboratuvarı →
Simulation + Arcade → editör dock / Inspector → algı sınırlı kaleci → Web
kalite / animasyon optimizasyonu → gerçek ilerlemeli yükleme → etkileşimli
tutorial / giriş eşlemeleri → Windows / tarayıcı doğrulama ve dokümantasyon.
Model, saha, ses ve logo projede var. Zorunlu kullanıcı asset'i yok.
Ek deneysel Cd/Cl ham verisi ve gerçek mobil cihaz ölçümü opsiyonel;
yokluğunda tahmini katsayılar ve cihaz sınırları açık belirtilecek.
