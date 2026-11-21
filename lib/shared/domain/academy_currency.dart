import 'payment_review_amounts.dart';

/// Arabic unit shown next to amounts in the academy default currency
/// ([AcademyPaymentSettingsContract.defaultCurrency], `EGP`).
const String academyCurrencyLabel = 'جنيه';

/// `140` → `140 جنيه`, `66.67` → `66.67 جنيه` (Western digits, staff screens).
String academyMoneyLabel(double amount) =>
    '${formatMoneyAmount(amount)} $academyCurrencyLabel';

/// For callers that already formatted the number (e.g. grouped counts).
String academyMoneyText(String formattedAmount) =>
    '$formattedAmount $academyCurrencyLabel';
