import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

const String APP_VERSION = "1.1.0";
const int OWNER_ADMIN_ID = 5053;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBm6UEHXGE7NpcoNUq7BjE8wO7ItTVV8GU",
        appId: "1:612015829097:android:c9bd7bc7839e3ad0d3b2f8",
        messagingSenderId: "612015829097",
        projectId: "remedial-matrix",
        storageBucket: "remedial-matrix.firebasestorage.app",
      ),
    );
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (e) {
    debugPrint("Firebase error: $e");
  }
  runApp(const RemedialApp());
}

class RemedialApp extends StatelessWidget {
  const RemedialApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Remedial Matrix',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181B28),
          elevation: 0,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF181B28),
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: const AuthCheckScreen(),
    );
  }
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

  Future checkRegistration() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool localRegistered = prefs.getBool('local_registered') ?? false;
      String localStatus = prefs.getString('local_status') ?? 'free';
      String deviceId = prefs.getString('device_id') ?? '';

      if (localRegistered && deviceId.isNotEmpty) {
        try {
          final snapshot = await FirebaseDatabase.instance.ref("students/$deviceId/status").get().timeout(const Duration(seconds: 5));
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
          children: const [
            Icon(Icons.block, color: Colors.red, size: 80),
            SizedBox(height: 20),
            Text("አካውንትዎ ታግዷል!", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("እባክዎ አድሚንን ያነጋግሩ።", style: TextStyle(color: Colors.white70)),
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
  String selectedStream = 'Natural';
  bool isSaving = false;

  Future registerUser() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("እባክዎ ሙሉ ስምዎን ያስገቡ!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => isSaving = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int shortId = Random().nextInt(9000) + 1000;
      String deviceId = "DEV_${DateTime.now().millisecondsSinceEpoch}_$shortId";

      await prefs.setBool('local_registered', true);
      await prefs.setString('local_status', 'free');
      await prefs.setString('local_name', nameCtrl.text.trim());
      await prefs.setString('local_stream', selectedStream);
      await prefs.setInt('local_short_id', shortId);
      await prefs.setString('device_id', deviceId);

      try {
        DatabaseReference ref = FirebaseDatabase.instance.ref("students/$deviceId");
        await ref.set({
          "full_name": nameCtrl.text.trim(),
          "stream": selectedStream,
          "status": "free",
          "short_id": shortId,
          "registered_at": DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 6));
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainMenuScreen(initialStatus: 'free')), (route) => false);
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
            const SizedBox(height: 30),
            const CircleAvatar(radius: 45, backgroundColor: Colors.amber, child: Icon(Icons.school, size: 50, color: Colors.black)),
            const SizedBox(height: 20),
            const Text("እንኳን ወደ Remedial Matrix በሰላም መጡ! 🌟\nለመጀመር መረጃዎትን ይሙሉ", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "ሙሉ ስም (Full Name)",
                filled: true,
                fillColor: const Color(0xFF1A1E2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 20),
            const Text("የጥናት መስመር (Stream):", style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF1A1E2E), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: RadioListTile(activeColor: Colors.amber, title: const Text("Natural"), value: "Natural", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val.toString()))),
                  Expanded(child: RadioListTile(activeColor: Colors.amber, title: const Text("Social"), value: "Social", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val.toString()))),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving ? null : registerUser,
              child: isSaving ? const CircularProgressIndicator(color: Colors.black) : const Text("Get Started 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            )
          ],
        ),
      ),
    );
  }
}

// ዋናው የጥናት ፕሮግራም መረጃ (Default Schedule)
Map<String, Map<String, String>> getDefaultSchedule() {
  return {
    "Natural": {
      "Monday": "Mathematics (Chapter 1 & 2) + Practice",
      "Tuesday": "Physics (Mechanics & Vectors)",
      "Wednesday": "Chemistry (Atomic Structure & Bonding)",
      "Thursday": "Biology (Cell Biology & Genetics)",
      "Friday": "English (Grammar & Reading Comprehension)",
      "Saturday": "Model Exam Practice & Weekly Revision",
      "Sunday": "Rest & Weak Subject Review",
    },
    "Social": {
      "Monday": "Mathematics (Algebra & Functions)",
      "Tuesday": "History (Ethiopian & World History)",
      "Wednesday": "Geography (Climatology & Map Reading)",
      "Thursday": "English (Vocabulary & Grammar Rules)",
      "Friday": "General Revision & Short Notes",
      "Saturday": "Model Exam Practice & Quizzes",
      "Sunday": "Rest & Weak Subject Review",
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    appStatus = widget.initialStatus;
    _initSequence();
  }

  Future _initSequence() async {
    await _loadUserData();
    await _checkAppUpdate();
    await _checkTargetedBroadcast();
    await _checkDailyStudyNotification();
  }

  Future _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userShortId = prefs.getInt('local_short_id') ?? 0;
      userName = prefs.getString('local_name') ?? 'Student';
      userStream = prefs.getString('local_stream') ?? 'Natural';
    });
  }

  // 1. አዲስ Update ሲለቀቅ በቀጥታ በድሮው አፕ ላይ እንዲጭኑት የሚያደርግ
  Future _checkAppUpdate() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref("admin_settings/update").get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        String latestVersion = data['version'] ?? APP_VERSION;
        String updateUrl = data['url'] ?? 'https://t.me/ADDIS_REMEDIAL';

        if (latestVersion != APP_VERSION && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E2235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [Icon(Icons.system_update, color: Colors.greenAccent, size: 28), SizedBox(width: 10), Expanded(child: Text("አዲስ Update ተለቋል!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))]),
              content: Text(
                "የ Remedial Matrix አዲስ ቨርሽን ($latestVersion) ተለቋል!\n\n✅ የድሮውን አፕ ማጥፋት (Uninstall) አያስፈልግም!\n✅ አዲሱን አውርደው 'Update' ሲሉት የድሮውን በራሱ ተክቶት ይጫናል (የተመዘገቡበት ዳታ እና VIP አይጠፋም)።",
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  onPressed: () => launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.download, color: Colors.black),
                  label: const Text("አሁኑኑ Update አድርግ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {}
  }

  // 2. ለVIP ለብቻ፣ ለFree ለብቻ ወይም ለሁሉም የሚላክ ማስታወቂያ መፈተሻ
  Future _checkTargetedBroadcast() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isVIP = appStatus == 'vip';

      // check general, vip, and free channels
      List<String> channels = ['all', isVIP ? 'vip' : 'free'];

      for (String target in channels) {
        final snapshot = await FirebaseDatabase.instance.ref("announcements/$target").get();
        if (snapshot.exists) {
          Map data = snapshot.value as Map;
          int lastTime = prefs.getInt('last_broadcast_$target') ?? 0;
          int newTime = data['time'] ?? 0;

          if (newTime > lastTime && mounted) {
            String badge = target == 'vip' ? "👑 የVIP ተማሪዎች ልዩ ማስታወቂያ" : (target == 'free' ? "📢 ለነጻ ተማሪዎች የተላከ ማስታወቂያ" : "📢 አጠቃላይ ማስታወቂያ");
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E2235),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge, style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(data['title'] ?? "ማስታወቂያ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: Text(data['message'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () async {
                      await prefs.setInt('last_broadcast_$target', newTime);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text("አንብቤያለሁ (Close)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }
        }
      }
    } catch (e) {}
  }

  // 3. የዕለቱ የጥናት ፕሮግራም ማስታወሻ (Daily Study Reminder Popup)
  Future _checkDailyStudyNotification() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String todayKey = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      String lastShownDay = prefs.getString('last_study_prompt_day') ?? '';

      String dayName = getDayName(DateTime.now().weekday);
      String todayCourse = getDefaultSchedule()[userStream]?[dayName] ?? "General Revision";

      // አድሚኑ በFirebase ላይ የቀየረው ፕሮግራም ወይም የዕለቱ ልዩ ማሳሰቢያ ካለ ያነባል
      try {
        final snap = await FirebaseDatabase.instance.ref("admin_content/schedule/$userStream/$dayName").get().timeout(const Duration(seconds: 3));
        if (snap.exists && snap.value != null) {
          todayCourse = snap.value.toString();
        }
      } catch (_) {}

      if (lastShownDay != todayKey && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E2235),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.cyanAccent, width: 1.2)),
            title: Row(
              children: const [
                Icon(Icons.notifications_active, color: Colors.cyanAccent, size: 28),
                SizedBox(width: 10),
                Expanded(child: Text("📅 የዛሬው የጥናት ፕሮግራም", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ዕለት፦ ${getAmharicDay(dayName)}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: Text("📚 ኮርስ፦ $todayCourse", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 14),
                const Text("ዛሬ ይህንን ኮርስ በፕሮግራምዎ መሰረት አንብበዋል? ካላነበቡ አሁኑኑ ጥናትዎን ይጀምሩ!", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setString('last_study_prompt_day', todayKey);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("በኋላ አነባለሁ", style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700),
                onPressed: () async {
                  await prefs.setString('last_study_prompt_day', todayKey);
                  await prefs.setBool('completed_$todayKey', true);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("👏 በጣም ጎበዝ! የዛሬው የጥናት ፕሮግራም ተመዝግቧል!"), backgroundColor: Colors.green));
                  }
                },
                icon: const Icon(Icons.check_circle, color: Colors.black, size: 18),
                label: const Text("አዎ አንብቤያለሁ / ልጀምር", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {}
  }

  Future refreshStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('device_id') ?? '';
    String cachedStatus = prefs.getString('local_status') ?? 'free';
    try {
      final snapshot = await FirebaseDatabase.instance.ref("students/$deviceId/status").get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        String newStatus = snapshot.value.toString();
        if (cachedStatus == 'vip' && newStatus != 'blocked') {
          newStatus = 'vip';
        }
        await prefs.setString('local_status', newStatus);
        setState(() => appStatus = newStatus);
        if (newStatus == 'blocked' && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BlockedScreen()));
        }
      }
    } catch (e) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ስቴተስ: ${appStatus.toUpperCase()}"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isVIP = appStatus == 'vip';
    final List<Widget> pages = [
      HomeContent(
        isVIP: isVIP,
        appStatus: appStatus,
        userShortId: userShortId,
        userName: userName,
        userStream: userStream,
        refreshCallback: refreshStatus,
        onStatusChange: (s) => setState(() => appStatus = s),
      ),
      StudyScheduleScreen(userStream: userStream),
      ProfileContent(userName: userName, userShortId: userShortId, appStatus: appStatus, userStream: userStream),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber, width: 1.5)),
              child: const CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.school, color: Colors.indigo, size: 20)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('REMEDIAL MATRIX', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                Text('Smart Learning Platform', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.amber), tooltip: "Refresh Status", onPressed: refreshStatus),
          if (isVIP) const Padding(padding: EdgeInsets.only(right: 12.0), child: Center(child: Icon(Icons.verified, color: Colors.amber, size: 26)))
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final bool isVIP;
  final String appStatus;
  final int userShortId;
  final String userName;
  final String userStream;
  final VoidCallback refreshCallback;
  final Function(String) onStatusChange;

  const HomeContent({
    Key? key,
    required this.isVIP,
    required this.appStatus,
    required this.userShortId,
    required this.userName,
    required this.userStream,
    required this.refreshCallback,
    required this.onStatusChange,
  }) : super(key: key);

  // ላልተመዘገቡ (Free) ተማሪዎች የአመዘጋገብ ቅደም ተከተል (Registration Steps) የሚያሳይና የሚመራ Dialog
  void _showRegistrationStepsGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.amber, width: 1.5)),
        title: Row(
          children: const [
            Icon(Icons.stars_rounded, color: Colors.amber, size: 30),
            SizedBox(width: 8),
            Expanded(child: Text("VIP አባል የመሆኛ ቅደም ተከተል", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepTile("ደረጃ 1 (Step 1)", "ክፍያ መፈጸም", "ለዓመቱ ሙሉ 500 ብር ወይም ለግማሽ ሴሚስተር 300 ብር በ CBE (1000667301673) ወይም በ Telebirr / CBE Birr (0929698365 - MUBAREK MUSTEFA) ይክፈሉ።", Icons.account_balance_wallet, Colors.amber),
              const SizedBox(height: 12),
              _buildStepTile("ደረጃ 2 (Step 2)", "ደረሰኝ መላክ (Screenshot)", "ከታች ያለውን 'አሁኑኑ ተመዝገብ' የሚለውን ቁልፍ ተጭነው የከፈሉበትን ደረሰኝ ፎቶ (Screenshot) አያይዘው ይላኩ።", Icons.camera_alt_rounded, Colors.cyanAccent),
              const SizedBox(height: 12),
              _buildStepTile("ደረጃ 3 (Step 3)", "ወዲያውኑ VIP መሆን", "ክፍያዎ እንደታየ ወዲያውኑ ሁሉም ፈተናዎች፣ 퀴ዞች እና የቴሌግራም VIP ቲቶሪያል ክፍሎች ይከፈቱልዎታል!", Icons.verified_rounded, Colors.greenAccent),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ዝጋ", style: TextStyle(color: Colors.white60))),
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

  Widget _buildStepTile(String step, String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$step: $title", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
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
            backgroundColor: const Color(0xFF1E2235),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: const [Icon(Icons.workspace_premium, color: Colors.amber, size: 28), SizedBox(width: 8), Text("Premium Access", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appStatus == 'rejected')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text("❌ የላኩት ጥያቄ አልፀደቀም፤ እባክዎ ትክክለኛውን ደረሰኝ ይላኩ።", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  const Text(
                    "ሰላም premium ሆነው አመቱን ሙሉ ከኛ ጋር ለመማር 500 ብር ለ ግማሽ semester ደሞ 300 ብር ከታች ባሉት accounts ያስገቡና send screen shoot ይበሉት ክፍያው ታይቶ ወዲያም premium ትደረጋላቹ",
                    style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121521),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("🏦 CBE = 1000667301673", style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("📱 Telebirr = 0929698365", style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("📲 CBE birr = 0929698365", style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                        Divider(color: Colors.white24, height: 16),
                        Text("👤 Name: MUBAREK MUSTEFA", style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (appStatus == 'pending') ...[
                    const Center(child: Icon(Icons.hourglass_top, color: Colors.amber, size: 45)),
                    const SizedBox(height: 10),
                    const Text("⏳ ደረሰኝዎ እየታየ ነው! እባክዎ በትዕግስት ይጠብቁ።", style: TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
                  ] else ...[
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
                          if (image != null) {
                            setStateDialog(() {
                              selectedImage = File(image.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.image, color: Colors.amber),
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
                child: const Text("ዝጋ (Close)", style: TextStyle(color: Colors.white70)),
              ),
              if (appStatus != 'pending')
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
                            await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": "pending", "receipt": base64Image});
                            await prefs.setString('local_status', 'pending');
                            if (context.mounted) {
                              Navigator.pop(context);
                              onStatusChange('pending');
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
    TextEditingController pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text("🔐 Activation & Admin", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("የእርስዎ መለያ (ID): $userShortId", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: pwdCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "የመክፈቻ ቁጥር ወይም Admin Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              String input = pwdCtrl.text.trim();
              int expectedVipCode = userShortId * 3;
              bool isOwnerDevice = (userShortId == OWNER_ADMIN_ID) || (userName.toLowerCase().trim() == "mubarek mustefa");

              if (input == "Matrix@2026") {
                if (isOwnerDevice) {
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
                  await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": "vip"});
                } catch (e) {}
                onStatusChange('vip');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ አፑ በተሳካ ሁኔታ VIP ተደርጓል!"), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ ትክክል ያልሆነ መክፈቻ ኮድ!"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Enter", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String todayDay = getDayName(DateTime.now().weekday);
    String todaySubject = getDefaultSchedule()[userStream]?[todayDay] ?? "General Study";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ዋናው ባነር (Hero Banner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B2667), Color(0xFFBC78EC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                      child: Text("👋 ሰላም፣ $userName", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text(isVIP ? "👑 VIP MEMBER" : "FREE PLAN", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Remedial Matrix", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("📚 የዛሬ ጥናት (${getAmharicDay(todayDay)})፦\n👉 $todaySubject", style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ላልተመዘገቡ (Free) ተማሪዎች ብቻ የሚታይ የRegistration Step መምሪያ ቁልፍ (VIP ሲሆኑ ይጠፋል!)
          if (!isVIP)
            InkWell(
              onTap: () => _showRegistrationStepsGuide(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orange.shade900]),
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black26,
                      child: Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("🌟 አንድ ላይ ለመመዝገብ (VIP Registration)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15.5)),
                          SizedBox(height: 4),
                          Text("እንዴት VIP መሆን እንደሚችሉ የአመዘጋገብ ቅደም ተከተሉን (Steps) ለማየት እዚህ ይጫኑ!", style: TextStyle(color: Colors.black87, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 18),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
          const Text("✨ Main Learning Modules", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildGridItem(context, "📅 የጥናት ፕሮግራም", "Daily Schedule", Icons.calendar_month_rounded, Colors.cyanAccent, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScheduleScreen(userStream: userStream)))),
              _buildGridItem(context, "🆕 Model Exams", "2017 & 2018", Icons.library_books_rounded, Colors.blueAccent, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'model_exams', title: 'Model Exams')))),
              _buildGridItem(context, "📖 Remedial Exams", "Past Papers", Icons.school_rounded, Colors.tealAccent, !isVIP, () {
                if (!isVIP) _showPremiumDialog(context);
                else Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'remedial_exams', title: 'Remedial Exams')));
              }),
              _buildGridItem(context, "🧠 Exam Trainer", "Smart Practice", Icons.psychology_rounded, Colors.purpleAccent, !isVIP, () {
                if (!isVIP) _showPremiumDialog(context);
                else Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'trainer', year: '2018', title: 'Exam Trainer')));
              }),
              _buildGridItem(context, "📝 Quizzes", "Fast Tests", Icons.quiz_rounded, Colors.orangeAccent, !isVIP, () {
                if (!isVIP) _showPremiumDialog(context);
                else Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'quizzes', year: '2018', title: 'Quizzes')));
              }),
              _buildGridItem(context, "📚 Notes & Videos", "Free Samples", Icons.play_lesson_rounded, Colors.redAccent, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SampleMaterialsScreen()))),
              _buildGridItem(context, "🏆 Leaderboard", "Top 10 Students", Icons.emoji_events_rounded, Colors.amber, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
              _buildGridItem(context, "💡 Study Tips", "Smart Advice", Icons.lightbulb_rounded, Colors.pinkAccent, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyTipsScreen()))),
            ],
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent.shade700,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              if (!isVIP) {
                _showPremiumDialog(context);
              } else {
                await launchUrl(Uri.parse('https://t.me/+yQdJM7LxN8VmNWY0'), mode: LaunchMode.externalApplication);
              }
            },
            icon: Icon(isVIP ? Icons.ondemand_video : Icons.lock, color: Colors.white),
            label: const Text("Go to VIP Tutorial Class", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => launchUrl(Uri.parse('https://t.me/Rmedial_matrix_support'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text("Support", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    side: const BorderSide(color: Colors.greenAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showActivationLogin(context),
                  icon: const Icon(Icons.vpn_key, size: 18),
                  label: const Text("Code / Admin", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, String subtitle, IconData icon, Color color, bool isLocked, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF181B28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(icon, size: 30, color: color),
                ),
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: Colors.amber, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// 📅 የጥናት ፕሮግራም ገጽ (Study Schedule Screen)
class StudyScheduleScreen extends StatefulWidget {
  final String userStream;
  const StudyScheduleScreen({Key? key, required this.userStream}) : super(key: key);
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

  Future _loadSchedule() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> defaultMap = Map.from(getDefaultSchedule()[selectedStream] ?? {});

    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/schedule/$selectedStream").get().timeout(const Duration(seconds: 4));
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

  Future _toggleDayRead(String day) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool current = completedDays[day] ?? false;
    await prefs.setBool('study_done_${selectedStream}_$day', !current);
    setState(() {
      completedDays[day] = !current;
    });
    if (!current && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ የ${getAmharicDay(day)} ኮርስ ማንበብዎ ተመዝግቧል!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    String todayName = getDayName(DateTime.now().weekday);

    return Scaffold(
      appBar: AppBar(
        title: const Text("📅 ሳምንታዊ የጥናት ፕሮግራም"),
        actions: [
          DropdownButton<String>(
            value: selectedStream,
            dropdownColor: const Color(0xFF1E2235),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
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
          const SizedBox(width: 12),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: daysOrder.length,
              itemBuilder: (context, index) {
                String day = daysOrder[index];
                String course = scheduleData[day] ?? "Revision";
                bool isToday = day == todayName;
                bool isDone = completedDays[day] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF232B45) : const Color(0xFF181B28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isToday ? Colors.amber : Colors.white12, width: isToday ? 2 : 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isDone ? Colors.green : (isToday ? Colors.amber : Colors.blueGrey.shade800),
                      child: Icon(isDone ? Icons.check : Icons.menu_book_rounded, color: isDone || isToday ? Colors.black : Colors.white),
                    ),
                    title: Row(
                      children: [
                        Text(getAmharicDay(day), style: TextStyle(color: isToday ? Colors.amber : Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                            child: const Text("ዛሬ (Today)", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text("📚 $course", style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDone ? Colors.green.shade700 : Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () => _toggleDayRead(day),
                      child: Text(isDone ? "አንብቤያለሁ ✅" : "አላነበብኩም", style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ProfileContent extends StatelessWidget {
  final String userName;
  final int userShortId;
  final String appStatus;
  final String userStream;
  const ProfileContent({Key? key, required this.userName, required this.userShortId, required this.appStatus, required this.userStream}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    bool isVip = appStatus == 'vip';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: isVip ? Colors.amber : Colors.blueGrey,
              child: Icon(isVip ? Icons.workspace_premium : Icons.person, size: 55, color: Colors.black),
            ),
            const SizedBox(height: 20),
            Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text("Stream: $userStream Science", style: const TextStyle(fontSize: 14, color: Colors.cyanAccent)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF181B28), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withOpacity(0.5))),
              child: Text("Student ID: $userShortId", style: const TextStyle(fontSize: 18, color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            const SizedBox(height: 12),
            Text("Account Status: ${appStatus.toUpperCase()}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isVip ? Colors.amber : Colors.white70)),
            const SizedBox(height: 8),
            const Text("App Version: $APP_VERSION", style: TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
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

  Future fetchTips() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/study_tips").get();
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
              ? const Center(child: Text("እስካሁን ምንም ጥቆማ አልተለቀቀም!"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tips.length,
                  itemBuilder: (c, i) => Card(
                    color: const Color(0xFF181B28),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb, color: Colors.amber, size: 30),
                      title: Text(tips[i]['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(tips[i]['content'] ?? '', style: const TextStyle(color: Colors.white70, height: 1.4)),
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

  Future fetchMaterials() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/sample_materials").get();
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
              ? const Center(child: Text("እስካሁን ምንም የናሙና ትምህርት አልተለቀቀም!"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: materials.length,
                  itemBuilder: (c, i) {
                    var m = materials[i];
                    bool isVideo = m['type'] == 'video';
                    return Card(
                      color: const Color(0xFF181B28),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Icon(isVideo ? Icons.play_circle_fill : Icons.picture_as_pdf, color: isVideo ? Colors.redAccent : Colors.lightBlueAccent, size: 40),
                        title: Text(m['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text("ይክፈቱ (Tap to open)", style: TextStyle(color: Colors.white54)),
                        trailing: const Icon(Icons.open_in_new, color: Colors.amber),
                        onTap: () => launchUrl(Uri.parse(m['url'] ?? ''), mode: LaunchMode.externalApplication),
                      ),
                    );
                  },
                ),
    );
  }
}

// 🛠 ADMIN DASHBOARD
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🛠 Admin Control Center")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReceiptsScreen())),
              icon: const Icon(Icons.receipt_long, color: Colors.black),
              label: const Text("📥 አዲስ ደረሰኞችን አረጋግጥ (Receipts)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStudentListScreen())),
              icon: const Icon(Icons.group, color: Colors.white),
              label: const Text("👥 የተመዘገቡ ተማሪዎች (Filter/Ban/VIP)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScheduleManagerScreen())),
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              label: const Text("📅 የጥናት ፕሮግራም እና የዕለቱ ማሳሰቢያ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.orange.shade800, minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
              icon: const Icon(Icons.campaign, color: Colors.white),
              label: const Text("📢 ማስታወቂያ ላክ (ለVIP / ለFree / ለሁሉም)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminContentScreen())),
              icon: const Icon(Icons.edit_document, color: Colors.white),
              label: const Text("✍️ ኮንቴንት ጨምር (Tips & Materials)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.purpleAccent, minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUpdateAppScreen())),
              icon: const Icon(Icons.system_update, color: Colors.white),
              label: const Text("🚀 አዲስ አፕሊኬሽን (Update) ልቀቅ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// 📅 አድሚኑ የጥናት ፕሮግራሙን የሚቀይርበት እና "ዛሬ ይሄን ኮርስ አንብበዋል?" ብሎ Notification የሚልክበት ገጽ
class AdminScheduleManagerScreen extends StatefulWidget {
  const AdminScheduleManagerScreen({Key? key}) : super(key: key);
  @override
  _AdminScheduleManagerScreenState createState() => _AdminScheduleManagerScreenState();
}

class _AdminScheduleManagerScreenState extends State<AdminScheduleManagerScreen> {
  String selectedStream = "Natural";
  String selectedDay = getDayName(DateTime.now().weekday);
  final TextEditingController courseCtrl = TextEditingController();
  bool isSaving = false;

  final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  @override
  void initState() {
    super.initState();
    courseCtrl.text = getDefaultSchedule()[selectedStream]?[selectedDay] ?? "";
  }

  Future saveAndNotifySchedule({required bool sendPushAlert}) async {
    if (courseCtrl.text.trim().isEmpty) return;
    setState(() => isSaving = true);
    try {
      String courseText = courseCtrl.text.trim();
      await FirebaseDatabase.instance.ref("admin_content/schedule/$selectedStream/$selectedDay").set(courseText);

      if (sendPushAlert) {
        await FirebaseDatabase.instance.ref("announcements/all").set({
          "title": "📅 የዛሬ የጥናት ማሳሰቢያ (${getAmharicDay(selectedDay)})",
          "message": "ውድ የ $selectedStream ተማሪዎች፣ የዛሬው የጥናት ፕሮግራም 【 $courseText 】 ነው! ዛሬ ይህንን ኮርስ አንብበዋል? ካላነበቡ አሁኑኑ ይጀምሩ!",
          "time": DateTime.now().millisecondsSinceEpoch,
        });
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
    return Scaffold(
      appBar: AppBar(title: const Text("📅 የጥናት ፕሮግራም ማስተካከያ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("የጥናት መስመር (Stream) እና ቀን ይምረጡ፦", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStream,
                    dropdownColor: const Color(0xFF1E2235),
                    decoration: const InputDecoration(labelText: "Stream", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "Natural", child: Text("Natural")),
                      DropdownMenuItem(value: "Social", child: Text("Social")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedStream = val;
                          courseCtrl.text = getDefaultSchedule()[selectedStream]?[selectedDay] ?? "";
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedDay,
                    dropdownColor: const Color(0xFF1E2235),
                    decoration: const InputDecoration(labelText: "Day", border: OutlineInputBorder()),
                    items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedDay = val;
                          courseCtrl.text = getDefaultSchedule()[selectedStream]?[selectedDay] ?? "";
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: courseCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "የሚጠናው ኮርስ (ምሳሌ: Physics Chapter 1 & 2)",
                border: OutlineInputBorder(),
              ),
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

// 📢 ለVIP ለብቻ፣ ለFree ለብቻ ወይም ለሁሉም ማስታወቂያ መላኪያ ገጽ
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({Key? key}) : super(key: key);
  @override
  _AdminBroadcastScreenState createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController msgCtrl = TextEditingController();
  String targetAudience = 'all'; // 'all', 'vip', 'free'
  bool isSending = false;

  Future sendBroadcast() async {
    if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
    setState(() => isSending = true);
    try {
      await FirebaseDatabase.instance.ref("announcements/$targetAudience").set({
        "title": titleCtrl.text.trim(),
        "message": msgCtrl.text.trim(),
        "target": targetAudience,
        "time": DateTime.now().millisecondsSinceEpoch,
      });
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
            const Text("ማስታወቂያው ለማን ይድረስ?", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: targetAudience,
              dropdownColor: const Color(0xFF1E2235),
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
            TextField(controller: msgCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "መልዕክት (Message)", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 52)),
              onPressed: isSending ? null : sendBroadcast,
              icon: const Icon(Icons.send, color: Colors.white),
              label: isSending ? const CircularProgressIndicator(color: Colors.white) : const Text("ማስታወቂያውን ላክ (Send Broadcast)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
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
                await FirebaseDatabase.instance.ref("admin_content/study_tips").push().set({"title": titleCtrl.text, "content": contentCtrl.text, "time": DateTime.now().millisecondsSinceEpoch});
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
            DropdownButton(
              value: mType,
              dropdownColor: Colors.black,
              items: const [DropdownMenuItem(value: 'video', child: Text("🎥 Video")), DropdownMenuItem(value: 'pdf', child: Text("📄 PDF / Note"))],
              onChanged: (val) => setStateDialog(() => mType = val.toString()),
            )
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                  await FirebaseDatabase.instance.ref("admin_content/sample_materials").push().set({"title": titleCtrl.text, "url": urlCtrl.text, "type": mType, "time": DateTime.now().millisecondsSinceEpoch});
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
    TextEditingController verCtrl = TextEditingController();
    TextEditingController urlCtrl = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("🚀 አዲስ Update ልቀቅ")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          const Text("አዲሱን APK ወደ ቴሌግራም ስትለቅ እዚህ ቨርሽኑን ቀይር። ተማሪዎች አዲሱን ሲጭኑ የድሮውን አፕ ሳያጠፉ በራሱ ላይ ይተካዋል!", style: TextStyle(color: Colors.amber)),
          const SizedBox(height: 20),
          TextField(controller: verCtrl, decoration: const InputDecoration(labelText: "አዲሱ ቨርሽን (ምሳሌ: 1.1.0)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "የማውረጃ ሊንክ (የቴሌግራም ፖስት ሊንክ)", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(double.infinity, 50)),
            onPressed: () async {
              if (verCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                await FirebaseDatabase.instance.ref("admin_settings/update").set({"version": verCtrl.text.trim(), "url": urlCtrl.text.trim()});
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Update ፖስት ተደርጓል!")));
                }
              }
            },
            child: const Text("ለተማሪዎች አሳውቅ (Push Update)", style: TextStyle(color: Colors.white)),
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

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future fetchStudents() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("students").get();
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
    if (currentFilter == 'All') displayedStudents = List.from(allStudents);
    else displayedStudents = allStudents.where((s) => s['status'].toString().toLowerCase() == currentFilter.toLowerCase()).toList();
  }

  Future updateStudentStatus(String deviceId, String newStatus) async {
    try {
      await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": newStatus});
      fetchStudents();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ስቴተስ ወደ $newStatus ተቀይሯል!")));
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ተማሪዎች"), actions: [
        PopupMenuButton(
          icon: const Icon(Icons.filter_list),
          onSelected: (val) {
            setState(() {
              currentFilter = val.toString();
              _applyFilter();
            });
          },
          itemBuilder: (context) => ['All', 'VIP', 'Pending', 'Free', 'Blocked'].map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
        )
      ]),
      body: isLoading
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
                    return Card(
                      color: const Color(0xFF181B28),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: isBlocked ? Colors.red : (isVip ? Colors.amber : Colors.blueGrey), child: Icon(isBlocked ? Icons.block : Icons.person, color: Colors.black)),
                        title: Text(s['full_name'] ?? 'Unknown', style: TextStyle(color: isBlocked ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("ID: ${s['short_id']} | Code: ${(s['short_id'] ?? 0) * 3}\nStatus: ${s['status']}", style: const TextStyle(color: Colors.white70)),
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
    );
  }
}

class AdminReceiptsScreen extends StatefulWidget {
  const AdminReceiptsScreen({Key? key}) : super(key: key);
  @override
  _AdminReceiptsScreenState createState() => _AdminReceiptsScreenState();
}

class _AdminReceiptsScreenState extends State<AdminReceiptsScreen> {
  List pendingStudents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReceipts();
  }

  Future fetchReceipts() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("students").get();
      List temp = [];
      if (snap.exists) {
        (snap.value as Map).forEach((k, v) {
          if (v['status'] == 'pending') {
            Map s = Map.from(v);
            s['device_id'] = k;
            temp.add(s);
          }
        });
      }
      if (mounted) setState(() {
        pendingStudents = temp;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future decideReceipt(String deviceId, String decision) async {
    try {
      await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": decision});
      fetchReceipts();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📥 Pending VIP Requests")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingStudents.isEmpty
              ? const Center(child: Text("ምንም አዲስ ጥያቄ የለም!"))
              : ListView.builder(
                  itemCount: pendingStudents.length,
                  itemBuilder: (c, i) {
                    var s = pendingStudents[i];
                    int id = s['short_id'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.all(10),
                      color: const Color(0xFF181B28),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(children: [
                          Text("👤 ስም: ${s['full_name']}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text("🆔 ID: $id   |   🔑 VIP Code: ${id * 3}", style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (s['receipt'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(s['receipt']), height: 300, width: double.infinity, fit: BoxFit.cover)),
                            ),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => decideReceipt(s['device_id'], 'rejected'), icon: const Icon(Icons.close, color: Colors.white), label: const Text("Decline", style: TextStyle(color: Colors.white))),
                            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => decideReceipt(s['device_id'], 'vip'), icon: const Icon(Icons.check, color: Colors.white), label: const Text("Approve VIP", style: TextStyle(color: Colors.white))),
                          ])
                        ]),
                      ),
                    );
                  },
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

  Future fetchLeaderboard() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("leaderboard").get();
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
                      color: const Color(0xFF181B28),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: i == 0 ? Colors.amber : i == 1 ? Colors.grey.shade400 : Colors.brown.shade300, child: Text("${i + 1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                        title: Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                        subtitle: Text("${user['subject']} • ${user['method']}", style: const TextStyle(color: Colors.greenAccent)),
                        trailing: Text("${user['score']} Pts", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.amber)),
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
    loadLocalQuestions();
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

  Future loadLocalQuestions() async {
    try {
      final jsonString = await rootBundle.loadString('assets/questions.json');
      final parsed = jsonDecode(jsonString);
      if (mounted) {
        setState(() {
          String targetType = (widget.examType == 'trainer' || widget.examType == 'quizzes') ? 'model_exams' : widget.examType;
          String targetYear = (widget.examType == 'trainer' || widget.examType == 'quizzes') ? '2018' : widget.year;
          List rawList = [];
          if (parsed is Map && parsed[targetType] != null && parsed[targetType][targetYear] != null) {
            var yearData = parsed[targetType][targetYear];
            if (yearData[widget.subject] != null) rawList = List.from(yearData[widget.subject]);
            else if (widget.subject == "Maths" && yearData["Mathematics"] != null) rawList = List.from(yearData["Mathematics"]);
            else if (widget.subject == "Mathematics" && yearData["Maths"] != null) rawList = List.from(yearData["Maths"]);
          }
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
        _submitScoreToLeaderboard();
        showCompletionDialog(isTimeUp: false);
      }
    });
  }

  Future _submitScoreToLeaderboard() async {
    if (score == 0) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? '';
      String name = prefs.getString('local_name') ?? 'Unknown';
      String recordId = "${deviceId}_${widget.subject}_${widget.year}";
      await FirebaseDatabase.instance.ref("leaderboard/$recordId").set({"name": name, "score": score, "subject": widget.subject, "method": widget.examType.replaceAll('_', ' ').toUpperCase() + " (${widget.year})"});
    } catch (e) {}
  }

  void showCompletionDialog({required bool isTimeUp}) {
    double percentage = questions.isEmpty ? 0 : (score / questions.length);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: Text(isTimeUp ? "⏰ ሰዓት አልቋል!" : "🎉 Quiz Completed!", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(height: 100, width: 100, child: CircularProgressIndicator(value: percentage, color: percentage >= 0.5 ? Colors.green : Colors.red, backgroundColor: Colors.grey.shade800, strokeWidth: 10)),
              Text("${(percentage * 100).toInt()}%", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 15),
            Text("ውጤትዎ: $score ከ ${questions.length}", style: const TextStyle(fontSize: 18, color: Colors.amber)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
    if (isLoading) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: CircularProgressIndicator()));
    if (hasError || questions.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: Text("ጥያቄዎች አልተገኙም!")));

    var currentQ = questions[currentQuestionIndex];
    var options = parseOptions(currentQ);
    int m = _remainingSeconds ~/ 60;
    int s = _remainingSeconds % 60;
    String timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject, style: const TextStyle(fontSize: 16)), actions: [Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text("⏱ $timeStr", style: const TextStyle(fontSize: 16, color: Colors.amberAccent))))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Q: ${currentQuestionIndex + 1}/${questions.length}", style: const TextStyle(color: Colors.white70)), Text("Score: $score", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent))]),
            const SizedBox(height: 15),
            Text(currentQ['question']?.toString() ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...List.generate(options.length, (i) {
              Color bCol = const Color(0xFF1E2235);
              if (showExplanation) {
                int correctId = int.tryParse(currentQ['correct_option_id']?.toString() ?? '0') ?? 0;
                if (i == correctId) bCol = Colors.green.shade700;
                else if (i == selectedOptionIndex) bCol = Colors.red.shade700;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: bCol, padding: const EdgeInsets.all(16), alignment: Alignment.centerLeft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => checkAnswer(i),
                  child: Text("${String.fromCharCode(65 + i)}. ${options[i]}", style: const TextStyle(color: Colors.white)),
                ),
              );
            }),
            if (showExplanation) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)), child: Text("💡 ${currentQ['explanation']?.toString() ?? 'ማብራሪያ የለውም።'}", style: const TextStyle(color: Colors.amber, fontSize: 15))),
              const SizedBox(height: 20),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: nextQuestion, child: const Text("Next Question ➡️", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))
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
            color: const Color(0xFF181B28),
            margin: const EdgeInsets.only(bottom: 15),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(isCorrect ? Icons.check_circle : (userId == null ? Icons.help : Icons.cancel), color: isCorrect ? Colors.green : (userId == null ? Colors.grey : Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Q${index + 1}: ${q['question']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ]),
                  const Divider(color: Colors.white24),
                  Text("✅ ትክክለኛው መልስ: ${opts.length > correctId ? opts[correctId] : 'Unknown'}", style: const TextStyle(color: Colors.greenAccent)),
                  if (!isCorrect) Text("❌ የእርስዎ መልስ: ${userId != null && opts.length > userId ? opts[userId] : 'አልተመለሰም'}", style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Text("💡 ማብራሪያ: ${q['explanation'] ?? 'የለውም'}", style: const TextStyle(color: Colors.amber, fontSize: 13)),
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
    List<String> years = examType == 'model_exams' ? ['2017', '2018'] : ['2015', '2016', '2017', '2018'];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0),
        itemCount: years.length,
        itemBuilder: (c, i) => ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectSelectionScreen(examType: examType, year: years[i], title: "$title - ${years[i]}"))),
          child: Text("🗓 ${years[i]}", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
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
    final subs = ["Biology", "Chemistry", "Physics", "Maths", "Mathematics", "English", "History", "Geography"];
    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.red, Colors.amber.shade700, Colors.purple, Colors.brown, Colors.teal];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.4),
        itemCount: subs.length,
        itemBuilder: (c, i) => ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: colors[i % colors.length], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(examType: examType, year: year, subject: subs[i]))),
          child: Text(subs[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }
}
