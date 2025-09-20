class UserProfile {
  final String id;
  final String ageGroup;
  final String gender;
  final List<String> focusAreas;
  final DateTime createdAt;
  final DateTime lastUpdated;

  const UserProfile({
    required this.id,
    required this.ageGroup,
    required this.gender,
    required this.focusAreas,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'age_group': ageGroup,
      'gender': gender,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, List<String> focusAreas) {
    return UserProfile(
      id: map['id'] ?? '',
      ageGroup: map['age_group'] ?? '',
      gender: map['gender'] ?? '',
      focusAreas: focusAreas,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['last_updated'] ?? 0),
    );
  }

  UserProfile copyWith({
    String? id,
    String? ageGroup,
    String? gender,
    List<String>? focusAreas,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return UserProfile(
      id: id ?? this.id,
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      focusAreas: focusAreas ?? this.focusAreas,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

enum AgeGroup {
  teenager('Teenager (13-17)'),
  youngAdult('Young Adult (18-25)'),
  adult('Adult (26-55)'),
  senior('Senior (56+)');

  const AgeGroup(this.displayName);
  final String displayName;
}

enum Gender {
  male('Male'),
  female('Female'),
  nonBinary('Non-binary'),
  preferNotToSay('Prefer not to say');

  const Gender(this.displayName);
  final String displayName;
}

enum FocusArea {
  relationship('Relationship'),
  family('Family'),
  career('Career'),
  health('Health'),
  selfEsteem('Self-Esteem'),
  finances('Finances'),
  creativePursuits('Creative Pursuits');

  const FocusArea(this.displayName);
  final String displayName;
}
