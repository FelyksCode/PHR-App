import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class for conditions history screen
class ConditionsHistoryState {
  final int currentPage;

  const ConditionsHistoryState({
    required this.currentPage,
  });

  ConditionsHistoryState copyWith({
    int? currentPage,
  }) {
    return ConditionsHistoryState(
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// State notifier for conditions history
class ConditionsHistoryNotifier extends StateNotifier<ConditionsHistoryState> {
  ConditionsHistoryNotifier() : super(const ConditionsHistoryState(currentPage: 1));

  void incrementPage() {
    state = state.copyWith(currentPage: state.currentPage + 1);
  }

  void resetPage() {
    state = state.copyWith(currentPage: 1);
  }
}

/// Provider for conditions history state
final conditionsHistoryProvider =
    StateNotifierProvider.autoDispose<ConditionsHistoryNotifier, ConditionsHistoryState>(
  (ref) => ConditionsHistoryNotifier(),
);
