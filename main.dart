import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

const String APP_VERSION = "1.5.0";
const int OWNER_ADMIN_ID = 5053;

const String DEFAULT_DIRECT_APK_URL =
    "https://github.com/mubarekmustefa60-collab/Remedial-Updates/releases/latest/download/Remedial_Matrix_Universal.apk";
const String REMOTE_FIREBASE_CONFIG_URL =
    "https://raw.githubusercontent.com/mubarekmustefa60-collab/Remedial-Updates/main/firebase_config.json";
const String TELEGRAM_CHANNEL_URL = "https://t.me/REMEDIAL_MATRIX";
// Max PDF size for direct upload (Realtime Database string limit is 10MB; base64 adds ~33%)
const int MAX_PDF_UPLOAD_BYTES = 7 * 1024 * 1024;

const List<String> ALL_COURSES = [
  "Mathematics",
  "Physics",
  "Chemistry",
  "Biology",
  "English",
  "History",
  "Geography",
];

const MethodChannel _securityChannel = MethodChannel("com.remedial.matrix/security");
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

bool isDarkMode(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
Color cardBg(BuildContext context) => isDarkMode(context) ? const Color(0xFF181B28) : Colors.white;
Color surfaceBg(BuildContext context) => isDarkMode(context) ? const Color(0xFF1E2235) : const Color(0xFFF1F3FA);
Color textPrimary(BuildContext context) => isDarkMode(context) ? Colors.white : const Color(0xFF1A1D2E);
Color textSecondary(BuildContext context) => isDarkMode(context) ? Colors.white70 : const Color(0xFF5A607F);
Color borderCol(BuildContext context) => isDarkMode(context) ? Colors.white12 : const Color(0xFFE3E7F4);

Future<void> toggleAppTheme() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool nowDark = appThemeMode.value != ThemeMode.dark;
  appThemeMode.value = nowDark ? ThemeMode.dark : ThemeMode.light;
  await prefs.setBool('is_dark_mode', nowDark);
}

FirebaseDatabase? _activeDatabase;

DatabaseReference dbRef(String path) {
  if (_activeDatabase != null) {
    return _activeDatabase!.ref(path);
  }
  return FirebaseDatabase.instance.ref(path);
}

Future<void> setScreenshotProtection(bool enabled) async {
  try {
    await _securityChannel.invokeMethod('setSecure', {'secure': enabled});
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> _initLocalNotifications() async {
  try {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
  } catch (_) {}
}

Future<void> _showLocalBanner(String title, String body, {int id = 1}) async {
  try {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'remedial_matrix_channel',
      'Remedial Matrix Alerts',
      channelDescription: 'Study reminders and important announcements',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(id, title, body, details);
  } catch (_) {}
}

Future<void> _scheduleOfflineDailyStudyReminder(String stream) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool alreadyScheduled = prefs.getBool('daily_offline_reminder_set_$stream') ?? false;
    if (alreadyScheduled) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_study_reminder',
      'Daily Study Reminder',
      channelDescription: 'Daily offline study schedule reminder',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.periodicallyShow(
      2026,
      '📅 የዛሬውን የጥናት ፕሮግራም አንብበዋል?',
      'Remedial Matrix ን ከፍተው የዛሬውን የ$stream ኮርስ እና ፈተና ይለማመዱ!',
      RepeatInterval.daily,
      details,
    );
    await prefs.setBool('daily_offline_reminder_set_$stream', true);
  } catch (_) {}
}

Future<void> _initFirebaseWithDynamicSwitcher() async {
  const FirebaseOptions defaultOptions = FirebaseOptions(
    apiKey: "AIzaSyBm6UEHXGE7NpcoNUq7BjE8wO7ItTVV8GU",
    appId: "1:612015829097:android:c9bd7bc7839e3ad0d3b2f8",
    messagingSenderId: "612015829097",
    projectId: "remedial-matrix",
    storageBucket: "remedial-matrix.firebasestorage.app",
  );

  try {
    await Firebase.initializeApp();
  } catch (_) {
    try {
      await Firebase.initializeApp(options: defaultOptions);
    } catch (_) {}
  }

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? configJson = prefs.getString('cached_fb_config');
    try {
      Response resp = await Dio().get(
        REMOTE_FIREBASE_CONFIG_URL,
        options: Options(receiveTimeout: const Duration(seconds: 3), sendTimeout: const Duration(seconds: 3)),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        String raw = resp.data is String ? resp.data : jsonEncode(resp.data);
        jsonDecode(raw);
        configJson = raw;
        await prefs.setString('cached_fb_config', raw);
      }
    } catch (_) {}

    if (configJson != null && configJson.isNotEmpty) {
      Map cfg = jsonDecode(configJson);
      String remoteProject = (cfg['projectId'] ?? '').toString().trim();
      String remoteDbUrl = (cfg['databaseURL'] ?? '').toString().trim();

      if (remoteProject.isNotEmpty && remoteProject != "remedial-matrix") {
        FirebaseApp altApp;
        try {
          altApp = Firebase.app('dynamic_db');
        } catch (_) {
          altApp = await Firebase.initializeApp(
            name: 'dynamic_db',
            options: FirebaseOptions(
              apiKey: (cfg['apiKey'] ?? '').toString(),
              appId: (cfg['appId'] ?? '').toString(),
              messagingSenderId: (cfg['messagingSenderId'] ?? '').toString(),
              projectId: remoteProject,
              storageBucket: (cfg['storageBucket'] ?? '').toString(),
              databaseURL: remoteDbUrl.isNotEmpty ? remoteDbUrl : null,
            ),
          );
        }
        _activeDatabase = remoteDbUrl.isNotEmpty
            ? FirebaseDatabase.instanceFor(app: altApp, databaseURL: remoteDbUrl)
            : FirebaseDatabase.instanceFor(app: altApp);
      } else if (remoteDbUrl.isNotEmpty) {
        _activeDatabase = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: remoteDbUrl);
      }
    }
  } catch (_) {}

  try {
    (_activeDatabase ?? FirebaseDatabase.instance).setPersistenceEnabled(true);
  } catch (_) {}

  try {
    await FirebaseAnalytics.instance.logAppOpen();
  } catch (_) {}
}

Future<void> _setupPushNotifications(bool isVip) async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic('all_students');
    if (isVip) {
      await messaging.subscribeToTopic('vip_students');
      await messaging.unsubscribeFromTopic('free_students');
    } else {
      await messaging.subscribeToTopic('free_students');
      await messaging.unsubscribeFromTopic('vip_students');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      String title = message.notification?.title ?? (message.data['title'] ?? 'Remedial Matrix').toString();
      String body = message.notification?.body ?? (message.data['body'] ?? '').toString();
      if (body.isNotEmpty) {
        _showLocalBanner(title, body, id: DateTime.now().millisecondsSinceEpoch % 100000);
      }
    });
  } catch (_) {}
}

// ============================================================================
// 🎮 GAMIFICATION & STUDY PROGRESS TRACKER
// ============================================================================
class StudyProgress {
  static String _todayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  static Future<void> recordAppOpenStreak() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = _todayKey();
    String lastDate = prefs.getString('streak_last_date') ?? '';
    int streak = prefs.getInt('study_streak') ?? 0;

    if (lastDate != today) {
      if (lastDate.isNotEmpty) {
        final parts = lastDate.split('-');
        if (parts.length == 3) {
          final lastDt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final nowDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          int diff = nowDt.difference(lastDt).inDays;
          streak = (diff == 1) ? streak + 1 : 1;
        } else {
          streak = 1;
        }
      } else {
        streak = 1;
      }
      await prefs.setInt('study_streak', streak);
      await prefs.setString('streak_last_date', today);
      int pts = prefs.getInt('user_points') ?? 0;
      await prefs.setInt('user_points', pts + 10);
    }
  }

  static Future<void> recordActivity({int topicsDelta = 0, int minutesDelta = 0, int pointsDelta = 0, bool highScore = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = _todayKey();

    if (topicsDelta > 0) {
      int totalTopics = (prefs.getInt('total_topics') ?? 0) + topicsDelta;
      int todayTopics = (prefs.getInt('today_topics_$today') ?? 0) + topicsDelta;
      await prefs.setInt('total_topics', totalTopics);
      await prefs.setInt('today_topics_$today', todayTopics);
    }
    if (minutesDelta > 0) {
      int todayMins = (prefs.getInt('today_minutes_$today') ?? 0) + minutesDelta;
      await prefs.setInt('today_minutes_$today', todayMins);
    }
    if (pointsDelta > 0) {
      int pts = (prefs.getInt('user_points') ?? 0) + pointsDelta;
      await prefs.setInt('user_points', pts);
    }
    if (highScore) {
      await prefs.setBool('badge_quiz_pro', true);
    }
  }

  static Future<Map<String, dynamic>> loadStats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = _todayKey();
    int streak = prefs.getInt('study_streak') ?? 1;
    int totalTopics = prefs.getInt('total_topics') ?? 0;
    int todayTopics = prefs.getInt('today_topics_$today') ?? 0;
    int todayMinutes = prefs.getInt('today_minutes_$today') ?? 0;
    int points = prefs.getInt('user_points') ?? 0;
    bool quizPro = prefs.getBool('badge_quiz_pro') ?? (points >= 150);

    bool bFirstStep = totalTopics >= 1 || points >= 20;
    bool bSevenDays = streak >= 7;
    bool bQuizPro = quizPro;
    bool bMaster = points >= 500;
    int unlocked = (bFirstStep ? 1 : 0) + (bSevenDays ? 1 : 0) + (bQuizPro ? 1 : 0) + (bMaster ? 1 : 0);

    return {
      'streak': streak,
      'totalTopics': totalTopics,
      'todayTopics': todayTopics,
      'todayMinutes': todayMinutes,
      'points': points,
      'bFirstStep': bFirstStep,
      'bSevenDays': bSevenDays,
      'bQuizPro': bQuizPro,
      'bMaster': bMaster,
      'unlockedBadges': unlocked,
    };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool savedDark = prefs.getBool('is_dark_mode') ?? false;
    appThemeMode.value = savedDark ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {}
  await _initLocalNotifications();
  await _initFirebaseWithDynamicSwitcher();
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}
  runApp(const RemedialApp());
}

// Returns true only when [latest] is a higher version than [current] (e.g. 1.5.0 > 1.4.0)
bool _isNewerVersion(String latest, String current) {
  List<int> parse(String v) => v
      .replaceAll(RegExp(r'[^0-9.]'), '')
      .split('.')
      .where((e) => e.isNotEmpty)
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final List<int> a = parse(latest);
  final List<int> b = parse(current);
  final int n = max(a.length, b.length);
  for (int i = 0; i < n; i++) {
    final int x = i < a.length ? a[i] : 0;
    final int y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

// ============================================================================
// 🎨 GLOBAL DESIGN SYSTEM (applies to every screen)
// ============================================================================
ThemeData _buildAppTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  const Color brand = Color(0xFF5B4FE9);
  final Color accent = dark ? Colors.amber : brand;
  final Color card = dark ? const Color(0xFF181B28) : Colors.white;
  final Color border = dark ? Colors.white12 : const Color(0xFFE3E7F4);
  final Color ink = dark ? Colors.white : const Color(0xFF1A1D2E);

  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: brand, brightness: brightness)
      .copyWith(primary: accent, onPrimary: dark ? Colors.black : Colors.white);

  final OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: border),
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    primaryColor: accent,
    scaffoldBackgroundColor: dark ? const Color(0xFF0F111A) : const Color(0xFFF5F6FA),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF181B28) : Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 0.6,
      scrolledUnderElevation: dark ? 0 : 0.6,
      centerTitle: false,
      iconTheme: IconThemeData(color: ink),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: accent,
      unselectedItemColor: dark ? Colors.white54 : const Color(0xFF8A90A6),
      elevation: dark ? 0 : 8,
    ),
    cardTheme: CardTheme(
      color: card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class RemedialApp extends StatelessWidget {
  const RemedialApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Remedial Matrix',
          themeMode: mode,
          theme: _buildAppTheme(Brightness.light),
          darkTheme: _buildAppTheme(Brightness.dark),
          home: const AuthCheckScreen(),
        );
      },
    );
  }
}

void shareRemedialMatrixApp(BuildContext context) {
  const String shareText =
      "🎓 Remedial Matrix (V$APP_VERSION - 2019 Special App)!\n\n"
      "✅ የ2019 ሙሉ የትምህርት ሚኒስቴር Course Outline\n"
      "✅ አዲሱ የ2019 Model Exam (7 ትምህርቶች - 427 ጥያቄዎች ከነማብራሪያቸው)\n"
      "✅ Short Notes & PDFs በየCourse እና በየChapter\n"
      "✅ Flashcards፣ Timed Mock Exam & Daily Streak\n\n"
      "📥 አፑን በቀጥታ ለማውረድ (Direct Download)፦\n$DEFAULT_DIRECT_APK_URL\n\n"
      "📢 የቴሌግራም ቻናላችን፦ $TELEGRAM_CHANNEL_URL";
  Share.share(shareText, subject: 'Remedial Matrix App');
}

// ============================================================================
// 🚀 1XBET-STYLE IN-APP SELF-UPDATER (SHOWS CURRENT & LATEST VERSION)
// ============================================================================
class InAppUpdateScreen extends StatefulWidget {
  final String latestVersion;
  final String downloadUrl;
  final String whatsNew;

  const InAppUpdateScreen({
    Key? key,
    required this.latestVersion,
    required this.downloadUrl,
    required this.whatsNew,
  }) : super(key: key);

  @override
  _InAppUpdateScreenState createState() => _InAppUpdateScreenState();
}

class _InAppUpdateScreenState extends State<InAppUpdateScreen> {
  bool isDownloading = false;
  double progress = 0.0;
  String statusMessage = "";
  bool hasError = false;

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _startInAppUpdate() async {
    String url = widget.downloadUrl.trim();
    if (url.contains("t.me/")) {
      url = DEFAULT_DIRECT_APK_URL;
    }

    setState(() {
      isDownloading = true;
      hasError = false;
      progress = 0.0;
      statusMessage = "Downloading v${widget.latestVersion}...";
    });

    RandomAccessFile? raf;
    try {
      final dir = await getTemporaryDirectory();
      final savePath = "${dir.path}/Remedial_Matrix_Update_${widget.latestVersion}.apk";
      final partFile = File("$savePath.part");
      int existing = await partFile.exists() ? await partFile.length() : 0;

      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

      Future<Response<ResponseBody>> request(int from) => dio.get<ResponseBody>(
            url,
            options: Options(
              responseType: ResponseType.stream,
              headers: from > 0 ? {'Range': 'bytes=$from-'} : null,
              receiveTimeout: const Duration(seconds: 60),
              validateStatus: (s) => s == 200 || s == 206 || s == 416,
            ),
          );

      Response<ResponseBody> resp = await request(existing);
      if (resp.statusCode == 416) {
        // Old/complete partial file does not match the server -> start fresh
        if (await partFile.exists()) await partFile.delete();
        existing = 0;
        resp = await request(0);
      }
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw Exception('bad status ${resp.statusCode}');
      }

      // 206 = server continued from where we stopped; 200 = server sent the whole file again
      final bool resumed = resp.statusCode == 206 && existing > 0;
      if (!resumed) existing = 0;

      final int bodyLen = int.tryParse(resp.headers.value(Headers.contentLengthHeader) ?? '') ?? -1;
      final int total = bodyLen > 0 ? bodyLen + existing : -1;

      raf = await partFile.open(mode: resumed ? FileMode.append : FileMode.write);
      int received = existing;
      int lastPct = -1;

      await for (final chunk in resp.data!.stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          final int pct = (received * 100) ~/ total;
          if (pct != lastPct) {
            lastPct = pct;
            setState(() {
              progress = received / total;
              statusMessage = "${_mb(received)} / ${_mb(total)} MB";
            });
          }
        }
      }
      await raf.close();
      raf = null;

      if (total > 0 && received < total) {
        throw Exception('incomplete download');
      }

      final finalFile = File(savePath);
      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(savePath);

      if (mounted) {
        setState(() {
          statusMessage = "Opening installer...";
        });
      }

      final result = await OpenFilex.open(savePath, type: "application/vnd.android.package-archive");
      if (result.type != ResultType.done && mounted) {
        setState(() {
          isDownloading = false;
          hasError = true;
          statusMessage = "መጫኛውን መክፈት አልተቻለም፦ ${result.message}";
        });
      }
    } catch (e) {
      try {
        await raf?.close();
      } catch (_) {}
      if (mounted) {
        setState(() {
          isDownloading = false;
          hasError = true;
          statusMessage = "ማውረድ ተቋርጧል። እንደገና ሲነኩ ካቆመበት ይቀጥላል፤ ካልሆነ ከታች ባለው ሊንክ ያውርዱ።";
        });
      }
    }
  }

  void _showWhatsNewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181B28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("✨ What's new in v${widget.latestVersion}?", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            widget.whatsNew.isNotEmpty
                ? widget.whatsNew
                : "• Short Notes & PDFs በየCourse እና በየChapter\n• Flashcards & Quick Actions ከላይ\n• ፈጣን የAdmin ደረሰኝ Refresh እና Scroll Fix",
            style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.amber))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int percent = (progress * 100).toInt().clamp(0, 100);

    return Scaffold(
      backgroundColor: const Color(0xFF061126),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      "Current: v$APP_VERSION",
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    height: 170,
                    width: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFF1E56A0), Color(0xFF061126)], radius: 0.8),
                      boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.35), blurRadius: 40, spreadRadius: 10)],
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, size: 90, color: Colors.amber),
                  ),
                  const SizedBox(height: 22),
                  const Text("REMEDIAL MATRIX", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("v$APP_VERSION", style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, color: Colors.amber, size: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                        ),
                        child: Text("New v${widget.latestVersion}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isDownloading)
                Column(
                  children: [
                    Text(
                      "You are on v$APP_VERSION. A new version (v${widget.latestVersion}) is ready — press \"Update\" to install",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.4),
                    ),
                    if (hasError) ...[
                      const SizedBox(height: 12),
                      Text(statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(widget.downloadUrl), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_browser, color: Colors.amber),
                        label: const Text("በብራውዘር / ቴሌግራም አውርድ", style: TextStyle(color: Colors.amber)),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B3548),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showWhatsNewDialog,
                        child: const Text("What's new?", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C9EEB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _startInAppUpdate,
                        child: Text("Update to v${widget.latestVersion}", style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(statusMessage, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        Text("$percent%", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4C9EEB)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 📚 OFFICIAL 2019 REMEDIAL COURSE OUTLINES
// ============================================================================
const Map<String, List<Map<String, String>>> officialCourseOutlines = {
  "Mathematics": [
    {"unit": "Unit 1: Further on Sets and the Number System (6 hrs)", "topics": "• Further on sets (Concept, Notion, Operations & Applications)\n• The Number System (Natural, Integers, Rational, Irrational & Real Numbers)"},
    {"unit": "Unit 2: Solving Equations and Inequalities (7 hrs)", "topics": "• Linear Equations in One & Two Variables, Non-linear Equations\n• Linear Inequalities, Absolute Value & Quadratic Inequalities"},
    {"unit": "Unit 3: Relations and Functions (16 hrs)", "topics": "• Domain, Range, Graphs & Inverse of Relations and Functions\n• Polynomial, Rational, Exponential, Logarithmic & Trigonometric Functions\n• Power, Modulus (Absolute Value), Signum & Greatest Integer Functions"},
    {"unit": "Unit 4: Geometry (14 hrs)", "topics": "• Congruency and Similarity of Triangles & Plane Figures\n• Regular Polygons, Circles (Angles, Arcs, Sectors)\n• Solid Figures (Cylinders, Prisms, Pyramids, Cones, Spheres, Frustum)\n• Coordinate Geometry (Distance, Section Formula, Equations of Lines)"},
    {"unit": "Unit 5: Vectors and Transformations of the Plane (9 hrs)", "topics": "• Vectors in 2D, Operations, Position Vector, Scalar & Cross Products\n• Plane Transformations: Translation, Reflection & Rotation"},
    {"unit": "Unit 6: Matrices and Determinants (6 hrs)", "topics": "• Matrix Operations, Elementary Row Operations, Inverse of a Matrix\n• Determinants of Order 2 & 3, Minors, Cofactors & Cramer's Rule"},
    {"unit": "Unit 7: Statistics and Probability (10 hrs)", "topics": "• Grouped Data, Measures of Central Tendency & Dispersion\n• Counting Principles, Permutations, Combinations, Binomial Theorem & Probability"},
    {"unit": "Unit 8: Sequences and Series (6 hrs)", "topics": "• Arithmetic and Geometric Sequences\n• Sigma Notation, Partial Sums, Finite & Infinite Series"},
    {"unit": "Unit 9: Introduction to Calculus (10 hrs)", "topics": "• Limits and Continuity\n• Derivatives (Rules, Special Functions, Extreme Values, Optimization)\n• Integration (Substitution, Partial Fractions, By Parts, Definite Integrals & Area)"},
    {"unit": "Unit 10: Introduction to Linear Programming (6 hrs)", "topics": "• Graphical Solutions of Systems of Linear Inequalities\n• Maximum and Minimum Values & Real-life Applications"},
    {"unit": "Unit 11: Mathematical Applications in Business (6 hrs)", "topics": "• Time Value of Money, Saving, Investing, Borrowing & Taxation"},
  ],
  "Physics": [
    {"unit": "Unit 1: Physical Quantities and Measurement (2 hrs)", "topics": "• Scales, Standards, Units (Prefixes), Measurement Safety & Unit Conversion"},
    {"unit": "Unit 2: Vectors (2 hrs)", "topics": "• Vector Representation, Addition/Subtraction, Resolution & Vector Products"},
    {"unit": "Unit 3: Motion in One and Two Dimensions (10 hrs)", "topics": "• Position, Displacement, Average/Instantaneous Speed & Velocity\n• Uniformly Accelerated Motion, Vertical Motion, Projectile & Circular Motion"},
    {"unit": "Unit 4: Angular Motion (3 hrs)", "topics": "• Angular Position, Velocity, Acceleration & Relation with Linear Motion"},
    {"unit": "Unit 5: Dynamics (10 hrs)", "topics": "• Newton's Laws, Friction, Impulse, Momentum & Collisions\n• Center of Mass, Torque, Rotational Inertia, Angular Momentum & Equilibrium"},
    {"unit": "Unit 6: Work, Energy, and Power (8 hrs)", "topics": "• Work by Constant/Variable Forces, Work-Energy Theorem, Conservation of Energy & Power"},
    {"unit": "Unit 7: Fluids and Pressure (6 hrs)", "topics": "• Pascal's Principle, Atmospheric Pressure, Archimedes' Principle & Bernoulli's Equation"},
    {"unit": "Unit 8: Simple Machines (4 hrs)", "topics": "• Classification, Mechanical Advantage (MA), Velocity Ratio (VR) & Efficiency"},
    {"unit": "Unit 9: Waves (6 hrs)", "topics": "• String, Pendulum, Spring, Wave Propagation, Superposition & Sound Waves"},
    {"unit": "Unit 10: Temperature and Heat Transfer (6 hrs)", "topics": "• Thermometric Scales, Scale Conversion & Thermal Expansion of Materials"},
    {"unit": "Unit 11: Electrostatics and Electric Circuits (8 hrs)", "topics": "• Charging Methods, Coulomb's Law, Electric Field, Ohm's Law & Resistor Combinations"},
    {"unit": "Unit 12: Magnetism and Its Applications (5 hrs)", "topics": "• Magnetic Fields, Earth's Magnetism, Current-Carrying Conductors & Applications"},
    {"unit": "Unit 13: Electromagnetic Waves and Light (6 hrs)", "topics": "• EM Spectrum, Reflection, Refraction, Mirrors, Lenses, Human Eye & Color Addition"},
    {"unit": "Unit 14: Nuclear Physics and Radiation (5 hrs)", "topics": "• The Nucleus, Radioactivity, Nuclear Reactions, Energy & Radiation Safety"},
    {"unit": "Unit 15: Basic Electronics (4 hrs)", "topics": "• Semiconductors, Diodes, Rectification, Transistors, Integrated Circuits & Logic Gates"},
  ],
  "Chemistry": [
    {"unit": "Unit 1: Atomic Structure and Periodicity (8 hrs)", "topics": "• Subatomic Particles, Bohr Theory & Quantum Mechanical Model\n• Electromagnetic Radiation, Quantum Numbers, Electron Configuration & Periodic Table"},
    {"unit": "Unit 2: Chemical Bonding and Structure (6 hrs)", "topics": "• Ionic, Covalent & Metallic Bonding\n• VSEPR Theory, Molecular Geometry, Valence Bond (VBT) & Molecular Orbital Theory (MOT)"},
    {"unit": "Unit 3: Physical States of Matter (6 hrs)", "topics": "• Kinetic Theory, Gas Laws, Liquid Properties (Surface Tension, Viscosity), Solids & Phase Transitions"},
    {"unit": "Unit 4: Solutions (12 hrs)", "topics": "• Types of Solutions, Solution Process, Solubility Equilibrium\n• Concentration Expressions (Molarity, Normality, Mole Fraction) & Solution Stoichiometry"},
    {"unit": "Unit 5: Chemical Reactions and Stoichiometry (8 hrs)", "topics": "• Laws of Chemical Reactions, Balancing Equations, Energy Changes, Stoichiometry & Reaction Rates"},
    {"unit": "Unit 6: Chemical Equilibrium (6 hrs)", "topics": "• Reversible/Irreversible Reactions, Equilibrium Constant (Kc, Kp) & Le Chatelier's Principle"},
    {"unit": "Unit 7: Electrochemistry (6 hrs)", "topics": "• Redox Reactions, Conductivity, Electrolysis, Quantitative Aspects (Faraday's Laws) & Voltaic Cells"},
    {"unit": "Unit 8: Introduction to Organic Chemistry (12 hrs)", "topics": "• Hydrocarbons (Alkanes, Alkenes, Alkynes, Aromatics)\n• Alcohols, Ethers, Aldehydes, Ketones, Carboxylic Acids, Esters, Fats & Oils"},
  ],
  "Biology": [
    {"unit": "Unit 1: The Science of Biology (2 hrs)", "topics": "• Significance of Biology, Scientific Method, Tools & Concepts of Biology"},
    {"unit": "Unit 2: Biomolecules (6 hrs)", "topics": "• Inorganic Molecules (Water, Minerals)\n• Organic Molecules (Carbohydrates, Lipids, Proteins, Nucleic Acids & Vitamins)"},
    {"unit": "Unit 3: Cell Biology (7 hrs)", "topics": "• Cell Theory, Cell Types/Organelles, Cell Environment (Osmosis, Diffusion) & Cellular Metabolism"},
    {"unit": "Unit 4: Microorganisms (7 hrs)", "topics": "• Beneficial Microorganisms & Pathogenic (Disease-causing) Microorganisms"},
    {"unit": "Unit 5: Genetics (7 hrs)", "topics": "• Mendelian & Non-Mendelian Genetics, DNA/Chromosome Structure\n• Mitosis & Meiosis, Mutations, DNA Replication, Transcription & Protein Synthesis"},
    {"unit": "Unit 6: Evolution (2 hrs)", "topics": "• Origin of Life, Theories of Evolution, Genetic Variation & Speciation"},
    {"unit": "Unit 7: Biotechnology (5 hrs)", "topics": "• Agricultural, Medical, Industrial & Environmental Biotechnology"},
    {"unit": "Unit 8: Human Biology and Health (12 hrs)", "topics": "• Nutrition, Digestive, Respiratory, Circulatory, Nervous, Endocrine & Reproductive Systems\n• Sense Organs, Communicable & Non-communicable Diseases"},
    {"unit": "Unit 9: Food Making and Growth in Plants (4 hrs)", "topics": "• Plant Parts, Photosynthesis, Transport in Plants, Plant Responses & Food Storage"},
    {"unit": "Unit 10: Ecology and Conservation of Biodiversity (5 hrs)", "topics": "• Food Chains/Webs, Nutrient Cycling, Ecological Succession, Biomes, Pollution & Climate Change"},
  ],
  "English": [
    {"unit": "Unit 1: Road Traffic Accidents (11 hrs)", "topics": "• Reading/Listening: Causes & Socio-Economic Impacts of Traffic Accidents\n• Grammar: Transitive/Intransitive Verbs, Present & Future Tenses (Active/Passive), Question Types\n• Vocabulary & Writing: Context Clues, Phrasal Verbs, Paragraph & Informal Letter Writing"},
    {"unit": "Unit 2: Artificial Intelligence (11 hrs)", "topics": "• Reading/Speaking: Merits & Demerits of AI, Using 'so' and 'neither', Apologizing\n• Grammar: Past Tenses, Conditional Sentences (Zero, I, II, III) & Modals\n• Writing: Fixing Run-on Sentences, Jumbled Paragraphs & Narrative Writing"},
    {"unit": "Unit 3: Tourist Attractions (11 hrs)", "topics": "• Reading/Speaking: Tourism Industry in Ethiopia, Giving Directions, Describing Places\n• Grammar: Degrees of Comparison, Relative Clauses, Adverbs, Prepositions & Reported Speech\n• Writing: Fixing Dangling Modifiers, Formal Business Letters & Expository Essays"},
    {"unit": "Unit 4: Global Warming (11 hrs)", "topics": "• Reading/Speaking: Effects of Global Warming, Cause & Effect, Debate, Skimming & Scanning\n• Grammar: Tenses Revision, Quantifiers, Articles, Conjunctions & Relative Pronouns\n• Vocabulary & Writing: Synonyms/Antonyms, Analogy, Faulty Parallelism, Reports & CV"},
    {"unit": "Unit 5: Time Management (10 hrs)", "topics": "• Reading/Speaking: Time Management & Productivity, Expressing Result, Opinion & Purpose\n• Grammar: Future Forms, Sentence Types (Simple, Compound, Complex), Gerunds/Infinitives & Wishes\n• Writing: Memos, Formal Letters & Argumentative Essays"},
    {"unit": "Unit 6: Indigenous Conflict Resolution (10 hrs)", "topics": "• Reading/Speaking: Conflict Resolution Strategies, Interviews & Panel Discussions\n• Vocabulary: Word Formation, Idioms, Homophones & Phrasal Verbs (get, do, make)\n• Grammar & Writing: Expressing Purpose, Regrets, Clauses of Result & Interpreting Charts"},
  ],
  "Geography": [
    {"unit": "Unit 1: Foundations of Geography and Geographic Inquiry (8 hrs)", "topics": "• Meaning, Scope & Branches of Geography\n• Map Components, Scale Conversion, Distance/Area Measurement, Relief Representation & GIS"},
    {"unit": "Unit 2: Physical Geography of Ethiopia and Africa (25 hrs)", "topics": "• Geological Time Scale, Continental Drift, Landforms of Ethiopia & Africa\n• Weather & Climate, Agro-climatic Zones of Ethiopia, Climate Change Adaptation & Mitigation\n• Natural Resources, Drainage Systems, Water & Biotic Resources of Ethiopia"},
    {"unit": "Unit 3: Population Geography and Human-Environment Interactions (11 hrs)", "topics": "• World, African & Ethiopian Population Trends, Fertility, Mortality & Migration\n• Settlement Patterns, Population Theories & Population Policies"},
    {"unit": "Unit 4: Economic Geography and Development (12 hrs)", "topics": "• Economic Activities, Ethiopian Agriculture, Trade, Transport & Tourism\n• African Economic Challenges, Landlocked Countries, Sustainable Development & Globalization"},
    {"unit": "Unit 5: Contemporary Geographic Issues and Public Concerns (8 hrs)", "topics": "• Environmental Degradation, Unplanned Urbanization, Migration, Coastal Pollution, Drought & Famine"},
  ],
  "History": [
    {"unit": "Unit 1: Introduction to History (6 hrs)", "topics": "• Definition & Uses of History, Historical Methods, Origin of Humans & Major Civilizations"},
    {"unit": "Unit 2: State Formation & Population Movements in the Horn till 17th C. (9 hrs)", "topics": "• Punt, Da'amet, Aksum, Zagwe, Bizamo, Damot, Enarya, Gafat & Muslim Sultanates\n• Interstate Conflicts, Population Movements & The Gada System of the Oromo"},
    {"unit": "Unit 3: The Modern World since 1500 (10 hrs)", "topics": "• Renaissance, Reformation, Scientific & Industrial Revolutions\n• English, American & French Revolutions, Napoleonic Era, Unification of Italy/Germany"},
    {"unit": "Unit 4: The Gondarian Period (5 hrs)", "topics": "• Jesuits in Ethiopia, Gondar Socio-Political Developments, Yejju Dynasty, Zemene Mesafint"},
    {"unit": "Unit 5: Africa and the Outside World to 1900 (6 hrs)", "topics": "• Trans-Atlantic Slave Trade, Legitimate Trade, Scramble for Africa & Colonial Rule Impacts"},
    {"unit": "Unit 6: Formation of the Modern State of Ethiopia: 1855-1941 (9 hrs)", "topics": "• Unification & Modernization, Battles of Gundet, Gura, Mettema, Adwa & 1935 Italian Invasion"},
    {"unit": "Unit 7: Major Global Developments of the World (12 hrs)", "topics": "• WWI & WWII, 1917 Russian Revolution, Formation of the UNO & The Cold War"},
    {"unit": "Unit 8: African Move Towards Independence (9 hrs)", "topics": "• Anti-Colonial Resistance, Decolonization, Liberation Struggles, Pan-Africanism & OAU"},
    {"unit": "Unit 9: Ethiopia Since Liberation (12 hrs)", "topics": "• British & American Eras, Eritrean Question, Dergue Era, Post-1991 & Indigenous Heritages"},
  ],
};

Map<String, Map<String, String>> getDefaultSchedule() {
  return {
    "Natural": {
      "Monday": "📐 Mathematics: Unit 1 (Sets & Number System) & Unit 2 (Solving Equations and Inequalities)",
      "Tuesday": "⚡ Physics: Unit 1-3 (Measurement, Vectors, 1D & 2D Motion) & Unit 5 (Dynamics)",
      "Wednesday": "🧪 Chemistry: Unit 1 (Atomic Structure & Periodicity) & Unit 2 (Chemical Bonding & VSEPR)",
      "Thursday": "🧬 Biology: Unit 1-3 (Science of Biology, Biomolecules & Cell Biology) + Unit 5 (Genetics)",
      "Friday": "🗣 English: Unit 1 (Road Traffic Accidents & Tenses) & Unit 2 (Artificial Intelligence & Conditionals)",
      "Saturday": "📝 Weekly Revision: Physics (Work, Energy & Circuits), Chemistry (Solutions) & Model Exams",
      "Sunday": "🎯 Self-Assessment: Mathematics (Relations, Functions & Calculus) + Weak Subject Review",
    },
    "Social": {
      "Monday": "📐 Mathematics: Unit 1 (Sets & Number System) & Unit 2 (Solving Equations and Inequalities)",
      "Tuesday": "🏛 History: Unit 1 (Intro & Civilizations) & Unit 2 (States in the Horn of Africa & Gada System)",
      "Wednesday": "🌍 Geography: Unit 1 (Foundations, Maps & GIS) & Unit 2 (Physical Geography of Ethiopia & Africa)",
      "Thursday": "🗣 English: Unit 1 (Road Traffic Accidents & Tenses) & Unit 2 (Artificial Intelligence & Conditionals)",
      "Friday": "🏛 History & Geography: History Unit 3 (Modern World) + Geography Unit 3 (Population Geography)",
      "Saturday": "📝 Weekly Revision: Maths (Functions, Statistics & Linear Programming) + Model Exam Practice",
      "Sunday": "🎯 Self-Assessment: History (Modern Ethiopia & Adwa), Geography (Economic Geography) & Rest",
    }
  };
}

String getDayName(int weekday) {
  const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  return days[(weekday - 1) % 7];
}

String getAmharicDay(String englishDay) {
  const map = {
    "Monday": "ሰኞ (Monday)",
    "Tuesday": "ማክሰኞ (Tuesday)",
    "Wednesday": "ረቡዕ (Wednesday)",
    "Thursday": "ሐሙስ (Thursday)",
    "Friday": "ዓርብ (Friday)",
    "Saturday": "ቅዳሜ (Saturday)",
    "Sunday": "እሁድ (Sunday)",
  };
  return map[englishDay] ?? englishDay;
}

String getGreetingText() {
  int h = DateTime.now().hour;
  if (h < 12) return "Good Morning! ☀️";
  if (h < 17) return "Good Afternoon! 🌤️";
  return "Good Evening! 🌇";
}

bool isOwnerUser(int shortId, String name) {
  return (shortId == OWNER_ADMIN_ID) || (name.toLowerCase().trim() == "mubarek mustefa");
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);
  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool isLoading = true;
  bool isRegistered = false;
  String appStatus = 'free';

  @override
  void initState() {
    super.initState();
    checkRegistration();
  }

  Future<void> checkRegistration() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool localRegistered = prefs.getBool('local_registered') ?? false;
      String localStatus = prefs.getString('local_status') ?? 'free';
      String deviceId = prefs.getString('device_id') ?? '';

      if (localRegistered && deviceId.isNotEmpty) {
        try {
          dbRef("students/$deviceId").update({
            "app_version": APP_VERSION,
            "last_seen": DateTime.now().toIso8601String(),
          });
        } catch (_) {}

        try {
          final snapshot = await dbRef("students/$deviceId/status").get().timeout(const Duration(seconds: 5));
          if (snapshot.exists) {
            String remoteStatus = snapshot.value.toString();
            if (localStatus == 'vip' && remoteStatus != 'blocked') {
              localStatus = 'vip';
            } else {
              localStatus = remoteStatus;
              await prefs.setString('local_status', localStatus);
            }
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          isRegistered = localRegistered;
          appStatus = localStatus;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    if (appStatus == 'blocked') return const BlockedScreen();
    if (!isRegistered) return const RegisterScreen();
    return MainMenuScreen(initialStatus: appStatus);
  }
}

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, color: Colors.red, size: 80),
            const SizedBox(height: 20),
            Text("አካውንትዎ ታግዷል!", style: TextStyle(fontSize: 24, color: textPrimary(context), fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("እባክዎ አድሚንን ያነጋግሩ።", style: TextStyle(color: textSecondary(context))),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController oldIdCtrl = TextEditingController();
  String selectedStream = 'Natural';
  bool isSaving = false;

  Future<void> registerUser() async {
    String enteredName = nameCtrl.text.trim();
    String enteredOldId = oldIdCtrl.text.trim();

    if (enteredName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("እባክዎ ሙሉ ስምዎን ያስገቡ!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => isSaving = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int shortId = Random().nextInt(9000) + 1000;
      String deviceId = "DEV_${DateTime.now().millisecondsSinceEpoch}_$shortId";
      String finalStatus = 'free';
      bool restoredAccount = false;

      if (enteredName.toLowerCase() == "mubarek mustefa" || enteredOldId == "5053") {
        shortId = OWNER_ADMIN_ID;
        finalStatus = 'vip';
        restoredAccount = true;
      }

      try {
        final snap = await dbRef("students").get().timeout(const Duration(seconds: 6));
        if (snap.exists && snap.value is Map) {
          Map allStudents = snap.value as Map;
          allStudents.forEach((key, val) {
            if (val is Map) {
              String dbName = (val['full_name'] ?? '').toString().trim().toLowerCase();
              String dbId = (val['short_id'] ?? '').toString().trim();
              String dbStatus = (val['status'] ?? 'free').toString();

              bool idMatch = enteredOldId.isNotEmpty && dbId == enteredOldId;
              bool nameMatch = dbName.isNotEmpty && dbName == enteredName.toLowerCase();

              if (idMatch || nameMatch) {
                if (dbStatus == 'vip' || !restoredAccount) {
                  deviceId = key.toString();
                  shortId = int.tryParse(dbId) ?? shortId;
                  finalStatus = dbStatus;
                  selectedStream = (val['stream'] ?? selectedStream).toString();
                  restoredAccount = true;
                }
              }
            }
          });
        }
      } catch (_) {}

      await prefs.setBool('local_registered', true);
      await prefs.setString('local_status', finalStatus);
      await prefs.setString('local_name', enteredName);
      await prefs.setString('local_stream', selectedStream);
      await prefs.setInt('local_short_id', shortId);
      await prefs.setString('device_id', deviceId);

      if (!restoredAccount) {
        try {
          await dbRef("students/$deviceId").set({
            "full_name": enteredName,
            "stream": selectedStream,
            "status": finalStatus,
            "short_id": shortId,
            "app_version": APP_VERSION,
            "registered_at": DateTime.now().toIso8601String(),
            "last_seen": DateTime.now().toIso8601String(),
          }).timeout(const Duration(seconds: 6));
        } catch (_) {}
      } else {
        try {
          await dbRef("students/$deviceId").update({
            "app_version": APP_VERSION,
            "last_seen": DateTime.now().toIso8601String(),
          }).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      if (mounted) {
        if (restoredAccount && finalStatus == 'vip') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 እንኳን ደህና መጡ! የድሮው VIP አካውንትዎ በራሱ ተመልሷል!"), backgroundColor: Colors.green));
        }
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => MainMenuScreen(initialStatus: finalStatus)), (route) => false);
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📝 Student Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 15),
            const CircleAvatar(radius: 42, backgroundColor: Color(0xFF5B4FE9), child: Icon(Icons.school, size: 46, color: Colors.white)),
            const SizedBox(height: 16),
            Text("እንኳን ወደ Remedial Matrix በሰላም መጡ! 🌟\nለመጀመር መረጃዎትን ይሙሉ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary(context)), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: textPrimary(context)),
              decoration: InputDecoration(
                labelText: "ሙሉ ስም (Full Name)",
                hintText: "ከዚህ በፊት የተመዘገቡበትን ስም ያስገቡ",
                filled: true,
                fillColor: cardBg(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF5B4FE9)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: oldIdCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPrimary(context)),
              decoration: InputDecoration(
                labelText: "የድሮ መለያ ቁጥር / Old ID (ካለዎት ብቻ)",
                hintText: "አዲስ ተማሪ ከሆኑ ይህንን ባዶ ይተዉት",
                filled: true,
                fillColor: cardBg(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 18),
            Text("የጥናት መስመር (Stream):", style: TextStyle(fontSize: 15, color: textSecondary(context), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: cardBg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol(context))),
              child: Row(
                children: [
                  Expanded(child: RadioListTile<String>(activeColor: const Color(0xFF5B4FE9), title: const Text("Natural"), value: "Natural", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val.toString()))),
                  Expanded(child: RadioListTile<String>(activeColor: const Color(0xFF5B4FE9), title: const Text("Social"), value: "Social", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val.toString()))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4FE9),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving ? null : registerUser,
              child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Get Started / Restore Account 🚀", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}

class MainMenuScreen extends StatefulWidget {
  final String initialStatus;
  const MainMenuScreen({Key? key, required this.initialStatus}) : super(key: key);
  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late String appStatus;
  int userShortId = 0;
  String userName = "";
  String userStream = "Natural";
  String todayScheduleCourse = "";
  bool isAdminCached = false;
  int? examDaysLeft;
  String examLabel = "2019 National Remedial Exam";
  int _currentIndex = 0;

  Map<String, dynamic> progressStats = {
    'streak': 1,
    'totalTopics': 0,
    'todayTopics': 0,
    'todayMinutes': 0,
    'points': 0,
    'bFirstStep': false,
    'bSevenDays': false,
    'bQuizPro': false,
    'bMaster': false,
    'unlockedBadges': 0,
  };

  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    appStatus = widget.initialStatus;
    _initSequence();
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) async {
      await StudyProgress.recordActivity(minutesDelta: 1);
      _refreshProgressStats();
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    super.dispose();
  }

  Future<void> _refreshProgressStats() async {
    final stats = await StudyProgress.loadStats();
    if (mounted) setState(() => progressStats = stats);
  }

  Future<void> _initSequence() async {
    await StudyProgress.recordAppOpenStreak();
    await _refreshProgressStats();
    await _loadUserData();
    await setScreenshotProtection(!isOwnerUser(userShortId, userName));
    await _setupPushNotifications(appStatus == 'vip');
    await _scheduleOfflineDailyStudyReminder(userStream);
    await _loadExamCountdown();
    await _checkAppUpdate();
    await _checkTargetedBroadcast();
    await _checkDailyStudyNotification();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String stream = prefs.getString('local_stream') ?? 'Natural';
    int id = prefs.getInt('local_short_id') ?? 0;
    String name = prefs.getString('local_name') ?? 'Student';
    bool cachedAdmin = (prefs.getBool('owner_admin_cached') ?? false) && isOwnerUser(id, name);

    String dayName = getDayName(DateTime.now().weekday);
    Map<String, String> streamMap = getDefaultSchedule()[stream] ?? {};
    String defaultToday = (streamMap[dayName] ?? "").toString();

    setState(() {
      userShortId = id;
      userName = name;
      userStream = stream;
      todayScheduleCourse = defaultToday;
      isAdminCached = cachedAdmin;
    });

    try {
      final snap = await dbRef("admin_content/schedule/$stream/$dayName").get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value != null && mounted) {
        setState(() => todayScheduleCourse = snap.value.toString());
      }
    } catch (_) {}
  }

  Future<void> _loadExamCountdown() async {
    try {
      final snap = await dbRef("admin_settings/exam_countdown").get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value is Map) {
        Map data = snap.value as Map;
        String dateStr = (data['date'] ?? '').toString();
        String label = (data['label'] ?? '2019 National Remedial Exam').toString();
        DateTime? target = DateTime.tryParse(dateStr);
        if (target != null && mounted) {
          int diff = target.difference(DateTime.now()).inDays;
          setState(() {
            examDaysLeft = diff >= 0 ? diff : 0;
            examLabel = label;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _checkAppUpdate() async {
    try {
      final snapshot = await dbRef("admin_settings/update").get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        String latestVersion = (data['version'] ?? APP_VERSION).toString().trim();
        String updateUrl = (data['url'] ?? DEFAULT_DIRECT_APK_URL).toString();
        String whatsNew = (data['whats_new'] ?? '').toString();

        if (_isNewerVersion(latestVersion, APP_VERSION) && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InAppUpdateScreen(
                latestVersion: latestVersion,
                downloadUrl: updateUrl,
                whatsNew: whatsNew,
              ),
            ),
          );
        }
      }
    } catch (e) {}
  }

  Future<void> _checkTargetedBroadcast() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isVIP = appStatus == 'vip';
      List<String> channels = ['all', isVIP ? 'vip' : 'free'];

      for (String target in channels) {
        final snapshot = await dbRef("announcements/$target").get();
        if (snapshot.exists) {
          Map data = snapshot.value as Map;
          int lastTime = prefs.getInt('last_broadcast_$target') ?? 0;
          int newTime = data['time'] ?? 0;

          if (newTime > lastTime && mounted) {
            String badge = target == 'vip'
                ? "👑 የVIP ተማሪዎች ልዩ ማስታወቂያ"
                : (target == 'free' ? "📢 ለነጻ ተማሪዎች የተላከ ማስታወቂያ" : "📢 አጠቃላይ ማስታወቂያ");
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: cardBg(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge, style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(data['title'] ?? "ማስታወቂያ", style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                  child: SingleChildScrollView(
                    child: Text(
                      data['message'] ?? "",
                      style: TextStyle(color: textSecondary(context), fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9)),
                    onPressed: () async {
                      await prefs.setInt('last_broadcast_$target', newTime);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text("አንብቤያለሁ (Close)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _checkDailyStudyNotification() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String todayKey = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      String lastShownDay = prefs.getString('last_study_prompt_day') ?? '';

      String dayName = getDayName(DateTime.now().weekday);
      Map<String, String> streamMap = getDefaultSchedule()[userStream] ?? {};
      String todayCourse = todayScheduleCourse.isNotEmpty
          ? todayScheduleCourse
          : (streamMap[dayName] ?? "General Revision").toString();

      if (lastShownDay != todayKey && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: cardBg(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF5B4FE9), width: 1.2)),
            title: Row(
              children: [
                const Icon(Icons.notifications_active, color: Color(0xFF5B4FE9), size: 26),
                const SizedBox(width: 10),
                Expanded(child: Text("📅 የዛሬው የጥናት ፕሮግራም (2019 Syllabus)", style: TextStyle(color: textPrimary(context), fontSize: 15.5, fontWeight: FontWeight.bold))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ዕለት፦ ${getAmharicDay(dayName)}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: surfaceBg(context), borderRadius: BorderRadius.circular(10)),
                    child: Text(todayCourse, style: TextStyle(color: textPrimary(context), fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                  ),
                  const SizedBox(height: 12),
                  Text("ዛሬ ይህንን የ2019 ሪሚዲያል ኮርስ ርዕስ አንብበዋል? ካላነበቡ አሁኑኑ ጥናትዎን ይጀምሩ!", style: TextStyle(color: textSecondary(context), fontSize: 13)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setString('last_study_prompt_day', todayKey);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text("በኋላ አነባለሁ", style: TextStyle(color: textSecondary(context))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9)),
                onPressed: () async {
                  await prefs.setString('last_study_prompt_day', todayKey);
                  await prefs.setBool('study_done_${userStream}_$dayName', true);
                  await StudyProgress.recordActivity(topicsDelta: 1, pointsDelta: 15);
                  _refreshProgressStats();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("👏 በጣም ጎበዝ! +15 ነጥብ አግኝተዋል!"), backgroundColor: Colors.green));
                  }
                },
                icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                label: const Text("አዎ አንብቤያለሁ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {}
  }

  Future<void> refreshStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('device_id') ?? '';
    String cachedStatus = prefs.getString('local_status') ?? 'free';
    try {
      final snapshot = await dbRef("students/$deviceId/status").get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        String newStatus = snapshot.value.toString();
        if (cachedStatus == 'vip' && newStatus != 'blocked') {
          newStatus = 'vip';
        }
        await prefs.setString('local_status', newStatus);
        setState(() => appStatus = newStatus);
        await _setupPushNotifications(newStatus == 'vip');
        if (newStatus == 'blocked' && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BlockedScreen()));
        }
      }
    } catch (e) {}
    _refreshProgressStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ስቴተስ: ${appStatus.toUpperCase()} (v$APP_VERSION)"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isVIP = appStatus == 'vip';
    bool dark = isDarkMode(context);

    final List<Widget> pages = [
      HomeContent(
        isVIP: isVIP,
        appStatus: appStatus,
        userShortId: userShortId,
        userName: userName,
        userStream: userStream,
        todayCourse: todayScheduleCourse,
        isAdminCached: isAdminCached,
        examDaysLeft: examDaysLeft,
        examLabel: examLabel,
        progressStats: progressStats,
        refreshCallback: refreshStatus,
        onProgressRefresh: _refreshProgressStats,
        onStatusChange: (s) {
          setState(() => appStatus = s);
          _setupPushNotifications(s == 'vip');
        },
        onAdminCached: () => setState(() => isAdminCached = true),
      ),
      StudyScheduleScreen(userStream: userStream, onMarkedDone: _refreshProgressStats),
      ProfileContent(
        userName: userName,
        userShortId: userShortId,
        appStatus: appStatus,
        userStream: userStream,
        points: progressStats['points'] ?? 0,
        streak: progressStats['streak'] ?? 1,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF5B4FE9).withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded, color: Color(0xFF5B4FE9), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remedial Matrix', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary(context))),
                  Text('2019 MoE Curriculum • v$APP_VERSION', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: dark ? Colors.amberAccent : const Color(0xFF5B4FE9))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isAdminCached)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.green, size: 24),
              tooltip: "Direct Admin Panel",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
            ),
          IconButton(
            icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: dark ? Colors.amber : const Color(0xFF5B4FE9)),
            tooltip: dark ? "Light Mode" : "Dark Mode",
            onPressed: toggleAppTheme,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textSecondary(context)),
            tooltip: "Refresh Status",
            onPressed: refreshStatus,
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _refreshProgressStats();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule & Outline'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// 🏠 HOME SCREEN
// ============================================================================
class HomeContent extends StatefulWidget {
  final bool isVIP;
  final String appStatus;
  final int userShortId;
  final String userName;
  final String userStream;
  final String todayCourse;
  final bool isAdminCached;
  final int? examDaysLeft;
  final String examLabel;
  final Map<String, dynamic> progressStats;
  final VoidCallback refreshCallback;
  final VoidCallback onProgressRefresh;
  final Function(String) onStatusChange;
  final VoidCallback onAdminCached;

  const HomeContent({
    Key? key,
    required this.isVIP,
    required this.appStatus,
    required this.userShortId,
    required this.userName,
    required this.userStream,
    required this.todayCourse,
    required this.isAdminCached,
    required this.examDaysLeft,
    required this.examLabel,
    required this.progressStats,
    required this.refreshCallback,
    required this.onProgressRefresh,
    required this.onStatusChange,
    required this.onAdminCached,
  }) : super(key: key);

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  Timer? _clockTimer;
  String _timeLeftToday = "";

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    String h = diff.inHours.toString().padLeft(2, '0');
    String m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    String s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    if (mounted) {
      setState(() => _timeLeftToday = "$h:$m:$s");
    }
  }

  void _showRegistrationStepsGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.amber, width: 1.5)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 30),
            const SizedBox(width: 8),
            Expanded(child: Text("VIP አባል የመሆኛ ቅደም ተከተል", style: TextStyle(color: textPrimary(context), fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepTile(context, "ደረጃ 1 (Step 1)", "ክፍያ መፈጸም", "በ CBE (1000667301673) ወይም በ Telebirr / CBE Birr (0929698365 - MUBAREK MUSTEFA) ይክፈሉ።", Icons.account_balance_wallet, Colors.orange),
              const SizedBox(height: 12),
              _buildStepTile(context, "ደረጃ 2 (Step 2)", "ደረሰኝ መላክ (Screenshot)", "ከታች ያለውን 'አሁኑኑ ተመዝገብ' የሚለውን ቁልፍ ተጭነው የከፈሉበትን ደረሰኝ ፎቶ (Screenshot) አያይዘው ይላኩ።", Icons.camera_alt_rounded, Colors.blue),
              const SizedBox(height: 12),
              _buildStepTile(context, "ደረጃ 3 (Step 3)", "ወዲያውኑ VIP መሆን", "ክፍያዎ እንደታየ ወዲያውኑ ሁሉም ፈተናዎች፣ Short Notes & PDFs፣ Flashcards እና የቴሌግራም VIP ክላስ ይከፈቱልዎታል!", Icons.verified_rounded, Colors.green),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("ዝጋ", style: TextStyle(color: textSecondary(context)))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            onPressed: () {
              Navigator.pop(context);
              _showPremiumDialog(context);
            },
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.black),
            label: const Text("አሁኑኑ ተመዝገብ (Proceed)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(BuildContext context, String step, String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surfaceBg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.18), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$step: $title", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: textSecondary(context), fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    bool isDialogLoading = false;
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: cardBg(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [const Icon(Icons.workspace_premium, color: Colors.amber, size: 28), const SizedBox(width: 8), Text("Premium Access", style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.appStatus == 'rejected')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text("❌ የላኩት ጥያቄ አልፀደቀም፤ እባክዎ ትክክለኛውን ደረሰኝ ይላኩ።", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  Text(
                    "ሰላም VIP ሆነው ሙሉ የ2019 ሞዴል ጥያቄዎችን፣ Short Notes & PDFs፣ Flashcards እና የቴሌግራም VIP ክላስ ለማግኘት ከታች ባሉት አካውንቶች ክፍያ ፈጽመው ደረሰኝ ይላኩ።",
                    style: TextStyle(color: textPrimary(context), fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceBg(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🏦 CBE = 1000667301673", style: TextStyle(color: isDarkMode(context) ? Colors.amber : Colors.orange.shade900, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("📱 Telebirr = 0929698365", style: TextStyle(color: isDarkMode(context) ? Colors.amber : Colors.orange.shade900, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("📲 CBE birr = 0929698365", style: TextStyle(color: isDarkMode(context) ? Colors.amber : Colors.orange.shade900, fontSize: 14, fontWeight: FontWeight.bold)),
                        Divider(color: borderCol(context), height: 16),
                        Text("👤 Name: MUBAREK MUSTEFA", style: TextStyle(color: isDarkMode(context) ? Colors.greenAccent : Colors.green.shade700, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (widget.appStatus == 'pending') ...[
                    const Center(child: Icon(Icons.hourglass_top, color: Colors.amber, size: 45)),
                    const SizedBox(height: 10),
                    Text("⏳ ደረሰኝዎ እየታየ ነው! እባክዎ በትዕግስት ይጠብቁ።", style: TextStyle(color: textPrimary(context), fontSize: 14), textAlign: TextAlign.center),
                  ] else ...[
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 900,
                            imageQuality: 45,
                          );
                          if (image != null) {
                            setStateDialog(() {
                              selectedImage = File(image.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: Text(selectedImage == null ? "ደረሰኝ ምረጥ (Attach Screenshot)" : "✅ ፎቶ ተመርጧል", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (selectedImage != null)
                      Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(selectedImage!, height: 120, width: double.infinity, fit: BoxFit.cover))),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("ዝጋ (Close)", style: TextStyle(color: textSecondary(context))),
              ),
              if (widget.appStatus != 'pending')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          if (selectedImage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("እባክዎ መጀመሪያ ደረሰኝ ይምረጡ!"), backgroundColor: Colors.red));
                            return;
                          }
                          setStateDialog(() => isDialogLoading = true);
                          try {
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            String deviceId = prefs.getString('device_id') ?? '';
                            final base64Image = base64Encode(await selectedImage!.readAsBytes());
                            await dbRef("students/$deviceId").update({"status": "pending", "receipt": base64Image});
                            await prefs.setString('local_status', 'pending');
                            if (context.mounted) {
                              Navigator.pop(context);
                              widget.onStatusChange('pending');
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ደረሰኝዎ ተልኳል! ክፍያው ሲታይ VIP ይደረጋሉ።"), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            setStateDialog(() => isDialogLoading = false);
                          }
                        },
                  icon: const Icon(Icons.send, color: Colors.black, size: 18),
                  label: isDialogLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text("Send Screen Shoot", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showActivationLogin(BuildContext context) {
    if (widget.isAdminCached && isOwnerUser(widget.userShortId, widget.userName)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      return;
    }

    TextEditingController pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg(context),
        title: Text("🔐 Activation & Admin", style: TextStyle(color: textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("የእርስዎ መለያ (ID): ${widget.userShortId}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: pwdCtrl, obscureText: true, style: TextStyle(color: textPrimary(context)), decoration: const InputDecoration(hintText: "የመክፈቻ ቁጥር ወይም Admin Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9)),
            onPressed: () async {
              String input = pwdCtrl.text.trim();
              int expectedVipCode = widget.userShortId * 3;
              bool isOwner = isOwnerUser(widget.userShortId, widget.userName);

              if (input == "Matrix@2026") {
                if (isOwner) {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('owner_admin_cached', true);
                  widget.onAdminCached();
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⛔ ይህ የአድሚን መቆጣጠሪያ ለአፕሊኬሽኑ ባለቤት ብቻ የተፈቀደ ነው!"), backgroundColor: Colors.red));
                }
              } else if (input == expectedVipCode.toString()) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String deviceId = prefs.getString('device_id') ?? '';
                await prefs.setString('local_status', 'vip');
                try {
                  await dbRef("students/$deviceId").update({"status": "vip"});
                } catch (e) {}
                widget.onStatusChange('vip');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ አፑ በተሳካ ሁኔታ VIP ተደርጓል!"), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ ትክክል ያልሆነ መክፈቻ ኮድ!"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Enter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openVipClass(BuildContext context) async {
    if (!widget.isVIP) {
      _showPremiumDialog(context);
    } else {
      await launchUrl(Uri.parse('https://t.me/+yQdJM7LxN8VmNWY0'), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool dark = isDarkMode(context);
    int streak = widget.progressStats['streak'] ?? 1;
    int totalTopics = widget.progressStats['totalTopics'] ?? 0;
    int todayTopics = widget.progressStats['todayTopics'] ?? 0;
    int todayMins = widget.progressStats['todayMinutes'] ?? 0;
    int points = widget.progressStats['points'] ?? 0;
    int unlocked = widget.progressStats['unlockedBadges'] ?? 0;
    double dailyGoalRatio = (todayMins / 25.0).clamp(0.0, 1.0);
    double challengeRatio = (todayTopics / 3.0).clamp(0.0, 1.0);

    String todayDay = getDayName(DateTime.now().weekday);
    Map<String, String> streamMap = getDefaultSchedule()[widget.userStream] ?? {};
    String displaySubject = widget.todayCourse.isNotEmpty
        ? widget.todayCourse
        : (streamMap[todayDay] ?? "General Study").toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: dark
                    ? const [Color(0xFF312A6C), Color(0xFF5F3DC4)]
                    : const [Color(0xFFFF8F71), Color(0xFFFFB56B), Color(0xFFFFDF73)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (dark ? Colors.deepPurple : Colors.orange).withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getGreetingText(),
                            style: TextStyle(
                              color: dark ? Colors.white : const Color(0xFF1E1B4B),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "ሰላም ${widget.userName} • v$APP_VERSION Ready",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dark ? Colors.white70 : const Color(0xFF3E345C),
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.isVIP ? Colors.amber : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.isVIP ? "👑 VIP" : "FREE",
                        style: TextStyle(
                          color: widget.isVIP ? Colors.black : (dark ? Colors.white : const Color(0xFF1E1B4B)),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _heroStat("$streak", "🔥 Day Streak", dark),
                    _heroStat("$totalTopics", "📚 Topics", dark),
                    _heroStat("$todayMins", "⏱ Minutes", dark),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Daily Goal: $todayMins/25 minutes",
                      style: TextStyle(
                        color: dark ? Colors.white : const Color(0xFF2B2447),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "${(dailyGoalRatio * 100).toInt()}%",
                      style: TextStyle(
                        color: dark ? Colors.amberAccent : const Color(0xFF2B2447),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: dailyGoalRatio,
                    minHeight: 6,
                    backgroundColor: Colors.black.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(dark ? Colors.amberAccent : const Color(0xFF5B4FE9)),
                  ),
                ),
              ],
            ),
          ),

          if (widget.examDaysLeft != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF5B4FE9).withOpacity(0.3)),
                boxShadow: [if (!dark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("⏳ ${widget.examLabel}", style: TextStyle(color: dark ? Colors.cyanAccent : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text("በየቀኑ በፕሮግራምዎ መሰረት ይለማመዱ!", style: TextStyle(color: textSecondary(context), fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                    child: Text("${widget.examDaysLeft} ቀን ቀረው", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  )
                ],
              ),
            ),
          ],

          if (!widget.isVIP) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _showRegistrationStepsGuide(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [Colors.amber.shade600, Colors.orange.shade800]),
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.black26,
                      child: Icon(Icons.workspace_premium, color: Colors.white, size: 25),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("🌟 VIP አባል ይሁኑ (Unlock All Exams & PDFs)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.5)),
                          SizedBox(height: 2),
                          Text("የአመዘጋገብ ቅደም ተከተሉን (Steps) ለማየት እዚህ ይጫኑ!", style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 16),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.18,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildModernTile(
                context,
                title: "Short Notes & PDFs",
                subtitle: "By Course & Chapter",
                icon: Icons.picture_as_pdf_rounded,
                color: Colors.deepOrange,
                isLocked: false,
                badgeText: "NEW",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShortNotesAndPdfsScreen(isVIP: widget.isVIP, onNeedVip: () => _showPremiumDialog(context)))),
              ),
              _buildModernTile(
                context,
                title: "Model Exams",
                subtitle: "2017, 2018 & 2019 NEW",
                icon: Icons.play_circle_outline_rounded,
                color: Colors.purple,
                isLocked: false,
                badgeText: "427 Qs",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'model_exams', title: 'Model Exams'))).then((_) => widget.onProgressRefresh()),
              ),
              _buildModernTile(
                context,
                title: "Remedial Exams",
                subtitle: "2015–2019 Past Papers",
                icon: Icons.school_rounded,
                color: Colors.green,
                isLocked: !widget.isVIP,
                onTap: () {
                  if (!widget.isVIP) _showPremiumDialog(context);
                  else Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'remedial_exams', title: 'Remedial Exams'))).then((_) => widget.onProgressRefresh());
                },
              ),
              _buildModernTile(
                context,
                title: "Flashcards",
                subtitle: "Fast Flip Revision",
                icon: Icons.style_rounded,
                color: Colors.indigo,
                isLocked: !widget.isVIP,
                badgeText: "v1.5",
                onTap: () {
                  if (!widget.isVIP) _showPremiumDialog(context);
                  else Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardsCourseScreen()));
                },
              ),
              _buildModernTile(
                context,
                title: "Syllabus & Schedule",
                subtitle: "2019 All Courses",
                icon: Icons.menu_book_rounded,
                color: Colors.orange,
                isLocked: false,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScheduleScreen(userStream: widget.userStream, onMarkedDone: widget.onProgressRefresh))),
              ),
              _buildModernTile(
                context,
                title: "Notes & Videos",
                subtitle: "Free Samples",
                icon: Icons.video_library_rounded,
                color: Colors.redAccent,
                isLocked: false,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SampleMaterialsScreen())),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF5B4FE9).withOpacity(0.35), width: 1.2),
              boxShadow: [if (!dark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text("💼", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text("Quick Actions & Tools", style: TextStyle(color: textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text("v$APP_VERSION", style: TextStyle(color: textSecondary(context), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),

                InkWell(
                  onTap: () => _openVipClass(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF9333EA), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E22CE).withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.play_circle_fill_rounded, color: Colors.amber, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.isVIP ? "VIP Video Class" : "VIP Video Class 🔒",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text("VIDEO", style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "ቀጥታ የቪዲዮ ትምህርቶችና የVIP ክላስ ግሩፕ",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 17),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _actionBox(context, "Bookmarks", Icons.star_rounded, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedQuestionsScreen()))),
                    _actionBox(context, "Share App", Icons.card_giftcard_rounded, Colors.pinkAccent, () => shareRemedialMatrixApp(context)),
                    _actionBox(context, "Support", Icons.support_agent_rounded, Colors.teal, () => launchUrl(Uri.parse('https://t.me/Rmedial_matrix_support'), mode: LaunchMode.externalApplication)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dark ? Colors.greenAccent : const Color(0xFF5B4FE9),
                      side: BorderSide(color: dark ? Colors.greenAccent : const Color(0xFF5B4FE9)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showActivationLogin(context),
                    icon: Icon(widget.isAdminCached ? Icons.admin_panel_settings : Icons.vpn_key, size: 18),
                    label: Text(widget.isAdminCached ? "Open Admin Control Center" : "VIP Activation Code / Admin", style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildGradientBannerButton(
            title: "Quiz Leaderboard",
            subtitle: "Compete with Top 10 Remedial Students!",
            icon: Icons.emoji_events_rounded,
            iconColor: Colors.amber,
            colors: const [Color(0xFF5B55D6), Color(0xFF7B6CF6)],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
          const SizedBox(height: 10),
          _buildGradientBannerButton(
            title: "Study Tips & Today's Plan",
            subtitle: displaySubject.replaceAll('\n', ' '),
            icon: Icons.lightbulb_rounded,
            iconColor: Colors.amberAccent,
            colors: const [Color(0xFF4E54C8), Color(0xFF6C63FF)],
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyTipsScreen())),
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'model_exams', title: 'Model Exams'))).then((_) => widget.onProgressRefresh()),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF281D33) : const Color(0xFFFFE5F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: dark ? Colors.pinkAccent.withOpacity(0.3) : Colors.pink.shade100),
                boxShadow: [if (!dark) BoxShadow(color: Colors.pink.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.track_changes_rounded, color: Colors.pinkAccent, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Challenge", style: TextStyle(color: dark ? Colors.white : const Color(0xFF241B4B), fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text("Complete 3 topics or quizzes today", style: TextStyle(color: dark ? Colors.white70 : const Color(0xFF5D4C7A), fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: dark ? Colors.pinkAccent : const Color(0xFF241B4B)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(_timeLeftToday, style: TextStyle(color: dark ? Colors.white60 : const Color(0xFF6B5B87), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: challengeRatio,
                            minHeight: 6,
                            backgroundColor: dark ? Colors.white12 : Colors.white70,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text("${todayTopics.clamp(0, 3)}/3", style: TextStyle(color: dark ? Colors.white : const Color(0xFF241B4B), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderCol(context)),
              boxShadow: [if (!dark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text("🏆", style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text("Achievements", style: TextStyle(color: textPrimary(context), fontSize: 16.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text("$unlocked/4", style: TextStyle(color: textSecondary(context), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: surfaceBg(context), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Text("💎", style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text("Your Points: $points", style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _badgeItem(context, "First Step", Icons.flag_rounded, Colors.redAccent, widget.progressStats['bFirstStep'] == true),
                    _badgeItem(context, "7 Days", Icons.local_fire_department_rounded, Colors.orange, widget.progressStats['bSevenDays'] == true),
                    _badgeItem(context, "Quiz Pro", Icons.auto_awesome_rounded, Colors.purpleAccent, widget.progressStats['bQuizPro'] == true),
                    _badgeItem(context, "Master", Icons.workspace_premium_rounded, Colors.amber, widget.progressStats['bMaster'] == true),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: surfaceBg(context), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    unlocked == 0
                        ? "✨ Start studying or take a 2019 Model Exam to earn your first badge!"
                        : "✨ Great job! Keep practicing daily to unlock all 4 badges!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary(context), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String val, String label, bool dark) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: dark ? Colors.white : const Color(0xFF1E1B4B), fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: dark ? Colors.white70 : const Color(0xFF3E345C), fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildModernTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isLocked,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    bool dark = isDarkMode(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderCol(context)),
          boxShadow: [if (!dark) BoxShadow(color: Colors.black.withOpacity(0.045), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: color.withOpacity(0.13), shape: BoxShape.circle),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 10),
                  Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textPrimary(context), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textSecondary(context), fontSize: 11)),
                ],
              ),
            ),
            if (isLocked)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 15),
                ),
              )
            else if (badgeText != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBannerButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: colors, begin: Alignment.centerLeft, end: Alignment.centerRight),
          boxShadow: [BoxShadow(color: colors.first.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _badgeItem(BuildContext context, String label, IconData icon, Color color, bool unlocked) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? color.withOpacity(0.18) : surfaceBg(context),
            border: Border.all(color: unlocked ? color : borderCol(context), width: 1.5),
          ),
          child: Icon(unlocked ? icon : Icons.lock_outline_rounded, color: unlocked ? color : Colors.grey, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: unlocked ? textPrimary(context) : textSecondary(context), fontSize: 11, fontWeight: unlocked ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _actionBox(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceBg(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderCol(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 📄 SHORT NOTES & PDFS BY COURSE & CHAPTER (WITH OFFLINE CACHE)
// ============================================================================
class ShortNotesAndPdfsScreen extends StatefulWidget {
  final bool isVIP;
  final VoidCallback onNeedVip;
  const ShortNotesAndPdfsScreen({Key? key, required this.isVIP, required this.onNeedVip}) : super(key: key);

  @override
  _ShortNotesAndPdfsScreenState createState() => _ShortNotesAndPdfsScreenState();
}

class _ShortNotesAndPdfsScreenState extends State<ShortNotesAndPdfsScreen> {
  String selectedCourse = "Biology";
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourseMaterials();
  }

  Future<void> _loadCourseMaterials() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String cacheKey = "cached_notes_pdfs_$selectedCourse";
    List<Map<String, dynamic>> loaded = [];

    try {
      final snap = await dbRef("admin_content/course_materials/$selectedCourse").get().timeout(const Duration(seconds: 4));
      if (snap.exists && snap.value is Map) {
        (snap.value as Map).forEach((k, v) {
          if (v is Map) {
            Map<String, dynamic> entry = Map<String, dynamic>.from(v);
            entry['id'] = k.toString();
            loaded.add(entry);
          }
        });
        loaded.sort((a, b) => (a['chapter'] ?? '').toString().compareTo((b['chapter'] ?? '').toString()));
        await prefs.setString(cacheKey, jsonEncode(loaded));
      }
    } catch (_) {
      String? cached = prefs.getString(cacheKey);
      if (cached != null) {
        try {
          List raw = jsonDecode(cached);
          loaded = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        items = loaded;
        isLoading = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByChapter() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in items) {
      String ch = (item['chapter'] ?? 'General Chapter').toString().trim();
      if (ch.isEmpty) ch = 'General Chapter';
      grouped.putIfAbsent(ch, () => []).add(item);
    }
    return grouped;
  }

  Future<void> _openStoredPdf(String id, String title) async {
    final String safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (safeId.isEmpty) return;

    bool dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 18),
            Expanded(child: Text("PDF እየተከፈተ ነው...", style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );

    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    String? error;
    File? readyFile;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pdf_$safeId.pdf');
      if (!await file.exists()) {
        final snap = await dbRef("admin_content/pdf_files/$safeId/data").get().timeout(const Duration(seconds: 90));
        if (!snap.exists || snap.value == null) {
          error = "❌ PDF አልተገኘም። ምናልባት ተሰርዟል።";
        } else {
          final tmp = File('${file.path}.part');
          await tmp.writeAsBytes(base64Decode(snap.value.toString()), flush: true);
          await tmp.rename(file.path);
          readyFile = file;
        }
      } else {
        readyFile = file;
      }
    } catch (_) {
      error = "❌ PDF መክፈት አልተቻለም። ኢንተርኔት ያረጋግጡ።";
    }

    closeDialog();
    if (!mounted) return;

    if (readyFile != null) {
      try {
        final result = await OpenFilex.open(readyFile.path, type: "application/pdf");
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📄 PDF ማንበቢያ አፕ አልተገኘም። Google Drive PDF Viewer ወይም ሌላ PDF reader ይጫኑ።"), backgroundColor: Colors.orange));
        }
      } catch (_) {}
    } else if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  void _openItem(Map<String, dynamic> item) {
    bool vipOnly = item['vip_only'] == true;
    if (vipOnly && !widget.isVIP) {
      widget.onNeedVip();
      return;
    }

    String kind = (item['kind'] ?? 'short').toString();
    String title = (item['title'] ?? 'Study Material').toString();
    String chapter = (item['chapter'] ?? '').toString();
    String bodyOrUrl = (item['content'] ?? '').toString();

    if (kind == 'pdf') {
      if (bodyOrUrl.startsWith('rtdb:')) {
        _openStoredPdf(bodyOrUrl.substring(5), title);
      } else {
        launchUrl(Uri.parse(bodyOrUrl), mode: LaunchMode.externalApplication);
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: cardBg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$selectedCourse • $chapter", style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("📝 $title", style: TextStyle(color: textPrimary(context), fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: SingleChildScrollView(
              child: Text(bodyOrUrl, style: TextStyle(color: textPrimary(context), fontSize: 14.5, height: 1.55)),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9)),
              onPressed: () => Navigator.pop(context),
              child: const Text("ዝጋ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> byChapter = _groupByChapter();
    List<String> chapterKeys = byChapter.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("📄 Short Notes & PDFs"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCourseMaterials),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: ALL_COURSES.length,
              itemBuilder: (context, i) {
                String c = ALL_COURSES[i];
                bool active = c == selectedCourse;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: active,
                    selectedColor: const Color(0xFF5B4FE9),
                    labelStyle: TextStyle(color: active ? Colors.white : textPrimary(context), fontWeight: FontWeight.bold, fontSize: 12.5),
                    onSelected: (_) {
                      setState(() => selectedCourse = c);
                      _loadCourseMaterials();
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chapterKeys.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            "ለ $selectedCourse እስካሁን Short Note ወይም PDF አልተጫነም።\nከAdmin Page → '📄 Short Notes & PDFs ጫን' በየChapter መጫን ይችላሉ።",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary(context), height: 1.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: chapterKeys.length,
                        itemBuilder: (context, idx) {
                          String ch = chapterKeys[idx];
                          List<Map<String, dynamic>> chItems = byChapter[ch] ?? [];
                          return Card(
                            color: cardBg(context),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderCol(context))),
                            child: ExpansionTile(
                              initiallyExpanded: idx == 0,
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF5B4FE9),
                                child: Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
                              ),
                              title: Text(ch, style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Text("${chItems.length} item(s) • Short & PDF", style: TextStyle(color: textSecondary(context), fontSize: 12)),
                              children: chItems.map((it) {
                                bool isPdf = (it['kind'] ?? 'short') == 'pdf';
                                bool vipOnly = it['vip_only'] == true;
                                bool locked = vipOnly && !widget.isVIP;
                                return ListTile(
                                  leading: Icon(
                                    isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                                    color: isPdf ? Colors.redAccent : Colors.teal,
                                  ),
                                  title: Text(
                                    (it['title'] ?? 'Untitled').toString(),
                                    style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    "${isPdf ? 'PDF File' : 'Short Note'} • ${vipOnly ? 'VIP Only' : 'Free'}",
                                    style: TextStyle(color: textSecondary(context), fontSize: 11.5),
                                  ),
                                  trailing: Icon(
                                    locked ? Icons.lock_rounded : (isPdf ? Icons.open_in_new : Icons.chevron_right),
                                    color: locked ? Colors.amber : textSecondary(context),
                                  ),
                                  onTap: () => _openItem(it),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🃏 FLASHCARDS SCREEN (FAST FLIP REVISION)
// ============================================================================
class FlashcardsCourseScreen extends StatelessWidget {
  const FlashcardsCourseScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🃏 Flashcards - Select Course")),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0),
        itemCount: ALL_COURSES.length,
        itemBuilder: (c, i) => ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardDeckScreen(subject: ALL_COURSES[i]))),
          child: Text(ALL_COURSES[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }
}

class FlashcardDeckScreen extends StatefulWidget {
  final String subject;
  const FlashcardDeckScreen({Key? key, required this.subject}) : super(key: key);
  @override
  _FlashcardDeckScreenState createState() => _FlashcardDeckScreenState();
}

class _FlashcardDeckScreenState extends State<FlashcardDeckScreen> {
  List cards = [];
  int idx = 0;
  bool showAnswer = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    List gathered = [];
    for (String assetPath in ['assets/remedial_2019_model_exams.json', 'assets/questions.json']) {
      try {
        final raw = await rootBundle.loadString(assetPath);
        final parsed = jsonDecode(raw);
        if (parsed is Map && parsed['model_exams'] != null) {
          (parsed['model_exams'] as Map).forEach((yr, subMap) {
            if (subMap is Map && subMap[widget.subject] is List) {
              gathered.addAll(subMap[widget.subject]);
            }
          });
        }
      } catch (_) {}
    }
    gathered.shuffle();
    if (mounted) {
      setState(() {
        cards = gathered.take(25).toList();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: Text("${widget.subject} Flashcards")), body: const Center(child: CircularProgressIndicator()));
    if (cards.isEmpty) return Scaffold(appBar: AppBar(title: Text("${widget.subject} Flashcards")), body: const Center(child: Text("Flashcards አልተገኙም!")));

    Map current = cards[idx] as Map;
    List opts = (current['options'] is List) ? current['options'] : [];
    int cId = int.tryParse(current['correct_option_id']?.toString() ?? '0') ?? 0;
    String answerText = opts.length > cId ? opts[cId].toString() : "N/A";
    String expText = (current['explanation'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text("🃏 ${widget.subject} (${idx + 1}/${cards.length})")),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => showAnswer = !showAnswer),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBg(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: showAnswer ? Colors.green : const Color(0xFF5B4FE9), width: 1.8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          showAnswer ? "✅ ANSWER & EXPLANATION" : "❓ QUESTION (Tap to flip)",
                          style: TextStyle(color: showAnswer ? Colors.green : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          showAnswer ? answerText : (current['question'] ?? '').toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold, height: 1.45),
                        ),
                        if (showAnswer && expText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text("💡 $expText", textAlign: TextAlign.center, style: TextStyle(color: textSecondary(context), fontSize: 14, height: 1.45)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => setState(() => showAnswer = !showAnswer),
                    child: Text(showAnswer ? "Show Question" : "Reveal Answer"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      setState(() {
                        idx = (idx + 1) % cards.length;
                        showAnswer = false;
                      });
                    },
                    child: const Text("Next Card ➡️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🔖 SAVED / BOOKMARKED QUESTIONS SCREEN
// ============================================================================
class SavedQuestionsScreen extends StatefulWidget {
  const SavedQuestionsScreen({Key? key}) : super(key: key);
  @override
  _SavedQuestionsScreenState createState() => _SavedQuestionsScreenState();
}

class _SavedQuestionsScreenState extends State<SavedQuestionsScreen> {
  List saved = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String raw = prefs.getString('bookmarked_questions') ?? '[]';
    try {
      setState(() => saved = jsonDecode(raw));
    } catch (_) {}
  }

  Future<void> _removeBookmark(int idx) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => saved.removeAt(idx));
    await prefs.setString('bookmarked_questions', jsonEncode(saved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔖 Saved Questions")),
      body: saved.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text("እስካሁን የተቀመጠ ጥያቄ የለም!\nፈተና ሲሰሩ የከበደዎትን ጥያቄ ከላይ ያለውን ⭐ ምልክት ነክተው ማስቀመጥ ይችላሉ።", textAlign: TextAlign.center, style: TextStyle(color: textSecondary(context), height: 1.5)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: saved.length,
              itemBuilder: (c, i) {
                Map q = saved[i] as Map;
                List opts = (q['options'] is List) ? q['options'] : [];
                int correctId = int.tryParse(q['correct_option_id']?.toString() ?? '0') ?? 0;
                return Card(
                  color: cardBg(context),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderCol(context))),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("📘 ${q['subject'] ?? 'Subject'}", style: const TextStyle(color: Color(0xFF5B4FE9), fontWeight: FontWeight.bold, fontSize: 12.5)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeBookmark(i),
                            )
                          ],
                        ),
                        Text((q['question'] ?? '').toString(), style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15.5)),
                        const SizedBox(height: 8),
                        if (opts.length > correctId)
                          Text("✅ መልስ: ${opts[correctId]}", style: TextStyle(color: isDarkMode(context) ? Colors.greenAccent : Colors.green.shade700, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text("💡 ${(q['explanation'] ?? 'ማብራሪያ የለውም').toString()}", style: TextStyle(color: isDarkMode(context) ? Colors.amber : Colors.orange.shade900, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class StudyScheduleScreen extends StatefulWidget {
  final String userStream;
  final VoidCallback? onMarkedDone;
  const StudyScheduleScreen({Key? key, required this.userStream, this.onMarkedDone}) : super(key: key);
  @override
  _StudyScheduleScreenState createState() => _StudyScheduleScreenState();
}

class _StudyScheduleScreenState extends State<StudyScheduleScreen> {
  late String selectedStream;
  Map<String, String> scheduleData = {};
  Map<String, bool> completedDays = {};
  bool isLoading = true;

  final List<String> daysOrder = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  @override
  void initState() {
    super.initState();
    selectedStream = widget.userStream;
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> defaultMap = Map<String, String>.from(getDefaultSchedule()[selectedStream] ?? {});

    try {
      final snap = await dbRef("admin_content/schedule/$selectedStream").get().timeout(const Duration(seconds: 4));
      if (snap.exists && snap.value is Map) {
        Map remote = snap.value as Map;
        remote.forEach((k, v) {
          defaultMap[k.toString()] = v.toString();
        });
      }
    } catch (_) {}

    Map<String, bool> tempCompleted = {};
    for (String d in daysOrder) {
      tempCompleted[d] = prefs.getBool('study_done_${selectedStream}_$d') ?? false;
    }

    if (mounted) {
      setState(() {
        scheduleData = defaultMap;
        completedDays = tempCompleted;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleDayRead(String day) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool current = completedDays[day] == true;
    await prefs.setBool('study_done_${selectedStream}_$day', !current);
    setState(() {
      completedDays[day] = !current;
    });
    if (!current) {
      await StudyProgress.recordActivity(topicsDelta: 1, pointsDelta: 15);
      widget.onMarkedDone?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ የ${getAmharicDay(day)} ኮርስ ማንበብዎ ተመዝግቧል! (+15 pts)"), backgroundColor: Colors.green));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool dark = isDarkMode(context);
    String todayName = getDayName(DateTime.now().weekday);
    List<String> streamSubjects = selectedStream == "Natural"
        ? ["Mathematics", "Physics", "Chemistry", "Biology", "English"]
        : ["Mathematics", "History", "Geography", "English"];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("📅 ፕሮግራም & Course Outline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            DropdownButton<String>(
              value: selectedStream,
              dropdownColor: cardBg(context),
              underline: const SizedBox(),
              style: TextStyle(color: dark ? Colors.amber : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: "Natural", child: Text("🔬 Natural ")),
                DropdownMenuItem(value: "Social", child: Text("🌍 Social ")),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedStream = val);
                  _loadSchedule();
                }
              },
            ),
            const SizedBox(width: 10),
          ],
          bottom: TabBar(
            indicatorColor: dark ? Colors.amber : const Color(0xFF5B4FE9),
            labelColor: dark ? Colors.amber : const Color(0xFF5B4FE9),
            unselectedLabelColor: textSecondary(context),
            tabs: const [
              Tab(icon: Icon(Icons.calendar_today, size: 18), text: "ሳምንታዊ ፕሮግራም"),
              Tab(icon: Icon(Icons.menu_book, size: 18), text: "2019 Course Outline"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: daysOrder.length,
                    itemBuilder: (context, index) {
                      String day = daysOrder[index];
                      String course = (scheduleData[day] ?? "Revision").toString();
                      bool isToday = day == todayName;
                      bool isDone = completedDays[day] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardBg(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isToday ? const Color(0xFF5B4FE9) : borderCol(context), width: isToday ? 2 : 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isDone ? Colors.green : (isToday ? const Color(0xFF5B4FE9) : surfaceBg(context)),
                            child: Icon(isDone ? Icons.check : Icons.menu_book_rounded, color: isDone || isToday ? Colors.white : textSecondary(context)),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(getAmharicDay(day), style: TextStyle(color: isToday ? (dark ? Colors.amber : const Color(0xFF5B4FE9)) : textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14.5))),
                              if (isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                                  child: const Text("ዛሬ", style: TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                ),
                              ]
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(course, style: TextStyle(color: textSecondary(context), fontSize: 13, height: 1.4)),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDone ? Colors.green.shade600 : (dark ? Colors.grey.shade800 : const Color(0xFFE7EAF6)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () => _toggleDayRead(day),
                            child: Text(isDone ? "አንብቤያለሁ ✅" : "አላነበብኩም", style: TextStyle(fontSize: 11, color: isDone ? Colors.white : textPrimary(context))),
                          ),
                        ),
                      );
                    },
                  ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: streamSubjects.length,
              itemBuilder: (context, idx) {
                String subject = streamSubjects[idx];
                List<Map<String, String>> units = officialCourseOutlines[subject] ?? [];
                return Card(
                  color: cardBg(context),
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderCol(context))),
                  child: ExpansionTile(
                    collapsedIconColor: const Color(0xFF5B4FE9),
                    iconColor: Colors.amber,
                    leading: const CircleAvatar(backgroundColor: Color(0xFF5B4FE9), child: Icon(Icons.auto_stories, color: Colors.white)),
                    title: Text("$subject Syllabus", style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text("${units.length} Official MoE Units", style: TextStyle(color: dark ? Colors.cyanAccent : const Color(0xFF5B4FE9), fontSize: 12)),
                    children: units.map<Widget>((unitMap) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: borderCol(context)))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((unitMap["unit"] ?? ""), style: TextStyle(color: dark ? Colors.amber : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text((unitMap["topics"] ?? ""), style: TextStyle(color: textSecondary(context), fontSize: 13, height: 1.4)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 👤 PROFILE + PERFORMANCE ANALYTICS + THEME SWITCH
// ============================================================================
class ProfileContent extends StatefulWidget {
  final String userName;
  final int userShortId;
  final String appStatus;
  final String userStream;
  final int points;
  final int streak;
  const ProfileContent({
    Key? key,
    required this.userName,
    required this.userShortId,
    required this.appStatus,
    required this.userStream,
    required this.points,
    required this.streak,
  }) : super(key: key);

  @override
  _ProfileContentState createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  Map subjectStats = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String raw = prefs.getString('subject_analytics') ?? '{}';
    try {
      setState(() => subjectStats = jsonDecode(raw));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    bool isVip = widget.appStatus == 'vip';
    bool dark = isDarkMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 6),
          CircleAvatar(
            radius: 46,
            backgroundColor: isVip ? Colors.amber : const Color(0xFF5B4FE9),
            child: Icon(isVip ? Icons.workspace_premium : Icons.person, size: 48, color: isVip ? Colors.black : Colors.white),
          ),
          const SizedBox(height: 14),
          Text(widget.userName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary(context))),
          const SizedBox(height: 4),
          Text("Stream: ${widget.userStream} Science", style: TextStyle(fontSize: 14, color: dark ? Colors.cyanAccent : const Color(0xFF5B4FE9))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: cardBg(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withOpacity(0.6))),
            child: Text("Student ID: ${widget.userShortId}", style: TextStyle(fontSize: 16, color: dark ? Colors.greenAccent : Colors.green.shade700, fontWeight: FontWeight.bold, letterSpacing: 1.4)),
          ),
          const SizedBox(height: 10),
          Text("Status: ${widget.appStatus.toUpperCase()}  |  v$APP_VERSION  |  💎 ${widget.points} Pts  |  🔥 ${widget.streak}d", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary(context))),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(color: cardBg(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol(context))),
            child: SwitchListTile(
              secondary: Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: dark ? Colors.amber : const Color(0xFF5B4FE9)),
              title: Text(dark ? "Dark Mode (የማታ ገጽታ)" : "Light Mode (የቀን ገጽታ)", style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: Text("ገጽታውን በአንድ ንክኪ ይቀይሩ", style: TextStyle(color: textSecondary(context), fontSize: 12)),
              value: dark,
              activeColor: Colors.amber,
              onChanged: (_) => toggleAppTheme(),
            ),
          ),

          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9), minimumSize: const Size(double.infinity, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => shareRemedialMatrixApp(context),
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text("📤 ለጓደኞችህ አጋራ (Share App)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Text("📊 የጥናት ውጤት ትንታኔ (Performance Analytics)", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: dark ? Colors.amber : const Color(0xFF5B4FE9))),
          ),
          const SizedBox(height: 10),
          if (subjectStats.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol(context))),
              child: Text("ፈተናዎችን ሲሰሩ የእያንዳንዱ ትምህርት ውጤትዎ በፐርሰንት እዚህ ይታያል!", style: TextStyle(color: textSecondary(context), fontSize: 13)),
            )
          else
            ...subjectStats.entries.map((entry) {
              String sub = entry.key.toString();
              Map st = entry.value as Map;
              int correct = st['correct'] ?? 0;
              int total = st['total'] ?? 1;
              double ratio = (correct / total).clamp(0.0, 1.0);
              int pct = (ratio * 100).toInt();
              Color barColor = pct >= 70 ? Colors.green : (pct >= 50 ? Colors.orange : Colors.redAccent);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cardBg(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol(context))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(sub, style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold)),
                        Text("$pct% ($correct/$total)", style: TextStyle(color: barColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: surfaceBg(context), valueColor: AlwaysStoppedAnimation<Color>(barColor)),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}

class StudyTipsScreen extends StatefulWidget {
  const StudyTipsScreen({Key? key}) : super(key: key);
  @override
  _StudyTipsScreenState createState() => _StudyTipsScreenState();
}

class _StudyTipsScreenState extends State<StudyTipsScreen> {
  List tips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTips();
  }

  Future<void> fetchTips() async {
    try {
      final snap = await dbRef("admin_content/study_tips").get();
      if (snap.exists) {
        List temp = [];
        (snap.value as Map).forEach((k, v) => temp.add(Map.from(v)));
        temp.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
        if (mounted) setState(() {
          tips = temp;
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("💡 Study Tips")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tips.isEmpty
              ? Center(child: Text("እስካሁን ምንም ጥቆማ አልተለቀቀም!", style: TextStyle(color: textSecondary(context))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tips.length,
                  itemBuilder: (c, i) => Card(
                    color: cardBg(context),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderCol(context))),
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb, color: Colors.amber, size: 30),
                      title: Text(tips[i]['title'] ?? '', style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(tips[i]['content'] ?? '', style: TextStyle(color: textSecondary(context), height: 1.4)),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class SampleMaterialsScreen extends StatefulWidget {
  const SampleMaterialsScreen({Key? key}) : super(key: key);
  @override
  _SampleMaterialsScreenState createState() => _SampleMaterialsScreenState();
}

class _SampleMaterialsScreenState extends State<SampleMaterialsScreen> {
  List materials = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMaterials();
  }

  Future<void> fetchMaterials() async {
    try {
      final snap = await dbRef("admin_content/sample_materials").get();
      if (snap.exists) {
        List temp = [];
        (snap.value as Map).forEach((k, v) => temp.add(Map.from(v)));
        temp.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
        if (mounted) setState(() {
          materials = temp;
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📚 Sample Notes & Videos")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : materials.isEmpty
              ? Center(child: Text("እስካሁን ምንም የናሙና ትምህርት አልተለቀቀም!", style: TextStyle(color: textSecondary(context))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: materials.length,
                  itemBuilder: (c, i) {
                    var m = materials[i];
                    bool isVideo = m['type'] == 'video';
                    return Card(
                      color: cardBg(context),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderCol(context))),
                      child: ListTile(
                        leading: Icon(isVideo ? Icons.play_circle_fill : Icons.picture_as_pdf, color: isVideo ? Colors.redAccent : Colors.blueAccent, size: 40),
                        title: Text(m['title'] ?? '', style: TextStyle(color: textPrimary(context), fontWeight: FontWeight.bold)),
                        subtitle: Text("ይክፈቱ (Tap to open)", style: TextStyle(color: textSecondary(context))),
                        trailing: const Icon(Icons.open_in_new, color: Colors.amber),
                        onTap: () => launchUrl(Uri.parse(m['url'] ?? ''), mode: LaunchMode.externalApplication),
                      ),
                    );
                  },
                ),
    );
  }
}

// ============================================================================
// 🛠 ADMIN DASHBOARD
// ============================================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalCount = 0;
  int vipCount = 0;
  int pendingCount = 0;
  int freeCount = 0;
  int blockedCount = 0;
  int naturalCount = 0;
  int socialCount = 0;
  int latestVersionCount = 0;
  int olderVersionCount = 0;
  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => loadingStats = true);
    try {
      final snap = await dbRef("students").get();
      int total = 0, vip = 0, pending = 0, free = 0, blocked = 0, nat = 0, soc = 0, vLatest = 0, vOld = 0;
      if (snap.exists && snap.value is Map) {
        (snap.value as Map).forEach((k, v) {
          if (v is Map) {
            total++;
            String st = (v['status'] ?? 'free').toString().toLowerCase();
            if (st == 'vip') vip++;
            else if (st == 'pending') pending++;
            else if (st == 'blocked') blocked++;
            else free++;

            String stream = (v['stream'] ?? '').toString().toLowerCase();
            if (stream.contains('social')) soc++;
            else nat++;

            String ver = (v['app_version'] ?? '').toString().trim();
            if (ver == APP_VERSION) vLatest++;
            else vOld++;
          }
        });
      }
      if (mounted) {
        setState(() {
          totalCount = total;
          vipCount = vip;
          pendingCount = pending;
          freeCount = free;
          blockedCount = blocked;
          naturalCount = nat;
          socialCount = soc;
          latestVersionCount = vLatest;
          olderVersionCount = vOld;
          loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingStats = false);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final snap = await dbRef("students").get();
      if (!snap.exists || snap.value == null) return;
      Map cleanBackup = {};
      (snap.value as Map).forEach((k, v) {
        if (v is Map) {
          Map copy = Map.from(v);
          copy.remove('receipt');
          cleanBackup[k.toString()] = copy;
        }
      });
      String jsonText = jsonEncode({"students": cleanBackup});
      await Clipboard.setData(ClipboardData(text: jsonText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ የሁሉም ተማሪዎች ዳታ ባክአፕ Copy ተደርጓል!"), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  void _showExamCountdownDialog() {
    TextEditingController dateCtrl = TextEditingController(text: "2027-06-15");
    TextEditingController labelCtrl = TextEditingController(text: "2019 National Remedial Exam");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg(context),
        title: Text("⏳ የፈተና ቀን ቆጣሪ (Countdown)", style: TextStyle(color: textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: "ርዕስ (Label)")),
            const SizedBox(height: 10),
            TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: "ቀን (YYYY-MM-DD)", hintText: "2027-06-15")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await dbRef("admin_settings/exam_countdown").set({
                "date": dateCtrl.text.trim(),
                "label": labelCtrl.text.trim(),
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ የፈተና ቀን ቆጣሪ ተቀምጧል!"), backgroundColor: Colors.green));
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textSecondary(context), fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🛠 Admin Control Center"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.amber), onPressed: _loadStats),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (loadingStats)
              const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.amber))
            else ...[
              Row(
                children: [
                  _statBox(context, "ጠቅላላ ተማሪ", "$totalCount", Colors.blue),
                  const SizedBox(width: 8),
                  _statBox(context, "👑 VIP", "$vipCount", Colors.amber.shade700),
                  const SizedBox(width: 8),
                  _statBox(context, "⏳ Pending", "$pendingCount", Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statBox(context, "🆓 Free", "$freeCount", Colors.teal),
                  const SizedBox(width: 8),
                  _statBox(context, "🔬 Nat / 🌍 Soc", "$naturalCount / $socialCount", Colors.green),
                  const SizedBox(width: 8),
                  _statBox(context, "🚫 Blocked", "$blockedCount", Colors.redAccent),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statBox(context, "🚀 On v$APP_VERSION", "$latestVersionCount", const Color(0xFF5B4FE9)),
                  const SizedBox(width: 8),
                  _statBox(context, "📦 Older Versions", "$olderVersionCount", Colors.grey),
                ],
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReceiptsScreen())).then((_) => _loadStats()),
              icon: const Icon(Icons.receipt_long, color: Colors.black),
              label: Text("⚡ አዲስ ደረሰኞችን አረጋግጥ ($pendingCount Pending)", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.deepOrange, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUploadShortPdfScreen())),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text("📄 Short Notes & PDFs ጫን (By Course & Chapter)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStudentListScreen())).then((_) => _loadStats()),
              icon: const Icon(Icons.group, color: Colors.white),
              label: const Text("👥 የተመዘገቡ ተማሪዎች (Version / Search / VIP)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.indigo, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddQuestionScreen())),
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text("➕ አዲስ ጥያቄ በቀጥታ ጫን (Live Question)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScheduleManagerScreen())),
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              label: const Text("📅 የ2019 ፕሮግራም & የዕለቱ ማሳሰቢያ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.orange.shade800, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
              icon: const Icon(Icons.campaign, color: Colors.white),
              label: const Text("📢 ማስታወቂያ ላክ (ለVIP / ለFree / ለሁሉም)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminContentScreen())),
              icon: const Icon(Icons.edit_document, color: Colors.white),
              label: const Text("✍️ ኮንቴንት ጨምር (Tips & Materials)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.purple, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUpdateAppScreen())),
              icon: const Icon(Icons.system_update, color: Colors.white),
              label: const Text("🚀 አዲስ Update (1xBet-Style) ልቀቅ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF5B4FE9), side: const BorderSide(color: Color(0xFF5B4FE9)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _showExamCountdownDialog,
                    icon: const Icon(Icons.timer, size: 18),
                    label: const Text("Exam Countdown", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.amber.shade800, side: BorderSide(color: Colors.amber.shade800), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.backup, size: 18),
                    label: const Text("Backup Students", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 📄 ADMIN UPLOAD SHORT NOTES & PDFS BY COURSE & CHAPTER
// ============================================================================
class AdminUploadShortPdfScreen extends StatefulWidget {
  const AdminUploadShortPdfScreen({Key? key}) : super(key: key);
  @override
  _AdminUploadShortPdfScreenState createState() => _AdminUploadShortPdfScreenState();
}

class _AdminUploadShortPdfScreenState extends State<AdminUploadShortPdfScreen> {
  String course = "Biology";
  String kind = "short"; // short | pdf_file | pdf_link
  bool vipOnly = true;
  bool saving = false;

  String? pickedName;
  Uint8List? pickedBytes;

  final TextEditingController chapterCtrl = TextEditingController(text: "Chapter 1");
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController bodyOrUrlCtrl = TextEditingController();

  @override
  void dispose() {
    chapterCtrl.dispose();
    titleCtrl.dispose();
    bodyOrUrlCtrl.dispose();
    super.dispose();
  }

  void _snack(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  String _fmtSize(int bytes) => "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;

      if (f.size > MAX_PDF_UPLOAD_BYTES) {
        _snack("❌ ፋይሉ ${_fmtSize(f.size)} ነው። ከ ${_fmtSize(MAX_PDF_UPLOAD_BYTES)} በታች መሆን አለበት (ትልቅ ከሆነ 'PDF Link' ይጠቀሙ)።", Colors.red);
        return;
      }

      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        _snack("❌ ፋይሉን ማንበብ አልተቻለም። ሌላ ፋይል ይሞክሩ።", Colors.red);
        return;
      }

      if (!mounted) return;
      setState(() {
        pickedName = f.name;
        pickedBytes = bytes;
        if (titleCtrl.text.trim().isEmpty) {
          titleCtrl.text = f.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        }
      });
    } catch (_) {
      _snack("❌ ፋይል መምረጥ አልተቻለም። እንደገና ይሞክሩ።", Colors.red);
    }
  }

  Future<void> _saveMaterial() async {
    final String ch = chapterCtrl.text.trim();
    final String title = titleCtrl.text.trim();
    final String text = bodyOrUrlCtrl.text.trim();

    if (ch.isEmpty || title.isEmpty) {
      _snack("እባክዎ Chapter እና ርዕስ ይሙሉ!", Colors.red);
      return;
    }
    if (kind == 'short' && text.isEmpty) {
      _snack("እባክዎ የShort Note ጽሑፍ ይሙሉ!", Colors.red);
      return;
    }
    if (kind == 'pdf_link' && !text.startsWith('http')) {
      _snack("እባክዎ ትክክለኛ PDF ሊንክ ያስገቡ (http ወይም https)!", Colors.red);
      return;
    }
    if (kind == 'pdf_file' && pickedBytes == null) {
      _snack("እባክዎ መጀመሪያ PDF ፋይል ይምረጡ!", Colors.red);
      return;
    }

    setState(() => saving = true);
    try {
      String savedKind = kind == 'short' ? 'short' : 'pdf';
      String content = text;
      final Map<String, dynamic> extra = {};

      if (kind == 'pdf_file') {
        final fileRef = dbRef("admin_content/pdf_files").push();
        await fileRef.set({
          "name": pickedName ?? "$title.pdf",
          "size": pickedBytes!.length,
          "data": base64Encode(pickedBytes!),
          "time": DateTime.now().millisecondsSinceEpoch,
        }).timeout(const Duration(minutes: 3));
        content = "rtdb:${fileRef.key}";
        extra["file_name"] = pickedName ?? "$title.pdf";
        extra["file_size"] = pickedBytes!.length;
      }

      await dbRef("admin_content/course_materials/$course").push().set({
        "chapter": ch,
        "kind": savedKind,
        "title": title,
        "content": content,
        "vip_only": vipOnly,
        "time": DateTime.now().millisecondsSinceEpoch,
        ...extra,
      }).timeout(const Duration(seconds: 30));

      if (mounted) {
        titleCtrl.clear();
        bodyOrUrlCtrl.clear();
        setState(() {
          saving = false;
          pickedName = null;
          pickedBytes = null;
        });
        _snack("✅ ወደ $course → $ch ተጨምሯል!", Colors.green);
      }
    } catch (_) {
      if (mounted) setState(() => saving = false);
      _snack("❌ አልተቀመጠም። ኢንተርኔት ያረጋግጡና እንደገና ይሞክሩ።", Colors.red);
    }
  }

  InputDecoration _dec(String label, {IconData? icon, String? hint}) {
    final OutlineInputBorder base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderCol(context)),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: cardBg(context),
      border: base,
      enabledBorder: base,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF5B4FE9), width: 1.6),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final bool selected = kind == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : textPrimary(context))),
      selected: selected,
      selectedColor: const Color(0xFF5B4FE9),
      backgroundColor: cardBg(context),
      showCheckmark: false,
      side: BorderSide(color: selected ? const Color(0xFF5B4FE9) : borderCol(context)),
      onSelected: saving ? null : (_) => setState(() => kind = value),
    );
  }

  Widget _filePickerArea() {
    final bool hasFile = pickedBytes != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: saving ? null : _pickPdf,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: hasFile ? Colors.green.withOpacity(0.08) : cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hasFile ? Colors.green : const Color(0xFF5B4FE9), width: 1.4),
        ),
        child: hasFile
            ? Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pickedName ?? "PDF", maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary(context))),
                        const SizedBox(height: 2),
                        Text(_fmtSize(pickedBytes!.length), style: TextStyle(fontSize: 12.5, color: textSecondary(context))),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "ሌላ ምረጥ",
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: saving ? null : _pickPdf,
                  ),
                  IconButton(
                    tooltip: "አስወግድ",
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: saving ? null : () => setState(() { pickedName = null; pickedBytes = null; }),
                  ),
                ],
              )
            : Column(
                children: [
                  const Icon(Icons.upload_file, size: 42, color: Color(0xFF5B4FE9)),
                  const SizedBox(height: 8),
                  Text("PDF ፋይል ከስልክ ምረጥ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: textPrimary(context))),
                  const SizedBox(height: 4),
                  Text("እስከ ${_fmtSize(MAX_PDF_UPLOAD_BYTES)} ድረስ", style: TextStyle(fontSize: 12.5, color: textSecondary(context))),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📄 Upload Short Note / PDF")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: course,
              dropdownColor: cardBg(context),
              decoration: _dec("Course (ትምህርት)", icon: Icons.menu_book),
              items: ALL_COURSES.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: saving ? null : (v) => setState(() => course = v ?? "Biology"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: chapterCtrl,
              enabled: !saving,
              decoration: _dec("Chapter", icon: Icons.bookmark_outline, hint: "ምሳሌ: Chapter 1: Cell Biology"),
            ),
            const SizedBox(height: 16),
            Text("አይነት (Type)", style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeChip('short', "📝 Short Note"),
                _typeChip('pdf_file', "📎 PDF ፋይል"),
                _typeChip('pdf_link', "🔗 PDF Link"),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBg(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol(context)),
              ),
              child: SwitchListTile(
                title: const Text("👑 VIP Only", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(vipOnly ? "VIP ተማሪዎች ብቻ ያያሉ" : "ለሁሉም ተማሪ ክፍት ነው", style: const TextStyle(fontSize: 12.5)),
                value: vipOnly,
                activeColor: Colors.amber,
                onChanged: saving ? null : (val) => setState(() => vipOnly = val),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              enabled: !saving,
              decoration: _dec("ርዕስ (Title)", icon: Icons.title),
            ),
            const SizedBox(height: 12),
            if (kind == 'pdf_file') _filePickerArea(),
            if (kind == 'pdf_link')
              TextField(
                controller: bodyOrUrlCtrl,
                enabled: !saving,
                maxLines: 2,
                keyboardType: TextInputType.url,
                decoration: _dec("PDF URL / Drive / Telegram Link", icon: Icons.link),
              ),
            if (kind == 'short')
              TextField(
                controller: bodyOrUrlCtrl,
                enabled: !saving,
                maxLines: 8,
                decoration: _dec("Short Note Content (አጭር ማስታወሻ)"),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: saving ? null : _saveMaterial,
              child: saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                        const SizedBox(width: 12),
                        Text(kind == 'pdf_file' ? "PDF እየተጫነ ነው..." : "በማስቀመጥ ላይ...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, color: Colors.white),
                        SizedBox(width: 10),
                        Text("አስቀምጥ (Save to Chapter)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5)),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ➕ LIVE QUESTION UPLOADER
// ============================================================================
class AdminAddQuestionScreen extends StatefulWidget {
  const AdminAddQuestionScreen({Key? key}) : super(key: key);
  @override
  _AdminAddQuestionScreenState createState() => _AdminAddQuestionScreenState();
}

class _AdminAddQuestionScreenState extends State<AdminAddQuestionScreen> {
  String examType = 'model_exams';
  String year = '2019';
  String subject = 'Biology';
  int correctIndex = 0;
  bool isSaving = false;

  final qCtrl = TextEditingController();
  final aCtrl = TextEditingController();
  final bCtrl = TextEditingController();
  final cCtrl = TextEditingController();
  final dCtrl = TextEditingController();
  final expCtrl = TextEditingController();

  Future<void> _saveQuestion() async {
    if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty || bCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("እባክዎ ጥያቄውን እና ምርጫዎቹን ይሙሉ!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => isSaving = true);
    try {
      await dbRef("live_questions/$examType/$year/$subject").push().set({
        "question": qCtrl.text.trim(),
        "options": [aCtrl.text.trim(), bCtrl.text.trim(), cCtrl.text.trim(), dCtrl.text.trim()],
        "correct_option_id": correctIndex,
        "explanation": expCtrl.text.trim().isNotEmpty ? expCtrl.text.trim() : "ማብራሪያ የለውም።",
      });
      if (mounted) {
        qCtrl.clear();
        aCtrl.clear();
        bCtrl.clear();
        cCtrl.clear();
        dCtrl.clear();
        expCtrl.clear();
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ጥያቄው በቀጥታ ወደ አፑ ተጭኗል!"), backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("➕ Live Question Uploader")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: examType,
                    dropdownColor: cardBg(context),
                    decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'model_exams', child: Text("Model Exams")),
                      DropdownMenuItem(value: 'remedial_exams', child: Text("Remedial Exams")),
                    ],
                    onChanged: (v) => setState(() => examType = v ?? 'model_exams'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: year,
                    dropdownColor: cardBg(context),
                    decoration: const InputDecoration(labelText: "Year", border: OutlineInputBorder()),
                    items: ['2015', '2016', '2017', '2018', '2019'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setState(() => year = v ?? '2019'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: subject,
              dropdownColor: cardBg(context),
              decoration: const InputDecoration(labelText: "Subject", border: OutlineInputBorder()),
              items: ALL_COURSES.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => subject = v ?? 'Biology'),
            ),
            const SizedBox(height: 12),
            TextField(controller: qCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "ጥያቄ (Question)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: aCtrl, decoration: const InputDecoration(labelText: "Option A", border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: bCtrl, decoration: const InputDecoration(labelText: "Option B", border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "Option C", border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: dCtrl, decoration: const InputDecoration(labelText: "Option D", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: correctIndex,
              dropdownColor: cardBg(context),
              decoration: const InputDecoration(labelText: "ትክክለኛው መልስ (Correct Option)", border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 0, child: Text("Option A")),
                DropdownMenuItem(value: 1, child: Text("Option B")),
                DropdownMenuItem(value: 2, child: Text("Option C")),
                DropdownMenuItem(value: 3, child: Text("Option D")),
              ],
              onChanged: (v) => setState(() => correctIndex = v ?? 0),
            ),
            const SizedBox(height: 12),
            TextField(controller: expCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "ማብራሪያ (Explanation)", border: OutlineInputBorder())),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 52)),
              onPressed: isSaving ? null : _saveQuestion,
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              label: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("ጥያቄውን ጫን (Upload Question)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

class AdminScheduleManagerScreen extends StatefulWidget {
  const AdminScheduleManagerScreen({Key? key}) : super(key: key);
  @override
  _AdminScheduleManagerScreenState createState() => _AdminScheduleManagerScreenState();
}

class _AdminScheduleManagerScreenState extends State<AdminScheduleManagerScreen> {
  String selectedStream = "Natural";
  String selectedDay = getDayName(DateTime.now().weekday);
  String selectedSubjectForPicker = "Mathematics";
  final TextEditingController courseCtrl = TextEditingController();
  bool isSaving = false;

  final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  @override
  void initState() {
    super.initState();
    Map<String, String> streamMap = getDefaultSchedule()[selectedStream] ?? {};
    courseCtrl.text = (streamMap[selectedDay] ?? "").toString();
  }

  Future<void> saveAndNotifySchedule({required bool sendPushAlert}) async {
    if (courseCtrl.text.trim().isEmpty) return;
    setState(() => isSaving = true);
    try {
      String courseText = courseCtrl.text.trim();
      await dbRef("admin_content/schedule/$selectedStream/$selectedDay").set(courseText);

      if (sendPushAlert) {
        int now = DateTime.now().millisecondsSinceEpoch;
        Map<String, dynamic> alertData = {
          "title": "📅 የዛሬ የጥናት ማሳሰቢያ (${getAmharicDay(selectedDay)})",
          "message": "ውድ የ $selectedStream ተማሪዎች፣ የዛሬው የ2019 ሪሚዲያል የጥናት ፕሮግራም፦\n\n【 $courseText 】\n\nዛሬ ይህንን ኮርስ አንብበዋል? ካላነበቡ አሁኑኑ ይጀምሩ!",
          "time": now,
        };
        await dbRef("announcements/all").set(alertData);
        await dbRef("announcement").set(alertData);
      }

      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sendPushAlert ? "✅ ፕሮግራሙ ተቀይሮ ለተማሪዎች Notification ተልኳል!" : "✅ የጥናት ፕሮግራሙ ተቀምጧል!"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> subjectUnits = officialCourseOutlines[selectedSubjectForPicker] ?? [];
    List<String> subjectKeys = officialCourseOutlines.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("📅 የ2019 ፕሮግራም ማስተካከያ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("1. የጥናት መስመር (Stream) እና ቀን ይምረጡ፦", style: TextStyle(color: isDarkMode(context) ? Colors.amber : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStream,
                    dropdownColor: cardBg(context),
                    decoration: const InputDecoration(labelText: "Stream", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "Natural", child: Text("Natural")),
                      DropdownMenuItem(value: "Social", child: Text("Social")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedStream = val;
                          Map<String, String> streamMap = getDefaultSchedule()[selectedStream] ?? {};
                          courseCtrl.text = (streamMap[selectedDay] ?? "").toString();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedDay,
                    dropdownColor: cardBg(context),
                    decoration: const InputDecoration(labelText: "Day", border: OutlineInputBorder()),
                    items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedDay = val;
                          Map<String, String> streamMap = getDefaultSchedule()[selectedStream] ?? {};
                          courseCtrl.text = (streamMap[selectedDay] ?? "").toString();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text("2. ከ2019 Course Outline ላይ ርዕስ ይምረጡ (Quick Select)፦", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedSubjectForPicker,
              dropdownColor: cardBg(context),
              decoration: const InputDecoration(labelText: "ትምህርት ይምረጡ (Subject)", border: OutlineInputBorder()),
              items: subjectKeys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedSubjectForPicker = val);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: subjectUnits.length,
                itemBuilder: (context, i) {
                  Map<String, String> uMap = subjectUnits[i];
                  String uTitle = (uMap["unit"] ?? "");
                  String uTopics = (uMap["topics"] ?? "");
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        courseCtrl.text = "📘 $selectedSubjectForPicker - $uTitle\n$uTopics";
                      });
                    },
                    child: Container(
                      width: 240,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5B4FE9).withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(uTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDarkMode(context) ? Colors.amber : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Expanded(child: Text(uTopics, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: textSecondary(context), fontSize: 11))),
                          const Text("👉 ይህን ለመምረጥ ይጫኑ", style: TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: courseCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "የዕለቱ የሚጠናው ኮርስ ዝርዝር", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50)),
              onPressed: isSaving ? null : () => saveAndNotifySchedule(sendPushAlert: false),
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text("ፕሮግራሙን ብቻ ሴቭ አድርግ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 52)),
              onPressed: isSaving ? null : () => saveAndNotifySchedule(sendPushAlert: true),
              icon: const Icon(Icons.notifications_active, color: Colors.black),
              label: const Text("🔔 'ዛሬ ይሄን ኮርስ አንብበዋል?' ብለህ ላክ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({Key? key}) : super(key: key);
  @override
  _AdminBroadcastScreenState createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController msgCtrl = TextEditingController();
  String targetAudience = 'all';
  bool isSending = false;

  Future<void> sendBroadcast() async {
    if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
    setState(() => isSending = true);
    try {
      int now = DateTime.now().millisecondsSinceEpoch;
      Map<String, dynamic> payload = {
        "title": titleCtrl.text.trim(),
        "message": msgCtrl.text.trim(),
        "target": targetAudience,
        "time": now,
      };
      await dbRef("announcements/$targetAudience").set(payload);
      if (targetAudience == 'all') {
        await dbRef("announcement").set(payload);
      }
      if (mounted) {
        setState(() => isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ማስታወቂያው በተሳካ ሁኔታ ተልኳል!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📢 Targeted Broadcast")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ማስታወቂያው ለማን ይድረስ?", style: TextStyle(color: isDarkMode(context) ? Colors.amber : const Color(0xFF5B4FE9), fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: targetAudience,
              dropdownColor: cardBg(context),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'all', child: Text("🌍 ለሁሉም ተማሪዎች (All Students)")),
                DropdownMenuItem(value: 'vip', child: Text("👑 ለVIP ተማሪዎች ብቻ (VIP Only)")),
                DropdownMenuItem(value: 'free', child: Text("🆓 ለነጻ ተማሪዎች ብቻ (Free Only)")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => targetAudience = val);
              },
            ),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "ርዕስ (Title)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: msgCtrl, maxLines: 6, decoration: const InputDecoration(labelText: "መልዕክት (Message)", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 52)),
              onPressed: isSending ? null : sendBroadcast,
              icon: const Icon(Icons.send, color: Colors.white),
              label: isSending ? const CircularProgressIndicator(color: Colors.white) : const Text("ማስታወቂያውን ላክ (Send Broadcast)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(
              "💡 አፑ ዝግ ሆኖ ከውጭ (Notification Bar) ለመላክ Firebase Console -> Messaging ውስጥ Topic ላይ 'all_students', 'vip_students' ወይም 'free_students' ብለህ ላክ!",
              style: TextStyle(color: textSecondary(context), fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("✍️ Content Manager")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, minimumSize: const Size(double.infinity, 50)), onPressed: () => _showAddTipDialog(context), icon: const Icon(Icons.lightbulb, color: Colors.white), label: const Text("አዲስ Study Tip ጨምር", style: TextStyle(color: Colors.white))),
            const SizedBox(height: 15),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 50)), onPressed: () => _showAddMaterialDialog(context), icon: const Icon(Icons.video_library, color: Colors.white), label: const Text("አዲስ Sample Material ጨምር", style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _showAddTipDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("አዲስ Study Tip"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: "ርዕስ (ምሳሌ: የሰዓት አጠቃቀም)")),
          const SizedBox(height: 10),
          TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(hintText: "ዝርዝር ማብራሪያ")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
                await dbRef("admin_content/study_tips").push().set({"title": titleCtrl.text, "content": contentCtrl.text, "time": DateTime.now().millisecondsSinceEpoch});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ተጨምሯል!")));
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController urlCtrl = TextEditingController();
    String mType = 'video';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (c, setStateDialog) => AlertDialog(
          title: const Text("አዲስ Sample Material"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: "ርዕስ (ምሳሌ: Physics Chapter 1)")),
            const SizedBox(height: 10),
            TextField(controller: urlCtrl, decoration: const InputDecoration(hintText: "የቪዲዮ ወይም የፋይል ሊንክ (URL)")),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: mType,
              dropdownColor: cardBg(context),
              items: const [DropdownMenuItem(value: 'video', child: Text("🎥 Video")), DropdownMenuItem(value: 'pdf', child: Text("📄 PDF / Note"))],
              onChanged: (val) => setStateDialog(() => mType = val.toString()),
            )
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  await dbRef("admin_content/sample_materials").push().set({"title": titleCtrl.text, "url": urlCtrl.text, "type": mType, "time": DateTime.now().millisecondsSinceEpoch});
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ተጨምሯል!")));
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminUpdateAppScreen extends StatelessWidget {
  const AdminUpdateAppScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    TextEditingController verCtrl = TextEditingController(text: APP_VERSION);
    TextEditingController urlCtrl = TextEditingController(text: DEFAULT_DIRECT_APK_URL);
    TextEditingController whatsNewCtrl = TextEditingController(
        text: "• PDF ፋይሎች አሁን በቀጥታ በአፑ ውስጥ ይከፈታሉ\n• አዲስ እና ንጹህ ዲዛይን\n• የUpdate ማሳወቂያ ስህተት ተስተካክሏል");

    return Scaffold(
      appBar: AppBar(title: const Text("🚀 1xBet-Style Update ልቀቅ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Text("ይህንን ስትጫን የድሮውን አፕ ለያዙ ተማሪዎች ወዲያውኑ ወደ V$APP_VERSION እንዲያድጉ ማሳወቂያ ይደርሳቸዋል!", style: TextStyle(color: isDarkMode(context) ? Colors.amber : const Color(0xFF5B4FE9), fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(controller: verCtrl, decoration: const InputDecoration(labelText: "አዲሱ ቨርሽን (ምሳሌ: 1.5.0)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "Direct APK Download URL (Remedial-Updates)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: whatsNewCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "What's new? (ምን አዲስ ነገር ተጨመረ?)", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(double.infinity, 52)),
            onPressed: () async {
              if (verCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                await dbRef("admin_settings/update").set({
                  "version": verCtrl.text.trim(),
                  "url": urlCtrl.text.trim(),
                  "whats_new": whatsNewCtrl.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ የUpdate ትዕዛዝ ለሁሉም ተማሪዎች ተልኳል!"), backgroundColor: Colors.green));
                }
              }
            },
            child: const Text("ለተማሪዎች አሳውቅ (Push Update)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }
}

class AdminStudentListScreen extends StatefulWidget {
  const AdminStudentListScreen({Key? key}) : super(key: key);
  @override
  _AdminStudentListScreenState createState() => _AdminStudentListScreenState();
}

class _AdminStudentListScreenState extends State<AdminStudentListScreen> {
  List allStudents = [];
  List displayedStudents = [];
  bool isLoading = true;
  String currentFilter = 'All';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    try {
      final snap = await dbRef("students").get();
      if (snap.exists) {
        List temp = [];
        (snap.value as Map).forEach((k, v) {
          Map st = Map.from(v);
          st['device_id'] = k;
          temp.add(st);
        });
        if (mounted) setState(() {
          allStudents = temp;
          _applyFilter();
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    displayedStudents = allStudents.where((s) {
      bool filterOk = true;
      if (currentFilter == 'v$APP_VERSION') {
        filterOk = (s['app_version'] ?? '').toString().trim() == APP_VERSION;
      } else if (currentFilter != 'All') {
        filterOk = s['status'].toString().toLowerCase() == currentFilter.toLowerCase();
      }
      if (!filterOk) return false;
      if (searchQuery.isEmpty) return true;
      String name = (s['full_name'] ?? '').toString().toLowerCase();
      String id = (s['short_id'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase()) || id.contains(searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> updateStudentStatus(String deviceId, String newStatus) async {
    try {
      await dbRef("students/$deviceId").update({"status": newStatus});
      fetchStudents();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ስቴተስ ወደ $newStatus ተቀይሯል!")));
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ተማሪዎች (${displayedStudents.length})"), actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list),
          onSelected: (val) {
            setState(() {
              currentFilter = val.toString();
              _applyFilter();
            });
          },
          itemBuilder: (context) => ['All', 'v$APP_VERSION', 'VIP', 'Pending', 'Free', 'Blocked'].map((e) => PopupMenuItem<String>(value: e, child: Text(e))).toList(),
        )
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val.trim();
                  _applyFilter();
                });
              },
              decoration: InputDecoration(
                hintText: "በስም ወይም በID ፈልግ (Search)...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF5B4FE9)),
                filled: true,
                fillColor: cardBg(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol(context))),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedStudents.isEmpty
                    ? Center(child: Text("በ '$currentFilter' የተገኘ ተማሪ የለም!"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: displayedStudents.length,
                        itemBuilder: (c, i) {
                          var s = displayedStudents[i];
                          bool isVip = s['status'] == 'vip';
                          bool isBlocked = s['status'] == 'blocked';
                          String ver = (s['app_version'] ?? 'Old').toString();
                          return Card(
                            color: cardBg(context),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderCol(context))),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: isBlocked ? Colors.red : (isVip ? Colors.amber : Colors.blueGrey), child: Icon(isBlocked ? Icons.block : Icons.person, color: Colors.black)),
                              title: Row(
                                children: [
                                  Flexible(child: Text(s['full_name'] ?? 'Unknown', overflow: TextOverflow.ellipsis, style: TextStyle(color: isBlocked ? Colors.redAccent : textPrimary(context), fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ver == APP_VERSION ? Colors.green.withOpacity(0.18) : Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text("v$ver", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ver == APP_VERSION ? Colors.green : textSecondary(context))),
                                  ),
                                ],
                              ),
                              subtitle: Text("ID: ${s['short_id']} | Code: ${(s['short_id'] ?? 0) * 3}\nStream: ${s['stream'] ?? '-'} | Status: ${s['status']}", style: TextStyle(color: textSecondary(context), fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isVip) IconButton(icon: const Icon(Icons.verified, color: Colors.amber), onPressed: () => updateStudentStatus(s['device_id'], 'vip')),
                                  IconButton(icon: Icon(isBlocked ? Icons.lock_open : Icons.block, color: isBlocked ? Colors.green : Colors.red), onPressed: () => updateStudentStatus(s['device_id'], isBlocked ? 'free' : 'blocked')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ⚡ FAST ADMIN RECEIPTS SCREEN
class AdminReceiptsScreen extends StatefulWidget {
  const AdminReceiptsScreen({Key? key}) : super(key: key);
  @override
  _AdminReceiptsScreenState createState() => _AdminReceiptsScreenState();
}

class _AdminReceiptsScreenState extends State<AdminReceiptsScreen> {
  List<Map<String, dynamic>> pendingStudents = [];
  final Map<String, Uint8List> _decodedImageCache = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReceipts();
  }

  Future<void> fetchReceipts() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final snap = await dbRef("students")
          .orderByChild("status")
          .equalTo("pending")
          .get()
          .timeout(const Duration(seconds: 6));

      List<Map<String, dynamic>> temp = [];
      if (snap.exists && snap.value is Map) {
        (snap.value as Map).forEach((k, v) {
          if (v is Map) {
            Map<String, dynamic> s = Map<String, dynamic>.from(v);
            // Safety filter: the query can return extra (already approved) students,
            // so keep ONLY the ones whose status is really "pending".
            if (s['status']?.toString() != 'pending') return;
            String devId = k.toString();
            s['device_id'] = devId;
            temp.add(s);

            String? b64 = s['receipt']?.toString();
            if (b64 != null && b64.isNotEmpty && !_decodedImageCache.containsKey(devId)) {
              try {
                _decodedImageCache[devId] = base64Decode(b64);
              } catch (_) {}
            }
          }
        });
      }
      if (mounted) {
        setState(() {
          pendingStudents = temp;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> decideReceipt(String deviceId, String decision) async {
    try {
      await dbRef("students/$deviceId").update({"status": decision});
      _decodedImageCache.remove(deviceId);
      setState(() {
        pendingStudents.removeWhere((item) => item['device_id'] == deviceId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Status updated to $decision"), backgroundColor: decision == 'vip' ? Colors.green : Colors.orange),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("⚡ Pending VIP (${pendingStudents.length})"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.amber), onPressed: fetchReceipts),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("ምንም አዲስ ጥያቄ የለም!"),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: fetchReceipts,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh Again"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchReceipts,
                  child: ListView.builder(
                    itemCount: pendingStudents.length,
                    itemBuilder: (c, i) {
                      var s = pendingStudents[i];
                      String devId = s['device_id'].toString();
                      int id = int.tryParse(s['short_id']?.toString() ?? '0') ?? 0;
                      Uint8List? imgBytes = _decodedImageCache[devId];

                      return Card(
                        margin: const EdgeInsets.all(10),
                        color: cardBg(context),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(children: [
                            Text("👤 ስም: ${s['full_name']}", style: TextStyle(color: textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text("🆔 ID: $id   |   🔑 VIP Code: ${id * 3}", style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            if (imgBytes != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(imgBytes, height: 300, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true),
                                ),
                              ),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => decideReceipt(devId, 'rejected'), icon: const Icon(Icons.close, color: Colors.white), label: const Text("Decline", style: TextStyle(color: Colors.white))),
                              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => decideReceipt(devId, 'vip'), icon: const Icon(Icons.check, color: Colors.white), label: const Text("Approve VIP", style: TextStyle(color: Colors.white))),
                            ])
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List topUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLeaderboard();
  }

  Future<void> fetchLeaderboard() async {
    try {
      final snap = await dbRef("leaderboard").get();
      List temp = [];
      if (snap.exists) {
        (snap.value as Map).forEach((k, v) {
          temp.add(Map.from(v));
        });
        temp.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        if (temp.length > 10) temp = temp.sublist(0, 10);
      }
      if (mounted) setState(() {
        topUsers = temp;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Top 10 Leaderboard")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : topUsers.isEmpty
              ? const Center(child: Text("እስካሁን ምንም ውጤት አልተመዘገበም!"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: topUsers.length,
                  itemBuilder: (c, i) {
                    var user = topUsers[i];
                    return Card(
                      color: cardBg(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderCol(context))),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: i == 0 ? Colors.amber : i == 1 ? Colors.grey.shade400 : Colors.brown.shade300, child: Text("${i + 1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                        title: Text(user['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary(context))),
                        subtitle: Text("${user['subject']} • ${user['method']}", style: TextStyle(color: isDarkMode(context) ? Colors.greenAccent : Colors.green.shade700, fontSize: 12.5)),
                        trailing: Text("${user['score']} Pts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode(context) ? Colors.amber : const Color(0xFF5B4FE9))),
                      ),
                    );
                  },
                ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String examType;
  final String year;
  final String subject;
  const QuizScreen({Key? key, required this.examType, required this.year, required this.subject}) : super(key: key);
  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List questions = [];
  List userAnswers = [];
  int currentQuestionIndex = 0;
  int score = 0;
  bool showExplanation = false;
  int? selectedOptionIndex;
  bool isLoading = true;
  bool hasError = false;
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void fnStartTimer(int tq) {
    _remainingSeconds = tq * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        if (mounted) showCompletionDialog(isTimeUp: true);
      }
    });
  }

  void _extractFromParsed(dynamic parsed, String targetType, String targetYear, List targetList) {
    if (parsed is Map && parsed[targetType] != null && parsed[targetType][targetYear] != null) {
      var yearData = parsed[targetType][targetYear];
      if (yearData is Map) {
        if (yearData[widget.subject] != null) {
          targetList.addAll(List.from(yearData[widget.subject]));
        } else if (widget.subject == "Maths" && yearData["Mathematics"] != null) {
          targetList.addAll(List.from(yearData["Mathematics"]));
        } else if (widget.subject == "Mathematics" && yearData["Maths"] != null) {
          targetList.addAll(List.from(yearData["Maths"]));
        }
      }
    }
  }

  Future<void> loadQuestions() async {
    try {
      String targetType = (widget.examType == 'trainer' || widget.examType == 'quizzes') ? 'model_exams' : widget.examType;
      String targetYear = widget.year;
      List rawList = [];

      try {
        final jsonString = await rootBundle.loadString('assets/questions.json');
        final parsed = jsonDecode(jsonString);
        _extractFromParsed(parsed, targetType, targetYear, rawList);
      } catch (_) {}

      try {
        final json2019 = await rootBundle.loadString('assets/remedial_2019_model_exams.json');
        final parsed2019 = jsonDecode(json2019);
        _extractFromParsed(parsed2019, targetType, targetYear, rawList);
      } catch (_) {}

      try {
        String liveSub = widget.subject == "Maths" ? "Mathematics" : widget.subject;
        final snap = await dbRef("live_questions/$targetType/$targetYear/$liveSub").get().timeout(const Duration(seconds: 3));
        if (snap.exists && snap.value is Map) {
          (snap.value as Map).forEach((k, v) {
            if (v is Map) rawList.add(Map.from(v));
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          questions = rawList.where((q) => q != null && q is Map && q['question'] != null).toList();
          if (widget.examType == 'trainer' || widget.examType == 'quizzes') questions.shuffle();
          userAnswers = List.filled(questions.length, null);
          isLoading = false;
          if (questions.isNotEmpty) fnStartTimer(questions.length);
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _bookmarkCurrentQuestion() async {
    if (questions.isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String raw = prefs.getString('bookmarked_questions') ?? '[]';
    List saved = [];
    try {
      saved = jsonDecode(raw);
    } catch (_) {}

    var currentQ = questions[currentQuestionIndex];
    String qText = (currentQ['question'] ?? '').toString();
    bool exists = saved.any((item) => (item['question'] ?? '').toString() == qText);

    if (!exists) {
      saved.add({
        "subject": widget.subject,
        "question": qText,
        "options": parseOptions(currentQ),
        "correct_option_id": currentQ['correct_option_id'] ?? 0,
        "explanation": currentQ['explanation'] ?? 'ማብራሪያ የለውም።',
      });
      await prefs.setString('bookmarked_questions', jsonEncode(saved));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exists ? "⭐ ይህ ጥያቄ ቀድሞውኑ ተቀምጧል!" : "⭐ ጥያቄው Saved Questions ውስጥ ተቀምጧል!"),
          backgroundColor: Colors.amber.shade700,
        ),
      );
    }
  }

  void checkAnswer(int index) {
    if (showExplanation) return;
    setState(() {
      selectedOptionIndex = index;
      userAnswers[currentQuestionIndex] = index;
      showExplanation = true;
      int correctId = int.tryParse(questions[currentQuestionIndex]['correct_option_id']?.toString() ?? '0') ?? 0;
      if (index == correctId) score++;
    });
  }

  void nextQuestion() {
    setState(() {
      if (currentQuestionIndex < questions.length - 1) {
        currentQuestionIndex++;
        showExplanation = false;
        selectedOptionIndex = null;
      } else {
        _timer?.cancel();
        _saveAnalyticsAndProgress();
        _submitScoreToLeaderboard();
        showCompletionDialog(isTimeUp: false);
      }
    });
  }

  Future<void> _saveAnalyticsAndProgress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String raw = prefs.getString('subject_analytics') ?? '{}';
      Map stats = jsonDecode(raw);
      String sub = widget.subject == "Maths" ? "Mathematics" : widget.subject;
      Map prev = (stats[sub] is Map) ? Map.from(stats[sub]) : {"correct": 0, "total": 0};
      prev["correct"] = (prev["correct"] ?? 0) + score;
      prev["total"] = (prev["total"] ?? 0) + questions.length;
      stats[sub] = prev;
      await prefs.setString('subject_analytics', jsonEncode(stats));

      double pct = questions.isEmpty ? 0 : (score / questions.length);
      await StudyProgress.recordActivity(
        topicsDelta: 1,
        pointsDelta: (score * 5) + 20,
        highScore: pct >= 0.7,
      );
    } catch (_) {}
  }

  Future<void> _submitScoreToLeaderboard() async {
    if (score == 0) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? '';
      String name = prefs.getString('local_name') ?? 'Unknown';
      String recordId = "${deviceId}_${widget.subject}_${widget.year}";
      await dbRef("leaderboard/$recordId").set({"name": name, "score": score, "subject": widget.subject, "method": widget.examType.replaceAll('_', ' ').toUpperCase() + " (${widget.year})"});
    } catch (e) {}
  }

  void showCompletionDialog({required bool isTimeUp}) {
    double percentage = questions.isEmpty ? 0 : (score / questions.length);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg(context),
        title: Text(isTimeUp ? "⏰ ሰዓት አልቋል!" : "🎉 Quiz Completed!", style: TextStyle(color: textPrimary(context)), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(height: 100, width: 100, child: CircularProgressIndicator(value: percentage, color: percentage >= 0.5 ? Colors.green : Colors.red, backgroundColor: surfaceBg(context), strokeWidth: 10)),
              Text("${(percentage * 100).toInt()}%", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary(context))),
            ]),
            const SizedBox(height: 15),
            Text("ውጤትዎ: $score ከ ${questions.length}", style: const TextStyle(fontSize: 18, color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("💎 +${(score * 5) + 20} Points earned!", style: const TextStyle(fontSize: 13.5, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("ወደ ዋናው (Back)"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizReviewScreen(questions: questions, userAnswers: userAnswers, subject: widget.subject)));
            },
            child: const Text("መልስ አረጋግጥ (Review)", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  List parseOptions(dynamic qData) {
    if (qData is Map && qData['options'] != null) {
      var opts = qData['options'];
      if (opts is List) return opts.map((e) => e?.toString() ?? "").toList();
      else if (opts is Map) return opts.values.map((e) => e?.toString() ?? "").toList();
    }
    return ["Option A", "Option B", "Option C", "Option D"];
  }

  @override
  Widget build(BuildContext context) {
    bool dark = isDarkMode(context);
    if (isLoading) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: CircularProgressIndicator()));
    if (hasError || questions.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: Text("ጥያቄዎች አልተገኙም!")));

    var currentQ = questions[currentQuestionIndex];
    var options = parseOptions(currentQ);
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    String timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.subject} (${widget.year})", style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.star_border_rounded, color: Colors.amber), tooltip: "Bookmark Question", onPressed: _bookmarkCurrentQuestion),
          Center(child: Padding(padding: const EdgeInsets.only(right: 14), child: Text("⏱ $timeStr", style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: dark ? Colors.amberAccent : const Color(0xFF5B4FE9))))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Q: ${currentQuestionIndex + 1}/${questions.length}", style: TextStyle(color: textSecondary(context), fontWeight: FontWeight.bold)), Text("Score: $score", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (currentQuestionIndex + 1) / questions.length,
                minHeight: 6,
                backgroundColor: surfaceBg(context),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B4FE9)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol(context))),
              child: Text(currentQ['question']?.toString() ?? "", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary(context), height: 1.4)),
            ),
            const SizedBox(height: 16),
            ...List.generate(options.length, (i) {
              Color bCol = cardBg(context);
              Color txtCol = textPrimary(context);
              if (showExplanation) {
                int correctId = int.tryParse(currentQ['correct_option_id']?.toString() ?? '0') ?? 0;
                if (i == correctId) {
                  bCol = Colors.green.shade600;
                  txtCol = Colors.white;
                } else if (i == selectedOptionIndex) {
                  bCol = Colors.red.shade600;
                  txtCol = Colors.white;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bCol,
                    elevation: dark ? 0 : 1,
                    side: BorderSide(color: borderCol(context)),
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => checkAnswer(i),
                  child: Text("${String.fromCharCode(65 + i)}. ${options[i]}", style: TextStyle(color: txtCol, fontSize: 15)),
                ),
              );
            }),
            if (showExplanation) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: dark ? Colors.black38 : const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.5))),
                child: Text("💡 ${currentQ['explanation']?.toString() ?? 'ማብራሪያ የለውም።'}", style: TextStyle(color: dark ? Colors.amber : Colors.orange.shade900, fontSize: 14.5, height: 1.4)),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4FE9), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: nextQuestion,
                child: const Text("Next Question ➡️", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              )
            ],
          ],
        ),
      ),
    );
  }
}

class QuizReviewScreen extends StatelessWidget {
  final List questions;
  final List userAnswers;
  final String subject;
  const QuizReviewScreen({Key? key, required this.questions, required this.userAnswers, required this.subject}) : super(key: key);

  List parseOptions(dynamic qData) {
    if (qData is Map && qData['options'] != null) {
      var opts = qData['options'];
      if (opts is List) return opts.map((e) => e?.toString() ?? "").toList();
      else if (opts is Map) return opts.values.map((e) => e?.toString() ?? "").toList();
    }
    return ["A", "B", "C", "D"];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("📝 Review: $subject")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          var q = questions[index];
          var opts = parseOptions(q);
          int correctId = int.tryParse(q['correct_option_id']?.toString() ?? '0') ?? 0;
          int? userId = userAnswers[index];
          bool isCorrect = correctId == userId;
          return Card(
            color: cardBg(context),
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: borderCol(context))),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(isCorrect ? Icons.check_circle : (userId == null ? Icons.help : Icons.cancel), color: isCorrect ? Colors.green : (userId == null ? Colors.grey : Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Q${index + 1}: ${q['question']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: textPrimary(context)))),
                  ]),
                  Divider(color: borderCol(context)),
                  Text("✅ ትክክለኛው መልስ: ${opts.length > correctId ? opts[correctId] : 'Unknown'}", style: TextStyle(color: isDarkMode(context) ? Colors.greenAccent : Colors.green.shade700, fontWeight: FontWeight.w600)),
                  if (!isCorrect) Text("❌ የእርስዎ መልስ: ${userId != null && opts.length > userId ? opts[userId] : 'አልተመለሰም'}", style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Text("💡 ማብራሪያ: ${q['explanation'] ?? 'የለውም'}", style: TextStyle(color: isDarkMode(context) ? Colors.amber : Colors.orange.shade900, fontSize: 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class YearSelectionScreen extends StatelessWidget {
  final String examType;
  final String title;
  const YearSelectionScreen({Key? key, required this.examType, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    List<String> years = examType == 'model_exams' ? ['2019', '2018', '2017'] : ['2018', '2017', '2016', '2015'];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.9),
        itemCount: years.length,
        itemBuilder: (c, i) {
          bool isNew = years[i] == '2019';
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isNew ? const Color(0xFF5B4FE9) : Colors.indigo.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectSelectionScreen(examType: examType, year: years[i], title: "$title - ${years[i]}"))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("🗓 ${years[i]}", style: const TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.bold)),
                if (isNew) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                    child: const Text("NEW • 427 Qs", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

class SubjectSelectionScreen extends StatelessWidget {
  final String examType;
  final String year;
  final String title;
  const SubjectSelectionScreen({Key? key, required this.examType, required this.year, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.redAccent, Colors.purple, Colors.brown, Colors.teal];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2),
        itemCount: ALL_COURSES.length,
        itemBuilder: (c, i) => ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: colors[i % colors.length], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(examType: examType, year: year, subject: ALL_COURSES[i]))),
          child: Text(ALL_COURSES[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }
}
