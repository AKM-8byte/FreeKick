# Güncel top fiziği

Simulation modu kaldırıldı. `settings/ball_physics.tres` oyun sahnesinin parametrelerini, `settings/arcade_physics.tres` varsayılan referansı tutar. Mod seçimi ve eski bilimsel model kodu bulunmaz.

`ball.gd` bir RigidBody3D kullanır. Yerçekimini motor uygular; `gravity_scale` profilin yerçekimini proje değerine böler. İtki gerçek ayak temasında bir kez uygulanır. Uçuş kuvvetleri `_integrate_forces` içinde sabit fizik adımında uygulanır.

`flight_model.gd`: Fdrag = −v·|v|·0,0013·drag. FMagnus = (ω × v)·0,0018·curl; büyüklük 4,8·curl ile sınırlıdır. `magnus_enabled=false` yalnız Magnus kuvvetini sıfırlar. `curl` aynı merkezi profilin şiddet parametresidir; ayrı ve çelişen bir ayar yoktur. Hava direnci ve spin sönümü korunur. Mevcut oynanış modeli deneysel olarak kalibre edilmiş bilimsel model iddiası taşımaz.

Motor açısal sönümü 0,22; mevcut şut modeli, ölü yaprak kuvveti, zemin materyali, kaleci çelmesi ve file sönümü korunmuştur. Top yarıçapı görünür modeli ve çarpışma küresini birlikte değiştirir. CCD etkindir.

## File temasının maliyeti

Cloth bağlı parçacıklarla her fizik adımında çözülür. Sabitlenmiş bağlantıların ağırlıkları önceden hesaplanır. Topun süpürdüğü hacim, tüm parçacıkların güncel deformasyon zarfı ve top yarıçapıyla genişletilir. Bu hacmin erişebileceği grid hücreleri seçilir; kesin çarpışma yine deforme olmuş üçgenlerle yapılır. Köşe/birleşimlerde çoklu yüzey onarımı ve temasın cloth'a aktarılması korunur. Görsel ip mesh'i her kare yeniden üretilmez.

`tests/net_broadphase_tests.gd` kale içinden başlayan 360 sabit tohumlu, deforme file içeren sorguyu tam üçgen taramasıyla karşılaştırır. `tests/physics_settings_tests.gd` yan/arka/üst filede 130 m/s hızla canlı top kaçırma denemelerini içerir.
