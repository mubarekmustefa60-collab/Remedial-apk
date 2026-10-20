import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();
    runApp(const RemedialApp());
  }, (error, stack) {
    debugPrint('Caught error: $error');
  });
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

  Future<void> checkRegistration() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? '';
      
      if (deviceId.isEmpty) {
        deviceId = "DEV_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}";
        await prefs.setString('device_id', deviceId);
      }

      bool localRegistered = prefs.getBool('local_registered') ?? false;
      String localStatus = prefs.getString('local_status') ?? 'free';

      if (mounted) {
        setState(() {
          isRegistered = localRegistered;
          appStatus = localStatus;
          isLoading = false;
        });
      }

      try {
        final res = await http.post(
          Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/app_status'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"device_id": deviceId}),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          bool serverRegistered = data['registered'] ?? false;
          String serverStatus = data['status'] ?? 'free';

          if (serverRegistered) {
            await prefs.setBool('local_registered', true);
            await prefs.setString('local_status', serverStatus);
          }

          if (mounted) {
            setState(() {
              isRegistered = serverRegistered || localRegistered;
              appStatus = serverStatus == 'vip' ? 'vip' : (localStatus == 'vip' ? 'vip' : serverStatus);
            });
          }
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!isRegistered) return const RegisterScreen();
    return MainMenuScreen(initialStatus: appStatus);
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

  Future<void> registerUser() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("እባክዎ ሙሉ ስምዎን ያስገቡ!")),
      );
      return;
    }
    setState(() => isSaving = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? '';
      
      await prefs.setBool('local_registered', true);
      await prefs.setString('local_status', 'free');
      await prefs.setString('local_name', nameCtrl.text.trim());

      try {
        await http.post(
          Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/app_register'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"device_id": deviceId, "full_name": nameCtrl.text.trim(), "stream": selectedStream}),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen(initialStatus: 'free')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainMenuScreen(initialStatus: 'free')));
      }
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
                Expanded(child: RadioListTile<String>(title: const Text("Natural"), value: "Natural", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val!))),
                Expanded(child: RadioListTile<String>(title: const Text("Social"), value: "Social", groupValue: selectedStream, onChanged: (val) => setState(() => selectedStream = val!))),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: isSaving ? null : registerUser,
              child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Get Started 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  void initState() {
    super.initState();
    appStatus = widget.initialStatus;
    checkForAnnouncement();
  }

  Future<void> refreshStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? '';
      final res = await http.post(
        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/app_status'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"device_id": deviceId}),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String serverStatus = data['status'] ?? 'free';
        
        await prefs.setString('local_status', serverStatus);

        if (mounted) {
          setState(() {
            appStatus = serverStatus;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ አፕሊኬሽኑ ታድሷል!")),
          );
        }
      }
    } catch (e) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String localStatus = prefs.getString('local_status') ?? 'free';
      if (mounted) {
        setState(() {
          appStatus = localStatus;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("የኢንተርኔት ችግር! ሎካል ዴታ እየተጠቀሙ ነው።")),
      );
    }
  }

  Future<void> checkForAnnouncement() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool shown = prefs.getBool('ad_shown_session') ?? false;
      if (shown) return;

      final res = await http.get(Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/announcement'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['has_announcement'] == true && mounted) {
          await prefs.setBool('ad_shown_session', true);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: Text(data['title'] ?? "📢 ማስታወቂያ", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data['image_url'] != null && data['image_url'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Image.network(data['image_url'], height: 180, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()),
                      ),
                    Text(data['message'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
              ),
              actions: [
                if (data['button_link'] != null && data['button_link'].toString().isNotEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () async => await launchUrl(Uri.parse(data['button_link']), mode: LaunchMode.externalApplication),
                    child: Text(data['button_text'] ?? "ጎብኝ", style: const TextStyle(color: Colors.white)),
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("ዝጋ")),
              ],
            ),
          );
        }
      }
    } catch (e) {}
  }

  Future<void> _launchTutorial() async {
    final Uri url = Uri.parse('https://t.me/+yQdJM7LxN8VmNWY0');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) debugPrint('Error');
  }

  Future<void> _launchAdmin() async {
    final Uri url = Uri.parse('https://t.me/Rmedial_matrix_support');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) debugPrint('Error');
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
            backgroundColor: const Color(0xFF2C2C2C),
            title: Row(
              children: const [
                Icon(Icons.lock, color: Colors.amber),
                SizedBox(width: 10),
                Text("Premium Access", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appStatus == 'pending') ...[
                    const Center(child: Icon(Icons.hourglass_top, color: Colors.blueAccent, size: 50)),
                    const SizedBox(height: 15),
                    const Text("⏳ ክፍያዎ እየታየ ነው! እባክዎ አድሚን እስኪያረጋግጥልዎት ድረስ በትዕግስት ይጠብቁ።", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                  ] 
                  else ...[
                    if (appStatus == 'rejected')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text("❌ የላኩት ደረሰኝ ልክ ስላልሆነ አልፀደቀም፤ እባክዎ እንደገና ይሞክሩ።", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    const Text("💎 Premium ሲመዘገቡ የሚያገኙዋቸው ጥቅሞች፦", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 5),
                    const Text("• አፕሊኬሽኑ ሙሉ በሙሉ (Unlocked) ይከፈትልዎታል።\n• ከእሱ ጋር አብሮ ወደ ፕራይቬት ቱቶሪያል ክላስ (Private Tutorial Class) በቀጥታ ይገባሉ።", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const Divider(color: Colors.white24, height: 20),
                    const Text("📋 ለመመዝገብ የሚከተሉትን 3 ደረጃዎች ይከተሉ፦", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("1️⃣ በታች ባሉት አካውንቶች 300 ብር ይክፈሉ።\n🏦 CBE: 1000667301673\n📱 TELEBIRR: 0929698365\n👤 ስም: Mubarek Mustefa", style: TextStyle(color: Colors.amber, fontSize: 12)),
                    const SizedBox(height: 5),
                    const Text("2️⃣ የከፈሉበትን ደረሰኝ (Screenshot) ከታች ባለው በተን ይምረጡና 'Send Receipt' ይበሉ።", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 15),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
                        onPressed: () async {
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (image != null) { 
                            setStateDialog(() { selectedImage = File(image.path); }); 
                          }
                        },
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: Text(selectedImage == null ? "ደረሰኝ ምረጥ (Attach)" : "✅ ፎቶ ተመርጧል", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    if (selectedImage != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 10),
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.file(selectedImage!, height: 100, width: double.infinity, fit: BoxFit.cover),
                         ),
                       ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: Text(appStatus == 'pending' ? "ዝጋ" : "Cancel"),
              ),
              if (appStatus != 'pending')
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
                  onPressed: isDialogLoading ? null : () async {
                    if (selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("እባክዎ መጀመሪያ ደረሰኝ ይምረጡ!")),
                      );
                      return;
                    }
                    setStateDialog(() => isDialogLoading = true);
                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      String deviceId = prefs.getString('device_id') ?? '';
                      
                      final bytes = await selectedImage!.readAsBytes();
                      final base64Image = base64Encode(bytes);
                      
                      final res = await http.post(
                        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/app_upload'),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({"device_id": deviceId, "receipt_base64": base64Image}),
                      ).timeout(const Duration(seconds: 25));

                      if (res.statusCode == 200) {
                        final data = jsonDecode(res.body);
                        if (data['success'] == true) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            setState(() { appStatus = 'pending'; });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(data['message'] ?? "✅ ደረሰኝዎ ተልኳል!"), backgroundColor: Colors.green),
                            );
                          }
                        } else {
                          setStateDialog(() => isDialogLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("❌ መላክ አልተቻለም፣ እባክዎ እንደገና ይሞክሩ"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      } else {
                        setStateDialog(() => isDialogLoading = false);
                      }
                    } catch (e) { 
                      if (context.mounted) {
                        setStateDialog(() => isDialogLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("⚠️ የኢንተርኔት ወይም የሰርቨር ችግር አጋጥሟል!"), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: isDialogLoading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("Send Receipt", style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        }
      ),
    );
  }

  void _showAdminLogin(BuildContext context) {
    TextEditingController pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("🛠 Admin Login", style: TextStyle(color: Colors.white)),
        content: TextField(controller: pwdCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Password")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (pwdCtrl.text == "Matrix@2026") {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("❌ Error!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isVIP = appStatus == 'vip';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.school, color: Colors.blue, size: 20)),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REMEDIAL MATRIX', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Educational Platform', style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: "Refresh Status",
            onPressed: refreshStatus,
          ),
          if (isVIP) const Padding(padding: EdgeInsets.only(right: 12.0), child: Center(child: Icon(Icons.verified, color: Colors.amber, size: 26)))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.network('https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=800', height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 160, color: Colors.grey.shade800)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    child: const Text(
                      "Remedial Matrix የስኬትዎ መንገድ",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            _buildColorButton(context, "🏆 Top 10 Leaderboard", Colors.amber.shade700, false, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
            }),
            _buildColorButton(context, "🆕 Model Exams (2017-2018)", Colors.blue.shade600, false, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'model_exams', title: 'Model Exams')));
            }),
            _buildColorButton(context, "📖 Remedial National Exam", Colors.teal.shade600, !isVIP, () {
              if (!isVIP) { _showPremiumDialog(context); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const YearSelectionScreen(examType: 'remedial_exams', title: 'Remedial Exams'))); }
            }),
            _buildColorButton(context, "🧠 Exam Trainer", Colors.purple.shade500, !isVIP, () {
              if (!isVIP) { _showPremiumDialog(context); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'trainer', year: '', title: 'Exam Trainer'))); }
            }),
            _buildColorButton(context, "📝 Quizzes with Explanations", Colors.orange.shade600, !isVIP, () {
              if (!isVIP) { _showPremiumDialog(context); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'quizzes', year: '', title: 'Quizzes'))); }
            }),
            _buildColorButton(context, "💡 Study Tips", Colors.pink.shade600, false, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyTipsScreen()));
            }),
            const Divider(color: Colors.white24, height: 25, thickness: 1),
            _buildColorButton(context, "🚀 Go to Tutorial Class", Colors.blueAccent.shade700, !isVIP, () {
              if (!isVIP) {
                _showPremiumDialog(context);
              } else {
                _launchTutorial();
              }
            }),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber, 
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _launchAdmin,
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text("Contact Admin", style: TextStyle(fontSize: 13)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey, 
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _showAdminLogin(context),
                  icon: const Icon(Icons.admin_panel_settings, size: 18),
                  label: const Text("Admin Panel", style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(BuildContext context, String text, Color color, bool isLocked, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLocked) const Padding(padding: EdgeInsets.only(right: 6.0), child: Icon(Icons.lock, color: Colors.amber, size: 18)),
              Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalStudents = 0; int naturalCount = 0; int socialCount = 0; int vipCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      final res = await http.post(
        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/admin/student_stats'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": "Matrix@2026"}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] && mounted) {
          setState(() {
            totalStudents = data['total'] ?? 0;
            naturalCount = data['natural'] ?? 0;
            socialCount = data['social'] ?? 0;
            vipCount = data['vips'] ?? 0;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🛠 Admin Dashboard")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _statCard("Total Students", totalStudents.toString(), Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _statCard("VIP Verified", vipCount.toString(), Colors.amber)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _statCard("Natural Stream", naturalCount.toString(), Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: _statCard("Social Stream", socialCount.toString(), Colors.purple)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), backgroundColor: Colors.amber),
              onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReceiptsScreen())); },
              icon: const Icon(Icons.receipt_long, color: Colors.black),
              label: const Text("📥 የተላኩ ደረሰኞችን አረጋግጥ", style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), backgroundColor: Colors.blueAccent),
              onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStudentListScreen())); },
              icon: const Icon(Icons.group, color: Colors.white),
              label: const Text("👥 የተመዘገቡ ተማሪዎች ዝርዝር", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), backgroundColor: Colors.green),
              onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const PostAnnouncementScreen())); },
              icon: const Icon(Icons.campaign, color: Colors.white),
              label: const Text("📢 አዲስ ማስታወቂያ ለጠፍ (Post Ad)", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String count, Color col) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: col.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: col)),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: col)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
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
  List<dynamic> students = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); fetchStudents(); }

  Future<void> fetchStudents() async {
    try {
      final res = await http.post(
        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/admin/all_students'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": "Matrix@2026"}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { students = data['students'] ?? []; isLoading = false; });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("👥 የተመዘገቡ ተማሪዎች ዝርዝር")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : students.isEmpty ? const Center(child: Text("ምንም የተመዘገበ ተማሪ የለም!", style: TextStyle(fontSize: 18))) : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: students.length,
        itemBuilder: (context, index) {
          var s = students[index];
          bool isVip = s['status'] == 'vip';
          return Card(
            color: const Color(0xFF2C2C2C),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isVip ? Colors.amber : Colors.blueGrey,
                child: Icon(isVip ? Icons.verified : Icons.person, color: Colors.white),
              ),
              title: Text(s['full_name'] ?? 'ስም የሌለው', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("መስመር: ${s['stream']} | ስተተስ: ${s['status']}", style: TextStyle(color: isVip ? Colors.amberAccent : Colors.white70)),
              trailing: Text(isVip ? "💎 VIP" : "🆓 Free", style: TextStyle(color: isVip ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({Key? key}) : super(key: key);
  @override
  _PostAnnouncementScreenState createState() => _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  final TextEditingController titleCtrl = TextEditingController(text: "📢 ልዩ ማስታወቂያ");
  final TextEditingController msgCtrl = TextEditingController();
  final TextEditingController imgCtrl = TextEditingController();
  final TextEditingController linkCtrl = TextEditingController(text: "https://t.me/ADDIS_REMEDIAL");
  final TextEditingController btnCtrl = TextEditingController(text: "ቻናሉን ይቀላቀሉ");
  bool isPosting = false;

  Future<void> postAd() async {
    if (msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("እባክዎ የማስታወቂያውን መልዕክት ይጻፉ!")),
      );
      return;
    }
    setState(() => isPosting = true);
    try {
      final res = await http.post(
        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/admin/post_announcement'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "password": "Matrix@2026",
          "title": titleCtrl.text.trim(),
          "message": msgCtrl.text.trim(),
          "image_url": imgCtrl.text.trim(),
          "button_link": linkCtrl.text.trim(),
          "button_text": btnCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() => isPosting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'success'), backgroundColor: data['success'] ? Colors.green : Colors.red),
          );
          if (data['success']) Navigator.pop(context);
        }
      } else {
        if (mounted) setState(() => isPosting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ስህተት አጋጥሟል!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📢 Post Announcement")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "ርዕስ (Title)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: msgCtrl, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "መልዕክት (Message)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: imgCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "የፎቶ ሊንክ (Image URL - አማራጭ)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: linkCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "የተንቀሳቃሽ ሊንክ (Button Link)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: btnCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "የተንቀሳቃሽ በተን ጽሁፍ (Button Text)", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), minimumSize: const Size(double.infinity, 50)),
              onPressed: isPosting ? null : postAd,
              child: isPosting ? const CircularProgressIndicator(color: Colors.white) : const Text("🚀 ማስታወቂያውን ለጠፍ (Publish)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
  List<dynamic> receipts = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); fetchReceipts(); }

  Future<void> fetchReceipts() async {
    try {
      final res = await http.post(
        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/admin/receipts'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": "Matrix@2026"}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { receipts = data['receipts'] ?? []; isLoading = false; });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> decideReceipt(String deviceId, String decision) async {
    try {
      final res = await http.post(
        Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/admin/decide'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": "Matrix@2026", "device_id": deviceId, "decision": decision}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decision == 'vip' ? "✅ አፅድቀዋል!" : "❌ አልፀደቀም")),
        );
        fetchReceipts();
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📥 Pending Receipts")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : receipts.isEmpty ? const Center(child: Text("ምንም አዲስ ደረሰኝ የለም!", style: TextStyle(fontSize: 18))) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: receipts.length,
        itemBuilder: (context, index) {
          var r = receipts[index];
          return Card(
            color: const Color(0xFF2C2C2C),
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("ስም: ${r['full_name']} | መስመር: ${r['stream']}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Image.memory(base64Decode(r['receipt_base64'] ?? ''), height: 300, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100)),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => decideReceipt(r['device_id'], 'rejected'), icon: const Icon(Icons.close, color: Colors.white), label: const Text("Decline", style: TextStyle(color: Colors.white))),
                      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => decideReceipt(r['device_id'], 'vip'), icon: const Icon(Icons.check, color: Colors.white), label: const Text("Approve", style: TextStyle(color: Colors.white))),
                    ],
                  ),
                )
              ],
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
  List<dynamic> topUsers = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); fetchLeaderboard(); }

  Future<void> fetchLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/leaderboard'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) { 
        setState(() { topUsers = jsonDecode(response.body) ?? []; isLoading = false; }); 
      }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Top 10 Students")),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : topUsers.isEmpty ? const Center(child: Text("እስካሁን ምንም ውጤት አልተመዘገበም!", style: TextStyle(fontSize: 18))) : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: topUsers.length,
        itemBuilder: (context, index) {
          var user = topUsers[index];
          return Card(
            color: const Color(0xFF2C2C2C),
            child: ListTile(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    title: Text(user['name'] ?? 'User', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📚 ትምህርት: ${user['subject'] ?? 'General'}", style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
                        const SizedBox(height: 10),
                        Text("⚙️ የፈተና ዓይነት:\n${user['method'] ?? 'Standard Exam'}", style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        const SizedBox(height: 10),
                        Text("📊 ያመጣው ውጤት: ${user['score'] ?? 0} Pts", style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("ዝጋ")) ],
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: index == 0 ? Colors.amber : index == 1 ? Colors.grey.shade400 : index == 2 ? Colors.brown.shade300 : Colors.blueAccent,
                child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(user['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              subtitle: Text(user['subject'] ?? 'General', style: const TextStyle(color: Colors.greenAccent)),
              trailing: Text("${user['score'] ?? 0} Pts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0),
        itemCount: years.length,
        itemBuilder: (context, index) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade500),
            onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectSelectionScreen(examType: examType, year: years[index], title: "$title - ${years[index]}"))); },
            child: Text("🗓 ${years[index]}", style: const TextStyle(fontSize: 18, color: Colors.white)),
          );
        },
      ),
    );
  }
}

class SubjectSelectionScreen extends StatelessWidget {
  final String examType; final String year; final String title;
  const SubjectSelectionScreen({Key? key, required this.examType, required this.year, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subs = ["Biology", "Chemistry", "Physics", "Maths", "Mathematics", "English", "History", "Geography"];
    final colors = [Colors.green, Colors.orange, Colors.blue, Colors.red, Colors.amber, Colors.purple, Colors.brown, Colors.teal];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
        itemCount: subs.length,
        itemBuilder: (context, index) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors[index % colors.length]),
            onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(examType: examType, year: year, subject: subs[index]))); },
            child: Text(subs[index], style: const TextStyle(color: Colors.white)),
          );
        },
      ),
    );
  }
}

class StudyTipsScreen extends StatelessWidget {
  const StudyTipsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("💡 Study Tips")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(color: Color(0xFF2C2C2C), margin: EdgeInsets.only(bottom: 16), child: ListTile(leading: Icon(Icons.timer, color: Colors.orange, size: 30), title: Text("⏱ የሰዓት አጠቃቀም", style: TextStyle(color: Colors.white)), subtitle: Text("ለ 25 ደቂቃዎች በጥልቀት ያንብቡ። ከዛ ለ 5 ደቂቃ ያሳርፉ።", style: TextStyle(color: Colors.white70)))),
        ],
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
  List<dynamic> questions = [];
  int currentQuestionIndex = 0; int score = 0;
  bool showExplanation = false; int? selectedOptionIndex;
  bool isLoading = true; bool hasError = false;
  Timer? _timer; int _remainingSeconds = 0;

  @override
  void initState() { super.initState(); fetchQuestions(); }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

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

  Future<void> fetchQuestions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      final res = await http.get(Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/questions'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) { 
        await prefs.setString('cached_questions', res.body); 
        _loadFromJson(res.body); 
      } else { 
        _loadFromCache(prefs); 
      }
    } catch (e) { _loadFromCache(prefs); }
  }

  void _loadFromCache(SharedPreferences prefs) {
    String? cData = prefs.getString('cached_questions');
    if (cData != null) _loadFromJson(cData);
    else if (mounted) setState(() { hasError = true; isLoading = false; });
  }

  List<String> parseOptions(dynamic qData) {
    try {
      if (qData is Map && qData['options'] != null) {
        var opts = qData['options'];
        if (opts is List) {
          return opts.map((e) => e?.toString() ?? "").toList();
        } else if (opts is Map) {
          return opts.values.map((e) => e?.toString() ?? "").toList();
        }
      }
    } catch (e) {}
    return ["Option A", "Option B", "Option C", "Option D"];
  }

  void _loadFromJson(String jsonData) {
    try {
      final parsed = jsonDecode(jsonData);
      if (mounted) {
        setState(() {
          String subKey = widget.subject;
          List<dynamic> rawList = [];
          if (widget.examType == 'model_exams' || widget.examType == 'remedial_exams') {
            if (parsed is Map && parsed[widget.examType] != null && parsed[widget.examType][widget.year] != null) {
              var examData = parsed[widget.examType][widget.year];
              if (examData[subKey] != null) {
                rawList = examData[subKey];
              } else if (subKey == "Maths" && examData["Mathematics"] != null) {
                rawList = examData["Mathematics"];
              } else if (subKey == "Mathematics" && examData["Maths"] != null) {
                rawList = examData["Maths"];
              }
            }
          } else {
            if (parsed is Map && parsed['model_exams'] != null && parsed['model_exams']['2018'] != null) {
               var examData = parsed['model_exams']['2018'];
               if (examData[subKey] != null) {
                 rawList = examData[subKey];
               } else if (subKey == "Maths" && examData["Mathematics"] != null) {
                 rawList = examData["Mathematics"];
               }
               rawList.shuffle(); 
            }
          }
          
          questions = rawList.where((q) => q != null && q is Map && q['question'] != null).toList();
          isLoading = false;
          if (questions.isNotEmpty) fnStartTimer(questions.length);
        });
      }
    } catch (e) {
      if (mounted) setState(() { hasError = true; isLoading = false; });
    }
  }

  void checkAnswer(int index) {
    if (showExplanation) return;
    setState(() {
      selectedOptionIndex = index;
      showExplanation = true;
      int correctId = int.tryParse(questions[currentQuestionIndex]['correct_option_id']?.toString() ?? '0') ?? 0;
      if (index == correctId) score++;
    });
  }

  void nextQuestion() {
    setState(() {
      if (currentQuestionIndex < questions.length - 1) {
        currentQuestionIndex++; showExplanation = false; selectedOptionIndex = null;
      } else {
        _timer?.cancel();
        showCompletionDialog(isTimeUp: false);
      }
    });
  }

  void showCompletionDialog({required bool isTimeUp}) {
    TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(isTimeUp ? "⏰ ሰዓት አልቋል!" : "🎉 Quiz Completed!", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("ውጤትዎ: $score ከ ${questions.length}", style: const TextStyle(fontSize: 18, color: Colors.greenAccent)),
            const SizedBox(height: 15),
            const Text("ለ Leaderboard ስምዎን ያስገቡ:", style: TextStyle(color: Colors.white)),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Your Name"))
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text("ዝለል")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                String methodDesc = "${widget.examType.replaceAll('_', ' ').toUpperCase()} ${widget.year.isNotEmpty ? '(${widget.year})' : ''}";
                try {
                  await http.post(
                    Uri.parse('https://telegram-poll-bot-s6l9.onrender.com/api/leaderboard'),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"name": nameCtrl.text, "subject": widget.subject, "score": score, "method": methodDesc}),
                  ).timeout(const Duration(seconds: 5));
                } catch (e) {}
              }
              if (context.mounted) {
                Navigator.pop(context); 
                Navigator.pop(context);
              }
            },
            child: const Text("Submit Score"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: CircularProgressIndicator()));
    if (hasError) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: Text("No Internet or Error!", style: TextStyle(color: Colors.red))));
    if (questions.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: Text("ጥያቄዎች በቅርቡ ይገባሉ!")));

    var currentQ = questions[currentQuestionIndex];
    List<String> options = parseOptions(currentQ);
    int m = _remainingSeconds ~/ 60; int s = _remainingSeconds % 60;
    String timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject, style: const TextStyle(fontSize: 16)),
        actions: [Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text("⏱ $timeStr", style: const TextStyle(fontSize: 16, color: Colors.amberAccent))))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Q: ${currentQuestionIndex + 1}/${questions.length}", style: const TextStyle(color: Colors.white70)),
                Text("Score: $score", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ],
            ),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: bCol, padding: const EdgeInsets.all(16), alignment: Alignment.centerLeft),
                  onPressed: () => checkAnswer(i),
                  child: Text("${String.fromCharCode(65 + i)}. ${options[i]}", style: const TextStyle(color: Colors.white)),
                ),
              );
            }),
            if (showExplanation) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
                child: Text("💡 ${currentQ['explanation']?.toString() ?? 'ማብራሪያ የለውም።'}", style: const TextStyle(color: Colors.amber, fontSize: 15)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: nextQuestion, 
                child: const Text("Next Question ➡️", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
