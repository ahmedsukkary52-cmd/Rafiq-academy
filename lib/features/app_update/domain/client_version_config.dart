import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Firestore location of the minimum-version configuration (B10). Public
/// read, no client writes; changed only by the deployment procedure.
const String clientVersionCollection = 'appConfig';
const String clientVersionDocId = 'clientVersion';

/// Upper bound for a build number (Google Play's versionCode limit).
const int maxClientBuildNumber = 2100000000;

const int _maxUpdateUrlLength = 2048;

/// A valid `appConfig/clientVersion` document.
class ClientVersionConfig extends Equatable {
  final int minimumBuildNumber;
  final Uri? androidUpdateUrl;
  final Uri? iosUpdateUrl;

  const ClientVersionConfig({
    required this.minimumBuildNumber,
    this.androidUpdateUrl,
    this.iosUpdateUrl,
  });

  /// The store link for [platform], or null when none is configured.
  Uri? updateUrlFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => androidUpdateUrl,
    TargetPlatform.iOS => iosUpdateUrl,
    _ => null,
  };

  @override
  List<Object?> get props => [
    minimumBuildNumber,
    androidUpdateUrl,
    iosUpdateUrl,
  ];
}

sealed class ClientVersionConfigParse {
  const ClientVersionConfigParse();
}

final class ValidClientVersionConfig extends ClientVersionConfigParse {
  final ClientVersionConfig config;

  const ValidClientVersionConfig(this.config);
}

/// [field] names the first invalid field; the value itself is never kept.
final class InvalidClientVersionConfig extends ClientVersionConfigParse {
  final String field;

  const InvalidClientVersionConfig(this.field);
}

/// Validates raw document data. Unknown fields (for example `updatedAt`) are
/// ignored. An absent or empty URL means "not configured"; any other invalid
/// URL makes the whole document invalid.
ClientVersionConfigParse parseClientVersionConfig(Map<String, dynamic> data) {
  final minimum = data['minimumBuildNumber'];
  if (minimum is! int || minimum < 1 || minimum > maxClientBuildNumber) {
    return const InvalidClientVersionConfig('minimumBuildNumber');
  }
  final android = _optionalHttpsUrl(data['androidUpdateUrl']);
  if (identical(android, _invalid)) {
    return const InvalidClientVersionConfig('androidUpdateUrl');
  }
  final ios = _optionalHttpsUrl(data['iosUpdateUrl']);
  if (identical(ios, _invalid)) {
    return const InvalidClientVersionConfig('iosUpdateUrl');
  }
  return ValidClientVersionConfig(
    ClientVersionConfig(
      minimumBuildNumber: minimum,
      androidUpdateUrl: android,
      iosUpdateUrl: ios,
    ),
  );
}

/// Whether [installedBuild] may keep running under [minimumBuild].
bool meetsMinimumBuild({
  required int installedBuild,
  required int minimumBuild,
}) => installedBuild >= minimumBuild;

/// A parsed `https` URL with a host, or null when [raw] is not one.
Uri? validHttpsUrl(Object? raw) {
  if (raw is! String) return null;
  final text = raw.trim();
  if (text.isEmpty || text.length > _maxUpdateUrlLength) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}

final Uri _invalid = Uri(scheme: 'invalid');

Uri? _optionalHttpsUrl(Object? raw) {
  if (raw == null || (raw is String && raw.trim().isEmpty)) return null;
  return validHttpsUrl(raw) ?? _invalid;
}
