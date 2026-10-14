Karakter parçaları kurulu Blender 5.2.2 ile üretildi ve `football_parts.glb` olarak oyuna aktarıldı.

Düzenlenebilir kaynak: `source/football_parts.blend`.
Üretim betiği: `tools/build_models_blender.py`.
Parçalar: gövde, kalça, baş, üst/alt bacak, üst/alt kol, krampon ve taban.
Oyun malzemeleri ve forma renkleri Godot tarafından uygulanır.
Kramponda yuvarlatılmış burun, dar topuk, yükselen ayak üstü ve taban vardır.
Bağcık ve taban dişleri Godot'ta eklenir. Eldivenler mevcut modellerdir.

Parçalar metre ölçeğinde ve mevcut analitik IK'nin eksenlerine uygun üretildi.
Blender animasyon klibi kullanılmaz; tüm karakter hareketleri fizik adımında üretilir.
Bu sürüm parçalı, stilize bir karakterdir; tek parça deri deformasyonlu karakter değildir.
`.gdignore`, düzenlenebilir Blender kaynağını otomatik içe aktarımdan çıkarır;
oyun yalnızca GLB dosyasını kullanır ve çalıştırılırken Blender gerekmez.
