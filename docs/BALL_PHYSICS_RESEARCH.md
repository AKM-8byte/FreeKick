> Güncel durum (14 Ekim 2026): Simulation modu kullanıcı isteğiyle kaldırıldı. Bu belgedeki o modele ilişkin araştırma ve öneriler tarihsel kayıttır; oyunda uygulanmış güncel özellik olarak okunmamalıdır. Oyun mevcut Arcade fiziğini kullanır.

# Futbol topu fiziği araştırması

Tarih: 13 Ekim 2026. Aşağıdaki bağlantılar araştırma sırasında erişilen
birincil makale, yazar yayınları veya resmî belgelerdir. Açılmayan tam
metinlerin sonuçları yalnız indekslenen özet kapsamındadır. Oyun modeli
CFD / sonlu eleman çözümü değildir; deneysel eğilimlerle sınırlandırılmış
indirgenmiş modeldir. Evrensel futbol topu katsayıları iddia edilmez.

## Boyut ve SI

[IFAB Law 2](https://www.theifab.com/laws/2025-26/the-ball/): maç başında
410–450 g, çevre 68–70 cm. Buradan r=C/(2π)≈0.1082–0.1114 m hesaplanır.
Simulation referansı m=0.43 kg, r=0.11 m; A=πr²≈0.0380 m².
g=9.81 m/s², rho=1.225 kg/m³, dinamik viskozite 1.81e-5 Pa·s,
standart deniz seviyesi / yaklaşık 15 °C varsayımıdır. Bunlar hava koşulu
alanlarıyla değiştirilebilir; sıcaklık otomatik hava modeli değildir.

## Re, drag crisis, yüzey

[Hong & Asai 2017, Heliyon](https://pmc.ncbi.nlm.nih.gov/articles/PMC5714554/)
on farklı yüzeyi rüzgâr tünelinde karşılaştırır. Ölçümler 7–35 m/s;
aynı panel sayısında bile çukur / kabartma ve dikişler sürüklemeyi
değiştirir. Bazı örneklerin süperkritik minimum Cd'si yaklaşık 0.11–0.14.
Bu nedenle tek katsayı yerine Re tablosu ve yüzey profili gerekir.

[Asai & Hong 2013](https://springerplus.springeropen.com/counter/pdf/10.1186/2193-1801-2-171):
Roteiro, Teamgeist II, Jabulani, Tango 12 için kritik Re sırasıyla yaklaşık
2.2e5, 2.8e5, 3.3e5, 2.4e5; minimum Cd yaklaşık 0.12, 0.13, 0.13, 0.15.
Sonuçlar panel / dikiş farkıyla uyumludur; tüm toplara tek kritik hız
atanamaz. Tam PDF erişimi bu oturumda sınırlı; sayılar indekslenen
makale özetinden doğrulandı.

[Hong vd. 2020, Applied Sciences](https://www.mdpi.com/2076-3417/10/13/4543/xml)
CFD ile rüzgâr tüneli / serbest uçuşu karşılaştırır. İndekslenen metinde
spinsiz CFD ortalamaları Re=1.25e5 → Cd≈0.39, 2.80e5 → 0.19,
4.00e5 → 0.14. Bu üç nokta kalibrasyon için açık etiketli **CFD referansı**
olarak kullanılacak; bağımsız ham deneysel ölçüm diye sunulmayacak.
Spinning CFD'de Sp=0.1/0.2/0.3 için Cd≈0.28/0.34/0.36 bulunması
spinle drag'ın da değişebildiğini gösterir. Tam metin erişim hatası
nedeniyle daha ayrıntılı sayılar veya çizgi digitizasyonu uydurulmadı.

Re=rho·2r·|v-wind|/mu. Düşük Re'de Stokes sınırına yumuşak geçiş;
ölçülmüş aralık dışındaki yüksek Re'de son tablo değerini tutmak,
kontrolsüz lineer extrapolation'dan daha güvenlidir. Geçişin ayrıntısı
ölçüm değil model varsayımıdır.

## Magnus / spin

[Goff vd. 2020](https://www.mdpi.com/2504-3900/49/1/88)
gerçek uçuşta yanal kuvveti yüksek hızlı görüntüleme ile ele alır;
dikey spin ekseni varsayımı lift yönüne genellenirken dikkat gerekir.
[CFD makalesi](https://www.mdpi.com/2076-3417/10/13/4543/xml) Sp=omega·r/U
tanımını kullanır. Ölçülen katsayı yüzey ve Re ile değişir.
Modelde S için akışa dik spin bileşeni kullanılacak; akışa paralel spin
yanal Magnus üretmeyecek. Yön omega×v_rel, büyüklük 0.5rhoAv²Cl(S).
Cl(0)=0 ve sınırlı üst değer sağlanır. Veri yetersiz bölgede doygun
eğri bir **kalibre edilebilir yaklaşık**; evrensel deneysel yasa değildir.
Drag / lift farklı kaynaklarda farklı çünkü top, destek aparatı,
serbest uçuş, CFD ve sınır tabakası şartları aynı değildir.

## Düşük spin / ölü yaprak

[Hong & Asai 2010, J-STAGE](https://www.jstage.jst.go.jp/article/jjpehss/advpub/0/advpub_09053/_article/-char/en)
serbest uçuşta yaklaşık 2 N tepe vortex lift ve ortalama 3.5 Hz kuvvet
salınımı bildirir; bunlar her top / hız için sabitler değildir.
[Hong vd. 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8100144/)
15 m/s'de Pelada ile Flight topunun farklı yanal / lift dalgalanmalarını
bildirir; çalışma spinsiz sabit tünel topuyla sınırlıdır.
Bu yüzden şuta bağlı tohumla düzgün wake dalgalanması, düşük spin
eşiği, Re geçiş zarfı ve dinamik basınç ölçeği kullanılacak. Rastgele
teleport / her kare yeni gürültü yok. Model kuvvet dalgalanmasını temsil
eder; gerçek wake fazını tahmin ettiği iddia edilmez.

## Spin kaybı, çarpışma, zemin

[Tuplin vd. 2012](https://journals.sagepub.com/doi/abs/10.1177/1754337112444402)
uçuş simülasyonunda spin kaybı ve tam Re drag profili gereğini vurgular.
Bu erişimde sayısal spin torku ölçümü bulunamadı. Hava spin kaybı
pozitif sönüm torkuyla modellenir; katsayısı **belirsiz kalibrasyon
parametresidir**, makaleden elde edilmiş sabit diye sunulmaz.

[Rebound çalışması 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7146741/)
beton için 0.825, yapay çim için 0.65 değerlerini açıklayıcı COR
karşılaştırması olarak kullanır; evrensel ölçüm değildir.
[Penn State deneysel yüzey testi](https://plantscience.psu.edu/research/centers/ssrc/documents/pennbounce.pdf)
COR'un çarpma açısıyla değiştiğini bildirir.
[Price vd. 2006](https://www.sciencedirect.com/science/article/abs/pii/S0921509306000670)
yaklaşık 34 m/s sert yüzey çarpışmasında panel / malzeme yönüne bağlı
deformasyon, temas süresi ve enerji kaybını inceler. Oyun bu maliyetli
deformasyonu çözmez; normal restitution ve teğetsel sürtünmeyi motor
çözer. Top basıncı / malzeme etkisi bu katsayılara indirgenir.

Kayma u=v+omega×(-r·n) ile temas noktasından anlaşılır. Motorun Coulomb
sürtünmesi spin aktarımını sağlar; buna ikinci kayma impulsu eklenmez.
Yuvarlanma direnci kayma sürtünmesi değildir: küçük, enerjiyi azaltan
direnç torku ayrı eklenebilir. Çim ıslaklığı / kesim / zemin deformasyonu
verisi yoksa tek doğru mu veya yuvarlanma katsayısı iddia edilemez.
İnce kabuk I≈(2/3)mr² başlangıç geometrik yaklaşımıdır; gerçek çok katmanlı
topun ölçülmüş atalet tensörü değildir.

## Motor ve kaleci

[Godot doğrudan durum belgesi](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html)
kuvvetin her fizik adımında, impulsun yalnız çarpma anında uygulanmasını
destekler. Yerçekimi motor tarafından bir kez uygulanır; CCD korunur.
[Kaleci algı çalışması](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2020.00311/full)
penaltılarda yüksek / alçak el hareketinin yaklaşık temas sonrası 245 ms,
yan seçiminin temas öncesi ayrışabildiğini raporlar. Bu bir serbest vuruş
tepki süresi sabiti değildir. Modelde gecikmeli gözlem, ölçüm hatası ve
commit sınırı için gerekçe olarak kullanılacak.
[Dalış biyomekaniği](https://pubmed.ncbi.nlm.nih.gov/30036138/)
yüksek ve düşük dalışların farklı düşey momentum ve bacak katkılarını
gösterir. Mevcut ayak basma / balistik kalça sistemi korunacak.

## Kalibrasyon sınırı

Üç Cd referans noktasıyla tüm Cl, spin decay, zemin sürtünmesi ve wake
parametreleri belirlenemez. Kalibrasyon yalnız gözlenebilir parametreyi
sınırlı aralıkta fit etmeli; veri kaynağı, veri türü, RMSE ve belirsizlik
kayıtta tutulmalı. Analitik vakum testi güçlü sayısal doğrulama sağlar;
gerçek futbol topu eşleşmesini tek başına kanıtlamaz.
