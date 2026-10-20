import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

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
      bool localRegistered = prefs.getBool('local_registered') ?? false;
      String localStatus = prefs.getString('local_status') ?? 'free';

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
      await prefs.setBool('local_registered', true);
      await prefs.setString('local_status', 'free');
      await prefs.setString('local_name', nameCtrl.text.trim());
      await prefs.setString('local_stream', selectedStream);

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const MainMenuScreen(initialStatus: 'free'))
        );
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
  }

  Future<void> refreshStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String st = prefs.getString('local_status') ?? 'free';
    setState(() => appStatus = st);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ ስቴተስ: ${st.toUpperCase()}"), backgroundColor: Colors.green),
    );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              const Text("💎 Premium ሲመዘገቡ የሚያገኙዋቸው ጥቅሞች፦", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 5),
              const Text("• አፕሊኬሽኑ ሙሉ በሙሉ (Unlocked) ይከፈትልዎታል።\n• ወደ ፕራይቬት ቱቶሪያል ክላስ (Private Tutorial Class) በቀጥታ ይገባሉ።", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Divider(color: Colors.white24, height: 20),
              const Text("📋 ለመመዝገብ የሚከተሉትን ያድርጉ፦", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("1️⃣ በታች ባሉት አካውንቶች 300 ብር ይክፈሉ።\n🏦 CBE: 1000667301673\n📱 TELEBIRR: 0929698365\n👤 ስም: Mubarek Mustefa", style: TextStyle(color: Colors.amber, fontSize: 12)),
              const SizedBox(height: 10),
              const Text("2️⃣ የከፈሉበትን ደረሰኝ (Screenshot) ይዘው አድሚንን በቴሌግራም ያነጋግሩ።", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("ዝጋ"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              Navigator.pop(context);
              _launchAdmin();
            },
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text("አድሚን አነጋግር (Telegram)", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdminLogin(BuildContext context) {
    TextEditingController pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("🛠 Admin VIP Unlock", style: TextStyle(color: Colors.white)),
        content: TextField(controller: pwdCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Admin Password")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (pwdCtrl.text == "Matrix@2026") {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('local_status', 'vip');
                setState(() => appStatus = 'vip');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ አፑ በအောင်မြင်ነት VIP ተደርጓል!"), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("❌ ትክክል ያልሆነ የጸጥታ ቃል!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Unlock VIP"),
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
            tooltip: "Refresh",
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
                  Container(height: 140, width: double.infinity, color: Colors.blueGrey.shade900, child: const Icon(Icons.menu_book, size: 60, color: Colors.white54)),
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
              if (!isVIP) { _showPremiumDialog(context); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'trainer', year: '2018', title: 'Exam Trainer'))); }
            }),
            _buildColorButton(context, "📝 Quizzes with Explanations", Colors.orange.shade600, !isVIP, () {
              if (!isVIP) { _showPremiumDialog(context); } else { Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectSelectionScreen(examType: 'quizzes', year: '2018', title: 'Quizzes'))); }
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

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> topUsers = [
    {"name": "Mubarek Mustefa", "subject": "Physics", "score": 48, "method": "MODEL EXAMS (2018)"},
    {"name": "Abebe Kebede", "subject": "Chemistry", "score": 45, "method": "REMEDIAL EXAMS (2017)"},
    {"name": "Tigist Haile", "subject": "Biology", "score": 42, "method": "MODEL EXAMS (2017)"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Top 10 Students")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: topUsers.length,
        itemBuilder: (context, index) {
          var user = topUsers[index];
          return Card(
            color: const Color(0xFF2C2C2C),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: index == 0 ? Colors.amber : index == 1 ? Colors.grey.shade400 : Colors.brown.shade300,
                child: Text("${index + 1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              subtitle: Text("${user['subject']} • ${user['method']}", style: const TextStyle(color: Colors.greenAccent)),
              trailing: Text("${user['score']} Pts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
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
  void initState() { super.initState(); loadLocalQuestions(); }
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

  Future<void> loadLocalQuestions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/questions.json');
      _loadFromJson(jsonString);
    } catch (e) {
      if (mounted) setState(() { hasError = true; isLoading = false; });
    }
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
          
          if (parsed is Map && parsed[widget.examType] != null) {
            var typeData = parsed[widget.examType];
            if (widget.examType == 'trainer' || widget.examType == 'quizzes') {
              if (typeData['2018'] != null && typeData['2018'][subKey] != null) {
                rawList = typeData['2018'][subKey];
              } else if (subKey == "Maths" && typeData['2018']?["Mathematics"] != null) {
                rawList = typeData['2018']["Mathematics"];
              }
              rawList.shuffle();
            } else {
              if (typeData[widget.year] != null) {
                var yearData = typeData[widget.year];
                if (yearData[subKey] != null) {
                  rawList = yearData[subKey];
                } else if (subKey == "Maths" && yearData["Mathematics"] != null) {
                  rawList = yearData["Mathematics"];
                } else if (subKey == "Mathematics" && yearData["Maths"] != null) {
                  rawList = yearData["Maths"];
                }
              }
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
            const Text("እንኳን ደስ አላት! ውጤትዎ ተመዝግቧል።", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context);
            },
            child: const Text("ወደ ዋናው ገጽ (Back)"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: CircularProgressIndicator()));
    if (hasError) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: Text("ጥያቄዎችን ማንበብ አልተቻለም!", style: TextStyle(color: Colors.red))));
    if (questions.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.subject)), body: const Center(child: Text("ለዚህ ትምህርት ጥያቄዎች አልተገኙም!")));

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
