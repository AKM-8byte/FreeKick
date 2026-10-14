# Fizik laboratuvarı ve ayar profilleri

Simulation kaldırıldığı için ona bağlı Cd eğrisi kalibrasyonu da kaldırıldı. `data/calibration/` içindeki kaynaklı araştırma verileri korunmuştur; mevcut oyun fiziğinin bu verilere kalibre edildiği iddia edilmez.

`scenes/physics_lab.tscn` sahnesini F6 ile açın. Laboratuvar oyunun mevcut top modelini kullanır. Başlangıç konumu, hız, açı, spin ekseni, spin, hava direnci, Magnus şiddeti, zemin ve tohum değiştirilebilir. On hazır deney ve aynı şutu tekrarlama bulunur. Hava direncinin sıfır olduğu atışta uçuş süresi analitik sonuçla karşılaştırılır.

Ölçümler `user://physics-lab/latest.json` ve `latest.csv` olarak kaydedilir. Durmayan top için durma mesafesi uydurulmaz; timeout bilgisi bulunur. İzler ve ölçümler başlangıçta dondurulan girdilere bağlıdır; sonraki atışın ayarları devam eden ölçümü değiştirmez.

Profil kaydet/yükle düğmeleri mevcut top fiziği Resource'unu kullanır. Godot FreeKick Lab dock'unda fizik profili düzenlenebilir, kaydedilebilir, yüklenebilir ve sahneye bağlanabilir. Uçuş anındaki canlı düzenlemeler sonraki hazırlığa ertelenir.
