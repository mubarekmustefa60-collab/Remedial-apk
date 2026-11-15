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

const String APP_VERSION = "1.0.0";

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
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F), elevation: 0),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1F1F1F),
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.white54,
        )
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
            localStatus = snapshot.value.toString();
            await prefs.setString('local_status', localStatus);
          }
        } catch (_) {
          debugPrint("Offline mode - using cached VIP status.");
        }
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

      DatabaseReference ref = FirebaseDatabase.instance.ref("students/$deviceId");
      await ref.set({
        "full_name": nameCtrl.text.trim(),
        "stream": selectedStream,
        "status": "free",
        "short_id": shortId,
        "registered_at": DateTime.now().toIso8601String(),
      });

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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("እንኳን ደህና መጡ! 🌟\nእባክዎ ለመጀመር መረጃዎትን ይሙሉ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "ሙሉ ስም (Full Name)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 20),
            const Text("የጥናት መስመር (Stream):", style: TextStyle(fontSize: 16, color: Colors.white70)),
            Row(
              children: [
                Expanded(child: RadioListTile(title: const Text("Natural"), value: "Natural", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val.toString()))),
                Expanded(child: RadioListTile(title: const Text("Social"), value: "Social", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val.toString()))),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: isSaving ? null : registerUser,
              child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Get Started 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    appStatus = widget.initialStatus;
    _loadUserData();
    _checkAppUpdate(); 
    _checkBroadcast(); 
  }

  Future _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() { 
      userShortId = prefs.getInt('local_short_id') ?? 0; 
      userName = prefs.getString('local_name') ?? 'Student';
    });
  }

  Future _checkAppUpdate() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref("admin_settings/update").get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        String latestVersion = data['version'] ?? APP_VERSION;
        String updateUrl = data['url'] ?? 'https://t.me/ADDIS_REMEDIAL';

        if (latestVersion != APP_VERSION) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF2C2C2C),
                title: const Row(children: [Icon(Icons.system_update, color: Colors.greenAccent), SizedBox(width:10), Text("አዲስ Update አለ!", style: TextStyle(color: Colors.white))]),
                content: Text("የአፕሊኬሽኑ አዲስ ቨርሽን ($latestVersion) ተለቋል። እባክዎ አዲሱን አፕሊኬሽን በማውረድ ይጫኑት (የድሮው ዴታዎ አይጠፋም)።", style: const TextStyle(color: Colors.white70)),
                actions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () => launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text("Update Now (አውርድ)", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }
        }
      }
    } catch (e) {}
  }

  Future _checkBroadcast() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref("announcement").get();
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        int lastTime = prefs.getInt('last_broadcast_time') ?? 0;
        int newTime = data['time'] ?? 0;
        if (newTime > lastTime) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF2C2C2C),
                title: Text(data['title'] ?? "📢 ማስታወቂያ", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                content: Text(data['message'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 16)),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await prefs.setInt('last_broadcast_time', newTime);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text("አንብቤያለሁ (Close)"),
                  )
                ],
              ),
            );
          }
        }
      }
    } catch (e) {}
  }

  Future refreshStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('device_id') ?? '';
    try {
      final snapshot = await FirebaseDatabase.instance.ref("students/$deviceId/status").get().timeout(const Duration(seconds: 5));
      if (snapshot.exists) {
        String newStatus = snapshot.value.toString();
        await prefs.setString('local_status', newStatus);
        setState(() => appStatus = newStatus);
        if(newStatus == 'blocked' && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BlockedScreen()));
        }
      }
    } catch (e) {}
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ስቴተስ: ${appStatus.toUpperCase()}"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    bool isVIP = appStatus == 'vip';
    final List<Widget> pages = [
      HomeContent(isVIP: isVIP, appStatus: appStatus, userShortId: userShortId, refreshCallback: refreshStatus, onStatusChange: (s) => setState(() => appStatus = s)),
      ProfileContent(userName: userName, userShortId: userShortId, appStatus: appStatus),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.school, color: Colors.blue, size: 20)),
            SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('REMEDIAL MATRIX', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('Educational Platform', style: TextStyle(fontSize: 12, color: Colors.greenAccent))]),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.amber), tooltip: "Refresh", onPressed: refreshStatus),
          if (isVIP) const Padding(padding: EdgeInsets.only(right: 12.0), child: Center(child: Icon(Icons.verified, color: Colors.amber, size: 26)))
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final bool isVIP;
  final String appStatus;
  final int userShortId;
  final VoidCallback refreshCallback;
  final Function(String) onStatusChange;

  const HomeContent({Key? key, required this.isVIP, required this.appStatus, required this.userShortId, required this.refreshCallback, required this.onStatusChange}) : super(key: key);

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
            backgroundColor: const Color(0xFF2C2C2C),
            title: Row(children: const [Icon(Icons.lock, color: Colors.amber), SizedBox(width: 10), Text("Premium Access", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appStatus == 'pending') ...[
                    const Center(child: Icon(Icons.hourglass_top, color: Colors.blueAccent, size: 50)),
                    const SizedBox(height: 15),
                    const Text("⏳ ክፍያዎ እየታየ ነው! እባክዎ በትዕግስት ይጠብቁ።", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                  ] 
                  else ...[
                    if (appStatus == 'rejected')
                      const Padding(padding: EdgeInsets.only(bottom: 10), child: Text("❌ የላኩት ደረሰኝ አልፀደቀም፤ እባክዎ እንደገና ይሞክሩ።", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                    const Text("1️⃣ CBE: 1000667301673 | TELEBIRR: 0929698365 (Mubarek Mustefa) - 300 ብር ይክፈሉ።", style: TextStyle(color: Colors.amber, fontSize: 13)),
                    const SizedBox(height: 10),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
                          if (image != null) { setStateDialog(() { selectedImage = File(image.path); }); }
                        },
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: Text(selectedImage == null ? "ደረሰኝ ምረጥ (Attach)" : "✅ ፎቶ ተመርጧል", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    if (selectedImage != null)
                       Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(selectedImage!, height: 100, width: double.infinity, fit: BoxFit.cover))),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(appStatus == 'pending' ? "ዝጋ" : "Cancel")),
              if (appStatus != 'pending')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
                  onPressed: isDialogLoading ? null : () async {
                    if (selectedImage == null) return;
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ ደረሰኝዎ ተልኳል!")));
                      }
                    } catch (e) { setStateDialog(() => isDialogLoading = false); }
                  },
                  child: isDialogLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Send Receipt", style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        }
      ),
    );
  }

  void _showActivationLogin(BuildContext context) {
    TextEditingController pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
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
            onPressed: () async {
              int expectedVipCode = userShortId * 3;
              if (pwdCtrl.text == "Matrix@2026") {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
              } else if (pwdCtrl.text == expectedVipCode.toString()) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String deviceId = prefs.getString('device_id') ?? '';
                await prefs.setString('local_status', 'vip');
                try { await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": "vip"}); } catch(e) {}
                onStatusChange('vip');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ አፑ በအောင်မြင်ነት VIP ተደርጓል!"), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ ትክክል ያልሆነ መክፈቻ ኮድ!"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Enter"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              height: 150, width: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Stack(
                children: [
                  const Positioned(right: -20, bottom: -20, child: Icon(Icons.menu_book, size: 120, color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text("Remedial Matrix", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text("የስኬትዎ መንገድ - ዘመናዊ መማሪያ", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Main Features", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildGridItem(context, "🏆 Leaderboard", Icons.leaderboard, Colors.amber.shade700, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
              _buildGridItem(context, "🆕 Model Exams", Icons.library_books, Colors.blue.shade600, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'model_exams', title: 'Model Exams')))),
              _buildGridItem(context, "📖 Remedial Exams", Icons.school, Colors.teal.shade600, !isVIP, () { if (!isVIP) _showPremiumDialog(context); else Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'remedial_exams', title: 'Remedial Exams'))); }),
              _buildGridItem(context, "🧠 Exam Trainer", Icons.psychology, Colors.purple.shade500, !isVIP, () { if (!isVIP) _showPremiumDialog(context); else Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'trainer', year: '2018', title: 'Exam Trainer'))); }),
              _buildGridItem(context, "📝 Quizzes", Icons.quiz, Colors.orange.shade600, !isVIP, () { if (!isVIP) _showPremiumDialog(context); else Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'quizzes', year: '2018', title: 'Quizzes'))); }),
              _buildGridItem(context, "📚 Sample Notes & Videos", Icons.play_lesson, Colors.redAccent, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SampleMaterialsScreen()))),
              _buildGridItem(context, "💡 Study Tips", Icons.lightbulb, Colors.pink.shade600, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyTipsScreen()))),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.shade700, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async { if (!isVIP) { _showPremiumDialog(context); } else { await launchUrl(Uri.parse('https://t.me/+yQdJM7LxN8VmNWY0'), mode: LaunchMode.externalApplication); } },
            icon: Icon(isVIP ? Icons.ondemand_video : Icons.lock, color: Colors.white),
            label: const Text("Go to Tutorial Class", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: const BorderSide(color: Colors.amber)), onPressed: () => launchUrl(Uri.parse('https://t.me/Rmedial_matrix_support'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.support_agent, size: 16), label: const Text("Support", style: TextStyle(fontSize: 13)))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.greenAccent, side: const BorderSide(color: Colors.greenAccent)), onPressed: () => _showActivationLogin(context), icon: const Icon(Icons.vpn_key, size: 16), label: const Text("Code/Admin", style: TextStyle(fontSize: 13)))),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, IconData icon, Color color, bool isLocked, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(icon, size: 35, color: color),
                if (isLocked) const Padding(padding: EdgeInsets.only(left: 20, bottom: 20), child: Icon(Icons.lock, color: Colors.amber, size: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class ProfileContent extends StatelessWidget {
  final String userName; final int userShortId; final String appStatus;
  const ProfileContent({Key? key, required this.userName, required this.userShortId, required this.appStatus}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    bool isVip = appStatus == 'vip';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 50, backgroundColor: isVip ? Colors.amber : Colors.blueGrey, child: Icon(isVip ? Icons.workspace_premium : Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 20),
          Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(20)), child: Text("ID: $userShortId", style: const TextStyle(fontSize: 18, color: Colors.greenAccent, letterSpacing: 2))),
          const SizedBox(height: 10),
          Text("Status: ${appStatus.toUpperCase()}", style: TextStyle(fontSize: 16, color: isVip ? Colors.amber : (appStatus == 'pending' ? Colors.blue : Colors.white54))),
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
  void initState() { super.initState(); fetchTips(); }
  Future fetchTips() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/study_tips").get();
      if (snap.exists) {
        List temp = [];
        (snap.value as Map).forEach((k, v) => temp.add(Map.from(v)));
        temp.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
        if (mounted) setState(() { tips = temp; isLoading = false; });
      } else { if (mounted) setState(() => isLoading = false); }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("💡 Study Tips")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : tips.isEmpty 
        ? const Center(child: Text("እስካሁን ምንም ጥቆማ አልተለቀቀም!")) 
        : ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: tips.length,
            itemBuilder: (c, i) => Card(color: const Color(0xFF2C2C2C), margin: const EdgeInsets.only(bottom: 12), child: ListTile(leading: const Icon(Icons.lightbulb, color: Colors.orange, size: 30), title: Text(tips[i]['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(tips[i]['content'] ?? '', style: const TextStyle(color: Colors.white70)))),
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
  void initState() { super.initState(); fetchMaterials(); }
  Future fetchMaterials() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/sample_materials").get();
      if (snap.exists) {
        List temp = [];
        (snap.value as Map).forEach((k, v) => temp.add(Map.from(v)));
        temp.sort((a, b) => (b['time'] ?? 0).compareTo(a['time'] ?? 0));
        if (mounted) setState(() { materials = temp; isLoading = false; });
      } else { if (mounted) setState(() => isLoading = false); }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📚 Sample Notes & Videos")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : materials.isEmpty 
        ? const Center(child: Text("እስካሁን ምንም የናሙና ትምህርት አልተለቀቀም!")) 
        : ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: materials.length,
            itemBuilder: (c, i) {
              var m = materials[i];
              bool isVideo = m['type'] == 'video';
              return Card(
                color: const Color(0xFF2C2C2C), margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(isVideo ? Icons.play_circle_fill : Icons.picture_as_pdf, color: isVideo ? Colors.red : Colors.blue, size: 40),
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

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🛠 Admin Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 50)), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReceiptsScreen())); }, icon: const Icon(Icons.receipt_long, color: Colors.black), label: const Text("📥 አዲስ ደረሰኞችን አረጋግጥ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            const SizedBox(height: 15),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 50)), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStudentListScreen())); }, icon: const Icon(Icons.group, color: Colors.white), label: const Text("👥 የተመዘገቡ ተማሪዎች (Filter/Ban)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(height: 15),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminContentScreen())); }, icon: const Icon(Icons.edit_document, color: Colors.white), label: const Text("✍️ ኮንቴንት አስተካክል (Tips & Materials)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(height: 15),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.purpleAccent, minimumSize: const Size(double.infinity, 50)), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUpdateAppScreen())); }, icon: const Icon(Icons.system_update, color: Colors.white), label: const Text("🚀 አዲስ አፕሊኬሽን (Update) ልቀቅ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
            const SizedBox(height: 15),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50)), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())); }, icon: const Icon(Icons.campaign, color: Colors.white), label: const Text("📢 Pop-up ማስታወቂያ ላክ", style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  void _showAddTipDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("አዲስ Study Tip"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: "ርዕስ (ምሳሌ: የሰዓት አጠቃቀም)")),
        const SizedBox(height: 10),
        TextField(controller: contentCtrl, maxLines: 3, decoration: const InputDecoration(hintText: "ዝርዝር ማብራሪያ")),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          if (titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
            await FirebaseDatabase.instance.ref("admin_content/study_tips").push().set({"title": titleCtrl.text, "content": contentCtrl.text, "time": DateTime.now().millisecondsSinceEpoch});
            if(context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ተጨምሯል!"))); }
          }
        }, child: const Text("Save")),
      ],
    ));
  }

  void _showAddMaterialDialog(BuildContext context) {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController urlCtrl = TextEditingController();
    String mType = 'video';
    showDialog(context: context, builder: (context) => StatefulBuilder(
      builder: (c, setStateDialog) => AlertDialog(
        title: const Text("አዲስ Sample Material"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(hintText: "ርዕስ (ምሳሌ: Physics Chapter 1)")),
          const SizedBox(height: 10),
          TextField(controller: urlCtrl, decoration: const InputDecoration(hintText: "የቪዲዮ ወይም የፋይል ሊንክ (URL)")),
          const SizedBox(height: 10),
          DropdownButton(
            value: mType, dropdownColor: Colors.black,
            items: const [DropdownMenuItem(value: 'video', child: Text("🎥 Video")), DropdownMenuItem(value: 'pdf', child: Text("📄 PDF / Note"))],
            onChanged: (val) => setStateDialog(() => mType = val.toString()),
          )
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            if (titleCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
              await FirebaseDatabase.instance.ref("admin_content/sample_materials").push().set({"title": titleCtrl.text, "url": urlCtrl.text, "type": mType, "time": DateTime.now().millisecondsSinceEpoch});
              if(context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ተጨምሯል!"))); }
            }
          }, child: const Text("Save")),
        ],
      )
    ));
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
          const Text("አዲስ የ Flutter ኮድ ጽፈህ GitHub ላይ ስትለቅ፣ እዚህ ገብተህ ቨርሽኑን በመቀየር ሁሉም ተማሪዎች አዲሱን አፕ እንዲጭኑ ማስገደድ ትችላለህ።", style: TextStyle(color: Colors.amber)),
          const SizedBox(height: 20),
          TextField(controller: verCtrl, decoration: const InputDecoration(labelText: "አዲሱ ቨርሽን (ምሳሌ: 1.0.1)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "የማውረጃ ሊንክ (ምሳሌ: የቴሌግራም ቻናል ሊንክ)", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(double.infinity, 50)), onPressed: () async {
            if (verCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
              await FirebaseDatabase.instance.ref("admin_settings/update").set({"version": verCtrl.text.trim(), "url": urlCtrl.text.trim()});
              if(context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Update ፖስት ተደርጓል!"))); }
            }
          }, child: const Text("ለተማሪዎች አሳውቅ (Push Update)", style: TextStyle(color: Colors.white)))
        ]),
      )
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
  void initState() { super.initState(); fetchStudents(); }
  Future fetchStudents() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("students").get();
      if (snap.exists) {
        List temp = [];
        (snap.value as Map).forEach((k, v) { Map st = Map.from(v); st['device_id'] = k; temp.add(st); });
        if (mounted) setState(() { allStudents = temp; _applyFilter(); isLoading = false; });
      } else { if (mounted) setState(() => isLoading = false); }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }
  void _applyFilter() {
    if (currentFilter == 'All') displayedStudents = List.from(allStudents);
    else displayedStudents = allStudents.where((s) => s['status'].toString().toLowerCase() == currentFilter.toLowerCase()).toList();
  }
  Future toggleBanStatus(String deviceId, String currentStatus) async {
    String newStatus = (currentStatus == 'blocked') ? 'free' : 'blocked';
    try {
      await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": newStatus});
      fetchStudents();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStatus == 'blocked' ? "ተማሪው ታግዷል!" : "እግዱ ተነስቷል")));
    } catch(e){}
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ተማሪዎች"), actions: [
        PopupMenuButton(icon: const Icon(Icons.filter_list), onSelected: (val) { setState(() { currentFilter = val.toString(); _applyFilter(); }); }, itemBuilder: (context) => ['All', 'VIP', 'Free', 'Blocked'].map((e) => PopupMenuItem(value: e, child: Text(e))).toList())
      ]),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : displayedStudents.isEmpty 
        ? Center(child: Text("በ '$currentFilter' የተገኘ ተማሪ የለም!")) 
        : ListView.builder(
            padding: const EdgeInsets.all(12), itemCount: displayedStudents.length,
            itemBuilder: (c, i) {
              var s = displayedStudents[i];
              bool isVip = s['status'] == 'vip';
              bool isBlocked = s['status'] == 'blocked';
              return Card(
                color: const Color(0xFF2C2C2C), margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: isBlocked ? Colors.red : (isVip ? Colors.amber : Colors.blueGrey), child: Icon(isBlocked ? Icons.block : Icons.person, color: Colors.white)),
                  title: Text(s['full_name'] ?? 'Unknown', style: TextStyle(color: isBlocked ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold, decoration: isBlocked ? TextDecoration.lineThrough : null)),
                  subtitle: Text("ID: ${s['short_id']} | Status: ${s['status']}", style: const TextStyle(color: Colors.white70)),
                  trailing: IconButton(icon: Icon(isBlocked ? Icons.lock_open : Icons.block, color: isBlocked ? Colors.green : Colors.red), onPressed: () => toggleBanStatus(s['device_id'], s['status'])),
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
  void initState() { super.initState(); fetchReceipts(); }
  Future fetchReceipts() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("students").get();
      List temp = [];
      if (snap.exists) { (snap.value as Map).forEach((k, v) { if (v['status'] == 'pending' && v['receipt'] != null) { Map s = Map.from(v); s['device_id'] = k; temp.add(s); } }); }
      if (mounted) setState(() { pendingStudents = temp; isLoading = false; });
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }
  Future decideReceipt(String deviceId, String decision) async {
    try { await FirebaseDatabase.instance.ref("students/$deviceId").update({"status": decision}); fetchReceipts(); } catch (e) {}
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📥 Pending Receipts")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : pendingStudents.isEmpty ? const Center(child: Text("ምንም ደረሰኝ የለም!")) : ListView.builder(
        itemCount: pendingStudents.length,
        itemBuilder: (c, i) {
          var s = pendingStudents[i];
          return Card(
            margin: const EdgeInsets.all(10), color: const Color(0xFF2C2C2C),
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(8), child: Text("ስም: ${s['full_name']}", style: const TextStyle(color: Colors.greenAccent))),
              s['receipt'] != null ? Image.memory(base64Decode(s['receipt']), height: 300, fit: BoxFit.cover) : const SizedBox(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => decideReceipt(s['device_id'], 'rejected'), child: const Text("Decline")),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => decideReceipt(s['device_id'], 'vip'), child: const Text("Approve")),
              ])
            ]),
          );
        },
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
  bool isSending = false;

  Future sendBroadcast() async {
    if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
    setState(() => isSending = true);
    try {
      await FirebaseDatabase.instance.ref("announcement").set({"title": titleCtrl.text.trim(), "message": msgCtrl.text.trim(), "time": DateTime.now().millisecondsSinceEpoch});
      if (mounted) { setState(() => isSending = false); Navigator.pop(context); }
    } catch (e) { if (mounted) setState(() => isSending = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📢 Broadcast")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "ርዕስ", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: msgCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "መልዕክት", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)), onPressed: isSending ? null : sendBroadcast, child: isSending ? const CircularProgressIndicator() : const Text("ላክ (Send)", style: TextStyle(color: Colors.white)))
        ]),
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
  void initState() { super.initState(); fetchLeaderboard(); }
  Future fetchLeaderboard() async {
    try {
      final snap = await FirebaseDatabase.instance.ref("leaderboard").get();
      List temp = [];
      if (snap.exists) {
        (snap.value as Map).forEach((k, v) { temp.add(Map.from(v)); });
        temp.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        if(temp.length > 10) temp = temp.sublist(0, 10);
      }
      if (mounted) setState(() { topUsers = temp; isLoading = false; });
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Top 10 Leaderboard")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : topUsers.isEmpty ? const Center(child: Text("እስካሁን ምንም ውጤት አልተመዘገበም!")) : ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: topUsers.length,
        itemBuilder: (c, i) {
          var user = topUsers[i];
          return Card(
            color: const Color(0xFF2C2C2C),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: i == 0 ? Colors.amber : i == 1 ? Colors.grey.shade400 : Colors.brown.shade300, child: Text("${i + 1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              title: Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              subtitle: Text("${user['subject']} • ${user['method']}", style: const TextStyle(color: Colors.greenAccent)),
              trailing: Text("${user['score']} Pts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
          );
        },
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String examType; final String year; final String subject;
  const QuizScreen({Key? key, required this.examType, required this.year, required this.subject}) : super(key: key);
  @override
  _QuizScreenState createState() => _QuizScreenState();
}
class _QuizScreenState extends State<QuizScreen> {
  List questions = []; List userAnswers = [];
  int currentQuestionIndex = 0; int score = 0;
  bool showExplanation = false; int? selectedOptionIndex;
  bool isLoading = true; bool hasError = false;
  Timer? _timer; int _remainingSeconds = 0;

  @override
  void initState() { super.initState(); loadLocalQuestions(); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void fnStartTimer(int tq) {
    _remainingSeconds = tq * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) { if (mounted) setState(() => _remainingSeconds--); } 
      else { timer.cancel(); if (mounted) showCompletionDialog(isTimeUp: true); }
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
    } catch (e) { if (mounted) setState(() { hasError = true; isLoading = false; }); }
  }
  void checkAnswer(int index) {
    if (showExplanation) return;
    setState(() {
      selectedOptionIndex = index; userAnswers[currentQuestionIndex] = index; showExplanation = true;
      int correctId = int.tryParse(questions[currentQuestionIndex]['correct_option_id']?.toString() ?? '0') ?? 0;
      if (index == correctId) score++;
    });
  }
  void nextQuestion() {
    setState(() {
      if (currentQuestionIndex < questions.length - 1) { currentQuestionIndex++; showExplanation = false; selectedOptionIndex = null; } 
      else { _timer?.cancel(); _submitScoreToLeaderboard(); showCompletionDialog(isTimeUp: false); }
    });
  }
  Future _submitScoreToLeaderboard() async {
    if (score == 0) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? ''; String name = prefs.getString('local_name') ?? 'Unknown';
      String recordId = "${deviceId}_${widget.subject}_${widget.year}";
      await FirebaseDatabase.instance.ref("leaderboard/$recordId").set({"name": name, "score": score, "subject": widget.subject, "method": widget.examType.replaceAll('_', ' ').toUpperCase() + " (${widget.year})"});
    } catch (e) {}
  }
  void showCompletionDialog({required bool isTimeUp}) {
    double percentage = questions.isEmpty ? 0 : (score / questions.length);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
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
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("ወደ ዋናው (Back)")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () { Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizReviewScreen(questions: questions, userAnswers: userAnswers, subject: widget.subject))); }, child: const Text("መልስ አረጋግጥ (Review)", style: TextStyle(color: Colors.white)))
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
    int m = _remainingSeconds ~/ 60; int s = _remainingSeconds % 60;
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
              Color bCol = Colors.grey.shade800;
              if (showExplanation) {
                int correctId = int.tryParse(currentQ['correct_option_id']?.toString() ?? '0') ?? 0;
                if (i == correctId) bCol = Colors.green.shade600;
                else if (i == selectedOptionIndex) bCol = Colors.red.shade600;
              }
              return Padding(padding: const EdgeInsets.only(bottom: 10), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: bCol, padding: const EdgeInsets.all(16), alignment: Alignment.centerLeft), onPressed: () => checkAnswer(i), child: Text("${String.fromCharCode(65 + i)}. ${options[i]}", style: const TextStyle(color: Colors.white))));
            }),
            if (showExplanation) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)), child: Text("💡 ${currentQ['explanation']?.toString() ?? 'ማብራሪያ የለውም።'}", style: const TextStyle(color: Colors.amber, fontSize: 15))),
              const SizedBox(height: 20),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: nextQuestion, child: const Text("Next Question ➡️", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          ],
        ),
      ),
    );
  }
}

class QuizReviewScreen extends StatelessWidget {
  final List questions; final List userAnswers; final String subject;
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
        padding: const EdgeInsets.all(12), itemCount: questions.length,
        itemBuilder: (context, index) {
          var q = questions[index]; var opts = parseOptions(q);
          int correctId = int.tryParse(q['correct_option_id']?.toString() ?? '0') ?? 0;
          int? userId = userAnswers[index]; bool isCorrect = correctId == userId;
          return Card(
            color: const Color(0xFF2C2C2C), margin: const EdgeInsets.only(bottom: 15),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(isCorrect ? Icons.check_circle : (userId == null ? Icons.help : Icons.cancel), color: isCorrect ? Colors.green : (userId == null ? Colors.grey : Colors.red)),
                    const SizedBox(width: 8), Expanded(child: Text("Q${index + 1}: ${q['question']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ]),
                  const Divider(color: Colors.white24),
                  Text("✅ ትክክለኛው መልስ: ${opts.length > correctId ? opts[correctId] : 'Unknown'}", style: const TextStyle(color: Colors.greenAccent)),
                  if (!isCorrect) Text("❌ የእርስዎ መልስ: ${userId != null && opts.length > userId ? opts[userId] : 'አልተመለሰም'}", style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 8), Text("💡 ማብራሪያ: ${q['explanation'] ?? 'የለውም'}", style: const TextStyle(color: Colors.amber, fontSize: 13)),
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
  final String examType; final String title;
  const YearSelectionScreen({Key? key, required this.examType, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    List<String> years = examType == 'model_exams' ? ['2017', '2018'] : ['2015', '2016', '2017', '2018'];
    return Scaffold(appBar: AppBar(title: Text(title)), body: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0), itemCount: years.length, itemBuilder: (c, i) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade500), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectSelectionScreen(examType: examType, year: years[i], title: "$title - ${years[i]}"))), child: Text("🗓 ${years[i]}", style: const TextStyle(fontSize: 18, color: Colors.white)))));
  }
}

class SubjectSelectionScreen extends StatelessWidget {
  final String examType; final String year; final String title;
  const SubjectSelectionScreen({Key? key, required this.examType, required this.year, required this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final subs = ["Biology", "Chemistry", "Physics", "Maths", "Mathematics", "English", "History", "Geography"];
    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.red, Colors.amber, Colors.purple, Colors.brown, Colors.teal];
    return Scaffold(appBar: AppBar(title: Text(title)), body: GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5), itemCount: subs.length, itemBuilder: (c, i) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colors[i % colors.length]), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(examType: examType, year: year, subject: subs[i]))), child: Text(subs[i], style: const TextStyle(color: Colors.white)))));
  }
}
