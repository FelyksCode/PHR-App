import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class for dashboard calendar view
class DashboardCalendarState {
  final DateTime selectedDate;
  final DateTime focusedDate;
  final bool isMonthView;

  const DashboardCalendarState({
    required this.selectedDate,
    required this.focusedDate,
    required this.isMonthView,
  });

  DashboardCalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedDate,
    bool? isMonthView,
  }) {
    return DashboardCalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedDate: focusedDate ?? this.focusedDate,
      isMonthView: isMonthView ?? this.isMonthView,
    );
  }
}

/// State notifier for dashboard calendar view
class DashboardCalendarNotifier extends StateNotifier<DashboardCalendarState> {
  DashboardCalendarNotifier()
      : super(DashboardCalendarState(
          selectedDate: DateTime.now(),
          focusedDate: DateTime.now(),
          isMonthView: false,
        ));

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void navigateToPreviousPeriod() {
    if (state.isMonthView) {
      // Navigate to previous month
      state = state.copyWith(
        focusedDate: DateTime(
          state.focusedDate.year,
          state.focusedDate.month - 1,
        ),
      );
    } else {
      // Navigate to previous week
      state = state.copyWith(
        focusedDate: state.focusedDate.subtract(const Duration(days: 7)),
      );
    }
  }

  void navigateToNextPeriod() {
    if (state.isMonthView) {
      // Navigate to next month
      state = state.copyWith(
        focusedDate: DateTime(
          state.focusedDate.year,
          state.focusedDate.month + 1,
        ),
      );
    } else {
      // Navigate to next week
      state = state.copyWith(
        focusedDate: state.focusedDate.add(const Duration(days: 7)),
      );
    }
  }

  void toggleViewMode() {
    state = state.copyWith(
      isMonthView: !state.isMonthView,
      // Reset to current week/month when toggling
      focusedDate: DateTime.now(),
    );
  }
}

/// Provider for dashboard calendar state
final dashboardCalendarProvider =
    StateNotifierProvider<DashboardCalendarNotifier, DashboardCalendarState>(
  (ref) => DashboardCalendarNotifier(),
);
