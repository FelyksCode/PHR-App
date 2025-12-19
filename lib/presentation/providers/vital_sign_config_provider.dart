import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for vital sign configuration data
final vitalSignConfigProvider = Provider<Map<String, Map<String, dynamic>>>((ref) {
  return {
    'Body Weight': {
      'title': 'Body Weight',
      'subtitle': 'Track your weight changes',
      'icon': '⚖️',
      'unit': 'kg',
      'type': 'single',
      'observationType': 'body_weight',
    },
    'Body Height': {
      'title': 'Body Height',
      'subtitle': 'Record your height measurement',
      'icon': '📏',
      'unit': 'cm',
      'type': 'single',
      'observationType': 'body_height',
    },
    'Body Temperature': {
      'title': 'Body Temperature',
      'subtitle': 'Monitor body temperature',
      'icon': '🌡️',
      'unit': '°C',
      'type': 'single',
      'observationType': 'body_temperature',
    },
    'Heart Rate': {
      'title': 'Heart Rate',
      'subtitle': 'Track your heart rate',
      'icon': '❤️',
      'unit': 'bpm',
      'type': 'single',
      'observationType': 'heart_rate',
      'hasBluetooth': true,
    },
    'Blood Pressure': {
      'title': 'Blood Pressure',
      'subtitle': 'Record systolic and diastolic BP',
      'icon': '🩸',
      'unit': 'mmHg',
      'type': 'dual',
      'observationType': 'blood_pressure',
    },
    'Oxygen Saturation': {
      'title': 'Oxygen Saturation',
      'subtitle': 'Monitor blood oxygen levels',
      'icon': '🫁',
      'unit': '%',
      'type': 'single',
      'observationType': 'oxygen_saturation',
    },
  };
});

// Provider for getting all vital signs as a list
final vitalSignListProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final config = ref.watch(vitalSignConfigProvider);
  return config.values.toList();
});

// Provider for getting a specific vital sign data by type
final vitalSignDataProvider = Provider.family<Map<String, dynamic>?, String>((ref, vitalSignType) {
  final config = ref.watch(vitalSignConfigProvider);
  return config[vitalSignType];
});
