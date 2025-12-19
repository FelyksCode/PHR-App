import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/observation_providers.dart';
import '../providers/offline_queue_provider.dart';
import 'vital_signs_screen_wrapper.dart';
import 'vital_sign_details_screen.dart';

class ObservationsHistoryScreen extends ConsumerStatefulWidget {
  const ObservationsHistoryScreen({super.key});

  @override
  ConsumerState<ObservationsHistoryScreen> createState() => _ObservationsHistoryScreenState();
}

class _ObservationsHistoryScreenState extends ConsumerState<ObservationsHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final latestObservationsState = ref.watch(latestObservationsProvider);
    final queuedObservationsState = ref.watch(queuedObservationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Vital Signs History',
          style: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const VitalSignsScreenWrapper(),
                ),
              );
            },
            icon: const Icon(
              Icons.add,
              color: Color(0xFF007AFF),
            ),
            tooltip: 'Record Vital Signs',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(latestObservationsProvider);
          await ref.refresh(queuedObservationsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              latestObservationsState.when(
                data: (observations) => _buildVitalSignsList(observations, queuedObservationsState),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600], size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Error loading observations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalSignsList(List<Map<String, dynamic>> observations, AsyncValue<List<Map<String, dynamic>>> queuedObservationsState) {
    return queuedObservationsState.when(
      data: (queuedObservations) {
        // Convert observations to proper format and add queued ones
        final List<Map<String, dynamic>> allObservations = observations.map((obs) {
          final typeString = obs['type'] as String? ?? 'Unknown';
          final formattedType = typeString.replaceAllMapped(
            RegExp(r'([A-Z])'),
            (match) => ' ${match.group(1)}',
          ).trim();
          final titleCaseType = formattedType.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1);
          }).join(' ').replaceAll(RegExp(r'\s+'), ' '); // Normalize multiple spaces to single space
          
          return {
            ...obs,
            'type': titleCaseType,
          };
        }).toList();

        // Add queued observations
        for (final queued in queuedObservations) {
          final data = queued['data'] as Map<String, dynamic>;
          final typeString = data['type'] as String? ?? 'Unknown';
          final formattedType = typeString.replaceAllMapped(
            RegExp(r'([A-Z])'),
            (match) => ' ${match.group(1)}',
          ).trim();
          final titleCaseType = formattedType.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1);
          }).join(' ').replaceAll(RegExp(r'\s+'), ' '); // Normalize multiple spaces to single space
          
          allObservations.add({
            'type': titleCaseType,
            'value': data['value'],
            'unit': data['unit'],
            'effectiveDateTime': data['timestamp'] as String?,
            'notes': data['notes'],
            'isQueued': true,
          });
        }

        // Group observations by type
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final obs in allObservations) {
          final type = obs['type'] as String;
          grouped.putIfAbsent(type, () => []).add(obs);
        }

        if (grouped.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            ),
            child: Column(
              children: [
                Icon(Icons.favorite_border, color: Colors.grey[600], size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No vital signs recorded yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start recording your health measurements',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: grouped.entries.map((entry) {
            final vitalSignType = entry.key;
            final observations = entry.value;
            
            // Sort by date and get latest
            final sortedObs = List<Map<String, dynamic>>.from(observations)
              ..sort((a, b) {
                final dateA = DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                final dateB = DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                return dateB.compareTo(dateA);
              });
            
            final latest = sortedObs.first;
            final latestDate = DateTime.tryParse(latest['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
            
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VitalSignDetailsScreen(
                      vitalSignType: vitalSignType,
                      observations: observations,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getVitalSignColor(vitalSignType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getVitalSignIcon(vitalSignType),
                        color: _getVitalSignColor(vitalSignType),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vitalSignType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${observations.length} recordings',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(latestDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (latest['value'] != null)
                          Text(
                            '${latest['value']}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _getVitalSignColor(vitalSignType),
                            ),
                          ),
                        if (latest['unit'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            latest['unit'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) {
        if (observations.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            ),
            child: Column(
              children: [
                Icon(Icons.favorite_border, color: Colors.grey[600], size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No vital signs recorded yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          );
        }

        // Group observations by type even if queue fails
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final obs in observations) {
          final type = obs['type'] as String? ?? 'Unknown';
          grouped.putIfAbsent(type, () => []).add(obs);
        }

        return Column(
          children: grouped.entries.map((entry) {
            final vitalSignType = entry.key;
            final obs = entry.value;
            
            final sortedObs = List<Map<String, dynamic>>.from(obs)
              ..sort((a, b) {
                final dateA = DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                final dateB = DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
                return dateB.compareTo(dateA);
              });
            
            final latest = sortedObs.first;
            final latestDate = DateTime.tryParse(latest['effectiveDateTime'] as String? ?? '') ?? DateTime.now();
            
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VitalSignDetailsScreen(
                      vitalSignType: vitalSignType,
                      observations: obs,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getVitalSignColor(vitalSignType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getVitalSignIcon(vitalSignType),
                        color: _getVitalSignColor(vitalSignType),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vitalSignType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${obs.length} recordings',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(latestDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (latest['value'] != null)
                          Text(
                            '${latest['value']}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _getVitalSignColor(vitalSignType),
                            ),
                          ),
                        if (latest['unit'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            latest['unit'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getVitalSignIcon(String type) {
    switch (type.toLowerCase()) {
      case 'body weight':
        return Icons.scale;
      case 'body height':
        return Icons.height;
      case 'body temperature':
        return Icons.thermostat;
      case 'heart rate':
        return Icons.favorite;
      case 'blood pressure':
      case 'systolic blood pressure':
      case 'diastolic blood pressure':
        return Icons.monitor_heart;
      case 'oxygen saturation':
        return Icons.air;
      default:
        return Icons.medical_information;
    }
  }

  Color _getVitalSignColor(String type) {
    switch (type.toLowerCase()) {
      case 'body weight':
        return const Color(0xFF34C759); // Green
      case 'body height':
        return const Color(0xFF00B0FF); // Light Blue
      case 'body temperature':
        return const Color(0xFFFF9500); // Orange
      case 'heart rate':
        return const Color(0xFFFF3B30); // Red
      case 'blood pressure':
      case 'systolic blood pressure':
      case 'diastolic blood pressure':
        return const Color(0xFFFF3B30); // Red
      case 'oxygen saturation':
        return const Color(0xFF007AFF); // Blue
      default:
        return const Color(0xFF8E8E93); // Gray
    }
  }
}