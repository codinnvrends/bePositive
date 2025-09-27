import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_profile.dart';
import '../models/affirmation.dart';
import '../models/notification_settings.dart';
import '../models/custom_affirmation_reminder.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // Custom affirmation helpers
  Future<int> getCustomAffirmationsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM affirmations WHERE is_custom = 1');
    final count = result.isNotEmpty ? (result.first['cnt'] as int? ?? 0) : 0;
    return count;
  }

  Future<int> getConfiguredCustomAffirmationsCount() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt
      FROM custom_affirmation_reminders r
      INNER JOIN affirmations a ON a.id = r.affirmation_id
      WHERE a.is_custom = 1 AND (r.enabled = 1)
    ''');
    final count = result.isNotEmpty ? (result.first['cnt'] as int? ?? 0) : 0;
    return count;
  }

  Future<int> insertCustomAffirmation(Affirmation affirmation) async {
    final db = await database;
    return await db.insert('affirmations', affirmation.toMap());
  }

  Future<int> deleteCustomAffirmation(String affirmationId) async {
    final db = await database;
    // Cascade delete reminder first
    await db.delete('custom_affirmation_reminders', where: 'affirmation_id = ?', whereArgs: [affirmationId]);
    return await db.delete('affirmations', where: 'id = ?', whereArgs: [affirmationId]);
  }

  Future<int> updateCustomAffirmation(
    String affirmationId, {
    String? content,
    String? category,
  }) async {
    final db = await database;
    final values = <String, Object?>{};
    if (content != null) values['content'] = content;
    if (category != null) values['category'] = category;
    if (values.isEmpty) return 0;
    return await db.update(
      'affirmations',
      values,
      where: 'id = ? AND is_custom = 1',
      whereArgs: [affirmationId],
    );
  }

  // Custom reminder CRUD
  Future<int> upsertCustomReminder(CustomAffirmationReminder reminder) async {
    final db = await database;
    // Try update by affirmation_id
    final data = reminder.toMap();
    data.remove('id');
    // Backward compatibility: some users may have v3 table with NOT NULL hour/minute
    // Ensure legacy columns are populated if null
    data['hour'] = data['hour'] ?? data['start_hour'] ?? 9;
    data['minute'] = data['minute'] ?? data['start_minute'] ?? 0;
    final updated = await db.update(
      'custom_affirmation_reminders',
      data,
      where: 'affirmation_id = ?',
      whereArgs: [reminder.affirmationId],
    );
    if (updated > 0) return updated;
    return await db.insert('custom_affirmation_reminders', reminder.toMap());
  }

  Future<CustomAffirmationReminder?> getCustomReminderByAffirmationId(String affirmationId) async {
    final db = await database;
    final rows = await db.query(
      'custom_affirmation_reminders',
      where: 'affirmation_id = ?',
      whereArgs: [affirmationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CustomAffirmationReminder.fromMap(rows.first);
  }

  Future<List<Map<String, dynamic>>> getAllCustomRemindersJoined() async {
    final db = await database;
    // Join reminders with affirmations to get content
    return await db.rawQuery('''
      SELECT r.*, a.content, a.category, a.id AS affirmation_id
      FROM custom_affirmation_reminders r
      INNER JOIN affirmations a ON a.id = r.affirmation_id
      WHERE a.is_custom = 1
    ''');
  }

  Future<int> deleteCustomReminderByAffirmationId(String affirmationId) async {
    final db = await database;
    return await db.delete('custom_affirmation_reminders', where: 'affirmation_id = ?', whereArgs: [affirmationId]);
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

  Future<void> _addNotificationFrequencyColumns(Database db) async {
    // Ensure frequency-based notification columns exist (idempotent)
    final info = await db.rawQuery('PRAGMA table_info(notification_settings)');
    final columns = info.map((row) => row['name'] as String).toSet();
    
    if (!columns.contains('use_frequency_mode')) {
      await db.execute('ALTER TABLE notification_settings ADD COLUMN use_frequency_mode INTEGER DEFAULT 0');
    }
    if (!columns.contains('frequency_value')) {
      await db.execute('ALTER TABLE notification_settings ADD COLUMN frequency_value INTEGER DEFAULT 2');
    }
    if (!columns.contains('frequency_unit')) {
      await db.execute('ALTER TABLE notification_settings ADD COLUMN frequency_unit TEXT DEFAULT "hours"');
    }
    if (!columns.contains('show_on_lock_screen')) {
      await db.execute('ALTER TABLE notification_settings ADD COLUMN show_on_lock_screen INTEGER DEFAULT 1');
    }
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'be_positive.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addNotificationEndColumns(db);
        }
        if (oldVersion < 3) {
          // Add table for per-affirmation reminders
          await db.execute('''
            CREATE TABLE IF NOT EXISTS custom_affirmation_reminders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              affirmation_id TEXT NOT NULL,
              enabled INTEGER DEFAULT 1,
              hour INTEGER NOT NULL,
              minute INTEGER NOT NULL,
              selected_days TEXT DEFAULT '1,2,3,4,5,6,7',
              FOREIGN KEY (affirmation_id) REFERENCES affirmations(id)
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_car_affirmation_id ON custom_affirmation_reminders(affirmation_id)');
        }
        if (oldVersion < 4) {
          // Add scheduling window and count columns for custom reminders
          final info = await db.rawQuery('PRAGMA table_info(custom_affirmation_reminders)');
          final columns = info.map((row) => row['name'] as String).toSet();
          if (!columns.contains('start_hour')) {
            await db.execute('ALTER TABLE custom_affirmation_reminders ADD COLUMN start_hour INTEGER');
          }
          if (!columns.contains('start_minute')) {
            await db.execute('ALTER TABLE custom_affirmation_reminders ADD COLUMN start_minute INTEGER');
          }
          if (!columns.contains('end_hour')) {
            await db.execute('ALTER TABLE custom_affirmation_reminders ADD COLUMN end_hour INTEGER');
          }
          if (!columns.contains('end_minute')) {
            await db.execute('ALTER TABLE custom_affirmation_reminders ADD COLUMN end_minute INTEGER');
          }
          if (!columns.contains('daily_count')) {
            await db.execute('ALTER TABLE custom_affirmation_reminders ADD COLUMN daily_count INTEGER DEFAULT 1');
          }
        }
        if (oldVersion < 5) {
          // Add frequency-based notification columns
          await _addNotificationFrequencyColumns(db);
        }
      },
      onOpen: (db) async {
        await _addNotificationEndColumns(db);
        await _addNotificationFrequencyColumns(db);
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
        use_frequency_mode INTEGER DEFAULT 0,
        frequency_value INTEGER DEFAULT 2,
        frequency_unit TEXT DEFAULT 'hours',
        show_on_lock_screen INTEGER DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES user_profile(id)
      )
    ''');

    // Custom Affirmation Reminders Table (includes legacy hour/minute and new window fields)
    await db.execute('''
      CREATE TABLE custom_affirmation_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        affirmation_id TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        hour INTEGER,
        minute INTEGER,
        start_hour INTEGER,
        start_minute INTEGER,
        end_hour INTEGER,
        end_minute INTEGER,
        daily_count INTEGER DEFAULT 1,
        selected_days TEXT DEFAULT '1,2,3,4,5,6,7',
        FOREIGN KEY (affirmation_id) REFERENCES affirmations(id)
      )
    ''');

    // Insert default affirmations
    await _insertDefaultAffirmations(db);
  }

  Future<void> _insertDefaultAffirmations(Database db) async {
    final affirmations = [
      // --- Existing 20 Affirmations (A001 - A020) ---
      {
        "id": "A001",
        "content": "Your potential is limitless. Every lesson learned today shapes your amazing future.",
        "age_group": "Teenager (13-17)",
        "gender": null,
        "category": "Career",
        "is_custom": 0
      },
      {
        "id": "A002",
        "content": "You are exactly who you're meant to be at this moment.",
        "age_group": "Teenager (13-17)",
        "gender": null,
        "category": "Self-Esteem",
        "is_custom": 0
      },
      {
        "id": "A003",
        "content": "Every challenge is preparing you for the success that's coming.",
        "age_group": "Young Adult (18-25)",
        "gender": null,
        "category": "Career",
        "is_custom": 0
      },
      {
        "id": "A004",
        "content": "You're learning valuable lessons about money that will serve you for life.",
        "age_group": "Young Adult (18-25)",
        "gender": null,
        "category": "Finances",
        "is_custom": 0
      },
      {
        "id": "A005",
        "content": "The love you give your family creates ripples of positivity.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Family",
        "is_custom": 0
      },
      {
        "id": "A006",
        "content": "Your body is resilient and capable of amazing things.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Health",
        "is_custom": 0
      },
      {
        "id": "A007",
        "content": "Your happiness is a reflection of your inner peace and contentment.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Happiness",
        "is_custom": 0
      },
      {
        "id": "A008",
        "content": "Your success is a reflection of your hard work and dedication.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Success",
        "is_custom": 0
      },
      {
        "id": "A009",
        "content": "Your wealth is a reflection of your hard work and dedication.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Wealth",
        "is_custom": 0
      },
      {
        "id": "A010",
        "content": "Wealth is for sharing.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Wealth",
        "is_custom": 0
      },
      {
        "id": "A011",
        "content": "Wealth is for helping others.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Wealth",
        "is_custom": 0
      },
      {
        "id": "A012",
        "content": "Your relationships are a reflection of your hard work and dedication.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Relationship",
        "is_custom": 0
      },
      {
        "id": "A013",
        "content": "Your joy is a reflection of your hard work and dedication.",
        "age_group": "Adult (26-55)",
        "gender": null,
        "category": "Joy",
        "is_custom": 0
      },
      {
        "id": "A014",
        "content": "Your life experience is a treasure that enriches everyone around you.",
        "age_group": "Senior (56+)",
        "gender": null,
        "category": "Self-Esteem",
        "is_custom": 0
      },
      {
        "id": "A015",
        "content": "It's never too late to explore new passions and talents.",
        "age_group": "Senior (56+)",
        "gender": null,
        "category": "Creative Pursuits",
        "is_custom": 0
      },
      {
        "id": "A016",
        "content": "Your strength includes the courage to be vulnerable.",
        "age_group": null,
        "gender": "Male",
        "category": "Self-Esteem",
        "is_custom": 0
      },
      {
        "id": "A017",
        "content": "Your intuition is a powerful guide—trust it.",
        "age_group": null,
        "gender": "Female",
        "category": "Self-Esteem",
        "is_custom": 0
      },
      {
        "id": "A018",
        "content": "You are valid and worthy exactly as you are.",
        "age_group": null,
        "gender": "Non-binary",
        "category": "Self-Esteem",
        "is_custom": 0
      },
      {
        "id": "A019",
        "content": "You have the strength to overcome any challenge. Believe in your resilience and power.",
        "age_group": null,
        "gender": null,
        "category": "Universal Strength",
        "is_custom": 0
      },
      {
        "id": "A020",
        "content": "Every day brings new opportunities for growth and positive change.",
        "age_group": null,
        "gender": null,
        "category": "Universal Growth",
        "is_custom": 0
      },

      // --- First 180 Expansion (A021 - A200) ---
      { "id": "A021", "content": "My curiosity is leading me to my best future.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A022", "content": "Every mistake is a powerful lesson, not a failure.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A023", "content": "I am developing valuable skills every day.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A024", "content": "What I study today builds my confidence for tomorrow.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A025", "content": "I am disciplined and focused on my goals.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A026", "content": "I ask great questions and seek out new knowledge.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A027", "content": "I have the power to create the career path I desire.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A028", "content": "My effort in school will pay off in my future work.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A029", "content": "I am taking small, consistent steps toward my vision.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A030", "content": "I am perfectly fine the way I am right now.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A031", "content": "My unique qualities make me stand out in a positive way.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A032", "content": "I trust my own thoughts and feelings.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A033", "content": "I am worthy of love and respect from myself and others.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A034", "content": "I choose to be kind to myself, even when I make mistakes.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A035", "content": "I celebrate my small victories every day.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A036", "content": "My voice matters and deserves to be heard.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A037", "content": "I am a resilient person who can handle tough emotions.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A038", "content": "I am becoming the best version of myself one day at a time.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A039", "content": "I confidently network and create professional connections.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A040", "content": "My effort and dedication lead to my professional growth.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A041", "content": "I embrace new responsibilities and learn quickly.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A042", "content": "I am building a strong, successful foundation for my future.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A043", "content": "I trust my skills and abilities in my workplace.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A044", "content": "I speak up for myself and my worth in salary negotiations.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A045", "content": "I am constantly learning and adapting to my field.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A046", "content": "I choose work that is both meaningful and rewarding.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A047", "content": "I release the fear of judgment from others regarding my path.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A048", "content": "I am financially responsible and make smart choices.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A049", "content": "I am building healthy money habits that last a lifetime.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A050", "content": "I manage my expenses with intelligence and awareness.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A051", "content": "I am attracting wealth and abundance into my life.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A052", "content": "I treat saving as a priority and an act of self-care.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A053", "content": "I am confident in my ability to handle my financial future.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A054", "content": "Money flows to me easily and consistently.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A055", "content": "I pay my bills on time and create a great credit score.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A056", "content": "I am learning to invest in myself and my future success.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A057", "content": "I choose to be present and focused with my family.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A058", "content": "I communicate my love and appreciation clearly.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A059", "content": "I offer patience and forgiveness to my loved ones.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A060", "content": "My home is a safe and loving sanctuary.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A061", "content": "I set healthy boundaries that protect my energy and my family.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A062", "content": "I create meaningful traditions for my family to cherish.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A063", "content": "I am a source of stability and peace for my family.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A064", "content": "I release expectations and accept my family as they are.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A065", "content": "I nurture my relationships with positive attention.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A066", "content": "I listen to my body's wisdom and needs.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A067", "content": "I choose to nourish myself with healthy, vibrant food.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A068", "content": "I make time for rest and deep relaxation.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A069", "content": "Moving my body is a joyful celebration of life.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A070", "content": "I prioritize my mental health and emotional balance.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A071", "content": "My immune system is strong and protects me daily.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A072", "content": "I have all the energy I need to live my life fully.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A073", "content": "I heal quickly and completely from all challenges.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A074", "content": "I commit to making small, positive health choices today.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A075", "content": "I find joy in the present moment.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A076", "content": "My happiness is an inner decision, not an outer result.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A077", "content": "I focus on what I have, not what I lack.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A078", "content": "I am grateful for the simple blessings in my life.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A079", "content": "I release negativity and choose thoughts that uplift me.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A080", "content": "I am worthy of feeling pure, unfiltered joy.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A081", "content": "My life is full of light, laughter, and love.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A082", "content": "I give myself permission to be happy right now.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A083", "content": "I attract positive experiences into my life effortlessly.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A084", "content": "I define success on my own terms.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A085", "content": "I am a powerful creator of my own reality.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A086", "content": "My actions align with my highest professional goals.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A087", "content": "I confidently embrace opportunities for advancement.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A088", "content": "I celebrate the success of others and my own.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A089", "content": "I have the mental fortitude to overcome any business obstacle.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A090", "content": "I attract supportive and inspiring colleagues.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A091", "content": "I take initiative and complete my projects with excellence.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A092", "content": "Every decision I make moves me closer to my vision.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A093", "content": "I am open and ready to receive massive abundance.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A094", "content": "My mind is focused on creating and sustaining prosperity.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A095", "content": "I deserve to live a rich and fulfilling life.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A096", "content": "I manage my money wisely, and it multiplies.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A097", "content": "I am a channel for wealth that helps others.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A098", "content": "Generosity is a key component of my financial plan.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A099", "content": "I release all limiting beliefs about money.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A100", "content": "I am consistently increasing my streams of income.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A101", "content": "My wealth supports my freedom and my family.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A102", "content": "I give and receive love effortlessly and openly.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A103", "content": "I am a patient, attentive, and communicative partner.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A104", "content": "I attract people who respect and cherish me.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A105", "content": "My relationships are built on trust and mutual support.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A106", "content": "I listen with an open mind and heart.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A107", "content": "I am secure in myself, which strengthens my relationships.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A108", "content": "Conflict is an opportunity for deeper connection.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A109", "content": "I offer compassion and forgiveness freely.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A110", "content": "I show up as my true self in all my connections.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A111", "content": "I welcome joy into my life with open arms.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A112", "content": "My natural state is one of peace and happiness.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A113", "content": "I am intentional about seeking out moments of delight.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A114", "content": "My heart is light and full of positive energy.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A115", "content": "I choose to see the good in every situation.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A116", "content": "I deserve to feel profound, consistent joy.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A117", "content": "I radiate positive energy that attracts more joy.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A118", "content": "I allow myself to play and be silly every day.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A119", "content": "Joy is a vital part of my well-being and life.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A120", "content": "My mind is a fountain of original ideas.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A121", "content": "I have permission to experiment and play with my ideas.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A122", "content": "I fearlessly share my unique perspective with the world.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A123", "content": "I am a confident and powerful creator.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A124", "content": "I allow my creative energy to flow freely and unhindered.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A125", "content": "I make time every day to engage my imagination.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A126", "content": "Creativity is essential to my happiness and growth.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A127", "content": "I trust the spontaneous ideas that come to me.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A128", "content": "I transform my thoughts into tangible results.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A129", "content": "My creative work is valuable and necessary.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A130", "content": "My needs are important, and I attend to them first.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A131", "content": "Self-care is a priority, not a luxury.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A132", "content": "I allow myself to rest without feeling guilty.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A133", "content": "I set firm and kind boundaries to protect my peace.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A134", "content": "I recharge my energy so I can better serve others.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A135", "content": "I treat my mind and body with gentleness and respect.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A136", "content": "I am fully supported in taking time for myself.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A137", "content": "I release the need to be busy all the time.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A138", "content": "I give myself grace and space to simply be.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A139", "content": "Taking care of myself is the most productive thing I can do.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A140", "content": "My years have gifted me with invaluable wisdom to share.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A141", "content": "I am proud of the life I have built and the person I have become.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A142", "content": "I release any regrets and focus on the beauty of today.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A143", "content": "I am respected for my wisdom and life achievements.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A144", "content": "My presence enriches the lives of those around me.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A145", "content": "I am comfortable and confident in my own skin.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A146", "content": "I continue to learn and evolve every single day.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A147", "content": "I celebrate my resilience and ability to adapt.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A148", "content": "My contributions to the world are meaningful and lasting.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A149", "content": "I trust in the timing of my life and where I am.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A150", "content": "My mind is sharp and eager to learn new things.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A151", "content": "Joy and creativity are a daily part of my life.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A152", "content": "I am excited to explore new hobbies and talents.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A153", "content": "My passion for learning grows stronger every day.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A154", "content": "I am capable of mastering new technologies and skills.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A155", "content": "I joyfully pursue hobbies that make me feel alive.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A156", "content": "My creativity is boundless and always available to me.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A157", "content": "I find new ways to express myself and my ideas.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A158", "content": "I make time for fun, play, and adventure.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A159", "content": "I inspire others with my continued enthusiasm for life.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A160", "content": "I lead with integrity and compassion.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A161", "content": "I allow myself to feel all emotions fully.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A162", "content": "My true strength comes from my ability to connect with others.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A163", "content": "I honor my needs and confidently say 'no' when necessary.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A164", "content": "I trust the power of my inner knowing and voice.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A165", "content": "I am fierce, gentle, and utterly unstoppable.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A166", "content": "I am on a beautiful journey of self-discovery, and I embrace every step.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A167", "content": "My true, authentic self is my greatest contribution to the world.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A168", "content": "I am surrounded by a loving community that celebrates my identity.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A169", "content": "I lead with compassion, not control.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A170", "content": "I embody healthy, positive masculinity.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A171", "content": "My courage allows me to express my deeper feelings.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A172", "content": "I am emotionally intelligent and perceptive.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A173", "content": "I define my own success, independent of expectations.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A174", "content": "I am a supportive and nurturing presence.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A175", "content": "I am powerful because I am authentic.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A176", "content": "I am strong enough to ask for help when I need it.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A177", "content": "I use my power to lift up others.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A178", "content": "I am wise, powerful, and deeply insightful.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A179", "content": "I trust my gut feeling—it is always right for me.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A180", "content": "I am worthy of being fully supported and cared for.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A181", "content": "I embrace my feminine power and inner goddess.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A182", "content": "I am resilient and can overcome any obstacle.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A183", "content": "I speak my truth with clarity and kindness.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A184", "content": "I release the need for perfection and embrace progress.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A185", "content": "I am beautiful, inside and out, exactly as I am.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A186", "content": "I am fiercely protective of my peace and my energy.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A187", "content": "My identity is fluid, powerful, and authentic.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A188", "content": "I am seen, respected, and celebrated for who I am.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A189", "content": "I create space in the world for my true self to shine.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A190", "content": "I give myself the grace and freedom to evolve.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A191", "content": "I choose joy and self-love above all else.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A192", "content": "I am surrounded by people who honor my whole self.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A193", "content": "I am a beautiful reflection of the universe's diversity.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A194", "content": "I do not need anyone's permission to be me.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A195", "content": "I fully embrace my unique journey and expression.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A196", "content": "You can handle anything that comes your way.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A197", "content": "I am a force of resilience and inner power.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A198", "content": "My spirit is unbreakable, and my resolve is firm.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A199", "content": "I draw on my inner reserves of courage right now.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A200", "content": "I am able to persevere through any difficulty.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },

      // --- Second 200 Expansion (A201 - A400) ---
      { "id": "A201", "content": "I am building discipline that will empower my future work.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A202", "content": "I approach my studies with a focused, positive attitude.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A203", "content": "My unique talents will be an asset to the world.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A204", "content": "I am learning to manage my time effectively.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A205", "content": "The effort I put in now creates future ease.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A206", "content": "I seek out mentorship and advice from wise people.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A207", "content": "I am capable of achieving high academic goals.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A208", "content": "I embrace the process of becoming an expert.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A209", "content": "I am preparing for a future filled with opportunity.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A210", "content": "My potential is unfolding exactly as it should.", "age_group": "Teenager (13-17)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A211", "content": "I am honest about my feelings, and that is brave.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A212", "content": "I define my worth; others' opinions don't control me.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A213", "content": "I choose friends who uplift and respect me.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A214", "content": "I deserve to take up space and be heard.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A215", "content": "I am perfectly imperfect, and that's wonderful.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A216", "content": "I choose to be present instead of worrying about tomorrow.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A217", "content": "My body is strong, capable, and deserving of care.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A218", "content": "I celebrate my differences; they make me memorable.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A219", "content": "I am mindful of my self-talk and choose encouraging words.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A220", "content": "I am safe to be myself, no matter the environment.", "age_group": "Teenager (13-17)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A221", "content": "I am patient and persistent in my job search.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A222", "content": "I trust that the right opportunity is coming at the right time.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A223", "content": "I fearlessly negotiate for the compensation I deserve.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A224", "content": "I am resilient in the face of career setbacks.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A225", "content": "I collaborate effectively and contribute value to my team.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A226", "content": "I am a capable and respected young professional.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A227", "content": "My career path is guided by my values.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A228", "content": "I learn quickly from feedback and and apply it immediately.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A229", "content": "I am constantly expanding my professional network.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A230", "content": "I celebrate my small professional victories every week.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Career", "is_custom": 0 },
      { "id": "A231", "content": "I treat money as a tool for freedom and growth.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A232", "content": "I am mastering the art of conscious spending.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A233", "content": "I am consistently paying down my debts and becoming free.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A234", "content": "I budget responsibly and still allow for enjoyment.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A235", "content": "I am attracting smart opportunities to increase my income.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A236", "content": "My financial mindset is one of abundance and prosperity.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A237", "content": "I invest wisely in my future and my education.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A238", "content": "I am financially educated and make confident choices.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A239", "content": "Every penny I save comes back to me multiplied.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A240", "content": "I am creating a life where I never have to worry about money.", "age_group": "Young Adult (18-25)", "gender": null, "category": "Finances", "is_custom": 0 },
      { "id": "A241", "content": "I choose connection over correction in difficult moments.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A242", "content": "My greatest legacy is the love I share with my family.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A243", "content": "I forgive easily and move past small conflicts quickly.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A244", "content": "I create a calm and predictable environment for my children/partner.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A245", "content": "I value time spent together over material things.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A246", "content": "I am learning and growing right alongside my family.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A247", "content": "I speak words of encouragement and affirmation daily.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A248", "content": "I protect my family with fierce and gentle love.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A249", "content": "I model healthy communication for my children.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A250", "content": "My family supports my dreams, and I support theirs.", "age_group": "Adult (26-55)", "gender": null, "category": "Family", "is_custom": 0 },
      { "id": "A251", "content": "My immune system is functioning optimally and protecting me.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A252", "content": "I am motivated to exercise for my energy and longevity.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A253", "content": "I am grateful for the strength and function of my body.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A254", "content": "I prioritize sleep as a vital component of my health.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A255", "content": "I take proactive steps to care for my long-term health.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A256", "content": "I breathe deeply and release all tension from my body.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A257", "content": "I deserve to feel vibrant, energetic, and well.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A258", "content": "My body easily maintains a healthy and sustainable weight.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A259", "content": "I choose movement that feels good and nourishing.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A260", "content": "Every cell in my body is healing and rejuvenating right now.", "age_group": "Adult (26-55)", "gender": null, "category": "Health", "is_custom": 0 },
      { "id": "A261", "content": "My happiness is contagious and uplifts those around me.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A262", "content": "I find peace in stillness and silence.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A263", "content": "I am a master of turning problems into opportunities for gratitude.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A264", "content": "I choose joyful thoughts and loving perspectives.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A265", "content": "Laughter is a daily habit I cherish.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A266", "content": "I release the need to compare myself to others.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A267", "content": "I attract kind, positive, and supportive people.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A268", "content": "My life is a beautiful tapestry of moments I appreciate.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A269", "content": "I live in alignment with my deepest values.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A270", "content": "I allow simplicity to be the foundation of my contentment.", "age_group": "Adult (26-55)", "gender": null, "category": "Happiness", "is_custom": 0 },
      { "id": "A271", "content": "My ability to lead and innovate is constantly expanding.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A272", "content": "I take decisive action on my most important goals.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A273", "content": "I am a highly effective and productive person.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A274", "content": "My vision is clear, and I execute it flawlessly.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A275", "content": "I view failure only as necessary feedback for growth.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A276", "content": "I am disciplined and focused on generating results.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A277", "content": "I confidently pursue massive, fulfilling goals.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A278", "content": "I am recognized and rewarded for my unique contributions.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A279", "content": "I successfully balance my ambition with my well-being.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A280", "content": "I am achieving success with ease and integrity.", "age_group": "Adult (26-55)", "gender": null, "category": "Success", "is_custom": 0 },
      { "id": "A281", "content": "I am a responsible steward of the money I possess.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A282", "content": "I have an abundant supply of all resources I need.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A283", "content": "I happily pay my bills knowing my money circulates and returns.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A284", "content": "My income is consistently growing beyond my expenses.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A285", "content": "My prosperity benefits everyone in my circle.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A286", "content": "I attract opportunities for passive income and financial freedom.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A287", "content": "I save money automatically and without effort.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A288", "content": "I trust the universe to provide me with endless abundance.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A289", "content": "I am magnetic to unexpected windfalls and opportunities.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A290", "content": "My financial future is secure, prosperous, and joyous.", "age_group": "Adult (26-55)", "gender": null, "category": "Wealth", "is_custom": 0 },
      { "id": "A291", "content": "I attract profound intimacy and connection into my life.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A292", "content": "I speak my truth with love and receive others' truths with openness.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A293", "content": "I prioritize emotional safety and trust in my bonds.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A294", "content": "I offer genuine support and seek it when needed.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A295", "content": "I am a patient and affirming partner/friend.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A296", "content": "I let go of relationships that no longer serve my highest good.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A297", "content": "My partnerships are balanced, respectful, and joyful.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A298", "content": "I am fully seen and deeply loved for who I am.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A299", "content": "I nurture my social circle with positive energy.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A300", "content": "My relationship with myself is the foundation for all others.", "age_group": "Adult (26-55)", "gender": null, "category": "Relationship", "is_custom": 0 },
      { "id": "A301", "content": "Joy is my birthright and my constant companion.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A302", "content": "I actively seek out and notice moments of profound joy.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A303", "content": "My soul is vibrant, and my heart is light.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A304", "content": "I let go of seriousness and embrace playfulness.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A305", "content": "I celebrate my existence and the gift of life.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A306", "content": "I allow myself to be excited about the future.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A307", "content": "I am surrounded by beautiful and inspiring things.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A308", "content": "I make choices that bring me deep, soulful satisfaction.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A309", "content": "My internal state is one of peace and happiness.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A310", "content": "I am a beacon of light, radiating joy to others.", "age_group": "Adult (26-55)", "gender": null, "category": "Joy", "is_custom": 0 },
      { "id": "A311", "content": "My creative endeavors are met with success and appreciation.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A312", "content": "I fearlessly begin new projects and see them through.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A313", "content": "My imagination is a powerful tool for manifesting my dreams.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A314", "content": "I trust my unique style and artistic voice.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A315", "content": "I find innovative solutions to every problem I face.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A316", "content": "I am a brilliant and prolific creator.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A317", "content": "I use my hands and mind to bring beauty into the world.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A318", "content": "Creative blocks dissolve the moment I take action.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A319", "content": "I am constantly inspired by the world around me.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A320", "content": "I release perfectionism and embrace the creative flow.", "age_group": "Adult (26-55)", "gender": null, "category": "Creativity", "is_custom": 0 },
      { "id": "A321", "content": "I forgive myself for past lapses in self-care.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A322", "content": "I protect my time and energy fiercely.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A323", "content": "I nourish my spirit with activities that feed my soul.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A324", "content": "I schedule quiet time to reconnect with myself.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A325", "content": "I recognize when I need a break and take it immediately.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A326", "content": "I am worthy of rest, relaxation, and revitalization.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A327", "content": "I listen to the subtle cues my body gives me.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A328", "content": "I release the habit of overcommitting and pleasing others.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A329", "content": "I treat myself with profound love and respect every day.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A330", "content": "Self-care is a non-negotiable part of my success.", "age_group": "Adult (26-55)", "gender": null, "category": "Self-Care", "is_custom": 0 },
      { "id": "A331", "content": "I am fully present in this moment, and it is enough.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A332", "content": "I observe my thoughts without judgment or attachment.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A333", "content": "I breathe deeply and release stress with every exhale.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A334", "content": "I choose calm and peace in the midst of chaos.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A335", "content": "I am grounded and centered in my body.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A336", "content": "I approach every activity with focused awareness.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A337", "content": "I am grateful for the clarity my presence brings.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A338", "content": "I take moments throughout the day to simply notice.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A339", "content": "My mind is quiet and receptive to wisdom.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A340", "content": "I practice mindful living in everything I do.", "age_group": "Adult (26-55)", "gender": null, "category": "Mindfulness", "is_custom": 0 },
      { "id": "A341", "content": "My history has prepared me perfectly for this stage of life.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A342", "content": "I am comfortable and confident in my own skin.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A343", "content": "I am surrounded by love, gratitude, and good company.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A344", "content": "I am a mentor and an inspiration to younger generations.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A345", "content": "I accept the aging process with grace and positivity.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A346", "content": "I continue to learn and evolve every single day.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A347", "content": "I celebrate my resilience and ability to adapt.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A348", "content": "I am a valuable and cherished member of my community.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A349", "content": "I trust my intuition and the wisdom of my experience.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A350", "content": "I am loved deeply and unconditionally.", "age_group": "Senior (56+)", "gender": null, "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A351", "content": "I dedicate time to my passions and hobbies.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A352", "content": "My mind is sharp, and my hands are skilled.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A353", "content": "My artistic expression brings me and others great joy.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A354", "content": "I am always discovering new ways to occupy my time happily.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A355", "content": "I fearlessly share my creations and talents.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A356", "content": "I embrace the freedom to pursue anything that interests me.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A357", "content": "I am an active participant in life's endless wonder.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A358", "content": "I find beauty and inspiration in my everyday environment.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A359", "content": "My creativity is a beautiful expression of my soul.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A360", "content": "Every day is an opportunity for a new adventure or project.", "age_group": "Senior (56+)", "gender": null, "category": "Creative Pursuits", "is_custom": 0 },
      { "id": "A361", "content": "I respect women and advocate for equality.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A362", "content": "My leadership is characterized by empathy and justice.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A363", "content": "I am comfortable expressing affection and warmth.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A364", "content": "I am honest about my mistakes and committed to growth.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A365", "content": "I am a patient and supportive father/partner.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A366", "content": "I release societal pressure to be emotionally closed off.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A367", "content": "I am a protector who also knows when to yield.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A368", "content": "My identity is not tied to my work or achievements.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A369", "content": "I am a great listener and a thoughtful friend.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A370", "content": "I honor my body with fitness and good health.", "age_group": null, "gender": "Male", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A371", "content": "My intuition protects and guides me in all decisions.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A372", "content": "I am a fierce advocate for myself and for others.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A373", "content": "I honor the feminine cycles of rest and activity.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A374", "content": "I am comfortable with my power and my softness.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A375", "content": "I release the need to be everything to everyone.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A376", "content": "I am financially independent and successful.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A377", "content": "My voice is clear, persuasive, and influential.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A378", "content": "I attract equal and loving partnerships.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A379", "content": "I give myself permission to shine brightly and unapologetically.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A380", "content": "I am a resilient woman capable of great change.", "age_group": null, "gender": "Female", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A381", "content": "I am loved and valued exactly as I am today.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A382", "content": "My gender expression is beautiful and true.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A383", "content": "I seek out spaces where my identity is affirmed.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A384", "content": "I am a vibrant member of the queer community.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A385", "content": "I own my narrative and tell my story authentically.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A386", "content": "My journey is one of self-trust and bravery.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A387", "content": "I am perfectly whole, complete, and enough.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A388", "content": "I let go of external labels that don't fit me.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A389", "content": "I am celebrating my unique path to self-discovery.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A390", "content": "I create my own safety and comfort wherever I go.", "age_group": null, "gender": "Non-binary", "category": "Self-Esteem", "is_custom": 0 },
      { "id": "A391", "content": "I transform challenges into opportunities for growth.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A392", "content": "I am an unstoppable individual.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A393", "content": "I stand tall and firm in my own power.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A394", "content": "Every breath I take gives me new strength.", "age_group": null, "gender": null, "category": "Universal Strength", "is_custom": 0 },
      { "id": "A395", "content": "I am excited to step out of my comfort zone.", "age_group": null, "gender": null, "category": "Universal Growth", "is_custom": 0 },
      { "id": "A396", "content": "I embrace change as a path to something better.", "age_group": null, "gender": null, "category": "Universal Growth", "is_custom": 0 },
      { "id": "A397", "content": "I am always growing, evolving, and improving.", "age_group": null, "gender": null, "category": "Universal Growth", "is_custom": 0 },
      { "id": "A398", "content": "I choose progress over perfection every single day.", "age_group": null, "gender": null, "category": "Universal Growth", "is_custom": 0 },
      { "id": "A399", "content": "I learn something valuable from every experience.", "age_group": null, "gender": null, "category": "Universal Growth", "is_custom": 0 },
      { "id": "A400", "content": "I forgive myself and move forward with clarity.", "age_group": null, "gender": null, "category": "Universal Growth", "is_custom": 0 },
    ];

    for (final affirmation in affirmations) {
      // Use INSERT OR IGNORE to avoid UNIQUE constraint errors if data exists
      await db.rawInsert(
        'INSERT OR IGNORE INTO affirmations (id, content, age_group, gender, category, is_custom) VALUES (?, ?, ?, ?, ?, ?)',
        [
          affirmation['id'],
          affirmation['content'],
          affirmation['age_group'],
          affirmation['gender'],
          affirmation['category'],
          affirmation['is_custom'],
        ],
      );
    }
  }

  // User Profile operations
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('user_profile', profile.toMap());
      for (final focusArea in profile.focusAreas) {
        await txn.insert('user_focus_areas', {
          'user_id': profile.id,
          'focus_area': focusArea,
        });
      }
    });
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
    
    // Build the query to match user's profile and focus areas
    String whereClause;
    List<dynamic> whereArgs;
    
    if (profile.focusAreas.isNotEmpty) {
      // Include affirmations that match age/gender AND (custom OR focus areas)
      final placeholders = profile.focusAreas.map((_) => '?').join(',');
      whereClause = '''
        (age_group IS NULL OR age_group = ?) AND
        (gender IS NULL OR gender = ?) AND
        (is_custom = 1 OR category IN ($placeholders))
      ''';
      whereArgs = [profile.ageGroup, profile.gender, ...profile.focusAreas];
    } else {
      // If no focus areas, include custom affirmations and universal ones
      whereClause = '''
        (age_group IS NULL OR age_group = ?) AND
        (gender IS NULL OR gender = ?) AND
        is_custom = 1
      ''';
      whereArgs = [profile.ageGroup, profile.gender];
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'affirmations',
      where: whereClause,
      whereArgs: whereArgs,
    );
    
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<List<Affirmation>> getAllAffirmations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('affirmations');
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  // Debug method to check database state
  Future<void> debugDatabaseState() async {
    final db = await database;
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM affirmations');
    final customCount = await db.rawQuery('SELECT COUNT(*) as count FROM affirmations WHERE is_custom = 1');
    final categories = await db.rawQuery('SELECT DISTINCT category FROM affirmations WHERE category IS NOT NULL');
    
    print('=== DATABASE DEBUG ===');
    print('Total affirmations: ${count.first['count']}');
    print('Custom affirmations: ${customCount.first['count']}');
    print('Available categories: ${categories.map((c) => c['category']).join(', ')}');
    print('=====================');
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
