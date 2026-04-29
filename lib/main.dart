import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:math';

// ════════════════════════════════════════════
//  ENTRY POINT
// ════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MySchoolApp());
}

// ════════════════════════════════════════════
//  THEME & CONSTANTS
// ════════════════════════════════════════════
class AppColors {
  static const primary    = Color(0xFF1A1F5E);
  static const accent     = Color(0xFF4F67FF);
  static const gold       = Color(0xFFFFB830);
  static const success    = Color(0xFF2EC87E);
  static const danger     = Color(0xFFFF4D6A);
  static const surface    = Color(0xFFF5F6FF);
  static const textDark   = Color(0xFF1A1F5E);
  static const textGrey   = Color(0xFF7D8AA3);
  static const adminGrad  = [Color(0xFF1A1F5E), Color(0xFF4F67FF)];
  static const teachGrad  = [Color(0xFFFF6B35), Color(0xFFFFB830)];
  static const parentGrad = [Color(0xFF11998E), Color(0xFF38EF7D)];
  static const purpleGrad = [Color(0xFF9B5DE5), Color(0xFFD66BF0)];
  static const pinkGrad   = [Color(0xFFFF4D6A), Color(0xFFFF8FA0)];
}

class AppText {
  static const cardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark);
  static const label     = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textGrey);
  static const sectionHd = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark);
}

// ════════════════════════════════════════════
//  ROOT APP
// ════════════════════════════════════════════
class MySchoolApp extends StatelessWidget {
  const MySchoolApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SchoolHub',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
      scaffoldBackgroundColor: AppColors.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4E7F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE4E7F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    ),
    home: const AuthGate(),
  );
}

// ════════════════════════════════════════════
//  AUTH GATE
// ════════════════════════════════════════════
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (_, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snap.hasData ? const RoleRouter() : const LoginPage();
    });
}

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const LoginPage();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final role = (snap.data?.data() as Map?)?['role'] ?? '';
        if (role == 'admin')   return const AdminDashboard();
        if (role == 'teacher') return const TeacherDashboard();
        if (role == 'student' || role == 'parent') return const StudentDashboard();
        return const LoginPage();
      });
  }
}

// ════════════════════════════════════════════
//  LOGIN PAGE
// ════════════════════════════════════════════
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  bool _loading = false, _obscure = true;
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) { _snack('Fill all fields', err: true); return; }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'user-not-found' ? 'No account found'
          : e.code == 'wrong-password' ? 'Incorrect password'
          : 'Login failed: ${e.message}', err: true);
      setState(() => _loading = false);
    } catch (_) { _snack('Login failed. Try again.', err: true); setState(() => _loading = false); }
  }

  void _snack(String msg, {bool err = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: err ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: AppColors.adminGrad, begin: Alignment.topLeft, end: Alignment.bottomRight))),
      Positioned(top: -60, right: -60, child: _dot(200, 0.06)),
      Positioned(top: 90, left: -40, child: _dot(140, 0.06)),
      Positioned(bottom: -80, left: -30, child: _dot(260, 0.06)),
      SafeArea(child: FadeTransition(opacity: _fade,
        child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(children: [
          const SizedBox(height: 36),
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.3))),
            child: const Icon(Icons.school_rounded, size: 42, color: Colors.white)),
          const SizedBox(height: 18),
          const Text('SchoolHub', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: -1)),
          const Text('Complete School Management', style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 44),
          Container(padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 40, offset: const Offset(0, 16))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const Text('Sign in to continue', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 24),
              _lbl('Email'), const SizedBox(height: 6),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'you@school.edu',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.textGrey))),
              const SizedBox(height: 16),
              _lbl('Password'), const SizedBox(height: 6),
              TextField(controller: _pass, obscureText: _obscure, onSubmitted: (_) => _login(),
                  decoration: InputDecoration(hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textGrey),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textGrey),
                        onPressed: () => setState(() => _obscure = !_obscure)))),
              const SizedBox(height: 28),
              SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
            ])),
          const SizedBox(height: 24),
          const Text('Contact your school admin for credentials',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ])))),
    ]));
  Widget _dot(double s, double o) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(o)));
  Widget _lbl(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w600,
      fontSize: 13, color: AppColors.textDark));
}

// ════════════════════════════════════════════
//  REUSABLE WIDGETS
// ════════════════════════════════════════════
class GradAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; final String? subtitle;
  final List<Color> colors; final List<Widget>? actions; final bool showBack;
  const GradAppBar({super.key, required this.title, this.subtitle,
      required this.colors, this.actions, this.showBack = false});
  @override Size get preferredSize => const Size.fromHeight(70);
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(colors: colors,
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(children: [
        if (showBack) IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context)),
        if (!showBack) const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ]))));
}

Widget logoutBtn(BuildContext context) => IconButton(
  icon: Container(padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.logout_rounded, color: Colors.white, size: 18)),
  onPressed: () async {
    final ok = await _confirmDialog(context, 'Sign Out', 'Are you sure you want to sign out?');
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(context, _slide(const LoginPage()), (_) => false);
    }
  });

Widget statCard(String label, String value, IconData icon, Color color, {bool last = false}) =>
  Expanded(child: Container(
    margin: EdgeInsets.only(right: last ? 0 : 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: AppText.label),
    ])));

Widget sectionHeader(String title, {Widget? trailing}) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(title, style: AppText.sectionHd),
    if (trailing != null) trailing,
  ]);

class _ActionCard extends StatefulWidget {
  final String title, sub; final IconData icon; final Color color; final VoidCallback onTap;
  const _ActionCard({required this.title, required this.sub, required this.icon,
      required this.color, required this.onTap});
  @override State<_ActionCard> createState() => _ActionCardState();
}
class _ActionCardState extends State<_ActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override void initState() { super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 80),
        lowerBound: 0.97, upperBound: 1.0, value: 1.0); }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ac.reverse(), onTapUp: (_) { _ac.forward(); widget.onTap(); },
    onTapCancel: () => _ac.forward(),
    child: ScaleTransition(scale: _ac, child: Container(margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(widget.icon, color: widget.color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: AppText.cardTitle),
          Text(widget.sub, style: AppText.label),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.color.withOpacity(0.5)),
      ]))));
}

Widget actionCard(BuildContext ctx, String title, String sub, IconData icon,
    Color color, VoidCallback onTap) =>
  _ActionCard(title: title, sub: sub, icon: icon, color: color, onTap: onTap);

PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
    transitionDuration: const Duration(milliseconds: 260));

void _push(BuildContext ctx, Widget page) => Navigator.push(ctx, _slide(page));

Future<bool?> _confirmDialog(BuildContext ctx, String title, String content) =>
  showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title), content: Text(content),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
    ]));

Widget _field(String label, TextEditingController ctrl, IconData icon,
    {TextInputType type = TextInputType.text, bool obscure = false, int maxLines = 1}) =>
  Padding(padding: const EdgeInsets.only(bottom: 14),
    child: TextField(controller: ctrl, keyboardType: type, obscureText: obscure, maxLines: maxLines,
      decoration: InputDecoration(labelText: label,
          prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20))));

class _EmptyState extends StatelessWidget {
  final String label; final IconData? icon;
  const _EmptyState({required this.label, this.icon});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon ?? Icons.inbox_rounded, size: 64, color: AppColors.textGrey.withOpacity(0.3)),
      const SizedBox(height: 12),
      Text(label, style: TextStyle(color: AppColors.textGrey.withOpacity(0.7),
          fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    ]));
}

class _PersonCard extends StatelessWidget {
  final String name, sub, email, uid; final Color color;
  final String? photo; final VoidCallback onEdit, onDelete, onTap;
  const _PersonCard({required this.name, required this.sub, required this.email,
      required this.color, required this.uid, this.photo,
      required this.onEdit, required this.onDelete, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.15),
          backgroundImage: (photo != null && photo!.isNotEmpty) ? NetworkImage(photo!) : null,
          child: (photo == null || photo!.isEmpty) ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 17)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: AppText.cardTitle),
          Text(sub, style: AppText.label),
          Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ])),
        IconButton(icon: const Icon(Icons.edit_rounded, color: AppColors.accent, size: 20), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20), onPressed: onDelete),
      ])));
}

// ════════════════════════════════════════════
//  ATTENDANCE RING WIDGET
// ════════════════════════════════════════════
class AttendanceRing extends StatelessWidget {
  final int present, total; final double size;
  const AttendanceRing({super.key, required this.present, required this.total, this.size = 100});
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? present / total : 0.0;
    final color = pct > 0.75 ? AppColors.success : pct > 0.5 ? AppColors.gold : AppColors.danger;
    return SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: Size(size, size), painter: _RingPainter(pct, color)),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${(pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: size * 0.2, fontWeight: FontWeight.w900, color: color)),
        Text('Present', style: TextStyle(fontSize: size * 0.1, color: AppColors.textGrey)),
      ]),
    ]));
  }
}
class _RingPainter extends CustomPainter {
  final double pct; final Color color;
  _RingPainter(this.pct, this.color);
  @override
  void paint(Canvas c, Size s) {
    final ct = Offset(s.width / 2, s.height / 2); final r = (s.width - 16) / 2; const sw = 10.0;
    c.drawCircle(ct, r, Paint()..color = color.withOpacity(0.12)..strokeWidth = sw..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    c.drawArc(Rect.fromCircle(center: ct, radius: r), -pi / 2, 2 * pi * pct, false,
        Paint()..color = color..strokeWidth = sw..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_) => true;
}

// ════════════════════════════════════════════
//  FEATURE FLAGS
// ════════════════════════════════════════════
class FeatureFlags {
  static const _doc = 'settings/features';
  static Future<Map<String, bool>> get() async {
    final doc = await FirebaseFirestore.instance.doc(_doc).get();
    final d = doc.data() as Map? ?? {};
    return {
      'teacher_homework': d['teacher_homework'] ?? true,
      'teacher_ebooks': d['teacher_ebooks'] ?? true,
      'teacher_announcements': d['teacher_announcements'] ?? true,
      'teacher_reports': d['teacher_reports'] ?? true,
      'teacher_messages': d['teacher_messages'] ?? true,
      'teacher_face_attendance': d['teacher_face_attendance'] ?? true,
      'teacher_timetable': d['teacher_timetable'] ?? true,
      'parent_homework': d['parent_homework'] ?? true,
      'parent_ebooks': d['parent_ebooks'] ?? true,
      'parent_messages': d['parent_messages'] ?? true,
      'parent_timetable': d['parent_timetable'] ?? true,
      'parent_results': d['parent_results'] ?? true,
      'parent_announcements': d['parent_announcements'] ?? true,
    };
  }
  static Future<void> set(Map<String, bool> flags) =>
      FirebaseFirestore.instance.doc(_doc).set(flags, SetOptions(merge: true));
}

// ════════════════════════════════════════════
//  ADMIN DASHBOARD
// ════════════════════════════════════════════
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    const pages = [_AdminHome(), _AdminAcademic(), _AdminPeople(), _AdminSettings()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
        child: BottomNavigationBar(
          currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed, elevation: 0, backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.accent, unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.school_rounded), label: 'Academic'),
            BottomNavigationBarItem(icon: Icon(Icons.groups_rounded), label: 'People'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ])));
  }
}

// ── Admin Home ──────────────────────────────
class _AdminHome extends StatelessWidget {
  const _AdminHome();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(body: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: AppColors.adminGrad,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
        padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (_, s) {
                final d = s.data?.data() as Map? ?? {};
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Good day 👋', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  Text(d['name'] ?? 'Admin', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const Text('School Administrator', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ]);
              }),
            Row(children: [
              IconButton(
                icon: Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18)),
                onPressed: () => _push(context, const SendNotificationPage())),
              logoutBtn(context),
            ]),
          ]),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (_, s) {
              final docs = s.data?.docs ?? [];
              final t = docs.where((d) => (d.data() as Map?)?['role'] == 'teacher').length;
              final st = docs.where((d) => (d.data() as Map?)?['role'] == 'student').length;
              return Row(children: [
                _hStat('Teachers', t.toString(), Icons.person_rounded),
                const SizedBox(width: 10),
                _hStat('Students', st.toString(), Icons.school_rounded),
                const SizedBox(width: 10),
                _hStat('Total', (t + st).toString(), Icons.people_rounded),
              ]);
            }),
        ]))),
      SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList(delegate: SliverChildListDelegate([
        sectionHeader('Quick Access'), const SizedBox(height: 14),
        Row(children: [
          _qCard(context, 'Add Teacher', Icons.person_add_rounded, AppColors.accent, () => _push(context, const AddTeacherPage())),
          _qCard(context, 'Add Student', Icons.group_add_rounded, AppColors.success, () => _push(context, const AddStudentPage())),
        ]),
        Row(children: [
          _qCard(context, 'Bulk Import', Icons.upload_file_rounded, AppColors.gold, () => _push(context, const BulkImportPage())),
          _qCard(context, 'Timetable', Icons.calendar_view_week_rounded, const Color(0xFF9B5DE5), () => _push(context, const AdminTimetablePage())),
        ]),
        Row(children: [
          _qCard(context, 'Attendance', Icons.how_to_reg_rounded, AppColors.success, () => _push(context, const ViewAttendancePage())),
          _qCard(context, 'Teacher Att.', Icons.fact_check_rounded, const Color(0xFFFF6B35), () => _push(context, const TeacherAttendancePage(isAdmin: true))),
        ]),
        Row(children: [
          _qCard(context, 'Results', Icons.assessment_rounded, AppColors.danger, () => _push(context, const StudentReportsPage())),
          _qCard(context, 'Announce', Icons.campaign_rounded, const Color(0xFF9B5DE5), () => _push(context, const AnnouncementsPage(canPost: true))),
        ]),
        Row(children: [
          _qCard(context, 'E-Books', Icons.library_books_rounded, AppColors.accent, () => _push(context, const EBooksPage(canUpload: true))),
          _qCard(context, 'Messages', Icons.message_rounded, const Color(0xFF11998E), () => _push(context, const MessagesListPage())),
        ]),
        const SizedBox(height: 20),
        sectionHeader('Recent Activity'), const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('activity_log')
              .orderBy('timestamp', descending: true).limit(8).snapshots(),
          builder: (_, s) {
            if (!s.hasData || s.data!.docs.isEmpty) return const _EmptyState(label: 'No recent activity');
            return Column(children: s.data!.docs.map((doc) {
              final d = doc.data() as Map;
              return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const CircleAvatar(radius: 16, backgroundColor: Color(0xFFEEF1FF),
                      child: Icon(Icons.history_rounded, color: AppColors.accent, size: 14)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['message'] ?? '', style: AppText.cardTitle.copyWith(fontSize: 13)),
                    Text(_timeAgo(d['timestamp']), style: AppText.label),
                  ])),
                ]));
            }).toList());
          }),
      ]))),
    ]));
  }
  Widget _hStat(String l, String v, IconData i) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Icon(i, color: Colors.white, size: 18), const SizedBox(height: 4),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ])));
  Widget _qCard(BuildContext ctx, String label, IconData icon, Color color, VoidCallback onTap) =>
    Expanded(child: GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
      ]))));
}

// ── Admin Academic ────────────────────────────
class _AdminAcademic extends StatelessWidget {
  const _AdminAcademic();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Academic', subtitle: 'Classes, timetable & records', colors: AppColors.adminGrad),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      actionCard(context, 'Manage Classes', 'Add, edit, delete classes & sections',
          Icons.class_rounded, AppColors.accent, () => _push(context, const AdminClassesPage())),
      actionCard(context, 'Timetable', 'Set lecture schedules for each class',
          Icons.calendar_view_week_rounded, const Color(0xFF9B5DE5), () => _push(context, const AdminTimetablePage())),
      actionCard(context, 'Student Attendance', 'View attendance by date & class',
          Icons.how_to_reg_rounded, AppColors.success, () => _push(context, const ViewAttendancePage())),
      actionCard(context, 'Teacher Attendance', 'Track teacher presence records',
          Icons.fact_check_rounded, const Color(0xFFFF6B35), () => _push(context, const TeacherAttendancePage(isAdmin: true))),
      actionCard(context, 'Semester Results', 'View & manage all exam results',
          Icons.assessment_rounded, AppColors.danger, () => _push(context, const StudentReportsPage())),
      actionCard(context, 'Internal Test Results', 'Unit/internal exam scores overview',
          Icons.quiz_rounded, AppColors.gold, () => _push(context, const InternalResultsPage())),
      actionCard(context, 'Homework', 'View all class homework',
          Icons.assignment_rounded, AppColors.accent, () => _push(context, const HomeworkPage(isTeacher: true))),
      actionCard(context, 'E-Books Library', 'Upload & manage books',
          Icons.library_books_rounded, const Color(0xFF9B5DE5), () => _push(context, const EBooksPage(canUpload: true))),
      actionCard(context, 'Announcements', 'Post school notices with images',
          Icons.campaign_rounded, AppColors.danger, () => _push(context, const AnnouncementsPage(canPost: true))),
      actionCard(context, 'Send Notification', 'Push alert to specific class',
          Icons.notifications_rounded, const Color(0xFF11998E), () => _push(context, const SendNotificationPage())),
    ])));
}

// ── Admin People ─────────────────────────────
class _AdminPeople extends StatelessWidget {
  const _AdminPeople();
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 2,
    child: Scaffold(
      appBar: GradAppBar(title: 'People', subtitle: 'Manage teachers & students',
          colors: AppColors.adminGrad,
          actions: [
            IconButton(icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                onPressed: () => _push(context, const AddTeacherPage())),
            IconButton(icon: const Icon(Icons.group_add_rounded, color: Colors.white),
                onPressed: () => _push(context, const AddStudentPage())),
            IconButton(icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                onPressed: () => _push(context, const BulkImportPage())),
          ]),
      body: Column(children: [
        Container(color: AppColors.primary,
          child: const TabBar(labelColor: Colors.white, unselectedLabelColor: Colors.white54,
              indicatorColor: AppColors.gold,
              tabs: [Tab(text: 'Teachers'), Tab(text: 'Students')])),
        Expanded(child: TabBarView(children: [
          _PeopleList(role: 'teacher', color: const Color(0xFFFF6B35)),
          _PeopleList(role: 'student', color: AppColors.success),
        ])),
      ])));
}

class _PeopleList extends StatefulWidget {
  final String role; final Color color;
  const _PeopleList({required this.role, required this.color});
  @override State<_PeopleList> createState() => _PeopleListState();
}
class _PeopleListState extends State<_PeopleList> {
  String _search = '';
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(hintText: 'Search ${widget.role}s...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGrey)),
        onChanged: (v) => setState(() => _search = v.toLowerCase()))),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: widget.role).snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        var docs = s.data!.docs;
        if (_search.isNotEmpty) {
          docs = docs.where((d) {
          final data = d.data() as Map;
          return (data['name'] ?? '').toString().toLowerCase().contains(_search) ||
                 (data['email'] ?? '').toString().toLowerCase().contains(_search);
        }).toList();
        }
        if (docs.isEmpty) return _EmptyState(label: 'No ${widget.role}s found');
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map;
            return _PersonCard(
              name: d['name'] ?? '', uid: docs[i].id, color: widget.color,
              sub: widget.role == 'teacher'
                  ? '${d['subject'] ?? ''} • Class: ${d['assignedClass'] ?? 'N/A'}'
                  : 'Class: ${d['class'] ?? 'N/A'} • Roll: ${d['rollNo'] ?? 'N/A'}',
              email: d['email'] ?? '', photo: d['photoUrl'],
              onTap: () => _push(context, PersonDetailPage(uid: docs[i].id, isTeacher: widget.role == 'teacher')),
              onEdit: () => _push(context, EditPersonPage(uid: docs[i].id)),
              onDelete: () async {
                final ok = await _confirmDialog(context, 'Remove ${d['name']}?', 'This cannot be undone.');
                if (ok == true) await FirebaseFirestore.instance.collection('users').doc(docs[i].id).delete();
              });
          });
      })),
  ]);
}

// ── Admin Settings ────────────────────────────
class _AdminSettings extends StatelessWidget {
  const _AdminSettings();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: GradAppBar(title: 'Settings', colors: AppColors.adminGrad),
      body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
        actionCard(context, 'Edit My Profile', 'Update admin info & photo',
            Icons.manage_accounts_rounded, AppColors.accent, () => _push(context, EditPersonPage(uid: uid))),
        actionCard(context, 'Feature Control', 'Toggle features for teachers & parents',
            Icons.tune_rounded, const Color(0xFF9B5DE5), () => _push(context, const FeatureControlPage())),
        actionCard(context, 'Send Notification', 'Push alerts to specific classes',
            Icons.notifications_active_rounded, AppColors.gold, () => _push(context, const SendNotificationPage())),
        actionCard(context, 'Messages', 'Chat with any user',
            Icons.message_rounded, const Color(0xFF11998E), () => _push(context, const MessagesListPage())),
        const Divider(height: 32),
        actionCard(context, 'Sign Out', 'Logout from admin panel',
            Icons.logout_rounded, AppColors.danger, () async {
          final ok = await _confirmDialog(context, 'Sign Out', 'Are you sure?');
          if (ok == true) {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(context, _slide(const LoginPage()), (_) => false);
          }
        }),
      ])));
  }
}

// ════════════════════════════════════════════
//  ADMIN CLASSES PAGE
// ════════════════════════════════════════════
class AdminClassesPage extends StatelessWidget {
  const AdminClassesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Classes', subtitle: 'Manage all classes',
        colors: AppColors.adminGrad, showBack: true,
        actions: [IconButton(icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 26),
            onPressed: () => _showAddClassDialog(context))]),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('classes').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final classes = snap.data!.docs;
        if (classes.isEmpty) return const _EmptyState(label: 'No classes yet.\nTap + to add one.', icon: Icons.class_rounded);
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: classes.length,
          itemBuilder: (_, i) {
            final d = classes[i].data() as Map;
            final className = d['name'] ?? '';
            return GestureDetector(onTap: () => _push(context, ClassDetailPage(className: className)),
              child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(children: [
                  Container(width: 52, height: 52,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.adminGrad),
                        borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(className.length > 4 ? className.substring(0, 4) : className,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Class $className', style: AppText.cardTitle),
                    FutureBuilder<List<QuerySnapshot>>(
                      future: Future.wait([
                        FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('class', isEqualTo: className).get(),
                        FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').where('assignedClass', isEqualTo: className).get(),
                      ]),
                      builder: (_, s) {
                        if (!s.hasData) return Text('Loading...', style: AppText.label);
                        return Text('${s.data![0].docs.length} students  •  ${s.data![1].docs.length} teachers', style: AppText.label);
                      }),
                  ])),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textGrey),
                  IconButton(icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 18),
                      onPressed: () async {
                        final ok = await _confirmDialog(context, 'Delete Class $className?',
                            'Removes the class entry. Students/teachers are kept.');
                        if (ok == true) classes[i].reference.delete();
                      }),
                ])));
          });
      }));

  void _showAddClassDialog(BuildContext context) {
    final ctrl = TextEditingController(); final secCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Class'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Class name (e.g. 10-A)')),
        const SizedBox(height: 10),
        TextField(controller: secCtrl, decoration: const InputDecoration(labelText: 'Section (optional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.isNotEmpty) {
            await FirebaseFirestore.instance.collection('classes').add({
              'name': ctrl.text.trim(), 'section': secCtrl.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          Navigator.pop(context);
        }, child: const Text('Add')),
      ]));
  }
}

// ════════════════════════════════════════════
//  CLASS DETAIL PAGE
// ════════════════════════════════════════════
class ClassDetailPage extends StatelessWidget {
  final String className;
  const ClassDetailPage({super.key, required this.className});
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 3,
    child: Scaffold(
      appBar: GradAppBar(title: 'Class $className', colors: AppColors.adminGrad, showBack: true,
          actions: [
            IconButton(icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                onPressed: () => _push(context, AnnouncementsPage(canPost: true, targetClass: className))),
            IconButton(icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                onPressed: () => _push(context, SendNotificationPage(targetClass: className))),
          ]),
      body: Column(children: [
        Container(color: AppColors.primary,
          child: const TabBar(labelColor: Colors.white, unselectedLabelColor: Colors.white54,
              indicatorColor: AppColors.gold,
              tabs: [Tab(text: 'Students'), Tab(text: 'Teachers'), Tab(text: 'Subjects')])),
        Expanded(child: TabBarView(children: [
          // Students tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users')
                .where('role', isEqualTo: 'student').where('class', isEqualTo: className).snapshots(),
            builder: (_, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              if (docs.isEmpty) return const _EmptyState(label: 'No students in this class');
              return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map;
                  return _PersonCard(name: d['name'] ?? '',
                      sub: 'Roll: ${d['rollNo'] ?? 'N/A'} | Blood: ${d['bloodGroup'] ?? 'N/A'}',
                      email: d['email'] ?? '', color: AppColors.success, uid: docs[i].id, photo: d['photoUrl'],
                      onTap: () => _push(context, PersonDetailPage(uid: docs[i].id)),
                      onEdit: () => _push(context, EditPersonPage(uid: docs[i].id)),
                      onDelete: () async {
                        final ok = await _confirmDialog(context, 'Remove ${d['name']}?', 'Cannot be undone.');
                        if (ok == true) await FirebaseFirestore.instance.collection('users').doc(docs[i].id).delete();
                      });
                });
            }),
          // Teachers tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users')
                .where('role', isEqualTo: 'teacher').where('assignedClass', isEqualTo: className).snapshots(),
            builder: (_, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              if (docs.isEmpty) return const _EmptyState(label: 'No teachers assigned to this class');
              return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map;
                  return _PersonCard(name: d['name'] ?? '',
                      sub: '${d['subject'] ?? ''} • ${d['qualification'] ?? ''}',
                      email: d['email'] ?? '', color: const Color(0xFFFF6B35), uid: docs[i].id, photo: d['photoUrl'],
                      onTap: () => _push(context, PersonDetailPage(uid: docs[i].id, isTeacher: true)),
                      onEdit: () => _push(context, EditPersonPage(uid: docs[i].id)),
                      onDelete: () async {
                        final ok = await _confirmDialog(context, 'Remove ${d['name']}?', 'Cannot be undone.');
                        if (ok == true) await FirebaseFirestore.instance.collection('users').doc(docs[i].id).delete();
                      });
                });
            }),
          // Subjects tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users')
                .where('role', isEqualTo: 'teacher').where('assignedClass', isEqualTo: className).snapshots(),
            builder: (_, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs;
              if (docs.isEmpty) return const _EmptyState(label: 'No subjects for this class', icon: Icons.book_rounded);
              return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map;
                  return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.book_rounded, color: AppColors.accent, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['subject'] ?? 'N/A', style: AppText.cardTitle),
                        Text('Teacher: ${d['name'] ?? 'N/A'}', style: AppText.label),
                        Text('Employee ID: ${d['employeeId'] ?? 'N/A'}', style: AppText.label),
                      ])),
                      ElevatedButton(
                        onPressed: () => _push(context, MessageChatPage(otherUid: docs[i].id, otherName: d['name'] ?? '')),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF11998E), minimumSize: const Size(60, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10)),
                        child: const Text('Chat', style: TextStyle(fontSize: 12))),
                    ]));
                });
            }),
        ])),
      ])));
}

// ════════════════════════════════════════════
//  ADD TEACHER
// ════════════════════════════════════════════
class AddTeacherPage extends StatefulWidget {
  const AddTeacherPage({super.key});
  @override State<AddTeacherPage> createState() => _AddTeacherPageState();
}
class _AddTeacherPageState extends State<AddTeacherPage> {
  final _n = TextEditingController(); final _e = TextEditingController();
  final _s = TextEditingController(); final _p = TextEditingController();
  final _ph = TextEditingController(); final _cls = TextEditingController();
  final _photo = TextEditingController(); final _qual = TextEditingController();
  final _emp = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    if ([_n, _e, _s, _p].any((c) => c.text.isEmpty)) {
      _snack('Name, email, subject & password are required', err: true); return;
    }
    setState(() => _loading = true);
    try {
      final res = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _e.text.trim(), password: _p.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(res.user!.uid).set({
        'name': _n.text.trim(), 'email': _e.text.trim(), 'subject': _s.text.trim(),
        'phone': _ph.text.trim(), 'assignedClass': _cls.text.trim(),
        'qualification': _qual.text.trim(), 'employeeId': _emp.text.trim(),
        'photoUrl': _photo.text.trim(), 'role': 'teacher', 'uid': res.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _logActivity('Teacher "${_n.text}" added');
      if (!mounted) return;
      Navigator.pop(context); _snack('Teacher added successfully!');
    } on FirebaseAuthException catch (e) { _snack('Error: ${e.message}', err: true); }
    setState(() => _loading = false);
  }
  void _snack(String msg, {bool err = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: err ? AppColors.danger : AppColors.success, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'Add Teacher', colors: AppColors.adminGrad, showBack: true),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      _field('Full Name *', _n, Icons.person_outline),
      _field('Email *', _e, Icons.email_outlined, type: TextInputType.emailAddress),
      _field('Subject *', _s, Icons.book_outlined),
      _field('Employee ID', _emp, Icons.badge_rounded),
      _field('Phone', _ph, Icons.phone_outlined, type: TextInputType.phone),
      _field('Qualification', _qual, Icons.school_outlined),
      _field('Assigned Class (e.g. 10-A)', _cls, Icons.class_outlined),
      _field('Photo URL', _photo, Icons.image_outlined),
      _field('Default Password *', _p, Icons.lock_outline, obscure: true),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
          onPressed: _loading ? null : _register,
          child: _loading ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Create Teacher Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
    ])));
}

// ════════════════════════════════════════════
//  ADD STUDENT
// ════════════════════════════════════════════
class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});
  @override State<AddStudentPage> createState() => _AddStudentPageState();
}
class _AddStudentPageState extends State<AddStudentPage> {
  final _n = TextEditingController(); final _e = TextEditingController();
  final _cls = TextEditingController(); final _roll = TextEditingController();
  final _p = TextEditingController(); final _par = TextEditingController();
  final _parPh = TextEditingController(); final _parEmail = TextEditingController();
  final _dob = TextEditingController(); final _addr = TextEditingController();
  final _blood = TextEditingController(); final _photo = TextEditingController();
  final _admNo = TextEditingController();
  bool _loading = false;

  Future<void> _register() async {
    if ([_n, _e, _cls, _p].any((c) => c.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name, email, class & password required'), backgroundColor: AppColors.danger)); return;
    }
    setState(() => _loading = true);
    try {
      final res = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _e.text.trim(), password: _p.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(res.user!.uid).set({
        'name': _n.text.trim(), 'email': _e.text.trim(), 'class': _cls.text.trim(),
        'rollNo': _roll.text.trim(), 'admissionNo': _admNo.text.trim(),
        'parentName': _par.text.trim(), 'parentPhone': _parPh.text.trim(), 'parentEmail': _parEmail.text.trim(),
        'dob': _dob.text.trim(), 'address': _addr.text.trim(), 'bloodGroup': _blood.text.trim(),
        'photoUrl': _photo.text.trim(), 'role': 'student', 'uid': res.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _logActivity('Student "${_n.text}" enrolled in Class ${_cls.text}');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Student enrolled!'), backgroundColor: AppColors.success));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.message}'), backgroundColor: AppColors.danger));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'Enroll Student', colors: AppColors.adminGrad, showBack: true),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      _field('Full Name *', _n, Icons.person_outline),
      _field('Email *', _e, Icons.email_outlined, type: TextInputType.emailAddress),
      _field('Class (e.g. 10-A) *', _cls, Icons.class_outlined),
      _field('Roll Number', _roll, Icons.tag_rounded, type: TextInputType.number),
      _field('Admission Number', _admNo, Icons.numbers_rounded),
      _field("Parent's Name", _par, Icons.family_restroom_rounded),
      _field("Parent's Phone", _parPh, Icons.phone_outlined, type: TextInputType.phone),
      _field("Parent's Email", _parEmail, Icons.email_outlined, type: TextInputType.emailAddress),
      _field('Date of Birth (DD/MM/YYYY)', _dob, Icons.cake_rounded),
      _field('Blood Group', _blood, Icons.bloodtype_rounded),
      _field('Address', _addr, Icons.home_rounded, maxLines: 2),
      _field('Photo URL', _photo, Icons.image_outlined),
      _field('Default Password *', _p, Icons.lock_outline, obscure: true),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
          onPressed: _loading ? null : _register,
          child: _loading ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Enroll Student', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
    ])));
}

// ════════════════════════════════════════════
//  BULK IMPORT
// ════════════════════════════════════════════
class BulkImportPage extends StatefulWidget {
  const BulkImportPage({super.key});
  @override State<BulkImportPage> createState() => _BulkImportPageState();
}
class _BulkImportPageState extends State<BulkImportPage> {
  final List<Map<String, TextEditingController>> _rows = [];
  bool _loading = false; String _status = '';

  void _addRow() => setState(() => _rows.add({
    'name': TextEditingController(), 'email': TextEditingController(),
    'class': TextEditingController(), 'rollNo': TextEditingController(),
    'parentName': TextEditingController(), 'parentPhone': TextEditingController(),
    'dob': TextEditingController(), 'bloodGroup': TextEditingController(),
    'password': TextEditingController(text: 'School@123'),
  }));

  void _removeRow(int i) {
    for (final c in _rows[i].values) {
      c.dispose();
    }
    setState(() => _rows.removeAt(i));
  }

  Future<void> _importAll() async {
    if (_rows.isEmpty) return;
    setState(() { _loading = true; _status = 'Importing ${_rows.length} students...'; });
    int ok = 0; int fail = 0;
    for (final row in _rows) {
      try {
        final email = row['email']!.text.trim(); final pass = row['password']!.text.trim();
        if (email.isEmpty || pass.isEmpty) { fail++; continue; }
        final res = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        await FirebaseFirestore.instance.collection('users').doc(res.user!.uid).set({
          'name': row['name']!.text.trim(), 'email': email, 'class': row['class']!.text.trim(),
          'rollNo': row['rollNo']!.text.trim(), 'parentName': row['parentName']!.text.trim(),
          'parentPhone': row['parentPhone']!.text.trim(), 'dob': row['dob']!.text.trim(),
          'bloodGroup': row['bloodGroup']!.text.trim(), 'role': 'student',
          'uid': res.user!.uid, 'createdAt': FieldValue.serverTimestamp(),
        });
        ok++;
      } catch (_) { fail++; }
    }
    _logActivity('Bulk import: $ok students added, $fail failed');
    setState(() { _loading = false; _status = '✅ $ok imported  ❌ $fail failed'; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Bulk Student Import', subtitle: 'Add multiple students at once',
        colors: AppColors.adminGrad, showBack: true,
        actions: [IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: _addRow)]),
    body: Column(children: [
      if (_status.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(14),
          color: AppColors.success.withOpacity(0.1),
          child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success))),
      Expanded(child: _rows.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.group_add_rounded, size: 64, color: AppColors.textGrey),
              const SizedBox(height: 12),
              const Text('Tap + to add student rows', style: TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(onPressed: _addRow, icon: const Icon(Icons.add), label: const Text('Add First Student')),
            ]))
          : ListView.builder(padding: const EdgeInsets.all(14), itemCount: _rows.length,
              itemBuilder: (_, i) => _buildRow(i))),
      if (_rows.isNotEmpty) Padding(padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          onPressed: _loading ? null : _importAll,
          icon: _loading ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded),
          label: Text(_loading ? 'Importing...' : 'Import ${_rows.length} Students',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))))),
    ]));

  Widget _buildRow(int i) {
    final r = _rows[i];
    return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Student ${i + 1}', style: AppText.cardTitle.copyWith(color: AppColors.accent)),
          IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.danger, size: 20),
              onPressed: () => _removeRow(i)),
        ]),
        TextField(controller: r['name'], decoration: const InputDecoration(labelText: 'Full Name', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: r['email'], decoration: const InputDecoration(labelText: 'Email', isDense: true), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: r['class'], decoration: const InputDecoration(labelText: 'Class', isDense: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: r['rollNo'], decoration: const InputDecoration(labelText: 'Roll No', isDense: true))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: r['parentName'], decoration: const InputDecoration(labelText: 'Parent Name', isDense: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: r['parentPhone'], decoration: const InputDecoration(labelText: 'Parent Phone', isDense: true))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: r['dob'], decoration: const InputDecoration(labelText: 'DOB', isDense: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: r['bloodGroup'], decoration: const InputDecoration(labelText: 'Blood', isDense: true))),
        ]),
        const SizedBox(height: 8),
        TextField(controller: r['password'], decoration: const InputDecoration(labelText: 'Password', isDense: true), obscureText: true),
      ]));
  }
}

// ════════════════════════════════════════════
//  EDIT PERSON (Universal admin edit)
// ════════════════════════════════════════════
class EditPersonPage extends StatefulWidget {
  final String uid;
  const EditPersonPage({super.key, required this.uid});
  @override State<EditPersonPage> createState() => _EditPersonPageState();
}
class _EditPersonPageState extends State<EditPersonPage> {
  final Map<String, TextEditingController> _c = {};
  bool _loading = true; String _role = '';

  @override
  void initState() {
    super.initState();
    for (final k in ['name','email','subject','phone','assignedClass','qualification','employeeId',
                     'class','rollNo','admissionNo','parentName','parentPhone','parentEmail',
                     'dob','bloodGroup','address','photoUrl']) {
      _c[k] = TextEditingController();
    }
    FirebaseFirestore.instance.collection('users').doc(widget.uid).get().then((doc) {
      final d = doc.data() ?? {}; _role = d['role'] ?? '';
      d.forEach((k, v) { _c[k]?.text = v?.toString() ?? ''; });
      setState(() => _loading = false);
    });
  }
  @override void dispose() { for (final c in _c.values) {
    c.dispose();
  } super.dispose(); }

  Future<void> _save() async {
    setState(() => _loading = true);
    final update = <String, dynamic>{};
    _c.forEach((k, v) { update[k] = v.text; });
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update(update);
    _logActivity('Profile updated: ${_c['name']?.text ?? ''}');
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Profile saved!'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'Edit Profile', colors: AppColors.adminGrad, showBack: true),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      if ((_c['photoUrl']?.text ?? '').isNotEmpty)
        Center(child: Padding(padding: const EdgeInsets.only(bottom: 16),
          child: CircleAvatar(radius: 50, backgroundImage: NetworkImage(_c['photoUrl']!.text)))),
      _field('Full Name', _c['name']!, Icons.person_outline),
      if (_role == 'teacher') ...[
        _field('Subject', _c['subject']!, Icons.book_outlined),
        _field('Assigned Class', _c['assignedClass']!, Icons.class_outlined),
        _field('Phone', _c['phone']!, Icons.phone_outlined),
        _field('Qualification', _c['qualification']!, Icons.school_outlined),
        _field('Employee ID', _c['employeeId']!, Icons.badge_rounded),
      ],
      if (_role == 'student') ...[
        _field('Class', _c['class']!, Icons.class_outlined),
        _field('Roll Number', _c['rollNo']!, Icons.tag_rounded),
        _field('Admission No', _c['admissionNo']!, Icons.numbers_rounded),
        _field("Parent's Name", _c['parentName']!, Icons.family_restroom_rounded),
        _field("Parent's Phone", _c['parentPhone']!, Icons.phone_outlined),
        _field("Parent's Email", _c['parentEmail']!, Icons.email_outlined),
        _field('Date of Birth', _c['dob']!, Icons.cake_rounded),
        _field('Blood Group', _c['bloodGroup']!, Icons.bloodtype_rounded),
        _field('Address', _c['address']!, Icons.home_rounded, maxLines: 2),
      ],
      _field('Photo URL', _c['photoUrl']!, Icons.image_outlined),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _save,
          child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
    ])));
}

// ════════════════════════════════════════════
//  PERSON DETAIL PAGE (Admin/Teacher view)
// ════════════════════════════════════════════
class PersonDetailPage extends StatelessWidget {
  final String uid; final bool isTeacher;
  const PersonDetailPage({super.key, required this.uid, this.isTeacher = false});
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    builder: (_, snap) {
      final d = snap.data?.data() as Map? ?? {};
      final name = d['name'] ?? 'Unknown'; final photo = d['photoUrl'] ?? '';
      final colors = isTeacher ? AppColors.teachGrad : AppColors.parentGrad;
      return Scaffold(body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context)),
              const Spacer(),
              IconButton(icon: Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18)),
                  onPressed: () => _push(context, EditPersonPage(uid: uid))),
            ]),
            CircleAvatar(radius: 50, backgroundColor: Colors.white.withOpacity(0.3),
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)) : null),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(isTeacher
                ? '${d['subject'] ?? ''} Teacher • Class ${d['assignedClass'] ?? 'N/A'}'
                : 'Class: ${d['class'] ?? 'N/A'} • Roll: ${d['rollNo'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (!isTeacher && (d['bloodGroup'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('Blood: ${d['bloodGroup']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            ],
          ]))),
        SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList(delegate: SliverChildListDelegate([
          _infoCard('Personal Info', [
            _row(Icons.email_outlined, 'Email', d['email'] ?? '-'),
            _row(Icons.phone_outlined, 'Phone', d['phone'] ?? '-'),
            if (isTeacher) ...[
              _row(Icons.school_outlined, 'Qualification', d['qualification'] ?? '-'),
              _row(Icons.badge_rounded, 'Employee ID', d['employeeId'] ?? '-'),
              _row(Icons.class_outlined, 'Assigned Class', d['assignedClass'] ?? '-'),
            ],
            if (!isTeacher) ...[
              _row(Icons.cake_rounded, 'Date of Birth', d['dob'] ?? '-'),
              _row(Icons.home_rounded, 'Address', d['address'] ?? '-'),
              _row(Icons.numbers_rounded, 'Admission No', d['admissionNo'] ?? '-'),
            ],
          ]),
          if (!isTeacher) ...[
            const SizedBox(height: 14),
            _infoCard('Parent Info', [
              _row(Icons.person_rounded, 'Parent Name', d['parentName'] ?? '-'),
              _row(Icons.phone_rounded, 'Parent Phone', d['parentPhone'] ?? '-'),
              _row(Icons.email_outlined, 'Parent Email', d['parentEmail'] ?? '-'),
            ]),
            const SizedBox(height: 14),
            sectionHeader('📊 Attendance Summary'), const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('student_attendance_records')
                  .where('studentUid', isEqualTo: uid).snapshots(),
              builder: (_, as_) {
                final docs = as_.data?.docs ?? [];
                final present = docs.where((d) => (d.data() as Map)['status'] == 'Present').length;
                final total = docs.length;
                return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    AttendanceRing(present: present, total: total, size: 100),
                    const SizedBox(width: 20),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _attStat('Present', present.toString(), AppColors.success),
                      const SizedBox(height: 8),
                      _attStat('Absent', (total - present).toString(), AppColors.danger),
                      const SizedBox(height: 8),
                      _attStat('Total', total.toString(), AppColors.accent),
                    ])),
                  ]));
              }),
            const SizedBox(height: 14),
            sectionHeader('📋 Results'), const SizedBox(height: 10),
            actionCard(context, 'Semester Results', 'View exam scores',
                Icons.assessment_rounded, AppColors.accent, () => _push(context, StudentReportDetail(uid: uid, name: name, type: 'semester'))),
            actionCard(context, 'Internal Test Results', 'Midterm scores',
                Icons.quiz_rounded, AppColors.gold, () => _push(context, StudentReportDetail(uid: uid, name: name, type: 'internal'))),
            actionCard(context, 'Unit Test Results', 'Chapter-wise scores',
                Icons.task_alt_rounded, const Color(0xFF9B5DE5), () => _push(context, StudentReportDetail(uid: uid, name: name, type: 'unit'))),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _push(context, MessageChatPage(otherUid: uid, otherName: name)),
            icon: const Icon(Icons.message_rounded),
            label: const Text('Send Message'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
        ])))
      ]));
    });

  Widget _infoCard(String title, List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.cardTitle), const Divider(height: 16), ...rows]));
  Widget _row(IconData icon, String label, String val) => Padding(padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textGrey), const SizedBox(width: 10),
      Text('$label: ', style: AppText.label),
      Expanded(child: Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark))),
    ]));
  Widget _attStat(String l, String v, Color c) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6), Text('$l: ', style: AppText.label),
    Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 14)),
  ]);
}
// ════════════════════════════════════════════
//  FEATURE CONTROL PAGE (Admin)
// ════════════════════════════════════════════
class FeatureControlPage extends StatefulWidget {
  const FeatureControlPage({super.key});
  @override State<FeatureControlPage> createState() => _FeatureControlPageState();
}
class _FeatureControlPageState extends State<FeatureControlPage> {
  Map<String, bool> _flags = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _flags = await FeatureFlags.get();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await FeatureFlags.set(_flags);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Settings saved!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Feature Control', subtitle: 'Toggle teacher & parent access',
        colors: AppColors.purpleGrad, showBack: true,
        actions: [TextButton(onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)))]),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Teacher Features', const Color(0xFFFF6B35), [
        _toggle('Post Homework', 'teacher_homework'),
        _toggle('Upload E-Books', 'teacher_ebooks'),
        _toggle('Post Announcements', 'teacher_announcements'),
        _toggle('Student Reports & Results', 'teacher_reports'),
        _toggle('Messaging', 'teacher_messages'),
        _toggle('Face Recognition Attendance', 'teacher_face_attendance'),
        _toggle('View Timetable', 'teacher_timetable'),
      ]),
      const SizedBox(height: 20),
      _section('Parent / Student Features', AppColors.success, [
        _toggle('View Homework', 'parent_homework'),
        _toggle('E-Books Access', 'parent_ebooks'),
        _toggle('Messaging', 'parent_messages'),
        _toggle('Timetable View', 'parent_timetable'),
        _toggle('Exam Results', 'parent_results'),
        _toggle('Announcements', 'parent_announcements'),
      ]),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _save,
          child: const Text('Save All Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
    ])));

  Widget _section(String title, Color color, List<Widget> items) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 22, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: AppText.cardTitle),
      ]),
      const Divider(height: 20), ...items]));

  Widget _toggle(String label, String key) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textDark))),
      Switch(value: _flags[key] ?? true, onChanged: (v) => setState(() => _flags[key] = v),
          activeThumbColor: AppColors.accent),
    ]));
}

// ════════════════════════════════════════════
//  SEND NOTIFICATION
// ════════════════════════════════════════════
class SendNotificationPage extends StatefulWidget {
  final String? targetClass;
  const SendNotificationPage({super.key, this.targetClass});
  @override State<SendNotificationPage> createState() => _SendNotificationPageState();
}
class _SendNotificationPageState extends State<SendNotificationPage> {
  final _title = TextEditingController(); final _body = TextEditingController();
  String _selectedClass = 'All'; bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.targetClass != null) _selectedClass = widget.targetClass!;
  }

  Future<void> _send() async {
    if (_title.text.isEmpty || _body.text.isEmpty) return;
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': _title.text, 'body': _body.text,
      'targetClass': _selectedClass == 'All' ? null : _selectedClass,
      'sentAt': FieldValue.serverTimestamp(),
      'sentBy': FirebaseAuth.instance.currentUser?.uid,
    });
    _logActivity('Notification sent to $_selectedClass: "${_title.text}"');
    if (!mounted) return;
    setState(() => _loading = false);
    _title.clear(); _body.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📣 Notification stored! Set up FCM + Cloud Functions for real push delivery.'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Send Notification', subtitle: 'Push to students & parents',
        colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)], showBack: true),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Notifications are stored in Firestore. For real push, add Firebase Cloud Messaging & Cloud Functions.',
              style: TextStyle(fontSize: 12, color: AppColors.textDark))),
        ])),
      _field('Title *', _title, Icons.title_rounded),
      _field('Message Body *', _body, Icons.message_rounded, maxLines: 3),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('classes').snapshots(),
        builder: (_, cs) {
          final classes = ['All', ...(cs.data?.docs.map((d) => (d.data() as Map)['name']?.toString() ?? '').toList() ?? [])];
          return DropdownButtonFormField<String>(
            initialValue: _selectedClass,
            decoration: InputDecoration(labelText: 'Target Class',
                prefixIcon: const Icon(Icons.class_rounded, color: AppColors.textGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            items: classes.cast<String>().map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
  value: c,
  child: Text(c == 'All' ? '📢 All Classes' : 'Class $c'),
)).toList(),
            onChanged: (v) => setState(() => _selectedClass = v ?? 'All'));
        }),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _loading ? null : _send,
        icon: _loading ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded),
        label: const Text('Send Notification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11998E)))),
      const SizedBox(height: 24),
      sectionHeader('Notification History'), const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications')
            .orderBy('sentAt', descending: true).limit(10).snapshots(),
        builder: (_, s) {
          if (!s.hasData || s.data!.docs.isEmpty) return const _EmptyState(label: 'No notifications sent yet');
          return Column(children: s.data!.docs.map((doc) {
            final d = doc.data() as Map;
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border(left: const BorderSide(color: Color(0xFF11998E), width: 3))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['title'] ?? '', style: AppText.cardTitle.copyWith(fontSize: 13)),
                  Text(d['body'] ?? '', style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('To: ${d['targetClass'] ?? 'All'}  •  ${_timeAgo(d['sentAt'])}', style: AppText.label),
                ])),
                IconButton(icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 16),
                    onPressed: () => doc.reference.delete()),
              ]));
          }).toList());
        }),
    ])));
}

// ════════════════════════════════════════════
//  TIMETABLE - ADMIN
// ════════════════════════════════════════════
class AdminTimetablePage extends StatefulWidget {
  const AdminTimetablePage({super.key});
  @override State<AdminTimetablePage> createState() => _AdminTimetablePageState();
}
class _AdminTimetablePageState extends State<AdminTimetablePage> {
  String _selectedClass = '';
  final _days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Timetable', subtitle: 'Manage lecture schedules',
        colors: AppColors.purpleGrad, showBack: true),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('classes').snapshots(),
        builder: (_, cs) {
          final classes = cs.data?.docs.map((d) => (d.data() as Map)['name']?.toString() ?? '').toList() ?? [];
          if (classes.isEmpty) return const Text('No classes found. Add classes first.', style: TextStyle(color: AppColors.textGrey));
          return DropdownButtonFormField<String>(
            initialValue: _selectedClass.isNotEmpty && classes.contains(_selectedClass) ? _selectedClass : null,
            hint: const Text('Select Class to Edit Schedule'),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.class_rounded, color: AppColors.textGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            items: classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
            onChanged: (v) => setState(() => _selectedClass = v ?? ''));
        })),
      if (_selectedClass.isEmpty)
        const Expanded(child: _EmptyState(label: 'Select a class above\nto manage its timetable', icon: Icons.calendar_view_week_rounded))
      else Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _days.length,
        itemBuilder: (_, i) => _DayCard(day: _days[i], className: _selectedClass))),
    ]));
}

class _DayCard extends StatelessWidget {
  final String day, className;
  const _DayCard({required this.day, required this.className});

  void _addPeriod(BuildContext context) {
    final sub = TextEditingController(); final tchr = TextEditingController();
    final time = TextEditingController(); final room = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Add Period — $day'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: sub, decoration: const InputDecoration(labelText: 'Subject', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: tchr, decoration: const InputDecoration(labelText: 'Teacher', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: time, decoration: const InputDecoration(labelText: 'Time (e.g. 9:00-10:00)', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: room, decoration: const InputDecoration(labelText: 'Room/Lab (optional)', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await FirebaseFirestore.instance.collection('timetable')
              .doc('${className}_${day.toLowerCase()}').collection('periods').add({
            'subject': sub.text, 'teacher': tchr.text,
            'time': time.text, 'room': room.text,
            'order': DateTime.now().millisecondsSinceEpoch,
          });
          Navigator.pop(context);
        }, child: const Text('Add')),
      ]));
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('timetable')
        .doc('${className}_${day.toLowerCase()}').collection('periods').orderBy('order').snapshots(),
    builder: (_, snap) {
      final periods = snap.data?.docs ?? [];
      return Container(margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF9B5DE5).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(day, style: AppText.cardTitle),
            Row(children: [
              Text('${periods.length} periods', style: AppText.label),
              const SizedBox(width: 10),
              GestureDetector(onTap: () => _addPeriod(context),
                child: Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFF9B5DE5).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_rounded, color: Color(0xFF9B5DE5), size: 18))),
            ]),
          ])),
          if (periods.isNotEmpty) ...[
            const Divider(height: 1),
            ...periods.map((doc) {
              final p = doc.data() as Map;
              return ListTile(dense: true,
                leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFF9B5DE5).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.book_rounded, color: Color(0xFF9B5DE5), size: 18)),
                title: Text(p['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text('${p['teacher'] ?? ''} • ${p['time'] ?? ''}  ${p['room'] ?? ''}', style: const TextStyle(fontSize: 11)),
                trailing: IconButton(icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 16),
                    onPressed: () => doc.reference.delete()));
            }),
          ] else const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text('No periods. Tap + to add.', style: TextStyle(color: AppColors.textGrey, fontSize: 12))),
        ]));
    });
}

// Timetable view (read-only for student/teacher)
class TimetableViewPage extends StatefulWidget {
  final String className;
  const TimetableViewPage({super.key, required this.className});
  @override State<TimetableViewPage> createState() => _TimetableViewPageState();
}
class _TimetableViewPageState extends State<TimetableViewPage> {
  final _days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  int _dayIdx = DateTime.now().weekday <= 6 ? DateTime.now().weekday - 1 : 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Timetable', subtitle: 'Class ${widget.className}',
        colors: AppColors.purpleGrad, showBack: true),
    body: Column(children: [
      SizedBox(height: 54, child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8),
        itemCount: _days.length,
        itemBuilder: (_, i) => GestureDetector(onTap: () => setState(() => _dayIdx = i),
          child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: _dayIdx == i ? const Color(0xFF9B5DE5) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF9B5DE5).withOpacity(_dayIdx == i ? 0.3 : 0.08),
                    blurRadius: 8, offset: const Offset(0, 2))]),
            child: Text(_days[i].substring(0, 3), style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13,
                color: _dayIdx == i ? Colors.white : AppColors.textGrey)))))),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('timetable')
            .doc('${widget.className}_${_days[_dayIdx].toLowerCase()}').collection('periods')
            .orderBy('order').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final periods = snap.data!.docs;
          if (periods.isEmpty) return _EmptyState(label: 'No periods for ${_days[_dayIdx]}', icon: Icons.calendar_today_rounded);
          return ListView.builder(padding: const EdgeInsets.all(14), itemCount: periods.length,
            itemBuilder: (_, i) {
              final p = periods[i].data() as Map;
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(width: 4, height: 56, decoration: BoxDecoration(
                      color: const Color(0xFF9B5DE5), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['subject'] ?? '', style: AppText.cardTitle),
                    Text(p['teacher'] ?? '', style: AppText.label),
                    if ((p['room'] ?? '').isNotEmpty) Text('Room: ${p['room']}', style: AppText.label),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF9B5DE5).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(p['time'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9B5DE5)))),
                ]));
            });
        })),
    ]));
}

// ════════════════════════════════════════════
//  TEACHER ATTENDANCE
// ════════════════════════════════════════════
class TeacherAttendancePage extends StatefulWidget {
  final bool isAdmin;
  const TeacherAttendancePage({super.key, required this.isAdmin});
  @override State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}
class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  DateTime _date = DateTime.now();
  final Map<String, String> _status = {}; // uid -> Present/Absent/Leave
  bool _submitting = false;
  String get _dateStr => _date.toIso8601String().split('T')[0];

  Future<void> _submit(List<QueryDocumentSnapshot> teachers) async {
    setState(() => _submitting = true);
    final batch = FirebaseFirestore.instance.batch();
    for (final t in teachers) {
      final st = _status[t.id] ?? 'Absent';
      batch.set(FirebaseFirestore.instance.collection('teacher_attendance')
          .doc(_dateStr).collection('teachers').doc(t.id), {
        'name': (t.data() as Map)['name'], 'status': st, 'subject': (t.data() as Map)['subject'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    _logActivity('Teacher attendance marked for $_dateStr');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Teacher attendance saved!'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
    builder: (_, snap) {
      final teachers = snap.data?.docs ?? [];
      return Scaffold(
        appBar: GradAppBar(title: 'Teacher Attendance', subtitle: _dateStr,
            colors: AppColors.teachGrad, showBack: true,
            actions: [IconButton(icon: const Icon(Icons.date_range_rounded, color: Colors.white),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2024), lastDate: DateTime.now());
                if (d != null) setState(() => _date = d);
              })]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            statCard('Present', _status.values.where((v) => v == 'Present').length.toString(), Icons.check_circle_rounded, AppColors.success),
            statCard('Absent', _status.values.where((v) => v == 'Absent').length.toString(), Icons.cancel_rounded, AppColors.danger),
            statCard('Leave', _status.values.where((v) => v == 'Leave').length.toString(), Icons.event_busy_rounded, AppColors.gold, last: true),
          ])),
          Expanded(child: teachers.isEmpty ? const _EmptyState(label: 'No teachers found')
              : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: teachers.length,
                  itemBuilder: (_, i) {
                    final d = teachers[i].data() as Map; final id = teachers[i].id;
                    _status.putIfAbsent(id, () => 'Present');
                    final st = _status[id]!;
                    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _stColor(st).withOpacity(0.2))),
                      child: Row(children: [
                        CircleAvatar(radius: 22, backgroundColor: const Color(0xFFFF6B35).withOpacity(0.15),
                          backgroundImage: (d['photoUrl'] ?? '').isNotEmpty ? NetworkImage(d['photoUrl']) : null,
                          child: (d['photoUrl'] ?? '').isEmpty ? Text((d['name'] as String? ?? 'T').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w800)) : null),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['name'] ?? '', style: AppText.cardTitle),
                          Text('${d['subject'] ?? ''} • ${d['employeeId'] ?? ''}', style: AppText.label),
                        ])),
                        ...['Present','Absent','Leave'].map((s) => GestureDetector(
                          onTap: () => setState(() => _status[id] = s),
                          child: Container(margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: st == s ? _stColor(s) : _stColor(s).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7)),
                            child: Text(s.substring(0, 1), style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                color: st == s ? Colors.white : _stColor(s)))))),
                      ]));
                  })),
          if (widget.isAdmin) Padding(padding: const EdgeInsets.all(14),
            child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
              onPressed: _submitting ? null : () => _submit(teachers),
              icon: _submitting ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: const Text('Save Attendance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35))))),
        ]));
    });
  Color _stColor(String s) => s == 'Present' ? AppColors.success : s == 'Leave' ? AppColors.gold : AppColors.danger;
}

// ════════════════════════════════════════════
//  MARK ATTENDANCE (manual toggle + date pick)
// ════════════════════════════════════════════
class MarkAttendancePage extends StatefulWidget {
  final String teacherUid; final String? className;
  const MarkAttendancePage({super.key, required this.teacherUid, this.className});
  @override State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}
class _MarkAttendancePageState extends State<MarkAttendancePage> {
  final Map<String, bool> _att = {};
  DateTime _date = DateTime.now(); bool _submitting = false;
  String get _dateStr => _date.toIso8601String().split('T')[0];

  Future<void> _submit(List<QueryDocumentSnapshot> students) async {
    if (students.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final s in students) {
        final d = s.data() as Map; final status = (_att[s.id] ?? false) ? 'Present' : 'Absent';
        batch.set(FirebaseFirestore.instance.collection('attendance').doc(_dateStr).collection('students').doc(s.id), {
          'name': d['name'], 'status': status, 'class': d['class'] ?? '', 'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(FirebaseFirestore.instance.collection('student_attendance_records').doc('${s.id}_$_dateStr'), {
          'studentUid': s.id, 'date': _dateStr, 'status': status,
          'class': d['class'] ?? '', 'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      _logActivity('Attendance marked for Class ${widget.className ?? 'All'} on $_dateStr');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Attendance submitted!'),
          backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.className != null
        ? FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('class', isEqualTo: widget.className)
        : FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student');
    return StreamBuilder<QuerySnapshot>(stream: query.snapshots(), builder: (_, snap) {
      final students = snap.data?.docs ?? [];
      return Scaffold(
        appBar: GradAppBar(title: 'Mark Attendance',
            subtitle: widget.className != null ? 'Class ${widget.className}' : 'All Students',
            colors: [AppColors.success, const Color(0xFF0FA36A)], showBack: true,
            actions: [
              IconButton(icon: const Icon(Icons.face_rounded, color: Colors.white),
                  tooltip: 'Face Recognition',
                  onPressed: () => _push(context, FaceAttendancePage(
                      className: widget.className ?? '', date: _dateStr))),
              IconButton(icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: _date,
                        firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (d != null) setState(() => _date = d);
                  }),
            ]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(children: [
              Expanded(child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(_dateStr, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() { for (final s in students) { _att[s.id] = true; } }),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text('All Present', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)))),
            ])),
          Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), child: Row(children: [
            statCard('Present', _att.values.where((v) => v).length.toString(), Icons.check_circle_rounded, AppColors.success),
            statCard('Absent', _att.values.where((v) => !v).length.toString(), Icons.cancel_rounded, AppColors.danger),
            statCard('Total', students.length.toString(), Icons.groups_rounded, AppColors.accent, last: true),
          ])),
          Expanded(child: students.isEmpty ? const _EmptyState(label: 'No students found')
              : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: students.length,
                  itemBuilder: (_, i) {
                    final d = students[i].data() as Map; final id = students[i].id;
                    _att.putIfAbsent(id, () => false); final isP = _att[id]!;
                    return GestureDetector(onTap: () => setState(() => _att[id] = !isP),
                      child: Container(margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: isP ? AppColors.success.withOpacity(0.35) : Colors.transparent)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isP ? AppColors.success.withOpacity(0.15) : const Color(0xFFF0F0F0),
                            backgroundImage: (d['photoUrl'] ?? '').isNotEmpty ? NetworkImage(d['photoUrl']) : null,
                            child: (d['photoUrl'] ?? '').isEmpty ? Text((d['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.w800, color: isP ? AppColors.success : AppColors.textGrey)) : null),
                          title: Text(d['name'] ?? '', style: AppText.cardTitle),
                          subtitle: Text('Roll: ${d['rollNo'] ?? 'N/A'}', style: AppText.label),
                          trailing: GestureDetector(onTap: () => setState(() => _att[id] = !isP),
                            child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                              width: 52, height: 28, padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  color: isP ? AppColors.success : const Color(0xFFE0E0E0),
                                  borderRadius: BorderRadius.circular(14)),
                              child: Align(alignment: isP ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(width: 22, height: 22,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))))));
                  })),
          Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(onPressed: _submitting ? null : () => _submit(students),
              icon: _submitting ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_rounded),
              label: const Text('Submit Attendance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success)))),
        ]));
    });
  }
}

// ════════════════════════════════════════════
//  FACE RECOGNITION ATTENDANCE (UI + simulation)
// ════════════════════════════════════════════
class FaceAttendancePage extends StatefulWidget {
  final String className, date;
  const FaceAttendancePage({super.key, required this.className, required this.date});
  @override State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}
class _FaceAttendancePageState extends State<FaceAttendancePage> with TickerProviderStateMixin {
  bool _scanning = false;
  String _currentName = ''; String _scanResult = '';
  final List<Map<String, String>> _markedPresent = [];
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _pulse = Tween(begin: 0.94, end: 1.06).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _startScan(List<QueryDocumentSnapshot> students) async {
    if (students.isEmpty) return;
    setState(() { _scanning = true; _scanResult = 'Scanning...'; _currentName = ''; });
    await Future.delayed(const Duration(milliseconds: 1800));
    final unMarked = students.where((s) => !_markedPresent.any((m) => m['uid'] == s.id)).toList();
    if (unMarked.isEmpty) {
      setState(() { _scanning = false; _scanResult = '✅ All students marked!'; }); return;
    }
    final match = unMarked[Random().nextInt(unMarked.length)];
    final d = match.data() as Map;
    setState(() { _currentName = d['name'] ?? ''; _scanResult = '✅ Recognized: ${d['name']}'; });
    await Future.delayed(const Duration(milliseconds: 600));
    await FirebaseFirestore.instance.collection('attendance').doc(widget.date)
        .collection('students').doc(match.id).set({
      'name': d['name'], 'status': 'Present', 'class': d['class'] ?? '',
      'method': 'face_recognition', 'timestamp': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('student_attendance_records')
        .doc('${match.id}_${widget.date}').set({
      'studentUid': match.id, 'date': widget.date, 'status': 'Present',
      'class': d['class'] ?? '', 'method': 'face_recognition', 'timestamp': FieldValue.serverTimestamp(),
    });
    setState(() { _markedPresent.add({'uid': match.id, 'name': d['name'] ?? ''}); _scanning = false; });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'student')
        .where('class', isEqualTo: widget.className).snapshots(),
    builder: (_, snap) {
      final students = snap.data?.docs ?? [];
      return Scaffold(
        appBar: GradAppBar(title: 'Face Attendance', subtitle: 'Class ${widget.className} • ${widget.date}',
            colors: AppColors.adminGrad, showBack: true),
        body: Column(children: [
          // Camera view
          Container(height: 260, width: double.infinity, margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
            child: Stack(alignment: Alignment.center, children: [
              ScaleTransition(scale: _pulse, child: Container(width: 160, height: 200,
                decoration: BoxDecoration(border: Border.all(
                    color: _scanning ? AppColors.gold : AppColors.success, width: 3),
                    borderRadius: BorderRadius.circular(100)))),
              if (_scanning) Positioned(bottom: 20, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Scanning face...', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ]))),
              if (!_scanning && _currentName.isNotEmpty)
                Positioned(bottom: 20, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(20)),
                    child: Text('✅ $_currentName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
              Positioned(top: 12, left: 12, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: const Row(children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ]))),
            ])),
          if (_scanResult.isNotEmpty) Container(margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: (_scanResult.contains('✅') ? AppColors.success : AppColors.gold).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_scanResult, style: TextStyle(fontWeight: FontWeight.w700,
                color: _scanResult.contains('✅') ? AppColors.success : AppColors.gold), textAlign: TextAlign.center)),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
            statCard('Marked', _markedPresent.length.toString(), Icons.check_circle_rounded, AppColors.success),
            statCard('Remaining', (students.length - _markedPresent.length).toString(), Icons.pending_rounded, AppColors.gold),
            statCard('Total', students.length.toString(), Icons.groups_rounded, AppColors.accent, last: true),
          ])),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Column(children: [
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
              onPressed: _scanning ? null : () => _startScan(students),
              icon: _scanning ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.face_rounded),
              label: Text(_scanning ? 'Scanning...' : 'Scan Next Face',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: _scanning ? AppColors.textGrey : AppColors.primary))),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withOpacity(0.3))),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text('Demo mode — add camera + google_mlkit_face_detection for real face matching.',
                    style: TextStyle(fontSize: 11, color: AppColors.textDark))),
              ])),
          ])),
          const SizedBox(height: 8),
          Expanded(child: _markedPresent.isEmpty
              ? const _EmptyState(label: 'Tap "Scan Next Face" to begin', icon: Icons.face_rounded)
              : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: _markedPresent.length,
                  itemBuilder: (_, i) => Container(margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 10),
                      Text(_markedPresent[i]['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text('PRESENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success))),
                    ])))),
        ]));
    });
}

// ════════════════════════════════════════════
//  TEACHER DASHBOARD
// ════════════════════════════════════════════
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override State<TeacherDashboard> createState() => _TeacherDashboardState();
}
class _TeacherDashboardState extends State<TeacherDashboard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pages = [_TeacherHome(uid: uid), TeacherClassPage(teacherUid: uid),
        HomeworkPage(isTeacher: true, teacherUid: uid), _TeacherMore(uid: uid)];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
        child: BottomNavigationBar(currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed, elevation: 0, backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFFF6B35), unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.class_rounded), label: 'My Class'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Homework'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ])));
  }
}

class _TeacherHome extends StatelessWidget {
  final String uid;
  const _TeacherHome({required this.uid});
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    builder: (_, snap) {
      final d = snap.data?.data() as Map? ?? {};
      return Scaffold(body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: AppColors.teachGrad,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
          padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hello 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(d['name'] ?? 'Teacher', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text('${d['subject'] ?? ''} • Class ${d['assignedClass'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
            Row(children: [
              IconButton(icon: Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18)),
                  onPressed: () => _push(context, EditProfilePage(uid: uid))),
              logoutBtn(context),
            ]),
          ]))),
        SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList(delegate: SliverChildListDelegate([
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [const Icon(Icons.calendar_today_rounded, color: AppColors.gold),
              const SizedBox(width: 10), Text(_todayLabel(), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark))])),
          const SizedBox(height: 18),
          sectionHeader('Quick Actions'), const SizedBox(height: 12),
          actionCard(context, 'Mark Attendance', 'Take roll call for your class',
              Icons.how_to_reg_rounded, AppColors.success, () => _push(context, MarkAttendancePage(teacherUid: uid, className: d['assignedClass']))),
          actionCard(context, 'Face Scan Attendance', 'Auto-mark via face recognition',
              Icons.face_rounded, AppColors.primary, () => _push(context, FaceAttendancePage(
                  className: d['assignedClass'] ?? '', date: DateTime.now().toIso8601String().split('T')[0]))),
          actionCard(context, 'My Timetable', 'View your lecture schedule',
              Icons.calendar_view_week_rounded, const Color(0xFF9B5DE5), () => _push(context, TimetableViewPage(className: d['assignedClass'] ?? ''))),
          actionCard(context, 'Enter Student Results', 'Add semester/internal/unit marks',
              Icons.assessment_rounded, AppColors.danger, () => _push(context, const StudentReportsPage())),
          actionCard(context, 'My Attendance Record', 'View your own attendance',
              Icons.fact_check_rounded, const Color(0xFFFF6B35), () => _push(context, const TeacherAttendancePage(isAdmin: false))),
          actionCard(context, 'Messages', 'Chat with students & parents',
              Icons.message_rounded, const Color(0xFF11998E), () => _push(context, const MessagesListPage())),
        ]))),
      ]));
    });
}

class TeacherClassPage extends StatefulWidget {
  final String teacherUid; final bool startOnAttendance;
  const TeacherClassPage({super.key, required this.teacherUid, this.startOnAttendance = false});
  @override State<TeacherClassPage> createState() => _TeacherClassPageState();
}
class _TeacherClassPageState extends State<TeacherClassPage> {
  String _selectedClass = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(widget.teacherUid).snapshots(),
    builder: (_, tSnap) {
      final td = tSnap.data?.data() as Map? ?? {};
      final myClass = td['assignedClass'] ?? '';
      if (_selectedClass.isEmpty && myClass.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _selectedClass = myClass); });
      }
      return Scaffold(
        appBar: GradAppBar(title: 'My Class', subtitle: _selectedClass.isNotEmpty ? 'Class $_selectedClass' : 'Select a class',
            colors: AppColors.teachGrad),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('classes').snapshots(),
            builder: (_, cs) {
              final classes = cs.data?.docs.map((d) => (d.data() as Map)['name']?.toString() ?? '').toList() ?? [];
              if (classes.isEmpty) return const SizedBox.shrink();
              return DropdownButtonFormField<String>(
                initialValue: _selectedClass.isNotEmpty && classes.contains(_selectedClass) ? _selectedClass : null,
                hint: const Text('Select Class'),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.class_rounded, color: AppColors.textGrey),
                    labelText: 'Class', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                items: classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                onChanged: (v) => setState(() => _selectedClass = v ?? ''));
            })),
          if (_selectedClass.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _push(context, MarkAttendancePage(teacherUid: widget.teacherUid, className: _selectedClass)),
                    icon: const Icon(Icons.how_to_reg_rounded, size: 18), label: const Text('Attendance'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 44)))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _push(context, FaceAttendancePage(
                        className: _selectedClass, date: DateTime.now().toIso8601String().split('T')[0])),
                    icon: const Icon(Icons.face_rounded, size: 18), label: const Text('Face Scan'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 44)))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _push(context, TimetableViewPage(className: _selectedClass)),
                    icon: const Icon(Icons.schedule_rounded, size: 18), label: const Text('Timetable'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B5DE5), minimumSize: const Size(0, 44)))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _push(context, const StudentReportsPage()),
                    icon: const Icon(Icons.assessment_rounded, size: 18), label: const Text('Results'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)))),
                ]),
              ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: sectionHeader('Students in Class $_selectedClass')),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users')
                  .where('role', isEqualTo: 'student').where('class', isEqualTo: _selectedClass).snapshots(),
              builder: (_, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final docs = s.data!.docs;
                if (docs.isEmpty) return _EmptyState(label: 'No students in Class $_selectedClass');
                return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map;
                    return GestureDetector(onTap: () => _push(context, PersonDetailPage(uid: docs[i].id)),
                      child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Row(children: [
                          CircleAvatar(radius: 24, backgroundColor: const Color(0xFFFF6B35).withOpacity(0.15),
                            backgroundImage: (d['photoUrl'] ?? '').isNotEmpty ? NetworkImage(d['photoUrl']) : null,
                            child: (d['photoUrl'] ?? '').isEmpty ? Text((d['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w800, fontSize: 16)) : null),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d['name'] ?? '', style: AppText.cardTitle),
                            Text('Roll: ${d['rollNo'] ?? 'N/A'} • Adm: ${d['admissionNo'] ?? 'N/A'}', style: AppText.label),
                          ])),
                          Column(children: [
                            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textGrey),
                            const SizedBox(height: 4),
                            GestureDetector(onTap: () => _push(context, MessageChatPage(otherUid: docs[i].id, otherName: d['name'] ?? '')),
                              child: Container(padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(color: const Color(0xFF11998E).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.message_rounded, color: Color(0xFF11998E), size: 14))),
                          ]),
                        ])));
                  });
              })),
          ] else const Expanded(child: _EmptyState(label: 'Select a class above', icon: Icons.class_rounded)),
        ]));
    });
}

class _TeacherMore extends StatelessWidget {
  final String uid;
  const _TeacherMore({required this.uid});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'More', colors: AppColors.teachGrad),
    body: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
      actionCard(context, 'Enter Student Results', 'Semester / Internal / Unit marks',
          Icons.assessment_rounded, AppColors.danger, () => _push(context, const StudentReportsPage())),
      actionCard(context, 'E-Books Library', 'Upload & manage materials',
          Icons.library_books_rounded, const Color(0xFF9B5DE5), () => _push(context, const EBooksPage(canUpload: true))),
      actionCard(context, 'Announcements', 'Post class notices with images',
          Icons.campaign_rounded, AppColors.gold, () => _push(context, const AnnouncementsPage(canPost: true))),
      actionCard(context, 'My Attendance Record', 'View your own attendance',
          Icons.fact_check_rounded, const Color(0xFFFF6B35), () => _push(context, const TeacherAttendancePage(isAdmin: false))),
      actionCard(context, 'Edit My Profile', 'Update info & photo',
          Icons.manage_accounts_rounded, AppColors.accent, () => _push(context, EditProfilePage(uid: uid))),
    ])));
}

// ════════════════════════════════════════════
//  RESULTS SYSTEM
// ════════════════════════════════════════════
class StudentReportsPage extends StatelessWidget {
  const StudentReportsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Student Results', subtitle: 'All exams & tests', colors: AppColors.pinkGrad, showBack: true),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        if (docs.isEmpty) return const _EmptyState(label: 'No students');
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map;
            return GestureDetector(onTap: () => _push(context, _ResultsHub(uid: docs[i].id, name: d['name'] ?? '')),
              child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  CircleAvatar(radius: 24, backgroundColor: AppColors.accent.withOpacity(0.1),
                    backgroundImage: (d['photoUrl'] ?? '').isNotEmpty ? NetworkImage(d['photoUrl']) : null,
                    child: (d['photoUrl'] ?? '').isEmpty ? Text((d['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)) : null),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['name'] ?? '', style: AppText.cardTitle),
                    Text('Class: ${d['class'] ?? 'N/A'} • Roll: ${d['rollNo'] ?? 'N/A'}', style: AppText.label),
                  ])),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textGrey),
                ])));
          });
      }));
}

class _ResultsHub extends StatelessWidget {
  final String uid, name;
  const _ResultsHub({required this.uid, required this.name});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: name, subtitle: 'All Results', colors: AppColors.pinkGrad, showBack: true),
    body: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
      actionCard(context, 'Semester Exams', 'End-of-semester scores by subject',
          Icons.school_rounded, AppColors.accent, () => _push(context, StudentReportDetail(uid: uid, name: name, type: 'semester'))),
      actionCard(context, 'Internal / Midterm Tests', 'Mid-semester internal exam scores',
          Icons.quiz_rounded, AppColors.gold, () => _push(context, StudentReportDetail(uid: uid, name: name, type: 'internal'))),
      actionCard(context, 'Unit Tests', 'Chapter/unit specific test scores',
          Icons.task_alt_rounded, const Color(0xFF9B5DE5), () => _push(context, StudentReportDetail(uid: uid, name: name, type: 'unit'))),
    ])));
}

class StudentReportDetail extends StatefulWidget {
  final String uid, name, type;
  const StudentReportDetail({super.key, required this.uid, required this.name, required this.type});
  @override State<StudentReportDetail> createState() => _StudentReportDetailState();
}
class _StudentReportDetailState extends State<StudentReportDetail> {
  static const _subjects = ['Math','Science','English','History','Geography','Computer','Physics','Chemistry'];
  final Map<String, TextEditingController> _c = {};
  String _semester = 'Semester 1'; bool _loading = true;
  final _sems = ['Semester 1','Semester 2','Semester 3','Semester 4'];
  String get _docId => '${widget.uid}_${_semester.replaceAll(' ', '_')}_${widget.type}';

  @override
  void initState() {
    super.initState();
    for (final s in _subjects) {
      _c[s] = TextEditingController();
    }
    _load();
  }
  @override void dispose() { for (final c in _c.values) {
    c.dispose();
  } super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance.collection('exam_results').doc(_docId).get();
    if (doc.exists) { final d = doc.data()!; for (final s in _subjects) {
      _c[s]?.text = d[s]?.toString() ?? '';
    } }
    else { for (final s in _subjects) {
      _c[s]?.clear();
    } }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final data = <String, dynamic>{'studentUid': widget.uid, 'studentName': widget.name,
      'semester': _semester, 'type': widget.type, 'updatedAt': FieldValue.serverTimestamp()};
    for (final s in _subjects) {
      data[s] = _c[s]?.text ?? '';
    }
    await FirebaseFirestore.instance.collection('exam_results').doc(_docId).set(data);
    _logActivity('${widget.type.toUpperCase()} results saved for ${widget.name} - $_semester');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Results saved!'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: widget.name,
        subtitle: '${widget.type[0].toUpperCase()}${widget.type.substring(1)} Results',
        colors: AppColors.pinkGrad, showBack: true),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: DropdownButtonFormField<String>(
        initialValue: _semester,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.school_rounded, color: AppColors.textGrey),
            labelText: 'Select Semester / Term',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        items: _sems.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { setState(() => _semester = v ?? _semester); _load(); })),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.symmetric(horizontal: 14), children: [
        ..._subjects.map((s) {
          final score = int.tryParse(_c[s]?.text ?? '') ?? 0;
          final c = score >= 80 ? AppColors.success : score >= 60 ? AppColors.gold : AppColors.danger;
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              SizedBox(width: 100, child: Text(s, style: AppText.cardTitle.copyWith(fontSize: 14))),
              Expanded(child: TextField(controller: _c[s], keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Score / Grade', border: InputBorder.none,
                    filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                onChanged: (_) => setState(() {}))),
              if (score > 0) Container(width: 5, height: 36, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            ]));
        }),
        // Grade summary card
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('exam_results').doc(_docId).snapshots(),
          builder: (_, rs) {
            if (!rs.hasData || !rs.data!.exists) return const SizedBox.shrink();
            final rd = rs.data!.data() as Map;
            int total = 0; int count = 0;
            for (final s in _subjects) { final n = int.tryParse(rd[s]?.toString() ?? ''); if (n != null) { total += n; count++; } }
            final avg = count > 0 ? total / count : 0.0;
            final grade = avg >= 80 ? 'A+' : avg >= 70 ? 'A' : avg >= 60 ? 'B' : avg >= 50 ? 'C' : avg >= 40 ? 'D' : 'F';
            final gColor = avg >= 70 ? AppColors.success : avg >= 50 ? AppColors.gold : AppColors.danger;
            return Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: LinearGradient(
                  colors: [gColor.withOpacity(0.12), gColor.withOpacity(0.04)]),
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: gColor.withOpacity(0.3))),
              child: Row(children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(color: gColor, shape: BoxShape.circle),
                  child: Center(child: Text(grade, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)))),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${avg.toStringAsFixed(1)}% Average', style: TextStyle(fontWeight: FontWeight.w800, color: gColor, fontSize: 16)),
                  Text('$_semester • ${widget.type.toUpperCase()}', style: AppText.label),
                  Text('$count subjects recorded', style: AppText.label),
                ]),
              ]));
          }),
        const SizedBox(height: 60),
      ])),
      Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, height: 52,
        child: ElevatedButton(onPressed: _save,
          child: const Text('Save Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))))),
    ]));
}

// ════════════════════════════════════════════
//  INTERNAL RESULTS OVERVIEW (Admin)
// ════════════════════════════════════════════
class InternalResultsPage extends StatelessWidget {
  const InternalResultsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Internal & Unit Tests', subtitle: 'All test results overview',
        colors: AppColors.pinkGrad, showBack: true),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('exam_results')
          .orderBy('updatedAt', descending: true).snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs.where((d) {
          final type = (d.data() as Map)['type'] ?? '';
          return type == 'internal' || type == 'unit';
        }).toList();
        if (docs.isEmpty) return const _EmptyState(label: 'No internal/unit test results yet');
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map;
            final type = d['type'] ?? ''; final tc = type == 'unit' ? const Color(0xFF9B5DE5) : AppColors.gold;
            return GestureDetector(
              onTap: () => _push(context, StudentReportDetail(uid: d['studentUid'] ?? '', name: d['studentName'] ?? '', type: type)),
              child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(type == 'unit' ? Icons.task_alt_rounded : Icons.quiz_rounded, color: tc, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['studentName'] ?? '', style: AppText.cardTitle),
                    Text('${d['semester'] ?? ''} • ${type.toUpperCase()}', style: AppText.label),
                    Text(_timeAgo(d['updatedAt']), style: AppText.label),
                  ])),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textGrey),
                ])));
          });
      }));
}

// ════════════════════════════════════════════
//  STUDENT DASHBOARD
// ════════════════════════════════════════════
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override State<StudentDashboard> createState() => _StudentDashboardState();
}
class _StudentDashboardState extends State<StudentDashboard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pages = [_StudentHome(uid: uid), _StudentAttendance(uid: uid), _StudentResults(uid: uid), _StudentMore(uid: uid)];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))]),
        child: BottomNavigationBar(currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed, elevation: 0, backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.success, unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.assessment_rounded), label: 'Results'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ])));
  }
}

class _StudentHome extends StatelessWidget {
  final String uid;
  const _StudentHome({required this.uid});
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    builder: (_, snap) {
      final d = snap.data?.data() as Map? ?? {};
      final name = d['name'] ?? 'Student'; final cls = d['class'] ?? 'N/A'; final photo = d['photoUrl'] ?? '';
      return Scaffold(body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: AppColors.parentGrad,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
          padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
          child: Row(children: [
            CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.25),
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)) : null),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hello 👋', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Class $cls', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            logoutBtn(context),
          ]))),
        SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList(delegate: SliverChildListDelegate([
          // Live attendance ring
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('student_attendance_records').where('studentUid', isEqualTo: uid).snapshots(),
            builder: (_, as_) {
              final recs = as_.data?.docs ?? [];
              final present = recs.where((r) => (r.data() as Map)['status'] == 'Present').length;
              final total = recs.length;
              return Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(children: [
                  AttendanceRing(present: present, total: total, size: 100),
                  const SizedBox(width: 20),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    _attRow('Present', present, AppColors.success),
                    const SizedBox(height: 4),
                    _attRow('Absent', total - present, AppColors.danger),
                    const SizedBox(height: 4),
                    _attRow('Total Days', total, AppColors.accent),
                  ])),
                ]));
            }),
          const SizedBox(height: 20),
          // Announcements
          sectionHeader('📢 Announcements', trailing: TextButton(
              onPressed: () => _push(context, const AnnouncementsPage(canPost: false)), child: const Text('View all'))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('announcements').orderBy('createdAt', descending: true).limit(3).snapshots(),
            builder: (_, as_) {
              if (!as_.hasData || as_.data!.docs.isEmpty) return const _EmptyState(label: 'No announcements');
              return Column(children: as_.data!.docs.map((doc) {
                final ad = doc.data() as Map; final img = ad['imageUrl'] ?? '';
                return Container(margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (img.isNotEmpty) ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: Image.network(img, width: double.infinity, height: 150, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                    Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _typeChipSmall(ad['type'] ?? 'general'),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ad['title'] ?? '', style: AppText.cardTitle)),
                      ]),
                      if ((ad['message'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(ad['message'], style: AppText.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ])),
                  ]));
              }).toList());
            }),
          const SizedBox(height: 18),
          // Homework preview
          sectionHeader('📚 Latest Homework', trailing: TextButton(
              onPressed: () => _push(context, const HomeworkPage(isTeacher: false)), child: const Text('View all'))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('homework').orderBy('createdAt', descending: true).limit(3).snapshots(),
            builder: (_, hs) {
              if (!hs.hasData || hs.data!.docs.isEmpty) return const _EmptyState(label: 'No homework');
              return Column(children: hs.data!.docs.map((doc) {
                final hd = doc.data() as Map; final due = hd['dueDate'] ?? '';
                final isPast = due.compareTo(DateTime.now().toIso8601String().split('T')[0]) < 0;
                return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border(left: BorderSide(color: isPast ? AppColors.danger : AppColors.success, width: 3))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.assignment_rounded, color: AppColors.accent, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(hd['title'] ?? '', style: AppText.cardTitle.copyWith(fontSize: 14)),
                      Text('${hd['subject'] ?? ''}  •  Due: $due', style: AppText.label),
                      if ((hd['class'] ?? '').isNotEmpty) Text('Class: ${hd['class']}', style: AppText.label),
                    ])),
                    if (isPast) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.danger))),
                  ]));
              }).toList());
            }),
          const SizedBox(height: 80),
        ]))),
      ]));
    });
  Widget _attRow(String l, int v, Color c) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 6), Text('$l: ', style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
    Text(v.toString(), style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 13)),
  ]);
}

Widget _typeChipSmall(String type) {
  final c = type == 'urgent' ? AppColors.danger : type == 'event' ? AppColors.gold
      : type == 'exam' ? AppColors.accent : const Color(0xFF9B5DE5);
  return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(type.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c)));
}

// ── Student Attendance Tab ───────────────────
class _StudentAttendance extends StatelessWidget {
  final String uid;
  const _StudentAttendance({required this.uid});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'My Attendance', subtitle: 'Your history', colors: AppColors.parentGrad),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student_attendance_records')
          .where('studentUid', isEqualTo: uid).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList();
        docs.sort((a, b) { final da = (a.data() as Map)['date'] ?? ''; final db = (b.data() as Map)['date'] ?? ''; return db.compareTo(da); });
        if (docs.isEmpty) return const _EmptyState(label: 'No attendance records yet.\nYour teacher hasn\'t marked attendance.', icon: Icons.bar_chart_rounded);
        final present = docs.where((d) => (d.data() as Map)['status'] == 'Present').length;
        final total = docs.length;
        return Column(children: [
          Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.parentGrad), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              AttendanceRing(present: present, total: total, size: 110),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _s('Present', present.toString(), Colors.white),
                const SizedBox(height: 8), _s('Absent', (total - present).toString(), Colors.white70),
                const SizedBox(height: 8), _s('Total Days', total.toString(), Colors.white60),
              ]),
            ])),
          if (docs.length > 1) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: sectionHeader('Last ${min(docs.length, 14)} Days')),
            const SizedBox(height: 8),
            SizedBox(height: 96, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: min(docs.length, 14),
              itemBuilder: (_, i) {
                final r = docs[i].data() as Map; final isP = r['status'] == 'Present';
                return Container(margin: const EdgeInsets.only(right: 7), width: 34,
                  child: Column(children: [
                    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      AnimatedContainer(duration: Duration(milliseconds: 400 + i * 40),
                        height: isP ? 62 : 22, width: 26,
                        decoration: BoxDecoration(color: isP ? AppColors.success : AppColors.danger,
                            borderRadius: BorderRadius.circular(5))),
                    ])),
                    const SizedBox(height: 4),
                    Text((r['date'] ?? '').length >= 10 ? r['date'].substring(5) : '',
                        style: const TextStyle(fontSize: 7, color: AppColors.textGrey)),
                  ]));
              })),
            const SizedBox(height: 10),
          ],
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: sectionHeader('Full History')),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: docs.length,
            itemBuilder: (_, i) {
              final r = docs[i].data() as Map; final isP = r['status'] == 'Present';
              return Container(margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                child: Row(children: [
                  Icon(isP ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isP ? AppColors.success : AppColors.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((r['method'] ?? '') == 'face_recognition')
                      const Text('📷 Face Recognition', style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: (isP ? AppColors.success : AppColors.danger).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7)),
                    child: Text(r['status'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isP ? AppColors.success : AppColors.danger))),
                ]));
            })),
        ]);
      }));
  Widget _s(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    Text(v, style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900)),
  ]);
}

// ── Student Results Tab ──────────────────────
class _StudentResults extends StatefulWidget {
  final String uid;
  const _StudentResults({required this.uid});
  @override State<_StudentResults> createState() => _StudentResultsState();
}
class _StudentResultsState extends State<_StudentResults> {
  String _semester = 'Semester 1'; String _type = 'semester';
  final _sems = ['Semester 1','Semester 2','Semester 3','Semester 4'];
  final _types = ['semester','internal','unit'];
  static const _subjects = ['Math','Science','English','History','Geography','Computer','Physics','Chemistry'];
  String get _docId => '${widget.uid}_${_semester.replaceAll(' ', '_')}_$_type';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'My Results', subtitle: 'Exam & test scores', colors: AppColors.pinkGrad),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0), child: Row(children: [
        Expanded(child: DropdownButtonFormField<String>(initialValue: _semester,
          decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: _sems.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _semester = v ?? _semester))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(initialValue: _type,
          decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _type = v ?? _type))),
      ])),
      Expanded(child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('exam_results').doc(_docId).snapshots(),
        builder: (_, rs) {
          if (!rs.hasData) return const Center(child: CircularProgressIndicator());
          if (!rs.data!.exists) return _EmptyState(label: 'No $_semester ${_type.toUpperCase()} results\navailable yet', icon: Icons.assessment_rounded);
          final rd = rs.data!.data() as Map;
          int total = 0; int count = 0;
          for (final s in _subjects) { final n = int.tryParse(rd[s]?.toString() ?? ''); if (n != null) { total += n; count++; } }
          final avg = count > 0 ? total / count : 0.0;
          final grade = avg >= 80 ? 'A+' : avg >= 70 ? 'A' : avg >= 60 ? 'B' : avg >= 50 ? 'C' : avg >= 40 ? 'D' : 'F';
          final gColor = avg >= 70 ? AppColors.success : avg >= 50 ? AppColors.gold : AppColors.danger;
          return SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
                gradient: LinearGradient(colors: [gColor.withOpacity(0.15), gColor.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(20), border: Border.all(color: gColor.withOpacity(0.3))),
              child: Row(children: [
                Container(width: 70, height: 70, decoration: BoxDecoration(color: gColor, shape: BoxShape.circle),
                  child: Center(child: Text(grade, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
                const SizedBox(width: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${avg.toStringAsFixed(1)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: gColor)),
                  Text('Average Score', style: AppText.label),
                  Text('$_semester • $_type'.toUpperCase(), style: AppText.label),
                ]),
              ])),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(children: _subjects.map((s) {
                final score = rd[s]?.toString() ?? 'N/A'; final n = int.tryParse(score) ?? 0;
                final c = n >= 80 ? AppColors.success : n >= 60 ? AppColors.gold : AppColors.danger;
                return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                  SizedBox(width: 90, child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(value: n > 0 ? n / 100 : 0, backgroundColor: c.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(c), minHeight: 8))),
                  const SizedBox(width: 8),
                  SizedBox(width: 38, child: Text(score, style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 13), textAlign: TextAlign.right)),
                ]));
              }).toList())),
          ]));
        })),
    ]));
}

// ── Student More Tab ─────────────────────────
class _StudentMore extends StatelessWidget {
  final String uid;
  const _StudentMore({required this.uid});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'More', colors: AppColors.parentGrad),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      actionCard(context, 'My Timetable', 'View class lecture schedule',
          Icons.calendar_view_week_rounded, const Color(0xFF9B5DE5), () async {
        final doc = await FirebaseFirestore.instance.collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid).get();
        final cls = (doc.data() as Map?)?['class'] ?? '';
        if (cls.isNotEmpty && context.mounted) _push(context, TimetableViewPage(className: cls));
      }),
      actionCard(context, 'Homework', 'View all assignments',
          Icons.assignment_rounded, AppColors.accent, () => _push(context, const HomeworkPage(isTeacher: false))),
      actionCard(context, 'E-Books Library', 'Study materials',
          Icons.library_books_rounded, const Color(0xFF9B5DE5), () => _push(context, const EBooksPage(canUpload: false))),
      actionCard(context, 'Announcements', 'School notices',
          Icons.campaign_rounded, AppColors.danger, () => _push(context, const AnnouncementsPage(canPost: false))),
      actionCard(context, 'My Teachers', 'See who teaches which subject',
          Icons.person_rounded, const Color(0xFFFF6B35), () => _push(context, const TeacherDirectoryPage())),
      actionCard(context, 'Notifications', 'School alerts',
          Icons.notifications_rounded, const Color(0xFF11998E), () => _push(context, const NotificationsViewPage())),
      actionCard(context, 'Messages', 'Chat with teachers',
          Icons.message_rounded, const Color(0xFF11998E), () => _push(context, const MessagesListPage())),
      actionCard(context, 'Edit My Profile', 'Update photo, info & more',
          Icons.manage_accounts_rounded, AppColors.accent, () => _push(context, EditProfilePage(uid: uid))),
    ])));
}

// ════════════════════════════════════════════
//  EDIT PROFILE (Student/Teacher self-edit)
// ════════════════════════════════════════════
class EditProfilePage extends StatefulWidget {
  final String uid;
  const EditProfilePage({super.key, required this.uid});
  @override State<EditProfilePage> createState() => _EditProfilePageState();
}
class _EditProfilePageState extends State<EditProfilePage> {
  final _n = TextEditingController(); final _ph = TextEditingController();
  final _par = TextEditingController(); final _parPh = TextEditingController();
  final _parEmail = TextEditingController(); final _dob = TextEditingController();
  final _blood = TextEditingController(); final _addr = TextEditingController();
  final _photo = TextEditingController();
  bool _loading = true; String _role = '';

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('users').doc(widget.uid).get().then((doc) {
      final d = doc.data() ?? {}; _role = d['role'] ?? '';
      _n.text = d['name'] ?? ''; _ph.text = d['phone'] ?? ''; _photo.text = d['photoUrl'] ?? '';
      _par.text = d['parentName'] ?? ''; _parPh.text = d['parentPhone'] ?? '';
      _parEmail.text = d['parentEmail'] ?? ''; _dob.text = d['dob'] ?? '';
      _blood.text = d['bloodGroup'] ?? ''; _addr.text = d['address'] ?? '';
      setState(() => _loading = false);
    });
  }
  @override void dispose() { for (final c in [_n,_ph,_par,_parPh,_parEmail,_dob,_blood,_addr,_photo]) {
    c.dispose();
  } super.dispose(); }

  Future<void> _save() async {
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'name': _n.text, 'phone': _ph.text, 'photoUrl': _photo.text,
      if (_role == 'student') ...{
        'parentName': _par.text, 'parentPhone': _parPh.text, 'parentEmail': _parEmail.text,
        'dob': _dob.text, 'bloodGroup': _blood.text, 'address': _addr.text,
      },
    });
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Profile updated!'),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'Edit Profile', colors: AppColors.parentGrad, showBack: true),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
      Center(child: Stack(children: [
        CircleAvatar(radius: 50, backgroundColor: AppColors.success.withOpacity(0.2),
          backgroundImage: _photo.text.isNotEmpty ? NetworkImage(_photo.text) : null,
          child: _photo.text.isEmpty ? const Icon(Icons.person_rounded, size: 50, color: AppColors.success) : null),
        Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14))),
      ])),
      const SizedBox(height: 22),
      _field('Full Name', _n, Icons.person_outline),
      _field('Photo URL', _photo, Icons.image_outlined),
      _field('Phone Number', _ph, Icons.phone_outlined, type: TextInputType.phone),
      if (_role == 'student') ...[
        _field('Date of Birth', _dob, Icons.cake_rounded),
        _field('Blood Group', _blood, Icons.bloodtype_rounded),
        _field('Address', _addr, Icons.home_rounded, maxLines: 2),
        const Divider(),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Parent / Guardian Info', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark))),
        _field("Parent's Name", _par, Icons.family_restroom_rounded),
        _field("Parent's Phone", _parPh, Icons.phone_android_rounded, type: TextInputType.phone),
        _field("Parent's Email", _parEmail, Icons.email_outlined, type: TextInputType.emailAddress),
      ],
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)))),
    ])));
}

// ════════════════════════════════════════════
//  HOMEWORK PAGE
// ════════════════════════════════════════════
class HomeworkPage extends StatefulWidget {
  final bool isTeacher; final String? teacherUid;
  const HomeworkPage({super.key, required this.isTeacher, this.teacherUid});
  @override State<HomeworkPage> createState() => _HomeworkPageState();
}
class _HomeworkPageState extends State<HomeworkPage> {
  final _title = TextEditingController(); final _desc = TextEditingController();
  final _sub = TextEditingController(); final _cls = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 1));

  void _showAdd() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 22, right: 22, top: 22),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Post Homework', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _field('Title *', _title, Icons.title_rounded),
        _field('Subject', _sub, Icons.book_outlined),
        _field('For Class (e.g. 10-A)', _cls, Icons.class_outlined),
        _field('Description', _desc, Icons.description_outlined, maxLines: 2),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_rounded, color: AppColors.accent),
          title: Text('Due: ${_due.toIso8601String().split('T')[0]}', style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: TextButton(onPressed: () async {
            final d = await showDatePicker(context: ctx, initialDate: _due,
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
            if (d != null) setSt(() => _due = d);
          }, child: const Text('Change'))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _post,
            child: const Text('Post Homework', style: TextStyle(fontWeight: FontWeight.w700)))),
      ]))));

  Future<void> _post() async {
    if (_title.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('homework').add({
      'title': _title.text, 'subject': _sub.text, 'class': _cls.text,
      'description': _desc.text, 'dueDate': _due.toIso8601String().split('T')[0],
      'teacherUid': FirebaseAuth.instance.currentUser?.uid, 'createdAt': FieldValue.serverTimestamp(),
    });
    _title.clear(); _desc.clear(); _sub.clear(); _cls.clear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'Homework',
        subtitle: widget.isTeacher ? 'Manage assignments' : 'Your assignments',
        colors: [AppColors.accent, const Color(0xFF7B93FF)], showBack: !widget.isTeacher),
    floatingActionButton: widget.isTeacher ? FloatingActionButton.extended(onPressed: _showAdd,
        backgroundColor: AppColors.accent, icon: const Icon(Icons.add), label: const Text('Post')) : null,
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('homework').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        if (docs.isEmpty) return const _EmptyState(label: 'No homework posted yet', icon: Icons.assignment_rounded);
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map; final due = d['dueDate'] ?? '';
            final isPast = due.compareTo(DateTime.now().toIso8601String().split('T')[0]) < 0;
            return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: isPast ? AppColors.danger : AppColors.success, width: 3.5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(d['title'] ?? '', style: AppText.cardTitle)),
                  if ((d['subject'] ?? '').isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: (isPast ? AppColors.danger : AppColors.success).withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
                    child: Text(d['subject'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isPast ? AppColors.danger : AppColors.success))),
                ]),
                if ((d['class'] ?? '').isNotEmpty) Text('Class: ${d['class']}', style: AppText.label),
                if ((d['description'] ?? '').isNotEmpty) ...[const SizedBox(height: 4), Text(d['description'], style: const TextStyle(fontSize: 13, color: AppColors.textGrey))],
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.event_rounded, size: 13, color: isPast ? AppColors.danger : AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text('Due: $due', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPast ? AppColors.danger : AppColors.textGrey)),
                  if (isPast) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.danger)))],
                ]),
                if (widget.isTeacher) Align(alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: () => docs[i].reference.delete(),
                    icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                    label: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 12)))),
              ]));
          });
      }));
}

// ════════════════════════════════════════════
//  E-BOOKS PAGE
// ════════════════════════════════════════════
class EBooksPage extends StatefulWidget {
  final bool canUpload;
  const EBooksPage({super.key, required this.canUpload});
  @override State<EBooksPage> createState() => _EBooksPageState();
}
class _EBooksPageState extends State<EBooksPage> {
  final _t = TextEditingController(); final _s = TextEditingController();
  final _a = TextEditingController(); final _u = TextEditingController();
  final _cls = TextEditingController(); String _search = '';

  void _showAdd() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 22, right: 22, top: 22),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Upload E-Book', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _field('Book Title *', _t, Icons.book_rounded), _field('Subject', _s, Icons.subject_rounded),
        _field('Author', _a, Icons.person_outline), _field('For Class', _cls, Icons.class_outlined),
        _field('PDF URL / Drive Link *', _u, Icons.link_rounded),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: () async {
            if (_t.text.isEmpty || _u.text.isEmpty) return;
            await FirebaseFirestore.instance.collection('ebooks').add({
              'title': _t.text, 'subject': _s.text, 'author': _a.text, 'url': _u.text, 'class': _cls.text,
              'uploadedAt': FieldValue.serverTimestamp(), 'uploadedBy': FirebaseAuth.instance.currentUser?.uid,
            });
            _t.clear(); _s.clear(); _a.clear(); _u.clear(); _cls.clear();
            Navigator.pop(context);
          }, child: const Text('Upload', style: TextStyle(fontWeight: FontWeight.w700)))),
      ])));

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'E-Books Library', subtitle: 'Study materials', colors: AppColors.purpleGrad, showBack: true),
    floatingActionButton: widget.canUpload ? FloatingActionButton.extended(onPressed: _showAdd,
        backgroundColor: const Color(0xFF9B5DE5), icon: const Icon(Icons.upload_rounded), label: const Text('Upload')) : null,
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        decoration: const InputDecoration(hintText: 'Search books, subjects...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textGrey)),
        onChanged: (v) => setState(() => _search = v.toLowerCase()))),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ebooks').orderBy('uploadedAt', descending: true).snapshots(),
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          var docs = s.data!.docs;
          if (_search.isNotEmpty) {
            docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['title'] ?? '').toString().toLowerCase().contains(_search) ||
                   (data['subject'] ?? '').toString().toLowerCase().contains(_search);
          }).toList();
          }
          if (docs.isEmpty) return const _EmptyState(label: 'No books yet', icon: Icons.library_books_rounded);
          return GridView.builder(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map;
              final gradients = [AppColors.purpleGrad, AppColors.adminGrad,
                [AppColors.success, const Color(0xFF6EFFB4)], AppColors.teachGrad];
              final c = gradients[i % gradients.length];
              return Container(decoration: BoxDecoration(gradient: LinearGradient(colors: c,
                  begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22)),
                  const Spacer(),
                  Text(d['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(d['author'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, children: [
                    if ((d['subject'] ?? '').isNotEmpty) _chip(d['subject']),
                    if ((d['class'] ?? '').isNotEmpty) _chip(d['class']),
                  ]),
                  if (widget.canUpload) ...[const SizedBox(height: 6),
                    GestureDetector(onTap: () => docs[i].reference.delete(),
                      child: const Icon(Icons.delete_rounded, color: Colors.white70, size: 16))],
                ]));
            });
        })),
    ]));
  Widget _chip(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)));
}

// ════════════════════════════════════════════
//  VIEW ATTENDANCE (Admin)
// ════════════════════════════════════════════
class ViewAttendancePage extends StatefulWidget {
  const ViewAttendancePage({super.key});
  @override State<ViewAttendancePage> createState() => _ViewAttendancePageState();
}
class _ViewAttendancePageState extends State<ViewAttendancePage> {
  String _date = DateTime.now().toIso8601String().split('T')[0]; String _filterClass = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Attendance Records', subtitle: _date,
        colors: [AppColors.success, const Color(0xFF0FA36A)], showBack: true,
        actions: [IconButton(icon: const Icon(Icons.date_range_rounded, color: Colors.white),
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(),
                firstDate: DateTime(2024), lastDate: DateTime.now());
            if (d != null) setState(() => _date = d.toIso8601String().split('T')[0]);
          })]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 4), child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('classes').snapshots(),
        builder: (_, cs) {
          final classes = ['All', ...(cs.data?.docs.map((d) => (d.data() as Map)['name']?.toString() ?? '').toList() ?? [])];
          return DropdownButtonFormField<String>(initialValue: _filterClass.isEmpty ? 'All' : _filterClass,
            decoration: InputDecoration(labelText: 'Filter by Class',
                prefixIcon: const Icon(Icons.filter_list_rounded, color: AppColors.textGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            items: classes.cast<String>().map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
  value: c,
  child: Text(c == 'All' ? '📢 All Classes' : 'Class $c'),
)).toList(),
            onChanged: (v) => setState(() => _filterClass = v == 'All' ? '' : (v ?? '')));
        })),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('attendance').doc(_date).collection('students').snapshots(),
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          var docs = s.data!.docs;
          if (_filterClass.isNotEmpty) docs = docs.where((d) => (d.data() as Map)['class'] == _filterClass).toList();
          if (docs.isEmpty) return _EmptyState(label: 'No attendance for $_date${_filterClass.isNotEmpty ? '\nClass $_filterClass' : ''}');
          final present = docs.where((d) => (d.data() as Map)['status'] == 'Present').length;
          return Column(children: [
            Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              statCard('Present', present.toString(), Icons.check_circle_rounded, AppColors.success),
              statCard('Absent', (docs.length - present).toString(), Icons.cancel_rounded, AppColors.danger),
              statCard('Total', docs.length.toString(), Icons.groups_rounded, AppColors.accent, last: true),
            ])),
            Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map; final isP = d['status'] == 'Present';
                return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    CircleAvatar(radius: 18, backgroundColor: (isP ? AppColors.success : AppColors.danger).withOpacity(0.1),
                      child: Text((d['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isP ? AppColors.success : AppColors.danger))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['name'] ?? '', style: AppText.cardTitle),
                      Row(children: [
                        if ((d['class'] ?? '').isNotEmpty) Text('Class: ${d['class']}', style: AppText.label),
                        if ((d['method'] ?? '') == 'face_recognition') ...[const SizedBox(width: 6),
                          const Text('📷 Face', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700))],
                      ]),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (isP ? AppColors.success : AppColors.danger).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(d['status'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: isP ? AppColors.success : AppColors.danger))),
                  ]));
              })),
          ]);
        })),
    ]));
}

// ════════════════════════════════════════════
//  ANNOUNCEMENTS (with image + type + class target)
// ════════════════════════════════════════════
class AnnouncementsPage extends StatefulWidget {
  final bool canPost; final String? targetClass;
  const AnnouncementsPage({super.key, required this.canPost, this.targetClass});
  @override State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}
class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _title = TextEditingController(); final _msg = TextEditingController();
  final _img = TextEditingController(); String _type = 'general';

  void _showPost() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 22, right: 22, top: 22),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Post Announcement${widget.targetClass != null ? " — Class ${widget.targetClass}" : ""}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _tChip('general', '📢 General', setSt), _tChip('urgent', '🚨 Urgent', setSt),
          _tChip('event', '🎉 Event', setSt), _tChip('exam', '📝 Exam', setSt),
        ])),
        const SizedBox(height: 14),
        _field('Title *', _title, Icons.title_rounded),
        _field('Message', _msg, Icons.message_rounded, maxLines: 3),
        _field('Image URL (optional)', _img, Icons.image_rounded),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _tColor(_type)),
          onPressed: () async {
            if (_title.text.isEmpty) return;
            await FirebaseFirestore.instance.collection('announcements').add({
              'title': _title.text, 'message': _msg.text, 'imageUrl': _img.text,
              'type': _type, 'targetClass': widget.targetClass,
              'postedBy': FirebaseAuth.instance.currentUser?.uid, 'createdAt': FieldValue.serverTimestamp(),
            });
            _title.clear(); _msg.clear(); _img.clear();
            Navigator.pop(context);
          }, child: const Text('Post', style: TextStyle(fontWeight: FontWeight.w700)))),
      ]))));

  Widget _tChip(String val, String label, StateSetter setSt) => GestureDetector(onTap: () => setSt(() => _type = val),
    child: Container(margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _type == val ? _tColor(val) : _tColor(val).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _type == val ? Colors.white : _tColor(val)))));
  Color _tColor(String t) => t == 'urgent' ? AppColors.danger : t == 'event' ? AppColors.gold : t == 'exam' ? AppColors.accent : const Color(0xFF9B5DE5);

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: GradAppBar(title: 'Announcements', colors: AppColors.pinkGrad, showBack: true),
    floatingActionButton: widget.canPost ? FloatingActionButton.extended(onPressed: _showPost, backgroundColor: AppColors.danger,
        icon: const Icon(Icons.add), label: const Text('Post')) : null,
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('announcements').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        var docs = s.data!.docs;
        if (widget.targetClass != null) {
          docs = docs.where((d) { final tc = (d.data() as Map)['targetClass']; return tc == null || tc == widget.targetClass; }).toList();
        }
        if (docs.isEmpty) return const _EmptyState(label: 'No announcements yet', icon: Icons.campaign_rounded);
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map; final img = d['imageUrl'] ?? '';
            final type = d['type'] ?? 'general'; final tc = _tColor(type);
            return Container(margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (img.isNotEmpty) ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(img, width: double.infinity, height: 200, fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null ? child
                          : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                      errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(type.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tc))),
                    if ((d['targetClass'] ?? '').isNotEmpty) ...[const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('Class ${d['targetClass']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success))),
                    ],
                    const Spacer(),
                    Text(_timeAgo(d['createdAt']), style: AppText.label),
                  ]),
                  const SizedBox(height: 6),
                  Text(d['title'] ?? '', style: AppText.cardTitle),
                  if ((d['message'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4), Text(d['message'], style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                  ],
                  if (widget.canPost) Align(alignment: Alignment.centerRight,
                    child: TextButton.icon(onPressed: () => docs[i].reference.delete(),
                      icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.danger),
                      label: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 12)))),
                ])),
              ]));
          });
      }));
}

// ════════════════════════════════════════════
//  TEACHER DIRECTORY
// ════════════════════════════════════════════
class TeacherDirectoryPage extends StatelessWidget {
  const TeacherDirectoryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'My Teachers', subtitle: 'Who teaches what', colors: AppColors.teachGrad, showBack: true),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        if (docs.isEmpty) return const _EmptyState(label: 'No teachers found', icon: Icons.person_rounded);
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map; final photo = d['photoUrl'] ?? '';
            return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: const Color(0xFFFF6B35).withOpacity(0.15),
                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty ? Text((d['name'] as String? ?? 'T').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFF6B35), fontSize: 18)) : null),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['name'] ?? '', style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(d['subject'] ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text('Class ${d['assignedClass'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success))),
                    if ((d['qualification'] ?? '').isNotEmpty)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(d['qualification'], style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w600))),
                  ]),
                  if ((d['phone'] ?? '').isNotEmpty) ...[const SizedBox(height: 4), Text('📞 ${d['phone']}', style: AppText.label)],
                ])),
                IconButton(icon: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF11998E).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.message_rounded, color: Color(0xFF11998E), size: 18)),
                    onPressed: () => _push(context, MessageChatPage(otherUid: docs[i].id, otherName: d['name'] ?? 'Teacher'))),
              ]));
          });
      }));
}

// ════════════════════════════════════════════
//  NOTIFICATIONS VIEW (Student)
// ════════════════════════════════════════════
class NotificationsViewPage extends StatelessWidget {
  const NotificationsViewPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: 'Notifications', subtitle: 'School alerts',
        colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)], showBack: true),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').orderBy('sentAt', descending: true).snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs;
        if (docs.isEmpty) return const _EmptyState(label: 'No notifications yet', icon: Icons.notifications_none_rounded);
        return ListView.builder(padding: const EdgeInsets.all(14), itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map;
            return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: const Border(left: BorderSide(color: Color(0xFF11998E), width: 3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.notifications_rounded, color: Color(0xFF11998E), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d['title'] ?? '', style: AppText.cardTitle)),
                  Text(_timeAgo(d['sentAt']), style: AppText.label),
                ]),
                if ((d['body'] ?? '').isNotEmpty) ...[const SizedBox(height: 4), Text(d['body'], style: AppText.label)],
                if ((d['targetClass'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: Text('Class ${d['targetClass']}', style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w700))),
                ],
              ]));
          });
      }));
}

// ════════════════════════════════════════════
//  MESSAGES
// ════════════════════════════════════════════
class MessagesListPage extends StatefulWidget {
  const MessagesListPage({super.key});
  @override State<MessagesListPage> createState() => _MessagesListPageState();
}
class _MessagesListPageState extends State<MessagesListPage> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: GradAppBar(title: 'Messages', subtitle: 'Chat with anyone',
          colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)], showBack: true),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: const InputDecoration(hintText: 'Search by name or role...',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textGrey)),
          onChanged: (v) => setState(() => _search = v.toLowerCase()))),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            var users = s.data!.docs.where((d) => d.id != myUid).toList();
            if (_search.isNotEmpty) {
              users = users.where((d) {
              final data = d.data() as Map;
              return (data['name'] ?? '').toString().toLowerCase().contains(_search) ||
                     (data['role'] ?? '').toString().toLowerCase().contains(_search);
            }).toList();
            }
            if (users.isEmpty) return const _EmptyState(label: 'No users found', icon: Icons.message_rounded);
            return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: users.length,
              itemBuilder: (_, i) {
                final d = users[i].data() as Map;
                final name = d['name'] ?? 'User'; final role = d['role'] ?? ''; final photo = d['photoUrl'] ?? '';
                final rc = role == 'teacher' ? const Color(0xFFFF6B35) : role == 'admin' ? AppColors.accent : AppColors.success;
                return GestureDetector(onTap: () => _push(context, MessageChatPage(otherUid: users[i].id, otherName: name)),
                  child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      CircleAvatar(radius: 24, backgroundColor: rc.withOpacity(0.15),
                        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(fontWeight: FontWeight.w800, color: rc, fontSize: 18)) : null),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: AppText.cardTitle),
                        Container(margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(role.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: rc))),
                      ])),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textGrey),
                    ])));
              });
          })),
      ]));
  }
}

class MessageChatPage extends StatefulWidget {
  final String otherUid, otherName;
  const MessageChatPage({super.key, required this.otherUid, required this.otherName});
  @override State<MessageChatPage> createState() => _MessageChatPageState();
}
class _MessageChatPageState extends State<MessageChatPage> {
  final _ctrl = TextEditingController(); final _scroll = ScrollController();
  late String _chatId, _myUid;
  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sorted = [_myUid, widget.otherUid]..sort();
    _chatId = sorted.join('_');
  }
  @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim(); if (text.isEmpty) return; _ctrl.clear();
    try {
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').add(
          {'fromUid': _myUid, 'text': text, 'timestamp': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set(
          {'participants': [_myUid, widget.otherUid], 'lastMessage': text, 'lastTimestamp': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Send failed: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GradAppBar(title: widget.otherName, subtitle: 'Personal Chat',
        colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)], showBack: true),
    body: Column(children: [
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(_chatId)
            .collection('messages').orderBy('timestamp').snapshots(),
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final msgs = s.data!.docs;
          if (msgs.isEmpty) return const _EmptyState(label: 'No messages yet.\nSay hello! 👋', icon: Icons.message_rounded);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
          });
          return ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            itemCount: msgs.length,
            itemBuilder: (_, i) {
              final d = msgs[i].data() as Map; final isMe = d['fromUid'] == _myUid;
              return TweenAnimationBuilder<double>(tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 180), curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 6, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: isMe ? AppColors.accent : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                          bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18)),
                        boxShadow: [BoxShadow(color: (isMe ? AppColors.accent : Colors.black).withOpacity(0.10),
                            blurRadius: 8, offset: const Offset(0, 2))]),
                    child: Text(d['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : AppColors.textDark, fontSize: 14)))));
            });
        })),
      Container(padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))]),
        child: Row(children: [
          Expanded(child: TextField(controller: _ctrl, onSubmitted: (_) => _send(),
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(hintText: 'Type a message...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: Color(0xFFE4E7F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: Color(0xFFE4E7F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2)),
              filled: true, fillColor: AppColors.surface))),
          const SizedBox(width: 10),
          _SendBtn(onTap: _send),
        ])),
    ]));
}

class _SendBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _SendBtn({required this.onTap});
  @override State<_SendBtn> createState() => _SendBtnState();
}
class _SendBtnState extends State<_SendBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override void initState() { super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 80),
        lowerBound: 0.88, upperBound: 1.0, value: 1.0); }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ac.reverse(), onTapUp: (_) { _ac.forward(); widget.onTap(); },
    onTapCancel: () => _ac.forward(),
    child: ScaleTransition(scale: _ac, child: Container(width: 48, height: 48,
      decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle),
      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))));
}

// ════════════════════════════════════════════
//  UTILS & HELPERS
// ════════════════════════════════════════════
String _todayLabel() {
  final now = DateTime.now();
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  return '${w[now.weekday - 1]}, ${m[now.month - 1]} ${now.day} ${now.year}';
}

String _timeAgo(dynamic ts) {
  if (ts == null) return 'Just now';
  if (ts is Timestamp) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
  return '';
}

Future<void> _logActivity(String message) =>
    FirebaseFirestore.instance.collection('activity_log').add({
      'message': message, 'timestamp': FieldValue.serverTimestamp(),
    });