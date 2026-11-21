/// V1 academy branding — single place to rename/rebrand without hunting UI copy.
///
/// Not multi-tenancy: static constants only. Swap values (or later load from
/// config) without editing splash/login/profile strings across the tree.
class AcademyBranding {
  const AcademyBranding._();

  /// Logo tile (transparent rounded corners), also the launcher/splash art.
  static const String logoAsset = 'assets/branding/academy_logo.png';

  /// Primary product / academy name shown in chrome and titles.
  static const String displayName = 'أكاديمية بصمة';

  /// Short brand mark (splash hero, compact chrome).
  static const String shortName = 'بصمة';

  /// Supporting line under [shortName] (e.g. splash).
  static const String tagline = 'أكاديمية تحفيظ القرآن الكريم';

  /// Longer title used where a combined label is needed.
  static const String fullTitle = 'بصمة - أكاديمية التحفيظ';

  /// Footer / about lines: `أكاديمية بصمة · الإصدار 1.0.0`
  static String versionFooter(String version) =>
      '$displayName · الإصدار $version';
}
