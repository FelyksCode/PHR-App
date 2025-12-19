import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/observation_entity.dart';
import '../../data/models/observation_model.dart';

class VitalSignsProvider extends ChangeNotifier {
  // Controllers for different vital signs
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _notesControllers = {};
  
  // Search functionality
  String _searchQuery = '';
  
  // Loading state
  bool _isLoading = false;
  
  // Submission state
  String? _submissionMessage;
  bool _submissionSuccess = false;
  
  // Available reading types with metadata
  final List<Map<String, dynamic>> _vitalSignTypes = [
    {
      'title': 'Body Weight',
      'subtitle': 'Track your weight changes',
      'icon': '⚖️',
      'unit': 'kg',
      'type': 'single',
      'observationType': 'body_weight',
    },
    {
      'title': 'Body Height',
      'subtitle': 'Record your height measurement',
      'icon': '📏',
      'unit': 'cm',
      'type': 'single',
      'observationType': 'body_height',
    },
    {
      'title': 'Body Temperature',
      'subtitle': 'Monitor body temperature',
      'icon': '🌡️',
      'unit': '°C',
      'type': 'single',
      'observationType': 'body_temperature',
    },
    {
      'title': 'Heart Rate',
      'subtitle': 'Track your heart rate',
      'icon': '❤️',
      'unit': 'bpm',
      'type': 'single',
      'observationType': 'heart_rate',
      'hasBluetooth': true,
    },
    {
      'title': 'Blood Pressure',
      'subtitle': 'Record systolic and diastolic BP',
      'icon': '🩸',
      'unit': 'mmHg',
      'type': 'dual',
      'observationType': 'blood_pressure',
    },
    {
      'title': 'Oxygen Saturation',
      'subtitle': 'Monitor blood oxygen levels',
      'icon': '🫁',
      'unit': '%',
      'type': 'single',
      'observationType': 'oxygen_saturation',
    },
  ];

  // Getters
  Map<String, TextEditingController> get controllers => _controllers;
  Map<String, TextEditingController> get notesControllers => _notesControllers;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get submissionMessage => _submissionMessage;
  bool get submissionSuccess => _submissionSuccess;
  List<Map<String, dynamic>> get vitalSignTypes => _vitalSignTypes;
  
  List<Map<String, dynamic>> get filteredVitalSigns {
    if (_searchQuery.isEmpty) return _vitalSignTypes;
    return _vitalSignTypes.where((vitalSign) {
      final title = vitalSign['title'] as String;
      final subtitle = vitalSign['subtitle'] as String;
      return title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  VitalSignsProvider() {
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize controllers for all vital signs
    for (final vitalSign in _vitalSignTypes) {
      final title = vitalSign['title'] as String;
      _controllers[title] = TextEditingController();
      _notesControllers[title] = TextEditingController();
      
      // For blood pressure, create separate controllers
      if (title == 'Blood Pressure') {
        _controllers['Systolic BP'] = TextEditingController();
        _controllers['Diastolic BP'] = TextEditingController();
      }
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearchQuery() {
    _searchQuery = '';
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setSubmissionResult(bool success, String message) {
    _submissionSuccess = success;
    _submissionMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  void clearSubmissionMessage() {
    _submissionMessage = null;
    _submissionSuccess = false;
    notifyListeners();
  }

  void clearFormFields(String title, {bool isBloodPressure = false}) {
    if (isBloodPressure) {
      _controllers['Systolic BP']?.clear();
      _controllers['Diastolic BP']?.clear();
    } else {
      _controllers[title]?.clear();
    }
    _notesControllers[title]?.clear();
    notifyListeners();
  }

  bool validateInput(String title) {
    final controller = _controllers[title];
    if (controller?.text.isEmpty == true) {
      setSubmissionResult(false, 'Please enter a value for $title');
      return false;
    }

    if (title == 'Blood Pressure') {
      final systolicController = _controllers['Systolic BP'];
      final diastolicController = _controllers['Diastolic BP'];
      
      if (systolicController?.text.isEmpty == true || diastolicController?.text.isEmpty == true) {
        setSubmissionResult(false, 'Please enter both systolic and diastolic values');
        return false;
      }
    }

    return true;
  }

  ObservationEntity? createObservation(String title, String type) {
    final controller = _controllers[title];
    final notesController = _notesControllers[title];
    
    if (controller == null) return null;
    
    final notes = notesController?.text.isNotEmpty == true ? notesController!.text : null;

    try {
      switch (title) {
        case 'Body Weight':
          return ObservationModel.create(
            type: ObservationType.bodyWeight,
            value: double.parse(controller.text),
            unit: 'kg',
            notes: notes,
          );
        case 'Body Height':
          return ObservationModel.create(
            type: ObservationType.bodyHeight,
            value: double.parse(controller.text),
            unit: 'cm',
            notes: notes,
          );
        case 'Body Temperature':
          return ObservationModel.create(
            type: ObservationType.bodyTemperature,
            value: double.parse(controller.text),
            unit: '°C',
            notes: notes,
          );
        case 'Heart Rate':
          return ObservationModel.create(
            type: ObservationType.heartRate,
            value: double.parse(controller.text),
            unit: 'bpm',
            notes: notes,
          );
        case 'Oxygen Saturation':
          final value = double.parse(controller.text);
          if (value > 100) {
            setSubmissionResult(false, 'Oxygen saturation cannot exceed 100%');
            return null;
          }
          return ObservationModel.create(
            type: ObservationType.oxygenSaturation,
            value: value,
            unit: '%',
            notes: notes,
          );
        default:
          return null;
      }
    } catch (e) {
      setSubmissionResult(false, 'Invalid input: Please enter a valid number');
      return null;
    }
  }

  List<ObservationEntity> createBloodPressureObservations() {
    final systolicController = _controllers['Systolic BP'];
    final diastolicController = _controllers['Diastolic BP'];
    final notesController = _notesControllers['Blood Pressure'];
    
    if (systolicController == null || diastolicController == null) return [];
    
    final notes = notesController?.text.isNotEmpty == true ? notesController!.text : null;
    
    try {
      final systolicObservation = ObservationModel.create(
        type: ObservationType.bloodPressureSystolic,
        value: double.parse(systolicController.text),
        unit: 'mmHg',
        notes: notes,
      );
      final diastolicObservation = ObservationModel.create(
        type: ObservationType.bloodPressureDiastolic,
        value: double.parse(diastolicController.text),
        unit: 'mmHg',
        notes: notes,
      );
      
      return [systolicObservation, diastolicObservation];
    } catch (e) {
      setSubmissionResult(false, 'Invalid input: Please enter valid numbers');
      return [];
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}