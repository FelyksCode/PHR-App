import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import '../providers/vital_signs_provider.dart';
import '../providers/observation_service_provider.dart';
import '../providers/observation_providers.dart';
import '../providers/offline_queue_provider.dart';
import '../widgets/common_widgets.dart';

class VitalSignsScreen extends ConsumerStatefulWidget {
  const VitalSignsScreen({super.key});

  @override
  ConsumerState<VitalSignsScreen> createState() => _VitalSignsScreenState();
}

class _VitalSignsScreenState extends ConsumerState<VitalSignsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    // Initialize search controller listener
    _searchController.addListener(() {
      final provider = provider_pkg.Provider.of<VitalSignsProvider>(context, listen: false);
      provider.updateSearchQuery(_searchController.text);
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return provider_pkg.Consumer2<VitalSignsProvider, ObservationService>(
      builder: (context, vitalSignsProvider, observationService, child) {
        // Listen for submission messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (vitalSignsProvider.submissionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(vitalSignsProvider.submissionMessage!),
                backgroundColor: vitalSignsProvider.submissionSuccess ? Colors.green : Colors.red,
              ),
            );
            vitalSignsProvider.clearSubmissionMessage();
          }
        });

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: LoadingOverlay(
            isLoading: vitalSignsProvider.isLoading,
            message: 'Submitting vital signs...',
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // App Bar
                SliverAppBar(
                  title: const Text('Vital Signs'),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1C1C1E),
                  elevation: 0,
                  floating: true,
                  pinned: true,
                  centerTitle: false,
                  titleTextStyle: const TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  actions: [
                    // Offline indicator
                    Consumer(
                      builder: (context, ref, child) {
                        final connectivityAsync = ref.watch(connectivityStatusProvider);
                        return connectivityAsync.when(
                          data: (isOnline) {
                            if (!isOnline) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Offline',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                    // Sync button with queue count
                    Consumer(
                      builder: (context, ref, child) {
                        final queueService = ref.watch(offlineQueueServiceProvider);
                        final queuedItemsAsync = ref.watch(queuedItemsCountProvider);
                        return queuedItemsAsync.when(
                          data: (counts) {
                            final observationsCount = counts['observations'] ?? 0;
                            if (observationsCount > 0) {
                              return Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.cloud_upload),
                                    onPressed: () async {
                                      final result = await queueService.syncQueuedData();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message'] as String),
                                            backgroundColor: result['success'] as bool ? Colors.green : Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$observationsCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ],
                ),
                // Sticky Search Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchBarDelegate(
                    child: _buildSearchBar(),
                  ),
                ),
                // Vital Signs Cards
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final vitalSign = vitalSignsProvider.filteredVitalSigns[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildVitalSignCard(vitalSign, vitalSignsProvider, observationService),
                        );
                      },
                      childCount: vitalSignsProvider.filteredVitalSigns.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search vital signs...',
          prefixIcon: Icon(Icons.search, color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: Color(0xFF8E8E93)),
        ),
      ),
    );
  }

  Widget _buildVitalSignCard(Map<String, dynamic> vitalSign, VitalSignsProvider provider, ObservationService observationService) {
    final title = vitalSign['title'] as String;
    final subtitle = vitalSign['subtitle'] as String;
    final icon = vitalSign['icon'] as String;
    final unit = vitalSign['unit'] as String;
    final type = vitalSign['type'] as String;
    final hasBluetooth = vitalSign['hasBluetooth'] == true;

    return GestureDetector(
      onTap: () => _openVitalSignBottomSheet(vitalSign, provider, observationService),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            if (hasBluetooth) ...[
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/heart-rate-monitor');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bluetooth,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                ),
              ),
            ],
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF8E8E93),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFields(String title, String unit, String type, VitalSignsProvider provider) {
    if (type == 'dual' && title == 'Blood Pressure') {
      return Row(
        children: [
          Expanded(
            child: CustomTextField(
              label: 'Systolic ($unit)',
              controller: provider.controllers['Systolic BP']!,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomTextField(
              label: 'Diastolic ($unit)',
              controller: provider.controllers['Diastolic BP']!,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      );
    } else {
      return CustomTextField(
        label: '$title ($unit)',
        controller: provider.controllers[title]!,
        keyboardType: TextInputType.number,
        inputFormatters: _getInputFormatters(title),
      );
    }
  }

  List<TextInputFormatter> _getInputFormatters(String title) {
    if (title == 'Heart Rate') {
      return [FilteringTextInputFormatter.digitsOnly];
    } else {
      return [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
    }
  }

  Widget _buildSubmitButton(String title, String type, VitalSignsProvider provider, ObservationService observationService) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () => _submitVitalSign(title, type, provider, observationService),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text('Submit $title'),
      ),
    );
  }

  void _openVitalSignBottomSheet(Map<String, dynamic> vitalSign, VitalSignsProvider provider, ObservationService observationService) {
    final title = vitalSign['title'] as String;
    final subtitle = vitalSign['subtitle'] as String;
    final icon = vitalSign['icon'] as String;
    final unit = vitalSign['unit'] as String;
    final type = vitalSign['type'] as String;
    final hasBluetooth = vitalSign['hasBluetooth'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Bluetooth section (if available)
                        if (hasBluetooth) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E5EA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF007AFF).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.bluetooth,
                                          color: Color(0xFF007AFF),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Bluetooth Device',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1C1C1E),
                                            ),
                                          ),
                                          Text(
                                            'Connect to measure automatically',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(context, '/heart-rate-monitor');
                                    },
                                    icon: const Icon(Icons.bluetooth_connected, size: 20),
                                    label: const Text('Connect Device'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Divider with "OR" text
                          Row(
                            children: [
                              Expanded(child: Divider(color: Color(0xFFE5E5EA))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Color(0xFFE5E5EA))),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Manual entry section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasBluetooth ? 'Manual Entry' : 'Enter Reading',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildInputFields(title, unit, type, provider),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Notes (Optional)',
                                controller: provider.notesControllers[title]!,
                                maxLines: 3,
                                hint: 'Add any additional notes about this reading...',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSubmitButton(title, type, provider, observationService),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submitVitalSign(String title, String type, VitalSignsProvider provider, ObservationService observationService) async {
    // Validate input first (before loading)
    if (!provider.validateInput(title)) {
      return;
    }

    // Start loading after validation passes
    provider.setLoading(true);

    // Get offline queue service and check actual internet connectivity
    final queueService = ref.read(offlineQueueServiceProvider);
    
    // Check actual internet connectivity, not just WiFi connection
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 2));
      hasInternet = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      hasInternet = false;
    }

    print('*** Vital Signs Submission ***');
    print('Title: $title');
    print('Has Internet: $hasInternet');

    try {
      if (title == 'Blood Pressure') {
        // Handle blood pressure (dual reading)
        final observations = provider.createBloodPressureObservations();
        print('Blood Pressure Observations: ${observations.length}');
        if (observations.isNotEmpty) {
          if (hasInternet) {
            try {
              final success = await observationService.submitMultipleObservations(observations);
              print('BP Submit Success: $success');
              if (success) {
                // Refresh providers to update history
                ref.invalidate(latestObservationsProvider);
                provider.setLoading(false);
                provider.setSubmissionResult(true, 'Blood pressure submitted successfully!');
                provider.clearFormFields(title, isBloodPressure: true);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else {
                // If submission fails, queue for later
                print('BP Submit failed, queueing observations...');
                for (final obs in observations) {
                  await queueService.queueObservation(obs);
                }
                // Refresh queue providers to update history
                ref.invalidate(queuedObservationsProvider);
                ref.invalidate(queuedItemsCountProvider);
                provider.setLoading(false);
                provider.setSubmissionResult(true, 'Connection issue. Data saved and will sync automatically when online.');
                provider.clearFormFields(title, isBloodPressure: true);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            } catch (e) {
              // Network error - queue the data
              print('BP Submit Exception: $e');
              for (final obs in observations) {
                await queueService.queueObservation(obs);
              }
              // Refresh queue providers to update history
              ref.invalidate(queuedObservationsProvider);
              ref.invalidate(queuedItemsCountProvider);
              provider.setLoading(false);
              provider.setSubmissionResult(true, 'No internet. Data saved and will sync automatically when online.');
              provider.clearFormFields(title, isBloodPressure: true);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          } else {
            // Queue observations when offline
            print('BP Offline, queueing observations...');
            for (final obs in observations) {
              await queueService.queueObservation(obs);
            }
            // Refresh queue providers to update history
            ref.invalidate(queuedObservationsProvider);
            ref.invalidate(queuedItemsCountProvider);
            provider.setLoading(false);
            provider.setSubmissionResult(true, 'No internet. Data saved and will sync automatically when online.');
            provider.clearFormFields(title, isBloodPressure: true);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        }
      } else {
        // Handle single reading
        final observation = provider.createObservation(title, type);
        print('Single Observation: ${observation?.runtimeType}');
        if (observation != null) {
          if (hasInternet) {
            try {
              final success = await observationService.submitObservation(observation);
              print('Single Submit Success: $success');
              if (success) {
                // Refresh providers to update history
                ref.invalidate(latestObservationsProvider);
                provider.setLoading(false);
                provider.setSubmissionResult(true, 'Observation submitted successfully!');
                provider.clearFormFields(title);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else {
                // If submission fails, queue for later
                print('Single Submit failed, queueing observation...');
                await queueService.queueObservation(observation);
                // Refresh queue providers to update history
                ref.invalidate(queuedObservationsProvider);
                ref.invalidate(queuedItemsCountProvider);
                provider.setLoading(false);
                provider.setSubmissionResult(true, 'Connection issue. Data saved and will sync automatically when online.');
                provider.clearFormFields(title);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            } catch (e) {
              // Network error - queue the data
              print('Single Submit Exception: $e');
              await queueService.queueObservation(observation);
              // Refresh queue providers to update history
              ref.invalidate(queuedObservationsProvider);
              ref.invalidate(queuedItemsCountProvider);
              provider.setLoading(false);
              provider.setSubmissionResult(true, 'No internet. Data saved and will sync automatically when online.');
              provider.clearFormFields(title);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            }
          } else {
            // Queue observation when offline
            print('Single Offline, queueing observation...');
            await queueService.queueObservation(observation);
            // Refresh queue providers to update history
            ref.invalidate(queuedObservationsProvider);
            ref.invalidate(queuedItemsCountProvider);
            provider.setLoading(false);
            provider.setSubmissionResult(true, 'No internet. Data saved and will sync automatically when online.');
            provider.clearFormFields(title);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        }
      }
    } catch (e) {
      print('Critical Error: $e');
      provider.setLoading(false);
      provider.setSubmissionResult(false, 'Error submitting vital signs: $e');
    }
  }
}

// Custom delegate for sticky search bar
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  
  _SearchBarDelegate({required this.child});

  @override
  double get minExtent => 80.0;
  
  @override
  double get maxExtent => 80.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}