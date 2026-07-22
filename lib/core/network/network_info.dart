import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnection connectionChecker;

  const NetworkInfoImpl(this.connectionChecker);

  /// [InternetConnection.hasInternetAccess] بيفحص عدة مواقع خارجية، ولو
  /// الشبكة بتمنع/تبطّئ الفحوصات دي تحديدًا (زي ما بيحصل على بعض الشبكات
  /// المقيّدة) ممكن يفضل معلّق من غير ما يرجع نتيجة خالص، وده بيوقف أي
  /// عملية شبكة في التطبيق كله لأن كل الـ repositories بتتحقق منه الأول.
  /// فبنحط سقف زمني، ولو خلص من غير رد نفترض إن فيه اتصال ونسيب الطلب
  /// الفعلي (Firebase/Firestore) هو اللي يحدد الصح من الغلط.
  @override
  Future<bool> get isConnected => connectionChecker.hasInternetAccess.timeout(
    const Duration(seconds: 5),
    onTimeout: () => true,
  );
}
