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

// ============================================================================
// 📚 OFFICIAL 2019 REMEDIAL COURSE OUTLINES (SAFE SYNTAX WITHOUT NESTED <>)
// ============================================================================
const Map officialCourseOutlines = {
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
    {"unit": "Unit 1: Road Traffic Accidents (11 hrs)", "topics": "• Reading/Listening: Causes & Socio-Economic Impacts of Traffic Accidents\n• Grammar: Transitive/Intransitive Verbs, Present & Future Tenses (Active/Passive), Question Types (Wh-, Yes/No, Tag, Indirect)\n• Vocabulary & Writing: Context Clues, Phrasal Verbs, Paragraph & Informal Letter Writing"},
    {"unit": "Unit 2: Artificial Intelligence (11 hrs)", "topics": "• Reading/Speaking: Merits & Demerits of AI, Using 'so' and 'neither', Apologizing\n• Grammar: Past Tenses (Simple, Continuous, Perfect), Conditional Sentences (Zero, I, II, III) & Modals\n• Writing: Fixing Run-on Sentences, Jumbled Paragraphs & Narrative Writing"},
    {"unit": "Unit 3: Tourist Attractions (11 hrs)", "topics": "• Reading/Speaking: Tourism Industry in Ethiopia, Giving Directions, Describing Places\n• Grammar: Degrees of Comparison, Relative Clauses, Adverbs, Adjectives, Prepositions & Reported Speech\n• Writing: Fixing Dangling Modifiers, Formal Business Letters & Expository Essays"},
    {"unit": "Unit 4: Global Warming (11 hrs)", "topics": "• Reading/Speaking: Effects of Global Warming, Cause & Effect, Debate, Skimming & Scanning\n• Grammar: Tenses Revision, Quantifiers (many, much, few, little), Articles, Conjunctions & Relative Pronouns\n• Vocabulary & Writing: Synonyms/Antonyms, Analogy, Faulty Parallelism, Reports & CV/Application Letters"},
    {"unit": "Unit 5: Time Management (10 hrs)", "topics": "• Reading/Speaking: Time Management & Productivity, Expressing Result, Opinion & Purpose\n• Grammar: Future Forms, Sentence Types (Simple, Compound, Complex), Gerunds/Infinitives & Wishes\n• Writing: Memos, Formal Letters & Argumentative Essays"},
    {"unit": "Unit 6: Indigenous Conflict Resolution (10 hrs)", "topics": "• Reading/Speaking: Conflict Resolution Strategies, Interviews & Panel Discussions\n• Vocabulary: Word Formation (Prefixes/Suffixes), Idioms, Homophones & Phrasal Verbs (get, do, make)\n• Grammar & Writing: Expressing Purpose (so as to, in order to, so that), Regrets, Clauses of Result & Interpreting Charts"},
  ],
  "Geography": [
    {"unit": "Unit 1: Foundations of Geography and Geographic Inquiry (8 hrs)", "topics": "• Meaning, Scope & Branches of Geography\n• Map Components, Scale Conversion, Distance/Area Measurement, Relief Representation & GIS"},
    {"unit": "Unit 2: Physical Geography of Ethiopia and Africa (25 hrs)", "topics": "• Geological Time Scale, Continental Drift, Landforms of Ethiopia & Africa\n• Weather & Climate, Agro-climatic Zones of Ethiopia, Climate Change Adaptation & Mitigation\n• Natural Resources, Drainage Systems, Water & Biotic Resources of Ethiopia, Resource Conflicts"},
    {"unit": "Unit 3: Population Geography and Human-Environment Interactions (11 hrs)", "topics": "• World, African & Ethiopian Population Trends, Fertility, Mortality & Migration\n• Settlement Patterns, Population Theories (Malthusian, Boserup) & Population Policies"},
    {"unit": "Unit 4: Economic Geography and Development (12 hrs)", "topics": "• Economic Activities, Ethiopian Agriculture, Trade, Transport & Tourism\n• African Economic Challenges, Landlocked Countries, Sustainable Development, Poverty & Globalization"},
    {"unit": "Unit 5: Contemporary Geographic Issues and Public Concerns (8 hrs)", "topics": "• Environmental Degradation, Unplanned Urbanization, Migration, Coastal Pollution, Drought & Famine"},
  ],
  "History": [
    {"unit": "Unit 1: Introduction to History (6 hrs)", "topics": "• Definition & Uses of History, Historical Methods, Origin of Humans, State Emergence & Major Civilizations"},
    {"unit": "Unit 2: State Formation & Population Movements in the Horn till 17th C. (9 hrs)", "topics": "• Punt, Da'amet, Aksum, Zagwe, Bizamo, Damot, Enarya, Gafat & Muslim Sultanates\n• Interstate Conflicts, Population Movements & The Gada System of the Oromo"},
    {"unit": "Unit 3: The Modern World since 1500 (10 hrs)", "topics": "• Renaissance, Reformation, Scientific & Industrial Revolutions\n• English, American & French Revolutions, Napoleonic Era, Unification of Italy/Germany & Eastern Question"},
    {"unit": "Unit 4: The Gondarian Period (5 hrs)", "topics": "• Jesuits in Ethiopia, Gondar Socio-Political Developments, Yejju Dynasty, Zemene Mesafint & Southern/Eastern Polities"},
    {"unit": "Unit 5: Africa and the Outside World to 1900 (6 hrs)", "topics": "• Trans-Atlantic Slave Trade, Legitimate Trade, Scramble for Africa & Colonial Rule Impacts"},
    {"unit": "Unit 6: Formation of the Modern State of Ethiopia: 1855-1941 (9 hrs)", "topics": "• Unification & Modernization, Battles of Gundet, Gura, Mettema, Adwa & The 1935 Italian Invasion"},
    {"unit": "Unit 7: Major Global Developments of the World (12 hrs)", "topics": "• WWI & WWII, 1917 Russian Revolution, Formation of the UNO & The Cold War"},
    {"unit": "Unit 8: African Move Towards Independence (9 hrs)", "topics": "• Anti-Colonial Resistance, Decolonization, Liberation Struggles, Pan-Africanism & OAU"},
    {"unit": "Unit 9: Ethiopia Since Liberation (12 hrs)", "topics": "• British & American Eras, Eritrean Question, Opposition to Imperial Regime, Dergue Era, Post-1991 & Indigenous Heritages"},
  ],
};

Map getDefaultSchedule() {
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
  final TextEditingController oldIdCtrl = TextEditingController();
  String selectedStream = 'Natural';
  bool isSaving = false;

  Future registerUser() async {
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
        final snap = await FirebaseDatabase.instance.ref("students").get().timeout(const Duration(seconds: 6));
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
          DatabaseReference ref = FirebaseDatabase.instance.ref("students/$deviceId");
          await ref.set({
            "full_name": enteredName,
            "stream": selectedStream,
            "status": finalStatus,
            "short_id": shortId,
            "registered_at": DateTime.now().toIso8601String(),
          }).timeout(const Duration(seconds: 6));
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
            const CircleAvatar(radius: 42, backgroundColor: Colors.amber, child: Icon(Icons.school, size: 46, color: Colors.black)),
            const SizedBox(height: 16),
            const Text("እንኳን ወደ Remedial Matrix በሰላም መጡ! 🌟\nለመጀመር መረጃዎትን ይሙሉ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "ሙሉ ስም (Full Name)",
                hintText: "ከዚህ በፊት የተመዘገቡበትን ስም ያስገቡ",
                filled: true,
                fillColor: const Color(0xFF1A1E2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person, color: Colors.amber),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: oldIdCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "የድሮ መለያ ቁጥር / Old ID (ካለዎት ብቻ)",
                hintText: "አዲስ ተማሪ ከሆኑ ይህንን ባዶ ይተዉት",
                filled: true,
                fillColor: const Color(0xFF1A1E2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge_outlined, color: Colors.cyanAccent),
              ),
            ),
            const SizedBox(height: 18),
            const Text("የጥናት መስመር (Stream):", style: TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving ? null : registerUser,
              child: isSaving ? const CircularProgressIndicator(color: Colors.black) : const Text("Get Started / Restore Account 🚀", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
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
    String stream = prefs.getString('local_stream') ?? 'Natural';
    String dayName = getDayName(DateTime.now().weekday);
    Map streamMap = getDefaultSchedule()[stream] ?? {};
    String defaultToday = (streamMap[dayName] ?? "").toString();

    setState(() {
      userShortId = prefs.getInt('local_short_id') ?? 0;
      userName = prefs.getString('local_name') ?? 'Student';
      userStream = stream;
      todayScheduleCourse = defaultToday;
    });

    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/schedule/$stream/$dayName").get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value != null && mounted) {
        setState(() => todayScheduleCourse = snap.value.toString());
      }
    } catch (_) {}
  }

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
                "የ Remedial Matrix አዲስ ቨርሽን ($latestVersion) ተለቋል!\n\nእባክዎ አዲሱን አፕሊኬሽን በማውረድ ይጫኑት (ከዚህ በፊት VIP ከነበሩ ስምዎን ሲያስገቡ በራሱ VIP ይመልስልዎታል)።",
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  onPressed: () => launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.download, color: Colors.black),
                  label: const Text("Update Now (አውርድ)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {}
  }

  Future _checkTargetedBroadcast() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isVIP = appStatus == 'vip';
      List channels = ['all', isVIP ? 'vip' : 'free'];

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

  Future _checkDailyStudyNotification() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String todayKey = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      String lastShownDay = prefs.getString('last_study_prompt_day') ?? '';

      String dayName = getDayName(DateTime.now().weekday);
      Map streamMap = getDefaultSchedule()[userStream] ?? {};
      String todayCourse = todayScheduleCourse.isNotEmpty
          ? todayScheduleCourse
          : (streamMap[dayName] ?? "General Revision").toString();

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
                Expanded(child: Text("📅 የዛሬው የጥናት ፕሮግራም (2019 Syllabus)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
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
                  child: Text(todayCourse, style: const TextStyle(color: Colors.greenAccent, fontSize: 14.5, fontWeight: FontWeight.bold, height: 1.4)),
                ),
                const SizedBox(height: 14),
                const Text("ዛሬ ይህንን የ2019 ሪሚዲያል ኮርስ ርዕስ አንብበዋል? ካላነበቡ አሁኑኑ ጥናትዎን ይጀምሩ!", style: TextStyle(color: Colors.white70, fontSize: 13.5)),
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
                  await prefs.setBool('study_done_${userStream}_$dayName', true);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("👏 በጣም ጎበዝ! የዛሬው የጥናት ፕሮግራም ተመዝግቧል!"), backgroundColor: Colors.green));
                  }
                },
                icon: const Icon(Icons.check_circle, color: Colors.black, size: 18),
                label: const Text("አዎ አንብቤያለሁ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        todayCourse: todayScheduleCourse,
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
                Text('2019 MoE Curriculum Platform', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
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
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule & Outline'),
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
  final String todayCourse;
  final VoidCallback refreshCallback;
  final Function(String) onStatusChange;

  const HomeContent({
    Key? key,
    required this.isVIP,
    required this.appStatus,
    required this.userShortId,
    required this.userName,
    required this.userStream,
    required this.todayCourse,
    required this.refreshCallback,
    required this.onStatusChange,
  }) : super(key: key);

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
    Map streamMap = getDefaultSchedule()[userStream] ?? {};
    String displaySubject = todayCourse.isNotEmpty
        ? todayCourse
        : (streamMap[todayDay] ?? "General Study").toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const Text("Remedial Matrix", style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("📚 የዛሬ ጥናት (${getAmharicDay(todayDay)})፦\n$displaySubject", style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
              _buildGridItem(context, "📅 ፕሮግራም & Outline", "2019 All Courses", Icons.calendar_month_rounded, Colors.cyanAccent, false, () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScheduleScreen(userStream: userStream)))),
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

class StudyScheduleScreen extends StatefulWidget {
  final String userStream;
  const StudyScheduleScreen({Key? key, required this.userStream}) : super(key: key);
  @override
  _StudyScheduleScreenState createState() => _StudyScheduleScreenState();
}

class _StudyScheduleScreenState extends State<StudyScheduleScreen> {
  late String selectedStream;
  Map scheduleData = {};
  Map completedDays = {};
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
    Map defaultMap = Map.from(getDefaultSchedule()[selectedStream] ?? {});

    try {
      final snap = await FirebaseDatabase.instance.ref("admin_content/schedule/$selectedStream").get().timeout(const Duration(seconds: 4));
      if (snap.exists && snap.value is Map) {
        Map remote = snap.value as Map;
        remote.forEach((k, v) {
          defaultMap[k.toString()] = v.toString();
        });
      }
    } catch (_) {}

    Map tempCompleted = {};
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
    bool current = completedDays[day] == true;
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
            const SizedBox(width: 10),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.calendar_today, size: 18), text: "ሳምንታዊ ፕሮግራም"),
              Tab(icon: Icon(Icons.menu_book, size: 18), text: "2019 Course Outline"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
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
                          color: isToday ? const Color(0xFF232B45) : const Color(0xFF181B28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isToday ? Colors.amber : Colors.white12, width: isToday ? 2 : 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(course, style: const TextStyle(color: Colors.greenAccent, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4)),
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

            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: streamSubjects.length,
              itemBuilder: (context, idx) {
                String subject = streamSubjects[idx];
                List units = (officialCourseOutlines[subject] as List?) ?? [];
                return Card(
                  color: const Color(0xFF181B28),
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
                  child: ExpansionTile(
                    collapsedIconColor: Colors.amber,
                    iconColor: Colors.cyanAccent,
                    leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.auto_stories, color: Colors.black)),
                    title: Text("$subject Syllabus", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text("${units.length} Official MoE Units", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    children: units.map<Widget>((u) {
                      Map unitMap = u as Map;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((unitMap["unit"] ?? "").toString(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text((unitMap["topics"] ?? "").toString(), style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
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
              label: const Text("📅 የ2019 ፕሮግራም & የዕለቱ ማሳሰቢያ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    Map streamMap = getDefaultSchedule()[selectedStream] ?? {};
    courseCtrl.text = (streamMap[selectedDay] ?? "").toString();
  }

  Future saveAndNotifySchedule({required bool sendPushAlert}) async {
    if (courseCtrl.text.trim().isEmpty) return;
    setState(() => isSaving = true);
    try {
      String courseText = courseCtrl.text.trim();
      await FirebaseDatabase.instance.ref("admin_content/schedule/$selectedStream/$selectedDay").set(courseText);

      if (sendPushAlert) {
        int now = DateTime.now().millisecondsSinceEpoch;
        Map<String, dynamic> alertData = {
          "title": "📅 የዛሬ የጥናት ማሳሰቢያ (${getAmharicDay(selectedDay)})",
          "message": "ውድ የ $selectedStream ተማሪዎች፣ የዛሬው የ2019 ሪሚዲያል የጥናት ፕሮግራም፦\n\n【 $courseText 】\n\nዛሬ ይህንን ኮርስ አንብበዋል? ካላነበቡ አሁኑኑ ይጀምሩ!",
          "time": now,
        };
        await FirebaseDatabase.instance.ref("announcements/all").set(alertData);
        await FirebaseDatabase.instance.ref("announcement").set(alertData);
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
    List subjectUnits = (officialCourseOutlines[selectedSubjectForPicker] as List?) ?? [];
    List<String> subjectKeys = officialCourseOutlines.keys.map((k) => k.toString()).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("📅 የ2019 ፕሮግራም ማስተካከያ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. የጥናት መስመር (Stream) እና ቀን ይምረጡ፦", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
                          Map streamMap = getDefaultSchedule()[selectedStream] ?? {};
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
                    dropdownColor: const Color(0xFF1E2235),
                    decoration: const InputDecoration(labelText: "Day", border: OutlineInputBorder()),
                    items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedDay = val;
                          Map streamMap = getDefaultSchedule()[selectedStream] ?? {};
                          courseCtrl.text = (streamMap[selectedDay] ?? "").toString();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text("2. ከ2019 Course Outline ላይ ርዕስ ይምረጡ (Quick Select)፦", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedSubjectForPicker,
              dropdownColor: const Color(0xFF1E2235),
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
                  Map uMap = subjectUnits[i] as Map;
                  String uTitle = (uMap["unit"] ?? "").toString();
                  String uTopics = (uMap["topics"] ?? "").toString();
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
                        color: const Color(0xFF181B28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(uTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Expanded(child: Text(uTopics, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                          const Text("👉 ይህን ለመምረጥ ይጫኑ", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
              decoration: const InputDecoration(
                labelText: "የዕለቱ የሚጠናው ኮርስ ዝርዝር",
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

  Future sendBroadcast() async {
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
      await FirebaseDatabase.instance.ref("announcements/$targetAudience").set(payload);
      if (targetAudience == 'all') {
        await FirebaseDatabase.instance.ref("announcement").set(payload);
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
    TextEditingController verCtrl = TextEditingController(text: "1.1.0");
    TextEditingController urlCtrl = TextEditingController(text: "https://t.me/ADDIS_REMEDIAL");
    return Scaffold(
      appBar: AppBar(title: const Text("🚀 አዲስ Update ልቀቅ")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          const Text("ይህንን ቁልፍ ስትጫን የድሮውን አፕ (1.0.0) የሚጠቀሙ ተማሪዎች ሁሉ አዲሱን (1.1.0) ከቴሌግራም እንዲያወርዱ ወዲያውኑ ያስገድዳቸዋል!", style: TextStyle(color: Colors.amber)),
          const SizedBox(height: 20),
          TextField(controller: verCtrl, decoration: const InputDecoration(labelText: "አዲሱ ቨርሽን (ምሳሌ: 1.1.0)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "የማውረጃ ሊንክ (የቴሌግራም ቻናል ሊንክ)", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(double.infinity, 50)),
            onPressed: () async {
              if (verCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                await FirebaseDatabase.instance.ref("admin_settings/update").set({"version": verCtrl.text.trim(), "url": urlCtrl.text.trim()});
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
