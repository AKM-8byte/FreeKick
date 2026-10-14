extends Node

var tutorial_pending := false
var guide_seen := false
var language_mode := "auto"
const ENGLISH := {
	"TANITIMI YENİDEN OYNA": "PLAY TUTORIAL AGAIN",
	"TANITIMI ATLA": "SKIP TUTORIAL",
	"ANA MENÜYE GEÇ": "GO TO MAIN MENU",
	"DEVAM": "CONTINUE",
	"1 / 4 · NİŞAN AL": "1 / 4 · AIM",
	"2 / 4 · GÜCÜ AYARLA": "2 / 4 · CHARGE POWER",
	"3 / 4 · FALSO VER": "3 / 4 · ADD SPIN",
	"4 / 4 · SERBEST DENEME": "4 / 4 · FREE PRACTICE",
	"Kaleye tıkla veya sürükle. Hedefi seçince Devam'a bas. Yön kontrolleri: %s · %s": "Click or drag on the goal, then continue. Aim controls: %s · %s",
	"%s tuşunu veya VUR düğmesini basılı tut. Güç dolunca bırak; oyuncu topa yaklaşarak vurur.": "Hold %s or SHOOT to charge power. Release to let the player approach and kick.",
	"Topun sağ veya sol yanını seç, sonra şut çek. Alt temas yükseltir, üst temas alçaltır. Temas kontrolleri: %s · %s": "Select the left or right side of the ball, then shoot. Bottom contact lifts; top contact stays low. Contact controls: %s · %s",
	"Öğrendiklerini dene. Gol atman gerekmiyor. %s veya TEKRAR ile yeni şuta geçebilirsin.": "Try what you learned. No goal is required. Use %s or RETRY for another shot.",
	"İkinci basışla zamanlama isteğe bağlıdır; basmazsan normal vurursun.": "A second press for timing is optional; skip it for a normal shot.",
	"Tamamlandı — devam edebilirsin.": "Completed — you can continue.",
	"Bu adımı deneyerek tamamla. Gol şart değil.": "Try this step to complete it. No goal is required.",
	"Kaynaklar yükleniyor…": "Loading resources…",
	"Kaynaklar hazır": "Resources ready",
	"Tamamlanan kaynak: %d / %d": "Completed resources: %d / %d",
	"Sahne kuruluyor…": "Building scene…",
	"Grafikler hazırlanıyor…": "Preparing graphics…",
	"Yükleme başarısız": "Loading failed",
	"Hazırlanıyor…": "Preparing…",
	"GÖRSEL KALİTE": "VISUAL QUALITY",
	"VURUŞ ZAMANLAMASI": "SHOT TIMING",
	"Boşluk / Vur: tekrar bas · Basmazsan normal şut": "Space / Shoot: press again \u00b7 Skip for a normal shot",
	"MÜKEMMEL! · GÜÇ + İSABET": "PERFECT! \u00b7 POWER + ACCURACY",
	"NORMAL VURUŞ": "NORMAL SHOT",
	"ERKEN! · ZAYIF VE SAPMALI": "EARLY! \u00b7 WEAK AND OFF TARGET",
	"TEKRAR BAS: ZAMANLA": "PRESS AGAIN: TIME SHOT",
	"3 GOL! · YENİ BİR MEYDAN OKUMA?": "3 GOALS! \u00b7 READY FOR A CHALLENGE?",
	"Kaleciyi %s seviyesine yükseltmek ister misin?": "Raise the goalkeeper to %s difficulty?",
	"SEVİYEYİ YÜKSELT": "RAISE DIFFICULTY",
	"BU SEVİYEDE KAL": "STAY AT THIS LEVEL",

	"Alt: yükseliş · Üst: alçak şut · Yan: falso": "Bottom: lift \u00b7 Top: low shot \u00b7 Side: curl",
	"Basılı tutarken güç dolar. Bıraktığında oyuncu şutu çeker.": "Hold to charge power. Release to make the player kick.",
	"Kale çizgisine uzaklık. Top ceza sahasının dışında kalır.": "Distance from the goal line. The ball stays outside the penalty area.",
	"Eksi: sol taraf · Artı: sağ taraf": "Negative: left side \u00b7 Positive: right side",
	"Topun kütlesi. Aynı vuruşta ağır top daha yavaş çıkar.": "Ball mass. A heavier ball launches more slowly from the same kick.",
	"Ayağın topa aktardığı kuvveti artırır veya azaltır.": "Increase or reduce the force transferred by the foot.",
	"Yükselişten sonra topun aşağı çekilme kuvveti.": "Downward acceleration after the ball rises.",
	"Topun uçuş sırasında ne kadar hız kaybettiği.": "How quickly the ball loses speed during flight.",
	"Yandan temasın topu havada ne kadar büktüğü.": "How much side contact bends the ball in flight.",
	"Topun zeminden ne kadar geri sıçradığı.": "How strongly the ball bounces off the ground.",
	"Yerde yuvarlanan topun ne kadar hızlı yavaşladığı.": "How quickly a rolling ball slows down.",
	"Az dönen ölü yaprak şutunun düzensiz hava hareketi.": "Irregular flight of a low-spin knuckleball.",

	"1 · Kaleye tıkla: nişan al     2 · Topa tıkla: temas / falso seç\n3 · Boşluk veya Vur: basılı tut, gücü seç; bırakınca şut çek": "1 · Click the goal: aim     2 · Click the ball: choose contact / curl\n3 · Hold Space or Shoot to charge; release to kick",
	"BASILI TUT → BIRAK / VUR": "HOLD → RELEASE / SHOOT",
	"Kolay: daha geç tepki, kısa uzanış.\nDengeli: köşeler hâlâ gol olabilir.\nZor: hızlı tepki ve iyi falso okuma.": "Easy: later reaction, shorter reach.\nNormal: corners remain scoreable.\nHard: quick reactions, better curl reading.",
	"TAM EKRAN": "FULLSCREEN",
	"GÜÇ %%%d": "POWER %d%%",
	"SERBEST VURUŞ ARENASI": "FREE KICK ARENA",
	"SERBEST VURUŞ": "FREE KICK",
	"ANTRENMAN  [Tab]": "TRAINING  [Tab]",
	"YÖNÜNÜ SEÇ": "CHOOSE YOUR AIM",
	"MERKEZ TEMAS": "CENTRE CONTACT",
	"Kaleye tıkla / sürükle   •   Top üzerinde temas seç   •   Boşluk: güç / bırak: vur": "Click / drag on goal   •   Select ball contact   •   Hold Space: power / release: shoot",
	"KALEYE UZAKLIK": "DISTANCE TO GOAL",
	"Çıkış hızı —": "Launch speed —",
	"GÜÇ %0": "POWER 0%",
	"ÖNERİ: %50–65": "SUGGESTED: 50–65%",
	"BASILI TUT / VUR": "HOLD / SHOOT",
	"TEKRAR  [R]": "RETRY  [R]",
	"ANTRENMAN AYARLARI": "TRAINING SETTINGS",
	"Uzaklık": "Goal-line distance",
	"Yatay konum": "Lateral position",
	"Baraj": "Wall",
	" kişi": " players",
	"Baraj mesafesi: —": "Wall distance: —",
	"KALECİ ZORLUĞU": "KEEPER DIFFICULTY",
	"Kolay": "Easy",
	"Dengeli": "Normal",
	"Zor": "Hard",
	"Uçuş izi": "Flight trail",
	"Alt temas: yükselt • Üst: alçalt\nSağ temas: sola falso\nSol temas: sağa falso\nMerkezin hafif altı: ölü yaprak": "Bottom: lift • Top: lower\nRight contact: curl left\nLeft contact: curl right\nSlightly below centre: knuckleball",
	"GELİŞMİŞ ÖZELLİKLER": "ADVANCED SETTINGS",
	"TOP FİZİĞİ": "BALL PHYSICS",
	"Ayarlar yeni denemeye uygulanır.\nUçuş ve tekrar sırasında kilitlenir.": "Settings apply to the next attempt.\nLocked during flight and replay.",
	"Kütle": "Mass",
	"Vuruş kuvveti": "Kick strength",
	"Yerçekimi": "Gravity",
	"Hava direnci": "Air drag",
	"Falso etkisi": "Magnus strength",
	"Magnus etkisi": "Magnus effect",
	"Magnus şiddeti": "Magnus strength",
	"Spin kaynaklı hava kuvvetini açar / kapatır. Şiddetini falso ayarıyla değiştir.": "Toggle spin-induced aerodynamic force. Adjust its strength with the curl slider.",
	"Sekme": "Bounce",
	"Zemin sürtünmesi": "Ground friction",
	"Ölü yaprak etkisi": "Knuckleball effect",
	"FİZİĞİ VARSAYILANA DÖNDÜR": "RESTORE PHYSICS DEFAULTS",
	"ÖNERİ: %%%d–%d": "SUGGESTED: %d–%d%%",
	"ÖLÜ YAPRAK BÖLGESİ · DÜŞÜK DÖNÜŞ · GÜÇ %55+": "KNUCKLEBALL ZONE · LOW SPIN · POWER 55%+",
	"ALT TEMAS · YÜKSELEN": "BOTTOM CONTACT · RISING",
	"ÜST TEMAS · ALÇAK": "TOP CONTACT · LOW",
	" · SOLA FALSO": " · CURL LEFT",
	" · SAĞA FALSO": " · CURL RIGHT",
	"GÜÇ %": "POWER %",
	"%d GOL  /  %d ŞUT": "%d GOALS  /  %d SHOTS",
	"GOL!": "GOAL!",
	"7 kamera · Sinematik ağır çekim": "7 cameras · Cinematic slow motion",
	"GOLÜ İZLE  ▶": "WATCH GOAL  ▶",
	"Tekrar hazırlanıyor…": "Preparing replay…",
	"GOL TEKRARI": "GOAL REPLAY",
	"GERİ DÖN  [Esc]": "RETURN  [Esc]",
	"Baraj mesafesi: %.1f m": "Wall distance: %.1f m",
	"Alt temas: yükselt • Üst temas: alçalt • Yan temas: falso": "Bottom: lift • Top: lower • Side: curl",
	"GÜCÜ AYARLA": "SET POWER",
	"Bıraktığında koşu ve vuruş başlayacak.": "Release to start the run-up and kick.",
	"VURUŞ HAZIRLANIYOR": "PREPARING THE KICK",
	"Destek ayağı sabitleniyor; temas anında top hareket edecek.": "Planting support foot; the ball moves on contact.",
	"Çıkış hızı %.1f km/sa": "Launch speed %.1f km/h",
	"TOP OYUNDA": "BALL IN PLAY",
	"Topun uçuşunu izle • R: yeniden dene": "Watch the flight • R: retry",
	"Topun tamamı kale çizgisini geçti.  •  R: yeniden dene": "The whole ball crossed the goal line.  •  R: next shot",
	"KAÇTI": "MISSED",
	"KALECİ KURTARDI": "SAVED BY THE KEEPER",
	"BARAJA TAKILDI": "BLOCKED BY THE WALL",
	"DİREK!": "HIT THE POST!",
	"R veya TEKRAR ile aynı ayarlarda yeniden dene.": "Press R or RETRY to try again.",
	"BARAJA ÇARPTI": "HIT THE WALL",
	"KALECİ TEMAS ETTİ": "KEEPER CONTACT",
	"DİREĞE ÇARPTI": "HIT THE POST",
	"Top oyunda; şutun sonucu bekleniyor.": "Ball in play; waiting for the result.",
	"HAZIR": "READY",
	"Boşluk tuşunu basılı tutup bırakarak vur.": "Hold Space for power, release to shoot.",
	"SAHA KENARI": "SIDELINE",
	"KALE ARKASI": "BEHIND GOAL",
	"ÜST AÇI": "HIGH ANGLE",
	"TERS ÇAPRAZ": "REVERSE ANGLE",
	"ÇİM SEVİYESİ": "GRASS LEVEL",
	"KALECİ YAKINI": "KEEPER CLOSE-UP",
	"FİLE YAKINI": "NET CLOSE-UP",
	"GOL TEKRARI · %d/7 · %s · AĞIR ÇEKİM ×0,25 · ← →": "GOAL REPLAY · %d/7 · %s · SLOW MOTION ×0.25 · ← →",
	"SAĞA": "RIGHT",
	"SOLA": "LEFT",
	"DÜZ": "STRAIGHT",
	"ÖLÜ YAPRAK": "KNUCKLEBALL",
	"ÇIKIŞ %.1f km/sa  ·  ANLIK %.1f km/sa  ·  FALSO %s  ·  DÖNÜŞ %.1f tur/sn  ·  GÜÇ %%%d": "LAUNCH %.1f km/h  ·  CURRENT %.1f km/h  ·  CURL %s  ·  SPIN %.1f rev/s  ·  POWER %d%%",
	"OYNA": "PLAY",
	"ÇIKIŞ": "QUIT",
	"DİL": "LANGUAGE",
	"Bilgisayar dili": "System language",
	"ANA MENÜ  [Esc]": "MAIN MENU  [Esc]",
	"KAMERA": "CAMERA",
	"Top odaklı": "Ball view",
	"Oyuncu arkası / üstü": "Behind / above player",
	"SONRAKİ ŞUT  [R]": "NEXT SHOT  [R]",
	"Yeni vuruş konumu hazır. R veya SONRAKİ ŞUT ile devam et.": "New shot position ready. Press R or NEXT SHOT to continue.",
	"Hedef: kaleye tıklayarak veya sürükleyerek nişan al.": "Aim: click or drag on the goal to set your target.",
	"Temas: topun yanına vurmak falso, altına vurmak yükseliş verir.": "Contact: hit the side for curl, below centre for lift.",
	"Ayarlar: uzaklık, baraj, kaleci ve top fiziğini buradan değiştir.": "Settings: change distance, wall, keeper and ball physics here.",
	"Güç: Boşluk veya VUR düğmesini basılı tut; bırakarak şut çek.": "Power: hold Space or SHOOT, release to kick.",
	"Herhangi bir tuşa bas veya tıkla: tanıtımı kapat.": "Press any key or click to close this guide.",
	"KISA TANITIM": "QUICK GUIDE",
	"GERİ DÖN": "RESUME",
	"TANITIMI GÖSTER": "SHOW GUIDE",
}

func _ready() -> void:
	var english := Translation.new()
	english.locale = "en"
	for key in ENGLISH:
		english.add_message(key, message_for_platform(ENGLISH[key]))
	TranslationServer.add_translation(english)
	if OS.has_feature("web"):
		# Native system font fallback is unavailable in the browser. Keep the
		# play/arrow hints readable without changing Windows or shipping OS fonts.
		var turkish := Translation.new()
		turkish.locale = "tr"
		for key in ENGLISH:
			turkish.add_message(key, message_for_platform(key))
		TranslationServer.add_translation(turkish)
	set_language("auto")
	var config := ConfigFile.new()
	if config.load("user://preferences.cfg") == OK:
		guide_seen = config.get_value("guide", "seen", false)

func locale_for_system(system_locale: String) -> String:
	return "tr" if system_locale.to_lower().replace("-", "_").get_slice("_", 0) == "tr" else "en"

func message_for_platform(text: String) -> String:
	return text.replace("←", "<-").replace("→", "->").replace("▶", ">") if OS.has_feature("web") else text

func set_language(language: String) -> void:
	language_mode = language
	TranslationServer.set_locale(locale_for_system(OS.get_locale()) if language == "auto" else language)

func mark_guide_seen() -> void:
	guide_seen = true
	var config := ConfigFile.new()
	config.load("user://preferences.cfg")
	config.set_value("guide", "seen", true)
	config.save("user://preferences.cfg")
