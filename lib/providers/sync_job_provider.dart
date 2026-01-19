import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/backend_sync_status.dart';
import '../services/api_service.dart';

class SyncJobState {
  final bool isTriggering;
  final bool isPolling;
  final BackendSyncStatus? status;
  final String? syncJobId;
  final String? error;

  const SyncJobState({
    this.isTriggering = false,
    this.isPolling = false,
    this.status,
    this.syncJobId,
    this.error,
  });

  SyncJobState copyWith({
    bool? isTriggering,
    bool? isPolling,
    BackendSyncStatus? status,
    String? syncJobId,
    String? error,
  }) {
    return SyncJobState(
      isTriggering: isTriggering ?? this.isTriggering,
      isPolling: isPolling ?? this.isPolling,
      status: status ?? this.status,
      syncJobId: syncJobId ?? this.syncJobId,
      error: error,
    );
  }

  static const initial = SyncJobState();
}

class SyncJobNotifier extends StateNotifier<SyncJobState> {
  SyncJobNotifier(this._api) : super(SyncJobState.initial) {
    refreshStatus();
  }

  final ApiService _api;
  bool _disposed = false;
  bool _pollingLoopActive = false;

  bool get _isAlive => mounted && !_disposed;

  void _updateState(SyncJobState Function(SyncJobState current) update) {
    if (!_isAlive) return;
    state = update(state);
  }

  BackendSyncStatus? get _statusOrNull {
    if (!_isAlive) return null;
    return state.status;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<BackendSyncStatus?> triggerVendorSync(String vendor) async {
    _updateState((s) => s.copyWith(isTriggering: true, error: null));

    try {
      final jobId = await _api.triggerVendorSync(vendor: vendor);
      _updateState(
        (s) => s.copyWith(
          isTriggering: false,
          syncJobId: jobId,
          // best-effort optimistic state until backend reports.
          status: const BackendSyncStatus(status: BackendSyncStatusType.queued),
        ),
      );

      await refreshStatus();
      return await _pollUntilTerminal();
    } catch (e) {
      _updateState(
        (s) => s.copyWith(isTriggering: false, error: _toUserMessage(e)),
      );
      return null;
    }
  }

  Future<void> refreshStatus() async {
    try {
      final status = await _api.getBackendSyncStatus();
      _updateState((s) => s.copyWith(status: status, error: null));
    } catch (e) {
      _updateState((s) => s.copyWith(error: _toUserMessage(e)));
    }
  }

  Future<BackendSyncStatus?> _pollUntilTerminal({
    Duration initialInterval = const Duration(seconds: 2),
    Duration maxInterval = const Duration(seconds: 10),
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_pollingLoopActive) return _statusOrNull;
    _pollingLoopActive = true;

    final deadline = DateTime.now().add(timeout);
    _updateState((s) => s.copyWith(isPolling: true));

    var delay = initialInterval;

    try {
      while (!_disposed && DateTime.now().isBefore(deadline)) {
        await refreshStatus();

        final status = _statusOrNull;
        if (status != null && status.isTerminal) {
          return status;
        }

        await Future.delayed(delay);
        final nextSeconds = (delay.inSeconds * 2).clamp(
          initialInterval.inSeconds,
          maxInterval.inSeconds,
        );
        delay = Duration(seconds: nextSeconds);
      }

      return _statusOrNull;
    } finally {
      _updateState((s) => s.copyWith(isPolling: false));
      _pollingLoopActive = false;
    }
  }

  String _toUserMessage(Object e) {
    if (e is ApiException) {
      final code = e.statusCode;
      if (code == 401 || code == 403) {
        return 'Session expired. Please sign in again.';
      }
      return e.message;
    }
    return e.toString();
  }
}

final syncJobProvider =
    StateNotifierProvider.autoDispose<SyncJobNotifier, SyncJobState>((ref) {
      final api = ref.read(apiServiceProvider);
      return SyncJobNotifier(api);
    });
