import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import '../providers/vital_signs_provider.dart';
import '../providers/observation_service_provider.dart';
import '../providers/observation_providers.dart';
import '../providers/condition_providers.dart';
import '../../services/api_service.dart';
import 'vital_signs_screen.dart';

class VitalSignsScreenWrapper extends ConsumerWidget {
  const VitalSignsScreenWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(
          create: (context) => VitalSignsProvider(),
        ),
        provider.ChangeNotifierProvider(
          create: (context) {
            final observationService = ObservationService(ApiService());
            
            // Set up refresh callbacks to update Riverpod providers
            observationService.setRefreshCallbacks(
              refreshObservations: () {
                ref.refresh(observationsProvider);
                ref.refresh(latestObservationsProvider);
              },
              refreshConditions: () {
                ref.refresh(conditionsProvider);
                ref.refresh(latestConditionsProvider);
              },
            );
            
            return observationService;
          },
        ),
      ],
      child: const VitalSignsScreen(),
    );
  }
}