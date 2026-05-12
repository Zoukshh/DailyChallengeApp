import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
        'Firebase initialization failed (Did you run flutterfire configure?): $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await appState.load();

  tz.initializeTimeZones();
  await NotificationService.init();
  runApp(const DailyChallengeApp());
}


enum Category { health, fitness, focus, mind, creativity }

enum Difficulty { easy, medium, hard }

enum Mood { great, good, neutral, tired, stressed }

// ---------------------------------------------------------------------------
// NOTIFICATION ENGINE
// ---------------------------------------------------------------------------

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<void> scheduleDaily(TimeOfDay time) async {
    await _notifications.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      0,
      'Daily Challenge Reminder 🚀',
      'Don\'t forget to complete your challenge today! Stay consistent! 🔥',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelAll() => _notifications.cancelAll();
}

// ---------------------------------------------------------------------------
// CLOUD ENGINE (Firebase logic)
// ---------------------------------------------------------------------------

class CloudService {
  static final _db = FirebaseFirestore.instance;
  static String? _userId;

  static Future<void> init(String userId) async {
    _userId = userId;
  }

  static Future<void> syncHistory(List<HistoryRecord> records) async {
    if (_userId == null) return;
    try {
      final batch = _db.batch();
      final userRef = _db.collection('users').doc(_userId);
      
      for (var record in records) {
        final recRef = userRef.collection('history').doc(record.date.toIso8601String());
        batch.set(recRef, record.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Cloud Sync Error: $e');
    }
  }

  static Future<void> updateStats(int xp, int level, int streak) async {
    if (_userId == null) return;
    try {
      await _db.collection('users').doc(_userId).set({
        'totalXp': xp,
        'level': level,
        'streak': streak,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Stats Sync Error: $e');
    }
  }

  static Stream<QuerySnapshot> getLeaderboard() {
    return _db.collection('users')
        .orderBy('totalXp', descending: true)
        .limit(20)
        .snapshots();
  }
}

// 🏗️ THE BLUEPRINTS (Data Models)
class Badge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final DateTime unlockedAt;

  Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon.codePoint,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        unlockedAt: DateTime.parse(json['unlockedAt']),
      );
}

class HabitChallenge {
  final String title;
  final String description;
  final Category category;
  final Difficulty difficulty;
  final int xp;
  final List<String> tags;

  HabitChallenge({
    required this.title,
    required this.description,
    required this.category,
    this.difficulty = Difficulty.easy,
    this.xp = 100,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category.index,
        'difficulty': difficulty.index,
        'xp': xp,
        'tags': tags,
      };

  factory HabitChallenge.fromJson(Map<String, dynamic> json) => HabitChallenge(
        title: json['title'],
        description: json['description'],
        category: Category.values[
            (json['category'] ?? 0) >= Category.values.length
                ? 0
                : (json['category'] ?? 0)],
        difficulty: Difficulty.values[
            (json['difficulty'] ?? 0) >= Difficulty.values.length
                ? 0
                : (json['difficulty'] ?? 0)],
        xp: json['xp'] ?? 100,
        tags: List<String>.from(json['tags'] ?? []),
      );
}

class HistoryRecord {
  final String title;
  final DateTime date;
  final int xpEarned;
  final Category category;
  final Mood? mood;
  final String? note;

  HistoryRecord({
    required this.title,
    required this.date,
    required this.xpEarned,
    required this.category,
    this.mood,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date.toIso8601String(),
        'xpEarned': xpEarned,
        'category': category.index,
        'mood': mood?.index,
        'note': note,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        title: json['title'],
        date: DateTime.parse(json['date']),
        xpEarned: json['xpEarned'],
        category: Category.values[
            (json['category'] ?? 0) >= Category.values.length
                ? 0
                : (json['category'] ?? 0)],
        mood: json['mood'] != null ? Mood.values[json['mood']] : null,
        note: json['note'],
      );
}

// 🧠 THE COMMAND CENTER (App Engine & State)
// ===========================================================================
// SECTION 3: THE ENGINE (App State & Persistence Logic)
// ===========================================================================

class AppManager extends ChangeNotifier {
  // [#ENGINE-XP] - Progress Tracking
  int streak = 0; // Number of consecutive days the goal was met
  int totalXp = 0; // Total experience points earned by the user
  double dailyProgress = 0.0; // % of today's goal completed (0.0 to 1.0)
  int dailyGoal = 1; // How many tasks the user wants to do per day
  int completedToday = 0; // Number of tasks finished since midnight

  List<HistoryRecord> history = [];
  List<HabitChallenge> customChallenges = [];
  List<Badge> unlockedBadges = [];

  bool isDarkMode = false;
  bool notificationsEnabled = false;
  bool motivationalReminders = true;
  bool firstRun = true;
  Color accentColor = const Color(0xFF6366F1);

  TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);
  HabitChallenge? activeChallenge;
  String? userId;

  // 📊 THE CALCULATOR (Progress & Level Logic)
  // Calculate Level: Every 500 XP = 1 Level
  int get level => (totalXp / LevelingEngine.getXPForLevel(1)).floor() + 1;

  // Calculate % progress toward the NEXT level
  double get levelProgress => (totalXp % LevelingEngine.getXPForLevel(1).toInt()) / LevelingEngine.getXPForLevel(1);

  String get rank => LevelingEngine.getRankName(level);

  // Filters history to find only tasks completed TODAY
  int get xpToday {
    final now = DateTime.now();
    return history
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold(0, (acc, e) => acc + e.xpEarned); // Adds up all XP from today
  }

  // [#ENGINE-SAVE] - Persistence Logic
  // SAVE: Converts all app data to JSON and stores it on the phone's memory
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance(); // Open storage
      final data = {
        'streak': streak,
        'totalXp': totalXp,
        'dailyProgress': dailyProgress,
        'dailyGoal': dailyGoal,
        'completedToday': completedToday,
        'history': history.map((e) => e.toJson()).toList(),
        'customChallenges': customChallenges.map((e) => e.toJson()).toList(),
        'unlockedBadges': unlockedBadges.map((e) => e.toJson()).toList(),
        'isDarkMode': isDarkMode,
        'notificationsEnabled': notificationsEnabled,
        'motivationalReminders': motivationalReminders,
        'accentColor': accentColor.toARGB32(),
        'reminderTime': '${reminderTime.hour}:${reminderTime.minute}',
        'activeChallenge': activeChallenge?.toJson(),
        'firstRun': firstRun,
        'userId': userId,
      };
      await prefs.setString('app_data_v3', jsonEncode(data)); // Write to disk
    } catch (e) {
      debugPrint('Save Error: $e');
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawData = prefs.getString('app_data_v3');

      if (rawData != null) {
        final data = jsonDecode(rawData);
        streak = data['streak'] ?? 0;
        totalXp = data['totalXp'] ?? 0;
        dailyProgress = data['dailyProgress'] ?? 0.0;
        dailyGoal = data['dailyGoal'] ?? 1;
        completedToday = data['completedToday'] ?? 0;

        history = (data['history'] as List? ?? [])
            .map((e) => HistoryRecord.fromJson(e))
            .toList();
        customChallenges = (data['customChallenges'] as List? ?? [])
            .map((e) => HabitChallenge.fromJson(e))
            .toList();
        unlockedBadges = (data['unlockedBadges'] as List? ?? [])
            .map((e) => Badge.fromJson(e))
            .toList();

        isDarkMode = data['isDarkMode'] ?? false;
        notificationsEnabled = data['notificationsEnabled'] ?? false;
        motivationalReminders = data['motivationalReminders'] ?? true;

        if (data['accentColor'] != null) {
          accentColor = Color(data['accentColor']);
        }

        if (data['reminderTime'] != null) {
          final parts = (data['reminderTime'] as String).split(':');
          reminderTime =
              TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        if (data['activeChallenge'] != null) {
          activeChallenge = HabitChallenge.fromJson(data['activeChallenge']);
        }
        if (data['userId'] != null) {
          userId = data['userId'];
          CloudService.init(userId!);
        } else {
          userId = 'user_${Random().nextInt(999999)}';
          CloudService.init(userId!);
          save();
        }

        if (notificationsEnabled) {
          NotificationService.scheduleDaily(reminderTime);
        }
        notifyListeners();
      } else {
        // First time initialization
        userId = 'user_${Random().nextInt(999999)}';
        CloudService.init(userId!);
        save();
      }
    } catch (e) {
      debugPrint('Load Error: $e');
    }
  }

  // Cloud Sync Trigger
  Future<void> syncToCloud() async {
    if (userId != null) {
      await CloudService.updateStats(totalXp, level, streak);
      await CloudService.syncHistory(history.take(10).toList()); // Sync last 10 for performance
    }
  }

  void toggleTheme(bool val) {
    isDarkMode = val;
    save();
    notifyListeners();
  }

  void setAccentColor(Color color) {
    accentColor = color;
    save();
    notifyListeners();
  }

  void toggleNotifications(bool val) {
    notificationsEnabled = val;
    if (val) {
      NotificationService.scheduleDaily(reminderTime);
    } else {
      NotificationService.cancelAll();
    }
    save();
    notifyListeners();
  }

  void updateReminderTime(TimeOfDay time) {
    reminderTime = time;
    if (notificationsEnabled) {
      NotificationService.scheduleDaily(time);
    }
    save();
    notifyListeners();
  }

  void addXp(int amount, {String? reason}) {
    totalXp += amount;
    if (reason != null) {
      history.insert(
          0,
          HistoryRecord(
            title: reason,
            date: DateTime.now(),
            xpEarned: amount,
            category: Category.mind, // Default for quick logs
          ));
    }
    syncToCloud();
    save();
    notifyListeners();
  }

  void completeTask(HabitChallenge c, {Mood? mood, String? note}) {
    completedToday += 1;
    
    // Apply Dart logic multipliers
    final multiplier = LevelingEngine.getMultiplier(streak);
    final earnedXp = (c.xp * multiplier).toInt();
    totalXp += earnedXp;

    // Check for streak increase if daily goal met
    if (completedToday >= dailyGoal) {
      streak += 1;
      dailyProgress = 1.0;
    } else {
      dailyProgress = completedToday / dailyGoal;
    }

    history.insert(
        0,
        HistoryRecord(
          title: c.title,
          date: DateTime.now(),
          xpEarned: c.xp,
          category: c.category,
          mood: mood,
          note: note,
        ));

    // Cleanup: Clear active challenge
    if (activeChallenge?.title == c.title) {
      activeChallenge = null;
    }

    _checkBadges();
    save();
    notifyListeners();
  }

  void _checkBadges() {
    final badgeData = [
      {
        'id': 'streak_7',
        'title': 'Week Warrior',
        'desc': 'Maintain a 7-day streak',
        'req': () => streak >= 7,
        'icon': Icons.local_fire_department_rounded
      },
      {
        'id': 'xp_1000',
        'title': 'Centurion',
        'desc': 'Earn 1000 total XP',
        'req': () => totalXp >= 1000,
        'icon': Icons.military_tech_rounded
      },
      {
        'id': 'lvl_5',
        'title': 'Adept',
        'desc': 'Reach Level 5',
        'req': () => level >= 5,
        'icon': Icons.workspace_premium_rounded
      },
    ];

    for (var b in badgeData) {
      if ((b['req'] as Function)() &&
          !unlockedBadges.any((existing) => existing.id == b['id'])) {
        unlockedBadges.add(Badge(
          id: b['id'] as String,
          title: b['title'] as String,
          description: b['desc'] as String,
          icon: b['icon'] as IconData,
          unlockedAt: DateTime.now(),
        ));
      }
    }
  }

  void updateProgress(double p) {
    dailyProgress = p;
    save();
    notifyListeners();
  }

  void shuffle(HabitChallenge c) {
    activeChallenge = c;
    dailyProgress = completedToday / dailyGoal;
    save();
    notifyListeners();
  }

  void addCustom(HabitChallenge c) {
    customChallenges.add(c);
    save();
    notifyListeners();
  }

  void completeOnboarding() {
    firstRun = false;
    save();
    notifyListeners();
  }

  void reset() {
    streak = 0;
    totalXp = 0;
    dailyProgress = 0.0;
    completedToday = 0;
    history.clear();
    customChallenges.clear();
    unlockedBadges.clear();
    save();
    notifyListeners();
  }
}

final appState = AppManager();

// ===========================================================================
// SECTION 4: THE LIBRARY [#LIBRARY]
// ===========================================================================

class ChallengeData {
  static final List<HabitChallenge> library = [
    HabitChallenge(
        title: "Digital Detox",
        description: "No social media for the first 2 hours of your day.",
        category: Category.focus,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Posture Check",
        description: "Maintain a straight back while working for 30 minutes.",
        category: Category.health,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Reading Sprint",
        description: "Read 15 pages of a non-fiction book.",
        category: Category.mind,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Gratitude Log",
        description: "Write down 3 things you are truly grateful for today.",
        category: Category.mind,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Sunlight Soak",
        description: "Get 15 minutes of direct morning sunlight.",
        category: Category.health,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Sugar Zero",
        description: "Avoid all processed sugars for the entire day.",
        category: Category.health,
        difficulty: Difficulty.hard,
        xp: 500),
    HabitChallenge(
        title: "Deep Breathing",
        description: "Practice box breathing (4-4-4-4) for 5 minutes.",
        category: Category.mind,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Plank Challenge",
        description: "Hold a steady plank position for 2 minutes.",
        category: Category.fitness,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Inbox Zero",
        description: "Clear your primary email inbox completely.",
        category: Category.focus,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Fruit Fuel",
        description: "Eat 3 different types of fresh fruit today.",
        category: Category.health,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Journal Entry",
        description: "Write 200 words about your goals for this month.",
        category: Category.creativity,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Cold Water Splash",
        description: "Wash your face with ice-cold water 3 times today.",
        category: Category.health,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "No Spend Day",
        description: "Do not spend money on anything non-essential today.",
        category: Category.focus,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Stretching Flow",
        description: "Complete a full-body stretching routine for 10 mins.",
        category: Category.fitness,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Learn Something New",
        description: "Watch a documentary or tutorial on a new topic.",
        category: Category.mind,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Desk Cleanse",
        description: "Completely clear and sanitize your workspace.",
        category: Category.focus,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Phone-Free Meal",
        description: "Eat your lunch/dinner without any digital devices.",
        category: Category.mind,
        difficulty: Difficulty.medium,
        xp: 250),
    HabitChallenge(
        title: "Walk 10k Steps",
        description: "Reach the 10,000 step milestone today.",
        category: Category.fitness,
        difficulty: Difficulty.hard,
        xp: 500),
    HabitChallenge(
        title: "Mindful Tea",
        description: "Drink a cup of tea slowly, focusing only on the taste.",
        category: Category.mind,
        difficulty: Difficulty.easy,
        xp: 100),
    HabitChallenge(
        title: "Visual Design",
        description: "Draw or sketch a logo concept for 15 minutes.",
        category: Category.creativity,
        difficulty: Difficulty.medium,
        xp: 250),
  ];

  static HabitChallenge getDaily() {
    int dayIndex = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    return library[dayIndex % library.length];
  }

  static HabitChallenge getRandom(HabitChallenge current) {
    var combined = [...library, ...appState.customChallenges];
    var others = combined.where((c) => c.title != current.title).toList();
    if (others.isEmpty) return current;
    return others[Random().nextInt(others.length)];
  }

  static Map<String, dynamic> getMeta(Category cat) {
    switch (cat) {
      case Category.health:
        return {
          'icon': Icons.spa_rounded,
          'color': const Color(0xFF10B981),
          'label': 'Vitality'
        };
      case Category.fitness:
        return {
          'icon': Icons.bolt_rounded,
          'color': const Color(0xFFF43F5E),
          'label': 'Power'
        };
      case Category.focus:
        return {
          'icon': Icons.center_focus_strong_rounded,
          'color': const Color(0xFF6366F1),
          'label': 'Focus'
        };
      case Category.mind:
        return {
          'icon': Icons.self_improvement_rounded,
          'color': const Color(0xFF8B5CF6),
          'label': 'Zen'
        };
      case Category.creativity:
        return {
          'icon': Icons.palette_rounded,
          'color': const Color(0xFFEC4899),
          'label': 'Creation'
        };
    }
  }
}

// 📈 THE ANALYTICS ENGINE (Pure Dart)
class HabitAnalytics {
  static double calculateSuccessRate(List<HistoryRecord> history) {
    if (history.isEmpty) return 0.0;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recent = history.where((h) => h.date.isAfter(thirtyDaysAgo)).toList();
    if (recent.isEmpty) return 0.0;
    return recent.length / 30.0;
  }

  static Map<Category, int> getCategoryDistribution(List<HistoryRecord> history) {
    Map<Category, int> dist = {};
    for (var cat in Category.values) {
      dist[cat] = history.where((h) => h.category == cat).length;
    }
    return dist;
  }

  static int getPredictedXp(int currentXp, int streak) {
    double velocity = currentXp / (streak == 0 ? 1 : streak);
    return (currentXp + (velocity * 7)).toInt(); // Predict next 7 days
  }
}

// 🎨 THE THEME ENGINE (Advanced Color Logic)
class ThemeEngine {
  static Color getContrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static LinearGradient getPremiumGradient(Color accent) {
    return LinearGradient(
      colors: [accent, accent.withValues(alpha: 0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static List<BoxShadow> getSoftShadow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.1),
        blurRadius: 20,
        spreadRadius: 5,
        offset: const Offset(0, 10),
      )
    ];
  }
}

// 🧠 THE LOGIC ENGINES (Pure Dart)
class LevelingEngine {
  static double getXPForLevel(int level) => level * 500.0;

  static double getMultiplier(int streak) {
    if (streak >= 30) return 2.0;
    if (streak >= 7) return 1.5;
    if (streak >= 3) return 1.2;
    return 1.0;
  }

  static String getRankName(int level) {
    if (level < 5) return 'Novice';
    if (level < 10) return 'Apprentice';
    if (level < 20) return 'Warrior';
    if (level < 50) return 'Elite';
    return 'Master';
  }

  static String getReflectionPrompt(Mood mood) {
    switch (mood) {
      case Mood.great: return "What was the highlight of your day?";
      case Mood.good: return "What made you smile today?";
      case Mood.neutral: return "What is one thing you can improve tomorrow?";
      case Mood.tired: return "How can you prioritize rest tonight?";
      case Mood.stressed: return "What is one thing you can let go of right now?";
    }
  }
}

// ===========================================================================
// SECTION 5: THE APP SHELL [#SHELL-NAV]
// ===========================================================================

class DailyChallengeApp extends StatelessWidget {
  const DailyChallengeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: appState.accentColor,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            textTheme: GoogleFonts.outfitTextTheme(),
            appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent, elevation: 0),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: appState.accentColor,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent, elevation: 0),
          ),
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboarding();
    });
  }

  void _showOnboarding() {
    if (appState.firstRun) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => const _OnboardingSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        const TodayScreen(),
        const HistoryScreen(),
        const LeaderboardScreen(),
        const CreateScreen(),
        const SettingsScreen(),
      ][_tab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
        ),
        child: NavigationBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedIndex: _tab,
          indicatorColor: appState.accentColor.withValues(alpha: 0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_rounded), label: 'Today'),
            NavigationDestination(
                icon: Icon(Icons.auto_graph_rounded), label: 'Progress'),
            NavigationDestination(
                icon: Icon(Icons.emoji_events_rounded), label: 'Hall'),
            NavigationDestination(
                icon: Icon(Icons.add_circle_outline_rounded), label: 'Create'),
            NavigationDestination(
                icon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SECTION 6: THE SCREENS [#SCREEN-TODAY]
// ===========================================================================

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _showMoodLog = false;
  final _noteCtrl = TextEditingController();
  Mood _selectedMood = Mood.good;

  @override
  void initState() {
    super.initState();
  }

  void _progress() async {
    setState(() => _showMoodLog = true);
  }

  void _confirmCompletion() async {
    final current = appState.activeChallenge ?? ChallengeData.getDaily();
    HapticFeedback.heavyImpact();
    appState.completeTask(current, mood: _selectedMood, note: _noteCtrl.text);
    _noteCtrl.clear();
    setState(() => _showMoodLog = false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _showSuccessSheet(current);
  }

  void _showSuccessSheet(HabitChallenge c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
            const SizedBox(height: 16),
            Text('Goal Reached!',
                style: GoogleFonts.outfit(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You earned ${c.xp} XP! Keep pushing!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Great Job!'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final current = appState.activeChallenge ?? ChallengeData.getDaily();
        var meta = ChallengeData.getMeta(current.category);
        bool isDone = appState.completedToday >= appState.dailyGoal;

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'DAILY GOAL: ${appState.completedToday}/${appState.dailyGoal}',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: appState.accentColor,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5)),
                          Text('Streak: ${appState.streak} 🔥',
                              style: GoogleFonts.outfit(
                                  fontSize: 32, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: appState.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16)),
                            child: Text('Lvl ${appState.level}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: appState.accentColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // New Stats Row
                  Row(
                    children: [
                      _buildQuickStat('RANK', appState.rank,
                          Icons.workspace_premium_rounded),
                      const SizedBox(width: 12),
                      _buildQuickStat('TOTAL XP', '${appState.totalXp}',
                          Icons.bolt_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 32),
                  // Motivational Quote
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: appState.accentColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: appState.accentColor.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote_rounded,
                            color: appState.accentColor.withValues(alpha: 0.3),
                            size: 32),
                        const SizedBox(height: 8),
                        Text(
                          "\"The secret of getting ahead is getting started.\"",
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_showMoodLog)
                    _buildMoodLog()
                  else
                    _buildChallengeCard(current, meta, isDone),

                  const SizedBox(height: 32),
                  if (!_showMoodLog)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          final current = appState.activeChallenge ??
                              ChallengeData.getDaily();
                          final next = ChallengeData.getRandom(current);
                          appState.shuffle(next);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('Next Challenge',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold)),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 40),
                  Text('QUICK LOGS',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickLogButton(
                          Icons.local_drink_rounded, 'Water', Colors.blue),
                      _buildQuickLogButton(
                          Icons.restaurant_rounded, 'Snack', Colors.amber),
                      _buildQuickLogButton(Icons.accessibility_new_rounded,
                          'Stretch', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                appState.accentColor,
                appState.accentColor.withValues(alpha: 0.8)
              ]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: appState.accentColor.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            const SizedBox(height: 12),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLogButton(IconData icon, String label, Color color) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            appState.addXp(10, reason: '$label Log');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Logged $label! +10 XP'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: color,
            ));
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      ],
    );
  }

  Widget _buildChallengeCard(
      HabitChallenge current, Map<String, dynamic> meta, bool isDone) {
    return GestureDetector(
      onTap: _progress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDone
              ? meta['color'].withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(32),
          border: isDone
              ? Border.all(color: meta['color'].withValues(alpha: 0.3), width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 30,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: meta['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(current.difficulty.name.toUpperCase(),
                      style: TextStyle(
                          color: meta['color'],
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: meta['color'].withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(meta['icon'], color: meta['color'], size: 40),
            ),
            const SizedBox(height: 24),
            Text(meta['label'].toUpperCase(),
                style: GoogleFonts.outfit(
                    color: meta['color'],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 12)),
            const SizedBox(height: 12),
            Text(current.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(current.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.4)),
            const SizedBox(height: 40),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: appState.dailyProgress,
                minHeight: 16,
                color: meta['color'],
                backgroundColor: (meta['color'] as Color).withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(height: 20),
            Text(isDone ? 'GOAL COMPLETE!' : 'TAP TO COMPLETE',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: isDone ? meta['color'] : Colors.grey.withValues(alpha: 0.6),
                  letterSpacing: 2,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodLog() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling?',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: Mood.values.map((m) {
              final icons = [
                Icons.sentiment_very_satisfied,
                Icons.sentiment_satisfied,
                Icons.sentiment_neutral,
                Icons.sentiment_dissatisfied,
                Icons.sentiment_very_dissatisfied
              ];
              bool sel = _selectedMood == m;
              return IconButton(
                onPressed: () => setState(() => _selectedMood = m),
                icon: Icon(icons[m.index],
                    color: sel ? appState.accentColor : Colors.grey, size: 32),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Any reflections? (Optional)',
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _showMoodLog = false),
                  child: const Text('Cancel'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appState.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _confirmCompletion,
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN: CREATE CUSTOM CHALLENGE
// ---------------------------------------------------------------------------

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  Category _cat = Category.health;
  Difficulty _diff = Difficulty.easy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('New Challenge',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Challenge Title',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                hintText: "e.g. Meditate for 10 mins",
              ),
            ),
            const SizedBox(height: 24),
            Text('Motivation Message',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                hintText: "Why is this important?",
              ),
            ),
            const SizedBox(height: 24),
            Text('Category',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: Category.values.map((c) {
                var m = ChallengeData.getMeta(c);
                bool sel = _cat == c;
                return ChoiceChip(
                  label: Text(m['label']),
                  selected: sel,
                  onSelected: (_) => setState(() => _cat = c),
                  selectedColor: m['color'].withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                      color: sel ? m['color'] : Colors.grey,
                      fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Difficulty',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: Difficulty.values.map((d) {
                bool sel = _diff == d;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: sel
                            ? appState.accentColor
                            : Colors.grey.withValues(alpha: 0.1),
                        foregroundColor: sel ? Colors.white : Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _diff = d),
                      child: Text(d.name.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                if (_title.text.isEmpty) return;
                appState.addCustom(HabitChallenge(
                  title: _title.text,
                  description:
                      _desc.text.isEmpty ? "Stay consistent!" : _desc.text,
                  category: _cat,
                  difficulty: _diff,
                  xp: (_diff.index + 1) * 100,
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Custom challenge added!')));
                _title.clear();
                _desc.clear();
              },
              child: Text('Create Challenge',
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN: PERFORMANCE HISTORY
// ---------------------------------------------------------------------------

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Performance',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  appState.accentColor,
                  appState.accentColor.withValues(alpha: 0.7)
                ]),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL PROGRESS',
                      style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text('${appState.totalXp} XP',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                        value: appState.levelProgress,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                        minHeight: 6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (appState.unlockedBadges.isNotEmpty) ...[
              Text('Achievements',
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: appState.unlockedBadges.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final b = appState.unlockedBadges[i];
                    return Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: appState.accentColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: appState.accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(b.icon, color: appState.accentColor, size: 30),
                          const SizedBox(height: 4),
                          Text(b.title.split(' ')[0],
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            Text('Activity History',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (appState.history.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Text('Start your journey today!',
                          style: TextStyle(color: Colors.grey))))
            else
              ...appState.history.map((h) {
                var meta = ChallengeData.getMeta(h.category);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: meta['color'].withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(meta['icon'],
                              color: meta['color'], size: 20)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(h.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text(DateFormat('MMM d, h:mm a').format(h.date),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                                if (h.mood != null) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.circle,
                                      size: 4, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(h.mood!.name,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                ]
                              ],
                            )
                          ])),
                      Text('+${h.xpEarned}',
                          style: GoogleFonts.outfit(
                              color: Colors.green,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN: USER SETTINGS
// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF43F5E),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B)
    ];

    return Scaffold(
      appBar: AppBar(
          title: Text('Settings',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Personalization',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            _SettingTile(
                icon: Icons.palette_rounded,
                title: 'Accent Color',
                subtitle: 'Choose your theme',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: colors.map((c) {
                    bool isSelected = appState.accentColor == c;
                    return GestureDetector(
                      onTap: () => appState.setAccentColor(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 12),
                        width: isSelected ? 28 : 24,
                        height: isSelected ? 28 : 24,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.transparent, width: 3),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: c.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2)
                                ]
                              : [],
                        ),
                      ),
                    );
                  }).toList(),
                )),
            _SettingTile(
                icon: Icons.dark_mode_rounded,
                title: 'Appearance',
                subtitle: 'Dark mode',
                trailing: Switch(
                    value: appState.isDarkMode,
                    onChanged: (v) => appState.toggleTheme(v),
                    activeTrackColor: appState.accentColor)),
            const SizedBox(height: 32),
            Text('Notifications',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            _SettingTile(
              icon: Icons.notifications_active_rounded,
              title: 'Daily Reminders',
              subtitle: 'Stay on track',
              trailing: Switch(
                  value: appState.notificationsEnabled,
                  onChanged: (v) => appState.toggleNotifications(v),
                  activeTrackColor: appState.accentColor),
            ),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.access_time_rounded,
              title: 'Reminder Time',
              subtitle: appState.reminderTime.format(context),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: appState.reminderTime,
                );
                if (time != null) appState.updateReminderTime(time);
              },
            ),
            const SizedBox(height: 32),
            Text('System',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            _SettingTile(
                icon: Icons.delete_forever_rounded,
                title: 'Clear Data',
                subtitle: 'Reset everything',
                onTap: () {
                  appState.reset();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('All data reset successfully.')));
                }),
            const SizedBox(height: 40),
            Center(
                child: Text('Daily Challenge v2.0.0',
                    style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.5), fontSize: 10))),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20)),
      child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Icon(icon, color: Colors.grey),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          trailing: trailing),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN: GLOBAL LEADERBOARD
// ---------------------------------------------------------------------------

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Hall of Fame',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: StreamBuilder<QuerySnapshot>(
        stream: CloudService.getLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Cloud connection required for Leaderboard'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No champions yet. Be the first!'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              bool isMe = docs[i].id == appState.userId;
              
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isMe ? appState.accentColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: isMe ? Border.all(color: appState.accentColor) : null,
                ),
                child: Row(
                  children: [
                    Text('#${i + 1}', 
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey)),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      backgroundColor: appState.accentColor.withValues(alpha: 0.2),
                      child: Text((data['level'] ?? 1).toString(), 
                        style: TextStyle(color: appState.accentColor, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isMe ? 'You (Me)' : 'Explorer ${docs[i].id.substring(0, 5)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Streak: ${data['streak'] ?? 0} days',
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${data['totalXp'] ?? 0} XP',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: appState.accentColor)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ===========================================================================
// SECTION 6: PREMIUM ENGINES (Advanced Logic)
// ===========================================================================

class AdvancedAnalyticsEngine {
  /// Calculates the projected user level based on current velocity and consistency
  static Map<String, dynamic> getDetailedProjections(AppManager state) {
    if (state.history.isEmpty) return {'projectedLevel': 1, 'confidence': 0.0};
    
    double avgXpPerDay = state.totalXp / (state.streak == 0 ? 1 : state.streak).clamp(1, 365);
    int projectedXpInYear = (state.totalXp + (avgXpPerDay * 365)).toInt();
    int projectedLevel = (projectedXpInYear / 500).floor() + 1;
    
    return {
      'projectedLevel': projectedLevel,
      'velocity': avgXpPerDay,
      'consistencyScore': (state.streak / 30.0).clamp(0.0, 1.0),
      'milestones': _calculateMilestones(state.totalXp),
    };
  }

  static List<Map<String, dynamic>> _calculateMilestones(int currentXp) {
    final goals = [1000, 5000, 10000, 50000, 100000];
    return goals.map((g) => {
      'goal': g,
      'remaining': (g - currentXp).clamp(0, g),
      'progress': (currentXp / g).clamp(0.0, 1.0),
    }).toList();
  }

  /// Generates a heat map representation of the user's activity
  static List<int> getActivityHeatMap(List<HistoryRecord> history) {
    final now = DateTime.now();
    final List<int> map = List.filled(7, 0);
    for (var record in history) {
      if (record.date.isAfter(now.subtract(const Duration(days: 7)))) {
        map[record.date.weekday - 1]++;
      }
    }
    return map;
  }
}

class RecommendationEngine {
  /// Mock AI logic to suggest the best challenge for the user
  static HabitChallenge getPersonalizedSuggestion(AppManager state) {
    final history = state.history;
    if (history.isEmpty) return ChallengeData.getDaily();

    // Find the least performed category
    final distribution = HabitAnalytics.getCategoryDistribution(history);
    Category weakCategory = Category.values.first;
    int minCount = 999;
    
    for (var cat in Category.values) {
      if ((distribution[cat] ?? 0) < minCount) {
        minCount = distribution[cat] ?? 0;
        weakCategory = cat;
      }
    }

    // Filter library for this category
    final options = ChallengeData.library.where((c) => c.category == weakCategory).toList();
    if (options.isEmpty) return ChallengeData.getDaily();
    
    return options[Random().nextInt(options.length)];
  }

  static String getMotivationalInsight(AppManager state) {
    if (state.streak > 3) {
      return "You're on a roll! People with a ${state.streak}-day streak are 80% more likely to reach their goals.";
    } else if (state.totalXp > 1000) {
      return "You've earned over 1,000 XP! You're now in the top 10% of consistent achievers.";
    } else {
      return "Every small step counts. Start your challenge today to build momentum!";
    }
  }
}

// ---------------------------------------------------------------------------
// WIDGET: ONBOARDING SHEET
// ---------------------------------------------------------------------------

class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text('✨', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('Welcome to\nDaily Challenge',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.1)),
                  const SizedBox(height: 16),
                  Text('Your journey to a better you starts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 40),
                  _buildFeature(
                    Icons.rocket_launch_rounded,
                    'Daily Tasks',
                    'Get a hand-picked challenge every single day to keep you growing.',
                    Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  _buildFeature(
                    Icons.bolt_rounded,
                    'Earn XP & Level Up',
                    'Every task you complete gives you points to rank up and earn badges.',
                    Colors.amber,
                  ),
                  const SizedBox(height: 24),
                  _buildFeature(
                    Icons.auto_graph_rounded,
                    'Track Your Progress',
                    'See your streaks and history to stay motivated on your path.',
                    Colors.green,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appState.accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              shadowColor: appState.accentColor.withValues(alpha: 0.4),
            ),
            onPressed: () {
              appState.completeOnboarding();
              Navigator.pop(context);
            },
            child: Text('Get Started',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String desc, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
