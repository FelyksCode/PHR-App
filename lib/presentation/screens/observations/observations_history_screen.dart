import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phr_app/domain/entities/observation_entity.dart';
import '../../providers/observation_providers.dart';
import '../../providers/offline_queue_provider.dart';
import 'observation_input_screen.dart';
import 'observation_detail_screen.dart';

class ObservationsHistoryScreen extends ConsumerStatefulWidget {
  const ObservationsHistoryScreen({super.key});

  @override
  ConsumerState<ObservationsHistoryScreen> createState() =>
      _ObservationsHistoryScreenState();
}

class _ObservationsHistoryScreenState
    extends ConsumerState<ObservationsHistoryScreen> {
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
                  builder: (context) => const ObservationInputScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, color: Color(0xFF007AFF)),
            tooltip: 'Record Vital Signs',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestObservationsProvider);
          ref.invalidate(queuedObservationsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              latestObservationsState.when(
                data: (observations) =>
                    _buildVitalSignsList(observations, queuedObservationsState),
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
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[600],
                        size: 48,
                      ),
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

  Widget _buildVitalSignsList(
    List<Map<String, dynamic>> observations,
    AsyncValue<List<Map<String, dynamic>>> queuedObservationsState,
  ) {
    return queuedObservationsState.when(
      data: (queuedObservations) {
        // Convert observations to proper format and add queued ones
        final List<Map<String, dynamic>> allObservations = observations.map((
          obs,
        ) {
          // Handle FHIR panel format (new blood pressure format)
          final codeDisplay = obs['code']?['coding']?[0]?['display'] as String?;
          final codeValue = obs['code']?['coding']?[0]?['code'] as String?;
          final components = obs['component'] as List<dynamic>?;

          // Detect blood pressure panel (either by display name containing "Blood Pressure" or by code 35094-2)
          final isBpPanel =
              (components != null && components.isNotEmpty) &&
              ((codeDisplay?.toLowerCase().contains('blood pressure') ??
                      false) ||
                  codeValue == '35094-2');

          if (isBpPanel) {
            // Mark as blood pressure panel
            return {...obs, 'type': 'Blood Pressure', '_isFhirPanel': true};
          }

          // Handle legacy format with type field
          final typeString = obs['type'] as String? ?? codeDisplay ?? 'Unknown';
          final formattedType = typeString
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(1)}',
              )
              .trim();
          final titleCaseType = formattedType
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1);
              })
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ');

          return {...obs, 'type': titleCaseType};
        }).toList();

        // Add queued observations
        for (final queued in queuedObservations) {
          final data = queued['data'] as Map<String, dynamic>;
          final typeString = data['type'] as String? ?? 'Unknown';
          final formattedType = typeString
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(1)}',
              )
              .trim();
          final titleCaseType = formattedType
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1);
              })
              .join(' ')
              .replaceAll(RegExp(r'\s+'), ' ');

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

        final bpKeys = grouped.keys
            .where((k) => k.toLowerCase().contains('blood pressure'))
            .toList();

        final entries = <MapEntry<String, List<Map<String, dynamic>>>>[].cast();

        if (bpKeys.isNotEmpty) {
          final combinedBp = <Map<String, dynamic>>[];
          for (final key in bpKeys) {
            combinedBp.addAll(grouped[key] ?? const []);
          }

          entries.add(MapEntry('_BloodPressureCombined', combinedBp));
          grouped.removeWhere((key, _) => bpKeys.contains(key));
        }

        entries.addAll(grouped.entries);

        // If there are no entries at all (including combined BP), show empty state
        if (entries.isEmpty) {
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
                  style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          );
        }

        return Column(
          children: entries.map((entry) {
            if (entry.key == '_BloodPressureCombined') {
              return _buildBloodPressureCard(entry.value);
            }

            final vitalSignType = entry.key;
            final observations = entry.value;

            // Sort by date and get latest
            final sortedObs = List<Map<String, dynamic>>.from(observations)
              ..sort((a, b) {
                final dateA =
                    DateTime.tryParse(
                      a['effectiveDateTime'] as String? ?? '',
                    ) ??
                    DateTime.now();
                final dateB =
                    DateTime.tryParse(
                      b['effectiveDateTime'] as String? ?? '',
                    ) ??
                    DateTime.now();
                return dateB.compareTo(dateA);
              });

            final latest = sortedObs.first;
            final latestDate =
                DateTime.tryParse(
                  latest['effectiveDateTime'] as String? ?? '',
                ) ??
                DateTime.now();

            return GestureDetector(
              onTap: () {
                // Map display type string to ObservationType enum
                final normalized = vitalSignType.trim().toLowerCase();
                final obsType = switch (normalized) {
                  'body weight' => ObservationType.bodyWeight,
                  'body height' => ObservationType.bodyHeight,
                  'body temperature' => ObservationType.bodyTemperature,
                  'heart rate' => ObservationType.heartRate,
                  'blood pressure' => ObservationType.bloodPressureSystolic,
                  'systolic blood pressure' =>
                    ObservationType.bloodPressureSystolic,
                  'diastolic blood pressure' =>
                    ObservationType.bloodPressureDiastolic,
                  'oxygen saturation' => ObservationType.oxygenSaturation,
                  'calories burned' => ObservationType.caloriesBurned,
                  _ => ObservationType.values.firstWhere(
                    (t) =>
                        t.displayName.toLowerCase() == normalized ||
                        t.name.toLowerCase() == normalized.replaceAll(' ', ''),
                    orElse: () => ObservationType.bodyWeight,
                  ),
                };
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ObservationDetailScreen(
                      observationType: obsType,
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
                      color: Colors.black.withValues(alpha:0.02),
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
                        color: _getVitalSignColor(
                          vitalSignType,
                        ).withValues(alpha:0.1),
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
          // Handle FHIR panel format
          final codeDisplay = obs['code']?['coding']?[0]?['display'] as String?;
          final codeValue = obs['code']?['coding']?[0]?['code'] as String?;
          final components = obs['component'] as List<dynamic>?;

          // Detect blood pressure panel (either by display name or by code 35094-2)
          final isBpPanel =
              (components != null && components.isNotEmpty) &&
              ((codeDisplay?.toLowerCase().contains('blood pressure') ??
                      false) ||
                  codeValue == '35094-2');

          final type = isBpPanel
              ? "Blood Pressure"
              : (obs['type'] as String? ?? codeDisplay ?? 'Unknown');

          grouped.putIfAbsent(type, () => []).add(obs);
        }

        return Column(
          children: grouped.entries.map((entry) {
            if (entry.key == 'Blood Pressure') {
              return _buildBloodPressureCard(entry.value);
            }

            final vitalSignType = entry.key;
            final obs = entry.value;

            final sortedObs = List<Map<String, dynamic>>.from(obs)
              ..sort((a, b) {
                final dateA =
                    DateTime.tryParse(
                      a['effectiveDateTime'] as String? ?? '',
                    ) ??
                    DateTime.now();
                final dateB =
                    DateTime.tryParse(
                      b['effectiveDateTime'] as String? ?? '',
                    ) ??
                    DateTime.now();
                return dateB.compareTo(dateA);
              });

            final latest = sortedObs.first;
            final latestDate =
                DateTime.tryParse(
                  latest['effectiveDateTime'] as String? ?? '',
                ) ??
                DateTime.now();

            return GestureDetector(
              onTap: () {
                // Map display type string to ObservationType enum
                final normalized = vitalSignType.trim().toLowerCase();
                final obsType = switch (normalized) {
                  'body weight' => ObservationType.bodyWeight,
                  'body height' => ObservationType.bodyHeight,
                  'body temperature' => ObservationType.bodyTemperature,
                  'heart rate' => ObservationType.heartRate,
                  'blood pressure' => ObservationType.bloodPressureSystolic,
                  'systolic blood pressure' =>
                    ObservationType.bloodPressureSystolic,
                  'diastolic blood pressure' =>
                    ObservationType.bloodPressureDiastolic,
                  'oxygen saturation' => ObservationType.oxygenSaturation,
                  'calories burned' => ObservationType.caloriesBurned,
                  _ => ObservationType.values.firstWhere(
                    (t) =>
                        t.displayName.toLowerCase() == normalized ||
                        t.name.toLowerCase() == normalized.replaceAll(' ', ''),
                    orElse: () => ObservationType.bodyWeight,
                  ),
                };
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ObservationDetailScreen(
                      observationType: obsType,
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
                      color: Colors.black.withValues(alpha:0.02),
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
                        color: _getVitalSignColor(
                          vitalSignType,
                        ).withValues(alpha:0.1),
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

  Widget _buildBloodPressureCard(List<Map<String, dynamic>> observations) {
    if (observations.isEmpty) return const SizedBox.shrink();

    // Filter to only FHIR panel format observations (newer format)
    final fhirPanelObs = observations.where((obs) {
      final components = obs['component'] as List<dynamic>?;
      return components != null && components.isNotEmpty;
    }).toList();

    // Use FHIR panel observations if available, otherwise use all observations
    final combined = fhirPanelObs.isNotEmpty ? fhirPanelObs : observations;

    final sorted = List<Map<String, dynamic>>.from(combined)
      ..sort((a, b) {
        final dateA =
            DateTime.tryParse(a['effectiveDateTime'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['effectiveDateTime'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

    // Get the latest observation
    final latest = sorted.isNotEmpty ? sorted.first : null;

    String systolicValue = '--';
    String diastolicValue = '--';
    String unit = 'mmHg';

    if (latest != null) {
      // Handle FHIR panel format with components
      final components = latest['component'] as List<dynamic>?;
      if (components != null && components.isNotEmpty) {
        for (final component in components) {
          final code = component['code'] as Map<String, dynamic>?;
          final coding = code?['coding'] as List<dynamic>?;
          if (coding != null && coding.isNotEmpty) {
            final loincCode =
                (coding[0] as Map<String, dynamic>?)?['code'] as String?;
            final valueQuantity =
                component['valueQuantity'] as Map<String, dynamic>?;
            final value = valueQuantity?['value'];
            if (loincCode == '8480-6') {
              // Systolic
              systolicValue = value?.toString() ?? '--';
            } else if (loincCode == '8462-4') {
              // Diastolic
              diastolicValue = value?.toString() ?? '--';
            }
          }
        }
        unit =
            latest['component']?[0]?['valueQuantity']?['unit'] as String? ??
            'mmHg';
      } else {
        // Handle legacy format with separate systolic/diastolic observations
        Map<String, dynamic> findByTypeSubstring(String term) {
          return combined.firstWhere(
            (obs) =>
                (obs['type'] as String? ?? '').toLowerCase().contains(term),
            orElse: () => <String, dynamic>{},
          );
        }

        final systolic = findByTypeSubstring('systolic');
        final diastolic = findByTypeSubstring('diastolic');

        systolicValue = systolic['value']?.toString() ?? '--';
        diastolicValue = diastolic['value']?.toString() ?? '--';
        unit = (systolic['unit'] ?? diastolic['unit'] ?? 'mmHg') as String;
      }
    }

    final latestDate = sorted.isNotEmpty
        ? DateTime.tryParse(
                sorted.first['effectiveDateTime'] as String? ?? '',
              ) ??
              DateTime.now()
        : DateTime.now();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ObservationDetailScreen(
              observationType: ObservationType.bloodPressureSystolic,
              observations: sorted,
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
              color: Colors.black.withValues(alpha:0.02),
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
                color: _getVitalSignColor('blood pressure').withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.monitor_heart,
                color: _getVitalSignColor('blood pressure'),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blood Pressure',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Latest reading',
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
                Text(
                  '$systolicValue / $diastolicValue',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _getVitalSignColor('blood pressure'),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF8E8E93),
            ),
          ],
        ),
      ),
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
      case 'calories burned':
        return Icons.local_fire_department;
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
      case 'calories burned':
        return const Color(0xFFFF9500); // Orange (Fire)
      default:
        return const Color(0xFF8E8E93); // Gray
    }
  }
}
