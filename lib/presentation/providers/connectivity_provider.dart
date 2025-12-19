import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global online/offline flag. True means internet reachable; false means offline.
final connectivityProvider = StateProvider<bool>((ref) => true);
