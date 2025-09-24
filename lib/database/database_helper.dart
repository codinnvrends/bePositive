import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_profile.dart';
import '../models/affirmation.dart';
import '../models/notification_settings.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<void> _addNotificationEndColumns(Database db) async {
    // Ensure end_hour and end_minute columns exist (idempotent)
    final info = await db.rawQuery('PRAGMA table_info(notification_settings)');
    final columns = info.map((row) => row['name'] as String).toSet();
    if (!columns.contains('end_hour')) {
      await db.execute('ALTER TABLE notification_settings ADD COLUMN end_hour INTEGER DEFAULT 21');
    }
    if (!columns.contains('end_minute')) {
      await db.execute('ALTER TABLE notification_settings ADD COLUMN end_minute INTEGER DEFAULT 0');
    }
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'be_positive.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addNotificationEndColumns(db);
        }
      },
      onOpen: (db) async {
        await _addNotificationEndColumns(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // User Profile Table
    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        age_group TEXT NOT NULL,
        gender TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Focus Areas Table
    await db.execute('''
      CREATE TABLE user_focus_areas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        focus_area TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile(id)
      )
    ''');

    // Affirmations Table
    await db.execute('''
      CREATE TABLE affirmations (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        age_group TEXT,
        gender TEXT,
        category TEXT NOT NULL,
        is_custom INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    // Favorites Table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        affirmation_id TEXT NOT NULL,
        saved_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile(id),
        FOREIGN KEY (affirmation_id) REFERENCES affirmations(id)
      )
    ''');

    // View History Table
    await db.execute('''
      CREATE TABLE view_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        affirmation_id TEXT NOT NULL,
        viewed_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile(id),
        FOREIGN KEY (affirmation_id) REFERENCES affirmations(id)
      )
    ''');

    // Notification Settings Table
    await db.execute('''
      CREATE TABLE notification_settings (
        id INTEGER PRIMARY KEY,
        user_id TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        hour INTEGER DEFAULT 9,
        minute INTEGER DEFAULT 0,
        daily_count INTEGER DEFAULT 3,
        selected_days TEXT DEFAULT '1,2,3,4,5,6,7',
        end_hour INTEGER DEFAULT 21,
        end_minute INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES user_profile(id)
      )
    ''');

    // Insert default affirmations
    await _insertDefaultAffirmations(db);
  }

  Future<void> _insertDefaultAffirmations(Database db) async {
    final affirmations = [
      // Teenager affirmations
      {
        'id': 'teen_career_1',
        'content': 'Your potential is limitless. Every lesson learned today shapes your amazing future.',
        'age_group': 'Teenager (13-17)',
        'gender': null,
        'category': 'Career',
        'is_custom': 0,
      },
      {
        'id': 'teen_self_esteem_1',
        'content': 'You are exactly who you\'re meant to be at this moment.',
        'age_group': 'Teenager (13-17)',
        'gender': null,
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
      // Young Adult affirmations
      {
        'id': 'young_career_1',
        'content': 'Every challenge is preparing you for the success that\'s coming.',
        'age_group': 'Young Adult (18-25)',
        'gender': null,
        'category': 'Career',
        'is_custom': 0,
      },
      {
        'id': 'young_finances_1',
        'content': 'You\'re learning valuable lessons about money that will serve you for life.',
        'age_group': 'Young Adult (18-25)',
        'gender': null,
        'category': 'Finances',
        'is_custom': 0,
      },
      // Adult affirmations
      {
        'id': 'adult_family_1',
        'content': 'The love you give your family creates ripples of positivity.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Family',
        'is_custom': 0,
      },
      {
        'id': 'adult_health_1',
        'content': 'Your body is resilient and capable of amazing things.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Health',
        'is_custom': 0,
      },
      {
        'id': 'adult_happiness_1',
        'content': 'Your happiness is a reflection of your inner peace and contentment.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Happiness',
        'is_custom': 0,
      },
      {
        'id': 'adult_success_1',
        'content': 'Your success is a reflection of your hard work and dedication.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Success',
        'is_custom': 0,
      },
      {
        'id': 'adult_wealth_1',
        'content': 'Your wealth is a reflection of your hard work and dedication.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Wealth',
        'is_custom': 0,
      },
      {
        'id': 'adult_relationship_1',
        'content': 'Your relationships are a reflection of your hard work and dedication.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Relationship',
        'is_custom': 0,
      },
      {
        'id': 'adult_joy_1',
        'content': 'Your joy is a reflection of your hard work and dedication.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Joy',
        'is_custom': 0,
      },
      {
        'id': 'adult_wealth_1',
        'content': 'Your wealth is a reflection of your hard work and dedication.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Wealth',
        'is_custom': 0,
      },
      {
        'id': 'adult_wealth_2',
        'content': 'Wealth is for sharing.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Wealth',
        'is_custom': 0,
      },
      {
        'id': 'adult_wealth_3',
        'content': 'Wealth is for helping others.',
        'age_group': 'Adult (26-55)',
        'gender': null,
        'category': 'Wealth',
        'is_custom': 0,
      },
      // Senior affirmations
      {
        'id': 'senior_self_esteem_1',
        'content': 'Your life experience is a treasure that enriches everyone around you.',
        'age_group': 'Senior (56+)',
        'gender': null,
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
      {
        'id': 'senior_creative_1',
        'content': 'It\'s never too late to explore new passions and talents.',
        'age_group': 'Senior (56+)',
        'gender': null,
        'category': 'Creative Pursuits',
        'is_custom': 0,
      },
      // Gender-specific affirmations
      {
        'id': 'male_strength_1',
        'content': 'Your strength includes the courage to be vulnerable.',
        'age_group': null,
        'gender': 'Male',
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
      {
        'id': 'female_intuition_1',
        'content': 'Your intuition is a powerful guide—trust it.',
        'age_group': null,
        'gender': 'Female',
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
      {
        'id': 'nonbinary_valid_1',
        'content': 'You are valid and worthy exactly as you are.',
        'age_group': null,
        'gender': 'Non-binary',
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
      // Universal affirmations
      {
        'id': 'universal_strength_1',
        'content': 'You have the strength to overcome any challenge. Believe in your resilience and power.',
        'age_group': null,
        'gender': null,
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
      {
        'id': 'universal_growth_1',
        'content': 'Every day brings new opportunities for growth and positive change.',
        'age_group': null,
        'gender': null,
        'category': 'Self-Esteem',
        'is_custom': 0,
      },
    ];

    for (final affirmation in affirmations) {
      await db.insert('affirmations', affirmation);
    }
  }

  // User Profile operations
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    
    // Insert profile
    await db.insert('user_profile', profile.toMap());
    
    // Insert focus areas
    for (final focusArea in profile.focusAreas) {
      await db.insert('user_focus_areas', {
        'user_id': profile.id,
        'focus_area': focusArea,
      });
    }
    
    return 1;
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    
    final profileMaps = await db.query('user_profile', limit: 1);
    if (profileMaps.isEmpty) return null;
    
    final profileMap = profileMaps.first;
    final focusAreaMaps = await db.query(
      'user_focus_areas',
      where: 'user_id = ?',
      whereArgs: [profileMap['id']],
    );
    
    final focusAreas = focusAreaMaps
        .map((map) => map['focus_area'] as String)
        .toList();
    
    return UserProfile.fromMap(profileMap, focusAreas);
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    
    // Update profile
    await db.update(
      'user_profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    
    // Delete existing focus areas
    await db.delete(
      'user_focus_areas',
      where: 'user_id = ?',
      whereArgs: [profile.id],
    );
    
    // Insert new focus areas
    for (final focusArea in profile.focusAreas) {
      await db.insert('user_focus_areas', {
        'user_id': profile.id,
        'focus_area': focusArea,
      });
    }
    
    return 1;
  }

  // Affirmation operations
  Future<List<Affirmation>> getPersonalizedAffirmations(UserProfile profile) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'affirmations',
      where: '''
        (age_group IS NULL OR age_group = ?) AND
        (gender IS NULL OR gender = ?) AND
        category IN (${profile.focusAreas.map((_) => '?').join(',')})
      ''',
      whereArgs: [profile.ageGroup, profile.gender, ...profile.focusAreas],
    );
    
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<List<Affirmation>> getAllAffirmations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('affirmations');
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<int> insertAffirmation(Affirmation affirmation) async {
    final db = await database;
    await db.insert('affirmations', affirmation.toMap());
    return 1;
  }

  // Favorites operations
  Future<int> addToFavorites(String userId, String affirmationId) async {
    final db = await database;
    final favorite = FavoriteAffirmation(
      userId: userId,
      affirmationId: affirmationId,
      savedAt: DateTime.now(),
    );
    return await db.insert('favorites', favorite.toMap());
  }

  Future<int> removeFromFavorites(String userId, String affirmationId) async {
    final db = await database;
    return await db.delete(
      'favorites',
      where: 'user_id = ? AND affirmation_id = ?',
      whereArgs: [userId, affirmationId],
    );
  }

  Future<List<Affirmation>> getFavoriteAffirmations(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.* FROM affirmations a
      INNER JOIN favorites f ON a.id = f.affirmation_id
      WHERE f.user_id = ?
      ORDER BY f.saved_at DESC
    ''', [userId]);
    
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<bool> isFavorite(String userId, String affirmationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'user_id = ? AND affirmation_id = ?',
      whereArgs: [userId, affirmationId],
    );
    return maps.isNotEmpty;
  }

  // View history operations
  Future<int> addToViewHistory(String userId, String affirmationId) async {
    final db = await database;
    final viewHistory = ViewHistory(
      userId: userId,
      affirmationId: affirmationId,
      viewedAt: DateTime.now(),
    );
    return await db.insert('view_history', viewHistory.toMap());
  }

  // Notification settings operations
  Future<int> saveNotificationSettings(String userId, NotificationSettings settings) async {
    final db = await database;
    final settingsMap = settings.toMap();
    settingsMap['user_id'] = userId;
    
    final existing = await db.query(
      'notification_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    if (existing.isNotEmpty) {
      return await db.update(
        'notification_settings',
        settingsMap,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } else {
      return await db.insert('notification_settings', settingsMap);
    }
  }

  Future<NotificationSettings> getNotificationSettings(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notification_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    if (maps.isNotEmpty) {
      return NotificationSettings.fromMap(maps.first);
    }
    
    return const NotificationSettings();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
