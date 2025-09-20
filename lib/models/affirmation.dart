class Affirmation {
  final String id;
  final String content;
  final String? ageGroup;
  final String? gender;
  final String category;
  final bool isCustom;
  final DateTime? createdAt;

  const Affirmation({
    required this.id,
    required this.content,
    this.ageGroup,
    this.gender,
    required this.category,
    this.isCustom = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'age_group': ageGroup,
      'gender': gender,
      'category': category,
      'is_custom': isCustom ? 1 : 0,
      'created_at': createdAt?.millisecondsSinceEpoch,
    };
  }

  factory Affirmation.fromMap(Map<String, dynamic> map) {
    return Affirmation(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      ageGroup: map['age_group'],
      gender: map['gender'],
      category: map['category'] ?? '',
      isCustom: (map['is_custom'] ?? 0) == 1,
      createdAt: map['created_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
    );
  }

  Affirmation copyWith({
    String? id,
    String? content,
    String? ageGroup,
    String? gender,
    String? category,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return Affirmation(
      id: id ?? this.id,
      content: content ?? this.content,
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      category: category ?? this.category,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Affirmation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class FavoriteAffirmation {
  final int? id;
  final String userId;
  final String affirmationId;
  final DateTime savedAt;

  const FavoriteAffirmation({
    this.id,
    required this.userId,
    required this.affirmationId,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'affirmation_id': affirmationId,
      'saved_at': savedAt.millisecondsSinceEpoch,
    };
  }

  factory FavoriteAffirmation.fromMap(Map<String, dynamic> map) {
    return FavoriteAffirmation(
      id: map['id'],
      userId: map['user_id'] ?? '',
      affirmationId: map['affirmation_id'] ?? '',
      savedAt: DateTime.fromMillisecondsSinceEpoch(map['saved_at'] ?? 0),
    );
  }
}

class ViewHistory {
  final int? id;
  final String userId;
  final String affirmationId;
  final DateTime viewedAt;

  const ViewHistory({
    this.id,
    required this.userId,
    required this.affirmationId,
    required this.viewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'affirmation_id': affirmationId,
      'viewed_at': viewedAt.millisecondsSinceEpoch,
    };
  }

  factory ViewHistory.fromMap(Map<String, dynamic> map) {
    return ViewHistory(
      id: map['id'],
      userId: map['user_id'] ?? '',
      affirmationId: map['affirmation_id'] ?? '',
      viewedAt: DateTime.fromMillisecondsSinceEpoch(map['viewed_at'] ?? 0),
    );
  }
}
