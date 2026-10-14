@tool
extends RefCounted

# Descriptions are presentation metadata, not another store of physics values.
# Type, range and current value are reflected from the actual Resource / scene node.
const INFO := {
	"level": ["Kalite seviyesi", "", "Web Low / Medium / High profil kimliği; fizik adımı değişmez."],
	"profile_name": ["Profil adı", "", "Kaydedilen ayar profilini tanımlar."],
	"provenance": ["Kaynak / belirsizlik", "", "Veri kaynağı, kalibrasyon ve modelin geçerlilik sınırları."],
	"mass": ["Kütle", "kg", "Aynı impuls için hız J/m olur; yerçekimi ivmesi kütleden bağımsızdır."],
	"radius": ["Yarıçap", "m", "Kesit alanı, inertia, görünür top ve çarpışma yarıçapını birlikte belirler."],
	"strength": ["Vuruş kuvveti ölçeği", "×", "Ayağın başlangıç temas hızını ölçekler; havada ek itki üretmez."],
	"gravity": ["Yerçekimi", "m/s²", "Motor tarafından bir kez uygulanan düşey ivme."],
	"drag": ["Sürükleme ölçeği", "×", "Mevcut uçuş modelinin hava direnci çarpanı."],
	"magnus_enabled": ["Magnus etkisi", "", "Dönen topa havada etki eden Magnus kuvvetini açar / kapatır. Spin ve hava direnci korunur."],
	"curl": ["Magnus şiddeti", "×", "Spin kaynaklı Magnus kuvvetini ölçekler."],
	"bounce": ["Sekme e", "", "Normal hız oranı. Enerji korunumu için 0–1; motor çarpışma çözümünü kullanır."],
	"friction": ["Kayma sürtünmesi μ", "", "Motorun teğetsel impulsu kaymayı dönmeye aktarır."],
	"knuckle": ["Ölü yaprak ölçeği", "×", "Ölü yaprak şutunun düzensiz hava hareketini ölçekler."],
	"reaction_delays": ["Tepki gecikmesi · Kolay / Dengeli / Zor", "s", "Şuttan sonra ilk kararı verme gecikmesi."],
	"running_speeds": ["Pozisyon alma hızı · K/D/Z", "m/s", "Yatay yer değiştirme hız sınırı."],
	"diving_speeds": ["Dalış hızı · K/D/Z", "m/s", "Dalıştaki yatay hızın fiziksel üst sınırı."],
	"spin_readings": ["Falso tahmin oranı · K/D/Z", "", "Gözlenen spinin tahminde kullanılan oranı; tam gelecek bilgisi değildir."],
	"decision_windows": ["Dalış karar penceresi · K/D/Z", "s", "Kesişim yaklaşınca destek ayağı / dalış hazırlığına geçiş."],
	"observation_delays": ["Algı gecikmesi · K/D/Z", "s", "Kararda kullanılan top gözleminin yaşı. Güncel hızdan kusursuz gelecek bilgisi alınmaz."],
	"prediction_errors": ["Tahmin hata payı · K/D/Z", "m", "Şut tohumundan üretilen sınırlı hedef sapması."],
	"velocity_errors": ["Hız tahmini hatası · K/D/Z", "m/s", "Algılanan hıza eklenen düzgün, tekrarlanabilir ölçüm hatası."],
	"running_accelerations": ["Koşu ivmesi · K/D/Z", "m/s²", "Pozisyon alırken gerçek yatay ivme sınırı."],
	"vertical_dive_speeds": ["Dalış düşey hızı · K/D/Z", "m/s", "Sıçramadaki düşey hız üst sınırı."],
	"observation_interval": ["Gözlem aralığı", "s", "Yörünge tahmininin tekrar hesaplanma aralığı."],
	"dive_set_seconds": ["Dalış hazırlık süresi", "s", "Destek ayağını basma ve itişe hazırlanma süresi."],
	"maximum_hand_adjustment": ["Dalış sonrası el düzeltme sınırı", "m", "İlk hedefe göre toplam düzeltme sınırı; kalça havada yön değiştirmez."],
	"perception_seed": ["Algı tohumu", "", "Aynı şut girdileriyle aynı algı hatalarını yeniden üretir."],
	"normal_hand_correction": ["Dengeli el düzeltmesi", "m", "Dalışta yalnız el hedeflerinin sınırlı düzeltmesi; kalça yeniden yönlenmez."],
	"hard_hand_correction": ["Zor el düzeltmesi", "m", "Zor seviyede gözlem başına erişim düzeltme sınırı."],
	"minimum_wall_distance": ["En az baraj uzaklığı", "m", "Top–baraj mesafesinin alt sınırı."],
	"wall_distance_ratio": ["Baraj mesafe oranı", "", "Top kale mesafesine göre barajın yerleşim oranı."],
	"wall_actor_scale": ["Baraj boy ölçeği", "×", "Fizik / görsel baraj oyuncularının ölçeği."],
	"wall_spacing": ["Baraj aralığı", "m", "Yan yana oyuncu merkezleri arasındaki uzaklık."],
	"thigh_length": ["Üst bacak uzunluğu", "m", "İki kemikli IK ilk segment uzunluğu."],
	"shin_length": ["Alt bacak uzunluğu", "m", "İki kemikli IK ikinci segment uzunluğu."],
	"upper_arm_length": ["Üst kol uzunluğu", "m", "Kol IK ilk segmenti."],
	"forearm_length": ["Ön kol uzunluğu", "m", "Kol IK ikinci segmenti."],
	"idle_pelvis_height": ["Ayakta pelvis yüksekliği", "m", "Duruş için pelvis hedefi; erişim sınırı uygulanır."],
	"knee_pole": ["Diz yönü", "", "Dizin bükülme düzlemi. Sıfır / paralel durumda güvenli fallback vardır."],
	"rig_ik_weight": ["Görsel IK ağırlığı", "", "Rig pozunu rest pozuyla harmanlar. Fizik IK hedefleri bağımsız kalır."],
	"visual_update_hz": ["Rig güncelleme sıklığı", "Hz", "Yalnız görsel rig. Sıfır her kare; fizik / çarpışma adımı değişmez."],
	"initial_target": ["Başlangıç hedefi", "m", "Hazırlıkta seçili kale hedefi; top fiziğinin kuvvet parametresi değildir."],
	"charge_seconds": ["Güç doldurma süresi", "s", "Basılı tutma ile 0–1 güce erişim süresi."],
	"ball_camera_fov": ["Top kamerası FOV", "°", "Hazırlık kamerasının görüş açısı."],
	"ball_camera_offset": ["Top kamerası uzaklığı", "m", "Yatay, yükseklik ve gerideki kamera mesafesi."],
	"player_camera_fov": ["Oyuncu kamerası FOV", "°", "Oyuncu arkasından / üstünden görüş açısı."],
	"player_camera_offset": ["Oyuncu kamerası uzaklığı", "m", "Fizikten bağımsız kamera konumu."],
	"runup_distance": ["Yaklaşma mesafesi", "m", "Oyuncunun yanal / geriye başlangıç mesafesi."],
	"runup_seconds": ["Yaklaşma süresi", "s", "Adımlama süresi; hazır animasyon klibi kullanılmaz."],
	"backswing_seconds": ["Geriye açılma süresi", "s", "Destek ayağı sabitken vuruş ayağının geriye hareketi."],
	"stride_height": ["Adım yüksekliği", "m", "Koşudaki ayağın yerden kalkma genliği."],
	"perfect_power_bonus": ["Yeşil zamanlama güç bonusu", "×", "İsteğe bağlı vuruş oyun yardımı; laboratuvar başlangıcına uygulanmaz."],
	"perfect_aim_assistance": ["Yeşil zamanlama isabet yardımı", "", "Başlangıç koşullarındaki sınırlı oyun yardımı."],
	"replay_speed": ["Sinematik hızı", "×", "Kayıt oynatma hızı; canlı fizik zaman adımını değiştirmez."],
	"render_scale": ["3D render ölçeği", "×", "UI çözünürlüğünden bağımsız 3D render ölçeği."],
	"shadows": ["Gölgeler", "", "Kalite profilindeki görsel gölge maliyeti."],
	"msaa": ["MSAA", "", "Kenar yumuşatma; yalnız render maliyetini değiştirir."],
	"skeleton_rate": ["Kalite rig sıklığı", "Hz", "Platform profili görsel rig sıklığı; fizik sabit kalır."],
	"net_visual_density": ["File görsel yoğunluğu", "×", "Görünen ip mesh yoğunluğu. Fizik parçacıkları / solver değişmez."],
	"grass_details": ["Çim detayları", "", "Normal / roughness texture ayrıntısı ve shader maliyeti."],
	"stadium_details": ["Çevre detayları", "", "Uzak dekoratif tribün detayları; fizik engellerini değiştirmez."],
	"flight_trail": ["Uçuş izi", "", "İsteğe bağlı görsel iz; yörüngeye kuvvet uygulamaz."],
	"cloth_damping": ["File sönümü", "1/s", "Cloth hareketinin enerji kaybı."],
	"solver_iterations": ["Cloth iterasyonları", "", "File fizik constraint çözümünün iterasyon sayısı."],
	"rope_radius": ["İp yarıçapı", "m", "Görünen file ipinin kalınlığı."],
	"rope_color": ["File rengi", "", "Yalnız görsel malzeme rengi."],
	"enabled": ["Tutorial etkin", "", "İlk açılış tutorial akışını etkinleştirir."],
	"persistence_version": ["Tutorial sürümü", "", "Kaydedilmiş tamamlanma bilgisinin sürümü."],
	"allow_skip": ["Tutorial atlama", "", "Oyuncunun tutorial'ı atlamasına izin verir."],
	"goalkeeper_level": ["Tutorial kaleci seviyesi", "", "Öğrenme sırasında zorluk; gol zorunlu değildir."],
	"minimum_power": ["Tutorial güç eşiği", "", "Güç aşamasındaki minimum deneme eşiği."],
	"minimum_side_contact": ["Tutorial falso eşiği", "", "Falso aşamasında yan temas miktarı."],
	"practice_shots": ["Serbest deneme sayısı", "", "Gol sonucu yerine şut denemesi sayılır."],
	"show_timing_tip": ["Zamanlama açıklaması", "", "İkinci basışın isteğe bağlı olduğunu açıklar."]
}

static func properties(target: Object) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var reference: Resource
	if target.get_script() != null and target.get_script().resource_path == "res://scripts/ball_physics_profile.gd":
		var path := "res://settings/arcade_physics.tres"
		reference = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	for property in target.get_property_list():
		var key := String(property.name)
		if INFO.has(key) and property.usage & PROPERTY_USAGE_EDITOR:
			var item: Dictionary = property.duplicate()
			item.title = INFO[key][0]
			item.unit = INFO[key][1]
			item.description = INFO[key][2]
			item.default = reference.get(key) if reference else default_value(target, key)
			output.append(item)
	return output

static func default_value(target: Object, key: String) -> Variant:
	if target.get_script() != null and target.get_script().resource_path == "res://scripts/quality_profile.gd":
		var reference: Resource = ResourceLoader.load(["res://settings/web_low.tres", "res://settings/web_medium.tres", "res://settings/web_high.tres"][clampi(target.level, 0, 2)], "", ResourceLoader.CACHE_MODE_IGNORE)
		return reference.get(key)
	if target.get_script() != null and target.get_script().resource_path == "res://scripts/ball_physics_profile.gd":
		var path := "res://settings/arcade_physics.tres"
		var reference: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		return reference.get(key)
	if target.get_script() != null:
		return target.get_script().get_property_default_value(key)
	return target.get(key)

static func numeric_range(property: Dictionary) -> Vector3:
	if property.hint == PROPERTY_HINT_RANGE:
		var fields := String(property.hint_string).split(",")
		return Vector3(float(fields[0]), float(fields[1]), float(fields[2]) if fields.size() > 2 else 0.01)
	var key := String(property.name)
	if key in ["reaction_delays", "decision_windows"]:
		return Vector3(0.01, 2.0, 0.005)
	if key == "observation_delays": return Vector3(0, 0.5, 0.005)
	if key == "prediction_errors": return Vector3(0, 1.0, 0.01)
	if key == "velocity_errors": return Vector3(0, 3.0, 0.01)
	if key == "running_accelerations": return Vector3(0, 30, 0.1)
	if key == "vertical_dive_speeds": return Vector3(0, 8, 0.1)
	if key == "spin_readings":
		return Vector3(0, 1, 0.01)
	if key in ["running_speeds", "diving_speeds"]:
		return Vector3(0, 10, 0.05)
	return Vector3(-100, 100, 0.01)

static func snapshot(target: Object) -> Dictionary:
	var data := {}
	for property in properties(target):
		data[property.name] = target.get(property.name)
	return data

static func validate_values(target: Object, data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var allowed := {}
	for property in properties(target):
		allowed[property.name] = property
	for key in data:
		if not allowed.has(key):
			errors.append("Bilinmeyen parametre: " + String(key))
			continue
		var property: Dictionary = allowed[key]
		var value = data[key]
		if typeof(value) != property.type and not (property.type == TYPE_FLOAT and typeof(value) == TYPE_INT):
			errors.append("Parametre türü yanlış: " + String(key))
			continue
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			var limits := numeric_range(property)
			if not is_finite(value) or (property.hint == PROPERTY_HINT_RANGE and (value < limits.x or value > limits.y)):
				errors.append("Parametre aralık dışında / sonlu değil: " + String(key))
		if value is Vector2 or value is Vector3:
			if not value.is_finite():
				errors.append("Vektör sonlu değil: " + String(key))
		if value is PackedFloat32Array:
			var limits := numeric_range(property)
			if value.size() != 3:
				errors.append("K/D/Z dizisi üç değer içermeli: " + String(key))
			for number in value:
				if not is_finite(number) or number < limits.x or number > limits.y:
					errors.append("Dizi değeri aralık dışında: " + String(key))
	if target is Resource and target.has_method("validate") and errors.is_empty():
		var candidate: Resource = target.duplicate(true)
		for key in data:
			candidate.set(key, data[key])
		errors.append_array(candidate.validate())
	return errors
