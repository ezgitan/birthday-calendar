# İyi ki • iOS widget veri aktarımı ve cihaz testi

## İncelemede doğrulananlar

- Runner ve BirthdayWidget, Debug/Release/Profile yapılandırmalarında kendi entitlements dosyalarını kullanıyor. İkisinin de istediği grup `group.com.birthdaycalendar.shared`.
- Önceki Flutter kodu `HomeWidget.setAppGroupId` sonrası `birthdays` anahtarına JSON metni yazıyordu. Widget aynı suite ve anahtarı okuyordu. Runner ayrıca standart UserDefaults içindeki `flutter.birthdays` değerini aynı paylaşılan anahtara kopyalıyordu. İki yazıcı farklı JSON biçimleri üretiyordu.
- Bu sürümde kullanılan home_widget 0.10.0 kaynak kodunda `setAppGroupId` grup adını kaydedip başarı döndürüyor. `saveWidgetData` ise optional suite üzerinden yazıp gerçek ortak alan erişimini doğrulamadan başarı döndürebiliyor. Runner’daki ikinci yazıcı da başarısız guard durumunda sessizce dönüyordu.
- Önceki “Günlerini bağlayalım” başlığı tam olarak `raw == nil` durumundaydı. Altındaki eşitleme yazısı `raw == nil || rows == nil` koşulundaydı. Hatalı JSON ile geçerli boş listeyi ve eksik yetki ile henüz yazılmamış anahtarı yeterince ayırt etmiyordu. İlk sürümde okuma veya decode hatası doğrudan boş listeye dönüşebiliyordu.
- Yerel iki IPA'nın paketlenmiş Info.plist dosyaları ve arm64 çalıştırılabilir dosyaları incelendi. `iyi-ki-ios-son-build.ipa` (Runner ve uzantı 1.9.7) ve `iyi-ki-iphone-test.ipa` (Runner 1.9.2, uzantı 1.1.0) içinde iki hedefte de imza yük komutu ve gömülü provisioning profili yok. Bunlar kurulu son imzayı kanıtlamıyor.
- İki IPA’da da uzantı `Runner.app/PlugIns/BirthdayWidget.appex` içinde ve extension point `com.apple.widgetkit-extension`. Kaynakta giriş noktası SwiftUI `@main BirthdayWidget`. Önceden görülen AppexBundleMissingClassOrStoryboard yükleme/paket tanımlama aşamasına aittir. Hatayı üreten orijinal kurulum logu olmadan kesin eski nedeni belirlemek mümkün değil. Widget’ın kendi durum mesajının görünmesi, o kurulumda uzantı kodunun çalıştığını gösterir. Bu veri sorunu için storyboard veya principal class eklenmedi.

## Yeni veri yolu

Flutter, mevcut yerel kayıtları yükleyince, ön plana dönünce ve başarılı bir ekleme/düzenleme/silmeden sonra iOS'a yalnızca görüntülenecek başlığı, gün/ayı ve iletişim numarasını gönderir. Runner seri bir kuyrukta ortak klasörü çözümler, widget kopyasını tek dosyaya atomik olarak yazar, geri okur ve içeriğini karşılaştırır. Başarılı işlemin ardından `BirthdayWidget` zaman çizelgesi yenilemesi istenir. Aynı içerik aynı revizyonu kullanabilir. Eski kayıtlar Flutter'ın yerel deposunda kalır ve ilk açılışta yeniden yayımlanır. Var olan uygulamayı kaldırarak test etmek yerel verileri kaybettirebilir.

Widget ve Runner aynı Swift okuyucusunu kullanır. Galeri önizlemesi temsili veri gösterir. Gerçek snapshot ve timeline ortak klasörden okur. Timeline sekiz gün için aynı doğrulanmış veri kopyasını kullanır; okumada hata varsa 15 dakika sonrası için yeniden okuma ister. Yenilemenin gerçek zamanını WidgetKit yönetir. Boş görünüm için geçerli, sıfır kayıtlı veri gerekir. Loglara kişi adları, numaralar, tarihler, içerik veya yerel yollar yazılmaz.

## İmzayı kontrol etme

Apple’ın güncel [iOS yetenek tablosunda](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) App groups ücretsiz Apple Developer sütununda da işaretlidir. Bu, belirli bir Sideloadly kurulumunun bu grubu doğru oluşturduğunu veya iki hedefe aynı yetkiyi verdiğini kanıtlamaz. Her iki imzada grubun istenmesi, her iki profilde buna izin verilmesi ve aynı takımla imzalama gerekir. [Apple TN3125](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)

Codemagic çıktısı ve mümkünse Sideloadly'nin **yeniden imzaladığı son IPA** için ayrı ayrı çalıştır:

    python tools/inspect_widget_ipa.py "dosya.ipa"

İki hedef için `expectedGroupInSignature=True`, `expectedGroupAllowed=True` ve paket için `sameSigningTeam=True` beklenir. Araç yalnızca paket içeriğini okur. İmzanın kriptografik geçerliliğini doğrulamaz. Çıktı `unknown` ise bunu “yetki kaldırıldı” olarak yorumlama. Özellikle DER-only imzalar için macOS'ta her iki binary/bundle üzerinde `codesign -d --entitlements :-` ve her iki profil üzerinde `security cms -D -i` kullan. Apple’ın genel yetenek tablosu veya sadece Codemagic giriş IPA’sı son imzanın yerini tutmaz.

Son imzada grup yoksa, farklı bir kimliğe çevrilmişse veya profiller izin vermiyorsa aynı kayıtlı App Group'u iki uygulama kimliğine tanımla, uygun profilleri oluştur ve her iki hedefi de bu yetkilerle imzala. Mevcut sideload aracıyla yetkiler korunamıyorsa Xcode veya uygun profillerle Codemagic imzalaması kullan. Ücretli hesap da tek başına üyelik/yetki eşleşmesini düzeltmez.

## Gerçek iPhone testi

1. Değişiklikleri Codemagic'in çektiği Git dalına al, **yeni iOS derlemesi** üret. Aynı uygulama kimliği ve takımla mevcut uygulamanın üzerine yükle. Uygulamayı açıp önceki kayıtlarının göründüğünü kontrol et.
2. Sideloadly’nin cihaz loglarında veya Mac Console’da `com.birthdaycalendar.widgetSync` alt sistemini filtrele. Runner için `writeVerified revision=… count=N` satırını bul. Gerçek ana ekran widget’ı için `readOK` satırındaki revizyon ve sayı eşleşmeli. Galerideki temsili görsel eşitleme kanıtı değildir.
3. Bugün tarihli geçici bir kayıt ekle. Adını değiştir ve sil. Her değişiklikte yazılan/okunan revizyonu ve gösterilen en yakın tarihi karşılaştır. Silmeden sonra önceki en yakın kayıt geri gelmeli. Sıfır kayıt testini yalnızca boş bir test kurulumunda yap.
4. `groupUnavailable` hangi süreçte görülüyorsa o hedef beklenen ortak klasörü alamamıştır; son imza ve profili karşılaştır. `snapshotMissing` klasör çözülmüş fakat dosya bulunamamış demektir. `readFailed`, `writeFailed`, `invalidSnapshot` veya `verificationFailed` farklı okuma, yazma veya içerik sorunlarını bildirir.
5. Runner doğrulanmış revizyon yazıyor, widget okuma olayı henüz gelmiyorsa uygulamayı ön plana getir ve ana ekrandaki widget’ı tekrar gözle. Gerekirse yalnızca widget’ı kaldırıp yeniden ekle. Widget sürekli eski revizyonu okuyorsa son imzalardaki ekip ve grup eşleşmesini kontrol et. İki revizyon aynıysa fakat içerik yanlışsa takvimdeki en yakın etkinliği ve tarih hesabını karşılaştır.

Windows'ta Flutter testleri ve proje/paket kontrolleri yapılmıştır. Son kurulu imza, Swift'in Xcode derlemesi ve iPhone'daki iki işlem arasındaki aktarım bu ortamda doğrulanmamıştır.
