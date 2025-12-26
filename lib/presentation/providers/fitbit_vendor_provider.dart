import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/health_observation.dart';
import '../../services/api_service.dart';

class FitbitVendorState {
  final bool isLoading;
  final bool isSelecting;
  final bool isSyncing;
  final FitbitStatus? status;
  final SyncResult? lastSyncResult;
  final String? error;

  const FitbitVendorState({
    this.isLoading = false,
    this.isSelecting = false,
    this.isSyncing = false,
    this.status,
    this.lastSyncResult,
    this.error,
  });

  FitbitVendorState copyWith({
    bool? isLoading,
    bool? isSelecting,
    bool? isSyncing,
    FitbitStatus? status,
    SyncResult? lastSyncResult,
    String? error,
  }) {
    return FitbitVendorState(
      isLoading: isLoading ?? this.isLoading,
      isSelecting: isSelecting ?? this.isSelecting,
      isSyncing: isSyncing ?? this.isSyncing,
      status: status ?? this.status,
      lastSyncResult: lastSyncResult ?? this.lastSyncResult,
      error: error,
    );
  }

  static const FitbitVendorState initial = FitbitVendorState();
}

class FitbitVendorNotifier extends StateNotifier<FitbitVendorState> {
  final ApiService _api;

  FitbitVendorNotifier(this._api) : super(FitbitVendorState.initial) {
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final status = await _api.getFitbitStatus();
      state = state.copyWith(isLoading: false, status: status);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> selectFitbitVendor() async {
    state = state.copyWith(isSelecting: true, error: null);
    try {
      await _api.selectVendor('fitbit');
      await refreshStatus();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSelecting: false);
    }
  }

  Future<Uri> buildAuthorizeUri() {
    return _api.buildFitbitAuthorizeUri();
  }

  Future<SyncResult?> triggerSync() async {
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final result = await _api.triggerImmediateSync();
      state = state.copyWith(isSyncing: false, lastSyncResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
      return null;
    }
  }
}

final fitbitVendorProvider =
    StateNotifierProvider<FitbitVendorNotifier, FitbitVendorState>((ref) {
  final api = ref.read(apiServiceProvider);
  return FitbitVendorNotifier(api);
});
