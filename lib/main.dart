import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/permissions_screen.dart';
import 'providers/auth_provider.dart';

// Add a provider to track permissions status
final permissionsRequestedProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize API client with Android emulator IP
  ApiClient.initialize(baseUrl: 'http://10.0.2.2:8000');
  
  runApp(const ProviderScope(child: PHRApp()));
}

class PHRApp extends StatelessWidget {
  const PHRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Health Record',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
          surface: Colors.white,
          onSurface: const Color(0xFF1C1C1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1C1C1E),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE5E5EA), width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/permissions': (context) => const PermissionsScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final permissionsRequested = ref.watch(permissionsRequestedProvider);
    
    // Show loading while checking auth status
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show login screen if not authenticated
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }
    
    // If authenticated but permissions not requested, show permissions screen
    if (authState.isAuthenticated && !permissionsRequested) {
      return const PermissionsScreen();
    }
    
    // Show dashboard screen if authenticated and permissions handled
    return const DashboardScreen();
  }
}
