# İyi ki — Doğum günü takvimi

Flutter ile Türkçe, pastel temalı Android/iOS uygulaması ve tarayıcı önizlemesi.

## Kullanım

- `flutter pub get`
- `flutter run -d chrome`: tarayıcı önizlemesi.
- `flutter run`: bağlı Android/iOS cihazı.
- `flutter test` ve `flutter analyze`: doğrulama.
- `flutter build apk --debug`: Android deneme paketi. Mağaza dağıtımı için kendi imzalama yapılandırmanız gerekir.

Windows'ta Android derlemesi için Türkçe karakter içermeyen bir klasör kullanın. Bu oturumda ayrı derleme kopyası `C:\Users\tanez\codex-builds\iyi-ki` altında oluşturuldu. Ana kaynak klasörü Masaüstü'ndeki `birthday calendar` klasörüdür.

## Özellikler

Üç sekme: Ana Sayfa, Takvim, Ayarlar. Kişi ekleme/düzenleme/silme, fotoğraf, kategori, arama ve filtre. Aylık takvim işaretleri ve geri sayım. Doğum yılı isteğe bağlı. Kayıtlar cihazda, hesap gerektirmez. Ön hatırlatmalar 1/3/7/14/30 veya 1–365 gün; her kişi için ayrı seçim. Doğum gününde 00.00, ön hatırlatmalarda 09.00. Artık yıl olmayan yıllarda 29 Şubat, 28 Şubat'a uyarlanır.

## Bildirimlerin çalışma sınırları

Bildirimleri Ayarlar'dan açın. Mobil bildirimler çevrimdışı planlanır. Android yeniden başlatma alıcısı mevcut planı geri yükler. Kesin saat izni yoksa gecikmeli zamanlama kullanılır ve kullanıcı bilgilendirilir. iOS izin durumu da kontrol edilir.

Her kişi için tek kayıt vardır. Sonraki yıllar bu kayıttan hesaplanır. Yaklaşan en fazla 60 bildirim, altı takvim yıllık pencere içinden seçilir; uygulama açıldığında, geri dönüldüğünde veya kayıt değiştiğinde plan yenilenir. Bu bir sınırsız arka plan zamanlayıcısı değildir: çok sayıda kayıt veya uzun süre açılmayan uygulama için kuyruk tükenebilir. Bildirimler uygulama yeniden açılarak yenilenmelidir. Saat dilimi değişikliği uygulamaya dönüldüğünde uygulanır. Pil tasarrufu, odak modu, izinler veya üretici kısıtlamaları kesin teslimi etkileyebilir.

Tarayıcı sürümünde mobil bildirimler ve ana ekran widget'ları çalışmaz. Veriler tarayıcının yerel alanına kaydedilir. Fotoğraflar küçültülür ve kayıtla saklanır; bulut senkronizasyonu ve yedekleme yoktur.

## Widget

Android: Ana ekrana basılı tut → Widget'lar → İyi ki. Yerel widget kayıtların tümünden sıradaki doğum gününü hesaplar; uygulama açılmadan sistemin güncelleme periyodunda yenilenir (yaklaşık 30 dakika, sistem geciktirebilir).

iOS: WidgetKit uzantısı Xcode projesine eklenmiştir. Runner ve BirthdayWidget hedeflerinde aynı Apple geliştirme takımını seçin; `group.com.birthdaycalendar.shared` App Group'unu her iki hedef için hesabınızda tanımlayın (gerekiyorsa entitlements ve Dart/Swift sabitlerini kendi benzersiz grubunuza değiştirin). Günlük timeline, sıradaki kişiyi cihazda hesaplar. Xcode/macOS gerektirir; Windows üzerinde derlenemez. iOS deployment target 14.0.

## Doğrulama ve yayın öncesi

Tarih sınırları, artık yıl, kayıt dönüşümü ve kişi ekleme akışı otomatik testlerle kapsanır. Web derlemesi ve kod analizi kontrol edilmiştir. Gerçek cihazlarda 00.00 bildirimi, yeniden başlatma, izin reddi/geri verilmesi, saat dilimi değişimi ve widget yenilemesi ayrıca denenmelidir. iOS kaynak ve proje bağlantıları hazırlanmıştır; Apple cihazında derleme/test yapılmamıştır.

Bildirim mimarisi için kaynak: https://pub.dev/packages/flutter_local_notifications/versions/19.5.0
Widget bağlantısı: https://pub.dev/packages/home_widget

Android debug APK, ayrı ASCII yolundaki derleme kopyasında başarıyla üretildi. Bu, gerçek cihaz bildirim/widget testinin yerine geçmez.
