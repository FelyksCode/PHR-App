import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enum for time period selection
enum TimePeriod { hours24, days7, days30 }

/// State class for observation detail screen
class ObservationDetailState {
  final TimePeriod selectedPeriod;
  final int currentPage;

  const ObservationDetailState({
    required this.selectedPeriod,
    required this.currentPage,
  });

  ObservationDetailState copyWith({
    TimePeriod? selectedPeriod,
    int? currentPage,
  }) {
    return ObservationDetailState(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// State notifier for observation detail
class ObservationDetailNotifier extends StateNotifier<ObservationDetailState> {
  ObservationDetailNotifier()
    : super(
        const ObservationDetailState(
          selectedPeriod: TimePeriod.days7,
          currentPage: 1,
        ),
      );

  void setPeriod(TimePeriod period) {
    state = state.copyWith(selectedPeriod: period, currentPage: 1);
  }

  void incrementPage() {
    state = state.copyWith(currentPage: state.currentPage + 1);
  }

  void resetPage() {
    state = state.copyWith(currentPage: 1);
  }
}

/// Provider for observation detail state
final observationDetailProvider =
    StateNotifierProvider.autoDispose<
      ObservationDetailNotifier,
      ObservationDetailState
    >((ref) => ObservationDetailNotifier());
