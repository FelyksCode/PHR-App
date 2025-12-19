import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/local_cache_service.dart';

final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService();
});
