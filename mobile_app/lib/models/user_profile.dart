enum HealthCategory {
  normal,
  asthmatic,
  elderly,
  children,
}

extension HealthCategoryExtension on HealthCategory {
  String get value {
    switch (this) {
      case HealthCategory.normal:
        return 'normal';
      case HealthCategory.asthmatic:
        return 'asthmatic';
      case HealthCategory.elderly:
        return 'elderly';
      case HealthCategory.children:
        return 'children';
    }
  }

  String get displayName {
    switch (this) {
      case HealthCategory.normal:
        return 'General Commuter (Normal)';
      case HealthCategory.asthmatic:
        return 'Asthmatic / Respiratory Vulnerable';
      case HealthCategory.elderly:
        return 'Senior Citizen (Elderly)';
      case HealthCategory.children:
        return 'Child / Pediatric Care';
    }
  }

  int get defaultThreshold {
    switch (this) {
      case HealthCategory.normal:
        return 300;
      case HealthCategory.asthmatic:
        return 150;
      case HealthCategory.elderly:
        return 200;
      case HealthCategory.children:
        return 100;
    }
  }

  static HealthCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'asthmatic':
        return HealthCategory.asthmatic;
      case 'elderly':
        return HealthCategory.elderly;
      case 'children':
        return HealthCategory.children;
      default:
        return HealthCategory.normal;
    }
  }
}

class UserProfile {
  final String id;
  final String name;
  final HealthCategory healthCategory;
  final int? customThreshold;
  final int effectiveThreshold;

  UserProfile({
    required this.id,
    required this.name,
    required this.healthCategory,
    this.customThreshold,
    required this.effectiveThreshold,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final cat = HealthCategoryExtension.fromString(json['health_category']);
    return UserProfile(
      id: json['id'] ?? 'user_default',
      name: json['name'] ?? 'Delhi Commuter',
      healthCategory: cat,
      customThreshold: json['custom_threshold'] as int?,
      effectiveThreshold: (json['effective_threshold'] as int?) ??
          (json['custom_threshold'] as int?) ??
          cat.defaultThreshold,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'health_category': healthCategory.value,
      'custom_threshold': customThreshold,
    };
  }
}
