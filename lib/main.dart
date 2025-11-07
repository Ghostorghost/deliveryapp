import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Make sure this is imported
// import 'package:path_provider/path_provider.dart'; // This import is no longer needed for Hive initialization
import 'firebase_options.dart';

// screens
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/phone_login_screen.dart';
import 'screens/common/role_based_redirect.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/agent/agent_home_screen.dart';
import 'screens/customer/customer_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- FIX START ---
  // Hive.initFlutter() automatically handles platform-specific initialization.
  // It uses path_provider internally for non-web platforms and IndexedDB for web.
  await Hive.initFlutter();
  // The following lines are no longer needed:
  // final appDocDir = await getApplicationDocumentsDirectory();
  // await Hive.initFlutter(appDocDir.path);
  // --- FIX END ---

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _updateTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogiDelivery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,

      // Launch with the welcome screen
      home: const WelcomeScreen(),

      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => const RegisterPage(),
        '/phone-login': (context) => const PhoneLoginScreen(),
        '/redirect': (context) => const RoleBasedRedirect(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/agent': (context) => const AgentHome(),
        '/customer': (context) => CustomerHome(onThemeChanged: _updateTheme),
      },
    );
  }
}