import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DayDetailsScreen extends ConsumerWidget {
  final DateTime selectedDate;

  const DayDetailsScreen({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Vital Signs', Icons.favorite, const Color(0xFFFF3B30)),
            const SizedBox(height: 12),
            _buildEmptyState('No vital signs recorded for this day'),
            const SizedBox(height: 24),
            _buildSectionHeader('Conditions', Icons.report_problem, const Color(0xFFFF9500)),
            const SizedBox(height: 12),
            _buildEmptyState('No conditions reported for this day'),
            const SizedBox(height: 24),
            _buildSectionHeader('Reminders', Icons.notifications, const Color(0xFF007AFF)),
            const SizedBox(height: 12),
            _buildEmptyState('No reminders scheduled for this day'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }
}
