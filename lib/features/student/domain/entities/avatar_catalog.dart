enum AvatarCategory { animals, premium }

class AvatarDefinition {
  final String id;
  final String emoji;
  final String name;
  final AvatarCategory category;

  /// تكلفة الفتح بالعملات - صفر يعني الشخصية مجانية من البداية
  final int unlockCost;

  const AvatarDefinition({
    required this.id,
    required this.emoji,
    required this.name,
    required this.category,
    this.unlockCost = 0,
  });
}

/// كاتالوج ثابت للشخصيات - مش محتاج Firestore لأنه مايتغيرش من لوحة تحكم
class AvatarCatalog {
  AvatarCatalog._();

  static const List<AvatarDefinition> all = [
    AvatarDefinition(
      id: 'panda',
      emoji: '🐼',
      name: 'الباندا المثابر',
      category: AvatarCategory.animals,
    ),
    AvatarDefinition(
      id: 'fox',
      emoji: '🦊',
      name: 'الثعلب الذكي',
      category: AvatarCategory.animals,
    ),
    AvatarDefinition(
      id: 'lion',
      emoji: '🦁',
      name: 'الأسد الحافظ',
      category: AvatarCategory.animals,
    ),
    AvatarDefinition(
      id: 'wizard',
      emoji: '🧙',
      name: 'الشيخ الصغير',
      category: AvatarCategory.premium,
      unlockCost: 500,
    ),
    AvatarDefinition(
      id: 'rabbit',
      emoji: '🐰',
      name: 'الأرنب السريع',
      category: AvatarCategory.animals,
    ),
    AvatarDefinition(
      id: 'owl',
      emoji: '🦉',
      name: 'البومة العالمة',
      category: AvatarCategory.animals,
    ),
    AvatarDefinition(
      id: 'champion',
      emoji: '🏆',
      name: 'بطل الحفظ',
      category: AvatarCategory.premium,
      unlockCost: 300,
    ),
    AvatarDefinition(
      id: 'star',
      emoji: '⭐',
      name: 'النجم المميز',
      category: AvatarCategory.premium,
      unlockCost: 1200,
    ),
    AvatarDefinition(
      id: 'camel',
      emoji: '🐫',
      name: 'الجمل المسافر',
      category: AvatarCategory.premium,
      unlockCost: 800,
    ),
  ];

  static AvatarDefinition byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}
