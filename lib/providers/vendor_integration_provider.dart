import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/health_observation.dart';
import '../services/api_service.dart';

class VendorIntegrationState {
  final bool isLoading;
  final bool isSelecting;
  final FitbitStatus? status;
  final String? error;

  const VendorIntegrationState({
    this.isLoading = false,
    this.isSelecting = false,
    this.status,
    this.error,
  });

  VendorIntegrationState copyWith({
    bool? isLoading,
    bool? isSelecting,
    FitbitStatus? status,
    String? error,
  }) {
    return VendorIntegrationState(
      isLoading: isLoading ?? this.isLoading,
      isSelecting: isSelecting ?? this.isSelecting,
      status: status ?? this.status,
      error: error,
    );
  }

  static const initial = VendorIntegrationState();
}

class VendorIntegrationNotifier extends StateNotifier<VendorIntegrationState> {
  VendorIntegrationNotifier(this._api, this._vendor)
    : super(VendorIntegrationState.initial) {
    refreshStatus();
  }

  final ApiService _api;
  final String _vendor;

  Future<void> refreshStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final status = await _api.getVendorStatus(_vendor);
      state = state.copyWith(isLoading: false, status: status);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> selectVendor() async {
    state = state.copyWith(isSelecting: true, error: null);
    try {
      await _api.selectVendor(_vendor);
      await refreshStatus();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSelecting: false);
    }
  }

  Future<bool> disconnect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.disconnectVendor(_vendor);
      await refreshStatus();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Uri> buildAuthorizeUri() {
    return _api.buildVendorAuthorizeUri(_vendor);
  }
}

final vendorIntegrationProvider =
    StateNotifierProviderFamily<
      VendorIntegrationNotifier,
      VendorIntegrationState,
      String
    >((ref, vendor) {
      final api = ref.read(apiServiceProvider);
      return VendorIntegrationNotifier(api, vendor);
    });
