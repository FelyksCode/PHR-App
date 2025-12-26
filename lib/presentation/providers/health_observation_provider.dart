import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/health_observation.dart';
import '../../services/api_service.dart';

class HealthObservationListState {
  final List<HealthObservation> items;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final int page;
  final String filter;
  final String? error;

  const HealthObservationListState({
    required this.items,
    required this.isLoading,
    required this.isRefreshing,
    required this.hasMore,
    required this.page,
    required this.filter,
    this.error,
  });

  factory HealthObservationListState.initial() {
    return const HealthObservationListState(
      items: [],
      isLoading: false,
      isRefreshing: false,
      hasMore: true,
      page: 1,
      filter: 'all',
      error: null,
    );
  }

  HealthObservationListState copyWith({
    List<HealthObservation>? items,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    int? page,
    String? filter,
    String? error,
  }) {
    return HealthObservationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      filter: filter ?? this.filter,
      error: error,
    );
  }
}

class HealthObservationListNotifier
    extends StateNotifier<HealthObservationListState> {
  HealthObservationListNotifier(this._api) : super(HealthObservationListState.initial()) {
    loadObservations(reset: true);
  }

  final ApiService _api;
  static const int _pageSize = 20;

  Future<void> loadObservations({bool reset = false}) async {
    if (state.isLoading) return;

    final nextPage = reset ? 1 : state.page;
    state = state.copyWith(
      isLoading: true,
      isRefreshing: reset,
      error: null,
      items: reset ? <HealthObservation>[] : null,
      hasMore: reset ? true : null,
      page: nextPage,
    );

    try {
      final result = await _api.fetchHealthObservations(
        type: state.filter,
        page: nextPage,
        pageSize: _pageSize,
      );

      final mergedItems = reset
          ? result.items
          : [...state.items, ...result.items];

      state = state.copyWith(
        items: mergedItems,
        hasMore: result.hasMore,
        page: nextPage + 1,
        isLoading: false,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadObservations(reset: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadObservations();
  }

  void setFilter(String filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter, page: 1, hasMore: true);
    loadObservations(reset: true);
  }
}

final healthObservationListProvider =
    StateNotifierProvider<HealthObservationListNotifier, HealthObservationListState>(
  (ref) {
    final api = ref.read(apiServiceProvider);
    return HealthObservationListNotifier(api);
  },
);
