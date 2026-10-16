import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get isSupabaseConfigured => supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isSupabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const AcademicPlatformApp());
}

const navy = Color(0xFF102A43);
const blue = Color(0xFF1976D2);
const paleBlue = Color(0xFFEAF3FF);
const pageBg = Color(0xFFF5F7FB);

class AcademicPlatformApp extends StatelessWidget {
  const AcademicPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المنصة الأكاديمية الرقمية',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue),
        scaffoldBackgroundColor: pageBg,
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          backgroundColor: pageBg,
          foregroundColor: navy,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3EAF2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

enum UserRole { student, teacher, head, admin }

extension RoleDetails on UserRole {
  String get label => switch (this) {
        UserRole.student => 'طالب',
        UserRole.teacher => 'مدرس',
        UserRole.head => 'رئيس القسم',
        UserRole.admin => 'إدارة الكلية',
      };
  String get greeting => switch (this) {
        UserRole.student => 'مرحباً بك في رحلتك التعليمية',
        UserRole.teacher => 'إدارة مقرراتك ومتابعة طلابك',
        UserRole.head => 'متابعة أداء القسم والمقررات',
        UserRole.admin => 'نظرة شاملة على العملية التعليمية',
      };
  IconData get icon => switch (this) {
        UserRole.student => Icons.school_rounded,
        UserRole.teacher => Icons.cast_for_education_rounded,
        UserRole.head => Icons.account_tree_rounded,
        UserRole.admin => Icons.admin_panel_settings_rounded,
      };
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!isSupabaseConfigured) {
      _message('لم يتم إعداد Supabase بعد. أضف SUPABASE_URL وSUPABASE_ANON_KEY إلى إعدادات البناء.');
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _message('أدخل البريد الإلكتروني وكلمة المرور');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AuthException('تعذر التحقق من الحساب');
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, role, is_active')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) {
        await Supabase.instance.client.auth.signOut();
        throw const AuthException('الحساب غير مضاف إلى ملفات المنصة. راجع إدارة الكلية.');
      }
      if (profile['is_active'] == false) {
        await Supabase.instance.client.auth.signOut();
        throw const AuthException('هذا الحساب موقوف. راجع إدارة الكلية.');
      }
      final role = switch (profile['role']) {
        'student' => UserRole.student,
        'teacher' => UserRole.teacher,
        'head' => UserRole.head,
        'admin' => UserRole.admin,
        _ => throw const AuthException('صلاحية الحساب غير صحيحة؛ راجع إدارة المنصة.'),
      };
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => HomeScreen(
          role: role,
          displayName: (profile['full_name'] as String?)?.trim().isNotEmpty == true
              ? profile['full_name'] as String
              : (user.email ?? email),
        ),
      ));
    } on AuthException catch (e) {
      _message(e.message);
    } on PostgrestException catch (e) {
      _message('تعذر تحميل ملف الحساب: ${e.message}');
    } catch (e) {
      _message('تعذر تسجيل الدخول. تحقق من الاتصال وإعدادات Supabase.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.center, child: Container(
                  width: 86, height: 86,
                  decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x22102A43), blurRadius: 24, offset: Offset(0, 10))]),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                )),
                const SizedBox(height: 22),
                const Text('المنصة الأكاديمية الرقمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy)),
                const SizedBox(height: 8),
                const Text('إدارة ومتابعة العملية التعليمية', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                const Text('جامعة الحديدة · كلية التربية – زبيد', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF8291A5))),
                const SizedBox(height: 34),
                const Text('تسجيل الدخول', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: navy)),
                const SizedBox(height: 6),
                const Text('استخدم بيانات الحساب الذي أنشأته إدارة الكلية', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 22),
                const FieldLabel('البريد الإلكتروني'),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: const InputDecoration(hintText: 'name@example.com', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 16),
                const FieldLabel('كلمة المرور'),
                TextField(controller: _passwordController, obscureText: _hidePassword, onSubmitted: (_) => _login(), autofillHints: const [AutofillHints.password], decoration: InputDecoration(hintText: 'أدخل كلمة المرور', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _login,
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded),
                  label: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text(_busy ? 'جارٍ التحقق...' : 'دخول إلى المنصة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  style: FilledButton.styleFrom(backgroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
                const SizedBox(height: 18),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(14)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.security_rounded, color: blue), const SizedBox(width: 10), Expanded(child: Text(isSupabaseConfigured ? 'تسجيل الدخول مرتبط بخدمة Supabase. صلاحية المستخدم تُقرأ من قاعدة البيانات ولا يختارها المستخدم بنفسه.' : 'لم تُضف إعدادات Supabase بعد. لن يقبل التطبيق تسجيل دخول تجريبي؛ جهّز مشروع Supabase ثم مرّر رابط المشروع ومفتاح anon عند البناء.', style: const TextStyle(fontSize: 12, height: 1.6, color: navy)))])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 14)));
}

class Course {
  final String name;
  final String code;
  final String teacher;
  final double progress;
  final Color color;
  const Course(this.name, this.code, this.teacher, this.progress, this.color);
}

const courses = <Course>[
  Course('أساسيات الحاسوب', 'CS101', 'أ. أحمد محمد', .78, Color(0xFF1976D2)),
  Course('برمجة تطبيقات الهاتف', 'CS204', 'أ. خالد علي', .54, Color(0xFF0F9D8A)),
  Course('قواعد البيانات', 'CS220', 'أ. سمية حسن', .86, Color(0xFF8B5CF6)),
  Course('تحليل وتصميم النظم', 'CS230', 'أ. محمد صالح', .32, Color(0xFFF59E0B)),
];

class HomeScreen extends StatefulWidget {
  final UserRole role;
  final String displayName;
  const HomeScreen({super.key, required this.role, required this.displayName});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(role: widget.role, displayName: widget.displayName, openFeature: _openFeature),
      CoursesPage(role: widget.role),
      const NotificationsPage(),
      ProfilePage(role: widget.role, displayName: widget.displayName, onLogout: _logout),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.school_rounded, color: Colors.white, size: 22)), const SizedBox(width: 10), const Expanded(child: Text('المنصة الأكاديمية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)))]),
          actions: [IconButton(onPressed: () => setState(() => _tab = 2), icon: const Icon(Icons.notifications_none_rounded)), const SizedBox(width: 6)],
        ),
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          backgroundColor: Colors.white,
          indicatorColor: paleBlue,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'المقررات'),
            NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: 'الإشعارات'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
          ],
        ),
      ),
    );
  }

  void _openFeature(String feature) {
    if (feature == 'إدارة المستخدمين' && widget.role == UserRole.admin) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersPage()));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeaturePage(title: feature, role: widget.role)));
  }

  Future<void> _logout() async {
    if (isSupabaseConfigured) await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentNumber = TextEditingController();
  UserRole _role = UserRole.student;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose(); _studentNumber.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!isSupabaseConfigured) { _show('إعداد Supabase غير مكتمل'); return; }
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.length < 8) {
      _show('أدخل الاسم والبريد وكلمة مرور لا تقل عن 8 أحرف');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-user',
        body: {
          'full_name': _name.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'password': _password.text,
          'role': switch (_role) { UserRole.student => 'student', UserRole.teacher => 'teacher', UserRole.head => 'head', UserRole.admin => 'admin' },
          'student_number': _studentNumber.text.trim(),
          'department': 'قسم معلم حاسوب',
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        throw Exception(data is Map ? data['error'] ?? 'تعذر إنشاء الحساب' : 'تعذر إنشاء الحساب');
      }
      _name.clear(); _email.clear(); _password.clear(); _studentNumber.clear();
      if (mounted) _show('تم إنشاء الحساب وإضافته إلى المنصة');
    } on FunctionException catch (e) {
      _show('تعذر إنشاء الحساب: ${e.details ?? e.reasonPhrase ?? 'خطأ بالخدمة'}');
    } catch (e) {
      _show('تعذر إنشاء الحساب. تحقق من نشر دالة create-user وإعداد الصلاحيات.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إدارة حسابات المنصة')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 8),
        const Text('تنشئ الإدارة حسابات الطلاب والمدرسين ورئيس القسم. الصلاحية تُحفظ في قاعدة البيانات ولا يحددها المستخدم عند تسجيل الدخول.', style: TextStyle(height: 1.6, color: Color(0xFF64748B))),
        const SizedBox(height: 20),
        const FieldLabel('الاسم الكامل'), TextField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'الاسم كما سيظهر في المنصة')),
        const SizedBox(height: 14), const FieldLabel('البريد الإلكتروني'), TextField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), hintText: 'name@example.com')),
        const SizedBox(height: 14), const FieldLabel('كلمة المرور الأولية'), TextField(controller: _password, obscureText: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), hintText: '8 أحرف على الأقل')),
        const SizedBox(height: 14), const FieldLabel('نوع الحساب'), DropdownButtonFormField<UserRole>(value: _role, items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(), onChanged: _busy ? null : (v) => setState(() => _role = v ?? UserRole.student), decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined))),
        if (_role == UserRole.student) ...[const SizedBox(height: 14), const FieldLabel('الرقم الجامعي (اختياري)'), TextField(controller: _studentNumber, decoration: const InputDecoration(prefixIcon: Icon(Icons.numbers), hintText: 'الرقم الجامعي'))],
        const SizedBox(height: 22), FilledButton.icon(onPressed: _busy ? null : _create, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1), label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب'))),
        const SizedBox(height: 14), const Text('يتطلب ذلك تنفيذ schema.sql ونشر دالة Supabase Edge Function المسماة create-user. لا يوضع مفتاح service_role داخل التطبيق.', style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF64748B))),
      ]),
    ),
  );
}

class DashboardPage extends StatelessWidget {
  final UserRole role;
  final String displayName;
  final ValueChanged<String> openFeature;
  const DashboardPage({super.key, required this.role, required this.displayName, required this.openFeature});

  @override
  Widget build(BuildContext context) {
    final stats = switch (role) {
      UserRole.student => const [(Icons.menu_book_rounded, 'المقررات', '4', Color(0xFF1976D2)), (Icons.fact_check_outlined, 'نسبة الحضور', '92%', Color(0xFF0F9D8A)), (Icons.assignment_outlined, 'تكليفات قادمة', '2', Color(0xFFF59E0B)), (Icons.trending_up_rounded, 'متوسط التقدم', '63%', Color(0xFF8B5CF6))],
      UserRole.teacher => const [(Icons.menu_book_rounded, 'مقرراتي', '4', Color(0xFF1976D2)), (Icons.groups_2_outlined, 'الطلاب', '86', Color(0xFF0F9D8A)), (Icons.fact_check_outlined, 'سجلات الحضور', '12', Color(0xFFF59E0B)), (Icons.assignment_outlined, 'التكليفات', '7', Color(0xFF8B5CF6))],
      UserRole.head => const [(Icons.menu_book_rounded, 'المقررات', '18', Color(0xFF1976D2)), (Icons.groups_2_outlined, 'المدرسون', '12', Color(0xFF0F9D8A)), (Icons.fact_check_outlined, 'تقارير الحضور', '8', Color(0xFFF59E0B)), (Icons.report_gmailerrorred_rounded, 'الشكاوى', '3', Color(0xFF8B5CF6))],
      UserRole.admin => const [(Icons.menu_book_rounded, 'المقررات', '32', Color(0xFF1976D2)), (Icons.groups_2_outlined, 'المستخدمون', '248', Color(0xFF0F9D8A)), (Icons.assessment_outlined, 'التقارير', '12', Color(0xFFF59E0B)), (Icons.pending_actions_rounded, 'طلبات معلقة', '5', Color(0xFF8B5CF6))],
    };
    final actions = switch (role) {
      UserRole.student => const [(Icons.library_books_outlined, 'ملفات المحاضرات'), (Icons.assignment_outlined, 'الواجبات والتكليفات'), (Icons.fact_check_outlined, 'الحضور والغياب'), (Icons.rate_review_outlined, 'تقييم المقرر'), (Icons.support_agent_rounded, 'الشكاوى والمقترحات'), (Icons.campaign_outlined, 'الإعلانات')],
      UserRole.teacher => const [(Icons.library_books_outlined, 'إدارة المحاضرات'), (Icons.assignment_outlined, 'إدارة التكليفات'), (Icons.fact_check_outlined, 'تسجيل الحضور'), (Icons.trending_up_rounded, 'تقدم المقرر'), (Icons.groups_2_outlined, 'متابعة الطلاب'), (Icons.campaign_outlined, 'الإعلانات')],
      UserRole.head => const [(Icons.menu_book_rounded, 'متابعة المقررات'), (Icons.groups_2_outlined, 'متابعة المدرسين'), (Icons.assessment_outlined, 'تقارير القسم'), (Icons.fact_check_outlined, 'متابعة الحضور'), (Icons.support_agent_rounded, 'الشكاوى والمقترحات'), (Icons.trending_up_rounded, 'مؤشرات الأداء')],
      UserRole.admin => const [(Icons.manage_accounts_outlined, 'إدارة المستخدمين'), (Icons.admin_panel_settings_outlined, 'الصلاحيات'), (Icons.assessment_outlined, 'التقارير العامة'), (Icons.menu_book_rounded, 'إدارة المقررات'), (Icons.support_agent_rounded, 'الشكاوى والمقترحات'), (Icons.insights_rounded, 'الإحصائيات')],
    };
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy, Color(0xFF1D4E89)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('أهلاً، $displayName', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)), child: Text(role.label, style: const TextStyle(color: Colors.white, fontSize: 12)))]),
          const SizedBox(height: 10),
          Text(role.greeting, style: const TextStyle(color: Color(0xFFD8E8FA), fontSize: 14)),
          const SizedBox(height: 20),
          const Row(children: [Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 18), SizedBox(width: 8), Text('الفصل الدراسي الحالي', style: TextStyle(color: Colors.white70, fontSize: 12)), Spacer(), Text('2026 – 2027', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]),
        ]),
      ),
      const SizedBox(height: 24),
      const SectionHeading(title: 'ملخص سريع', subtitle: 'نظرة عامة على بياناتك'),
      const SizedBox(height: 12),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: stats.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55), itemBuilder: (_, i) => StatCard(icon: stats[i].$1, title: stats[i].$2, value: stats[i].$3, color: stats[i].$4)),
      const SizedBox(height: 24),
      const SectionHeading(title: 'الخدمات الأكاديمية', subtitle: 'اختر الخدمة التي تريدها'),
      const SizedBox(height: 12),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: actions.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .95), itemBuilder: (_, i) => ActionTile(icon: actions[i].$1, title: actions[i].$2, onTap: () => openFeature(actions[i].$2))),
      const SizedBox(height: 24),
      const SectionHeading(title: 'آخر الإعلانات', subtitle: 'مستجدات الكلية والمقررات'),
      const SizedBox(height: 12),
      const NoticeTile(icon: Icons.campaign_rounded, title: 'مرحباً بكم في المنصة الأكاديمية', body: 'هذه نسخة تجريبية لعرض الواجهات والخدمات الأساسية.', time: 'إعلان المنصة'),
      const SizedBox(height: 10),
      const NoticeTile(icon: Icons.event_note_rounded, title: 'تابع مواعيد التكليفات', body: 'راجع صفحة الواجبات لمعرفة المطلوب ومواعيد التسليم.', time: 'تنبيه أكاديمي'),
    ]);
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const SectionHeading({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF7B8798)))]))]);
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const StatCard({super.key, required this.icon, required this.title, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 20)), Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)), Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A8D)))])));
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const ActionTile({super.key, required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: Colors.white, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: blue, size: 23)), const SizedBox(height: 9), Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.35, fontWeight: FontWeight.w700, color: navy))]))));
}

class NoticeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  const NoticeTile({super.key, required this.icon, required this.title, required this.body, required this.time});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: blue)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 5), Text(body, style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF6B7A8D))), const SizedBox(height: 7), Text(time, style: const TextStyle(fontSize: 10, color: blue, fontWeight: FontWeight.w700))]))])));
}

class CoursesPage extends StatelessWidget {
  final UserRole role;
  const CoursesPage({super.key, required this.role});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [const Text('المقررات الدراسية', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 7), Text(role == UserRole.student ? 'المقررات المسجل بها هذا الفصل' : 'استعراض المقررات ومتابعة تفاصيلها', style: const TextStyle(color: Color(0xFF718096))), const SizedBox(height: 20), ...courses.map((course) => Padding(padding: const EdgeInsets.only(bottom: 12), child: CourseCard(course: course, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailsPage(course: course, role: role))))))]);
}

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const CourseCard({super.key, required this.course, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: course.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.menu_book_rounded, color: course.color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(course.name, style: const TextStyle(fontWeight: FontWeight.w800, color: navy, fontSize: 15)), const SizedBox(height: 4), Text('${course.code}  ·  ${course.teacher}', style: const TextStyle(fontSize: 11, color: Color(0xFF718096)))])), const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8))]), const SizedBox(height: 17), Row(children: [const Expanded(child: Text('إنجاز المقرر', style: TextStyle(fontSize: 12, color: Color(0xFF718096)))), Text('${(course.progress * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: course.color))]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: course.progress, minHeight: 7, backgroundColor: const Color(0xFFEDF1F6), color: course.color))]))));
}

class CourseDetailsPage extends StatelessWidget {
  final Course course;
  final UserRole role;
  const CourseDetailsPage({super.key, required this.course, required this.role});
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('تفاصيل المقرر')), body: ListView(padding: const EdgeInsets.all(18), children: [Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(course.code, style: const TextStyle(color: Color(0xFFB9D9FF))), const SizedBox(height: 8), Text(course.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(course.teacher, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 20), LinearProgressIndicator(value: course.progress, color: Colors.lightBlueAccent, backgroundColor: Colors.white24, minHeight: 8), const SizedBox(height: 8), Text('نسبة الإنجاز ${(course.progress * 100).round()}%', style: const TextStyle(color: Colors.white))])), const SizedBox(height: 22), const SectionHeading(title: 'محتويات المقرر', subtitle: 'مواد تعليمية ومتابعة'), const SizedBox(height: 12), FeatureRow(icon: Icons.picture_as_pdf_outlined, title: 'المحاضرة الأولى: مقدمة وتعريفات', subtitle: 'ملف محاضرة · نموذج تجريبي', onTap: () => showInfo(context, 'ملفات المحاضرات')), FeatureRow(icon: Icons.assignment_outlined, title: 'التكليف الأول', subtitle: 'راجع تعليمات التكليف وموعد التسليم', onTap: () => showInfo(context, 'الواجبات والتكليفات')), FeatureRow(icon: Icons.fact_check_outlined, title: 'سجل الحضور', subtitle: 'عرض الحضور والغياب', onTap: () => showInfo(context, 'الحضور والغياب'))])));
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [const Text('الإشعارات', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 7), const Text('آخر التنبيهات والإعلانات الأكاديمية', style: TextStyle(color: Color(0xFF718096))), const SizedBox(height: 20), const NoticeTile(icon: Icons.campaign_rounded, title: 'إعلان عام', body: 'مرحباً بك في النسخة التجريبية للمنصة الأكاديمية.', time: 'اليوم'), const SizedBox(height: 12), const NoticeTile(icon: Icons.assignment_outlined, title: 'تذكير بالتكليفات', body: 'تحقق من صفحة المقرر لمعرفة التكليفات القادمة.', time: 'تنبيه'), const SizedBox(height: 12), const NoticeTile(icon: Icons.event_available_outlined, title: 'متابعة الحضور', body: 'تأكد من مراجعة سجل حضورك بشكل دوري.', time: 'إرشاد')]);
}

class ProfilePage extends StatelessWidget {
  final UserRole role;
  final String displayName;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.role, required this.displayName, required this.onLogout});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [const Text('حسابي', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 20), Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [CircleAvatar(radius: 38, backgroundColor: paleBlue, child: Icon(role.icon, color: blue, size: 38)), const SizedBox(height: 14), Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 5), Text(role.label, style: const TextStyle(color: Color(0xFF718096))), const SizedBox(height: 18), const Divider(), const ProfileInfoRow(label: 'الجهة التعليمية', value: 'كلية التربية – زبيد'), ProfileInfoRow(label: 'نوع الحساب', value: role.label), ProfileInfoRow(label: 'حالة الربط', value: isSupabaseConfigured ? 'Supabase' : 'غير مهيأ')]))), const SizedBox(height: 16), FeatureRow(icon: Icons.support_agent_rounded, title: 'المساعدة والدعم', subtitle: 'الأسئلة والشكاوى والمقترحات', onTap: () => showInfo(context, 'المساعدة والدعم')), const SizedBox(height: 10), FeatureRow(icon: Icons.info_outline_rounded, title: 'عن المنصة', subtitle: 'نسخة أولية قيد التطوير', onTap: () => showInfo(context, 'عن المنصة الأكاديمية')), const SizedBox(height: 22), OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded), label: const Padding(padding: EdgeInsets.all(13), child: Text('تسجيل الخروج')), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB42318), side: const BorderSide(color: Color(0xFFF0C7C4), width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))]);
}

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const ProfileInfoRow({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF718096), fontSize: 13))), Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13))]));
}

class FeaturePage extends StatefulWidget {
  final String title;
  final UserRole role;
  const FeaturePage({super.key, required this.title, required this.role});
  @override
  State<FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends State<FeaturePage> {
  final _textController = TextEditingController();
  final List<String> _items = [];

  @override
  void dispose() { _textController.dispose(); super.dispose(); }

  bool get _isInputFeature => widget.title.contains('الشكاوى') || widget.title.contains('الإعلانات') || widget.title.contains('التكليفات');

  @override
  Widget build(BuildContext context) {
    final examples = _sampleItems(widget.title);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: Text(widget.title)), body: ListView(padding: const EdgeInsets.all(18), children: [Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 26)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(height: 5), Text('الخدمة متاحة للعرض في النسخة التجريبية · ${widget.role.label}', style: const TextStyle(color: Color(0xFFD8E8FA), fontSize: 11))]))])), const SizedBox(height: 22), const SectionHeading(title: 'المحتوى', subtitle: 'بيانات توضيحية للنسخة الأولية'), const SizedBox(height: 12), if (_isInputFeature) ...[TextField(controller: _textController, maxLines: 3, decoration: InputDecoration(hintText: widget.title.contains('الشكاوى') ? 'اكتب الشكوى أو المقترح هنا...' : 'اكتب عنواناً أو وصفاً مختصراً هنا...', alignLabelWithHint: true)), const SizedBox(height: 10), FilledButton.icon(onPressed: () { if (_textController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب المحتوى أولاً'))); return; } setState(() { _items.insert(0, _textController.text.trim()); _textController.clear(); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة محلياً في هذه الجلسة التجريبية'))); }, icon: const Icon(Icons.add_rounded), label: const Text('إضافة إلى القائمة')), const SizedBox(height: 16)], if (_items.isNotEmpty) ..._items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FeatureRow(icon: Icons.note_alt_outlined, title: item, subtitle: 'إضافة تجريبية محلية', onTap: () {}))), ...examples.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FeatureRow(icon: item.$1, title: item.$2, subtitle: item.$3, onTap: () => showInfo(context, item.$2)))), const SizedBox(height: 12), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF5E5), borderRadius: BorderRadius.circular(14)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: Color(0xFF9A6700)), SizedBox(width: 10), Expanded(child: Text('تنبيه: البيانات الحالية تجريبية ومحلية داخل الواجهة. الحفظ الدائم والمزامنة بين حسابات متعددة يحتاجان إلى ربط قاعدة بيانات وخادم.', style: TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF7A4B00))))]))])));
  }
}

List<(IconData, String, String)> _sampleItems(String title) {
  if (title.contains('حضور')) return [(Icons.check_circle_outline_rounded, 'الأحد – أساسيات الحاسوب', 'حاضر · مثال توضيحي'), (Icons.event_busy_outlined, 'الثلاثاء – قواعد البيانات', 'لم يتم اعتماد السجل بعد')];
  if (title.contains('واجب') || title.contains('تكليف')) return [(Icons.assignment_outlined, 'حل أسئلة الفصل الأول', 'موعد التسليم: يحدد من المدرس'), (Icons.pending_actions_rounded, 'تطبيق عملي للمقرر', 'قيد المتابعة')];
  if (title.contains('محاضرات') || title.contains('المحاضرات')) return [(Icons.picture_as_pdf_outlined, 'المحاضرة الأولى: مقدمة المقرر', 'ملف تعليمي تجريبي'), (Icons.slideshow_outlined, 'المحاضرة الثانية: المفاهيم الأساسية', 'ملف تعليمي تجريبي')];
  if (title.contains('تقرير') || title.contains('إحصائ') || title.contains('مؤشرات')) return [(Icons.bar_chart_rounded, 'ملخص الأداء الأكاديمي', 'سيظهر التقرير بعد ربط قاعدة البيانات'), (Icons.pie_chart_outline_rounded, 'إحصاءات الحضور والتقدم', 'بيانات تجريبية غير معتمدة')];
  if (title.contains('مقرر')) return courses.map((c) => (Icons.menu_book_rounded, c.name, '${c.code} · إنجاز ${(c.progress * 100).round()}%')).toList();
  if (title.contains('طلاب') || title.contains('مدرس') || title.contains('مستخدم')) return [(Icons.person_outline_rounded, 'قائمة المستخدمين', 'تحتاج إلى بيانات حقيقية من الخادم'), (Icons.manage_accounts_outlined, 'إدارة الحسابات', 'متاحة بعد تفعيل الصلاحيات')];
  if (title.contains('إعلان')) return [(Icons.campaign_outlined, 'إعلان الكلية', 'مثال لإعلان أكاديمي'), (Icons.notifications_active_outlined, 'تنبيه المقرر', 'مثال لتنبيه للطلاب')];
  return [(Icons.info_outline_rounded, 'لا توجد بيانات فعلية بعد', 'ستظهر البيانات عند ربط قاعدة البيانات والخدمات الخلفية'), (Icons.settings_outlined, 'إعدادات الخدمة', 'قيد التطوير')];
}

class FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const FeatureRow({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(onTap: onTap, leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: blue)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),), trailing: const Icon(Icons.chevron_left_rounded, color: Color(0xFF94A3B8))));
}

void showInfo(BuildContext context, String title) {
  showDialog<void>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: Text(title), content: const Text('هذه الوظيفة جزء من الهيكل الأولي. سيتم تفعيلها وربطها بالبيانات الفعلية في المراحل التالية.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))])));
}