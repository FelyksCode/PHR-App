import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class for observation input screen
class ObservationInputState {
  final bool isSubmitting;

  const ObservationInputState({required this.isSubmitting});

  ObservationInputState copyWith({bool? isSubmitting}) {
    return ObservationInputState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// State notifier for observation input
class ObservationInputNotifier extends StateNotifier<ObservationInputState> {
  ObservationInputNotifier()
    : super(const ObservationInputState(isSubmitting: false));

  void setSubmitting(bool isSubmitting) {
    state = state.copyWith(isSubmitting: isSubmitting);
  }
}

/// Provider for observation input state
final observationInputProvider =
    StateNotifierProvider<ObservationInputNotifier, ObservationInputState>(
      (ref) => ObservationInputNotifier(),
    );

/// Provider for observation type search filter
final observationSearchProvider = StateProvider<String>((ref) => '');
