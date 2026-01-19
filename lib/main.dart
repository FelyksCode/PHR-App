import 'package:flutter/material.dart';
import 'package:phr_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'core/constants/api_constants.dart';
import 'core/network/api_client.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/health/heart_rate_monitor_screen.dart';
import 'presentation/screens/dashboard/main_shell.dart';
import 'presentation/screens/settings/permissions_screen.dart';
import 'presentation/screens/vendors/vendor_selection_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/health_permission_checker_provider.dart';
import 'services/notification_service.dart';
import 'services/workmanager_service.dart';

// Provider to track permissions status (prevents repeated async calls)
final permissionsRequestedProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ApiClient.initialize(baseUrl: ApiConstants.baseUrl);

  await NotificationService.instance.init();
  await NotificationService.instance.requestNotificationPermission();

  if (Platform.isAndroid) {
    await WorkManagerService.instance.initialize(
      isInDebugMode: false, // Set to true for debugging background tasks
    );
  }

  runApp(const ProviderScope(child: PHRApp()));
}

class PHRApp extends ConsumerWidget {
  const PHRApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Personal Health Record',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('id')],
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
        '/dashboard': (context) => const MainShell(),
        '/heart-rate-monitor': (context) => const HeartRateMonitorScreen(),
        '/vendors': (context) => const VendorSelectionScreen(),
      },
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Trigger initial permission check
    Future.microtask(() {
      ref.read(healthPermissionCheckerProvider.notifier).checkPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final permissionsRequested = ref.watch(permissionsRequestedProvider);
    final permissionCheckState = ref.watch(healthPermissionCheckerProvider);

    // Show loading while checking auth status
    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show login screen if not authenticated
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // If authenticated, use cached permission check
    return permissionCheckState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) {
        debugPrint('[AuthWrapper] Permission check error: $error');
        // On error, show permissions screen to allow user to retry
        return const PermissionsScreen();
      },
      data: (result) {
        final allPermissionsGranted = result.allPermissionsGranted;

        // If all permissions are granted, go directly to dashboard
        if (allPermissionsGranted) {
          // Mark permissions as requested to avoid showing permission screen later
          Future.microtask(() {
            ref.read(permissionsRequestedProvider.notifier).state = true;
          });
          return const MainShell();
        }

        // If permissions not requested and not all granted, show permissions screen
        if (!permissionsRequested) {
          return const PermissionsScreen();
        }

        // Show dashboard screen if permissions were requested (even if some denied)
        return const MainShell();
      },
    );
  }
}
