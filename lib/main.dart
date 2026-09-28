import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/supabase_service.dart';
import 'services/deep_link_service.dart';
import 'models/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('es', null);

  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  // Initialize Deep Links
  DeepLinkService().init();

  // Parse query parameters from deep link
  try {
    final code =
        Uri.base.queryParameters['routine'] ?? Uri.base.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      SupabaseService.pendingShareCode = code;
    }
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Color(0xFF737373),
          surface: Colors.white,
          error: Colors.black,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final screenWidth = mediaQueryData.size.width;
        if (screenWidth > 600) {
          const double targetWidth = 480;
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF2C2C2C), Color(0xFF0F0F0F)],
                radius: 1.5,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: targetWidth, maxHeight: 950),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.black87, width: 8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: MediaQuery(
                      data: mediaQueryData.copyWith(
                        size: Size(
                          targetWidth,
                          mediaQueryData.size.height > 950 ? 950 : mediaQueryData.size.height,
                        ),
                      ),
                      child: child!,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return child!;
      },
      home: StreamBuilder<UserProfile?>(
        stream: SupabaseService().authStateChangesProfile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            );
          }
          final userProfile = snapshot.data;
          if (userProfile != null) {
            if (userProfile.isAdmin) {
              return const AdminDashboardScreen();
            } else {
              return const HomeScreen();
            }
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
