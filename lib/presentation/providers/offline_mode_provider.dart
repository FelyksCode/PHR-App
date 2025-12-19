import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the app should avoid network calls and rely on cached data.
/// Setting this to true should bypass network-auth flows and force cached data usage.
/// Combined with connectivityProvider to form the app's offline/online mode.
final offlineModeProvider = StateProvider<bool>((ref) => false);
