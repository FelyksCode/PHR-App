# Personal Health Record (PHR) Flutter App

## Project Overview

This is a cross-platform Flutter PHR app (Android-first, iOS-compatible) that collects health data manually from users and sends it to a backend gateway API that converts the data to FHIR resources.

## Features

### 1. Vital Signs Collection (FHIR Observation Resources)
- Body Weight (kg)
- Body Height (cm) 
- Body Temperature (°C)
- Blood Pressure - Systolic (mmHg)
- Blood Pressure - Diastolic (mmHg)
- Oxygen Saturation (SpO₂, %)

### 2. Condition/Symptom Reporting (FHIR Condition Resources)
- Current Symptoms
- Side Effects
- Severity levels: Mild, Moderate, Severe

### 3. FHIR Gateway Integration
- POST /api/health-data/observation
- POST /api/health-data/condition

## Build Instructions

### Prerequisites
- Flutter SDK (≥3.9.2)
- Dart SDK (included with Flutter)

### Setup
```bash
cd phr_app
flutter pub get
dart run build_runner build
```

### Run
```bash
flutter run -d android  # Primary target
flutter run -d ios      # Compatible
```

### Configuration
Update backend URL in `lib/core/constants/api_constants.dart`

## Architecture

Clean architecture with Riverpod state management:
- **Presentation**: Screens, widgets, providers
- **Domain**: Entities, use cases, repository interfaces
- **Data**: Models, repository implementations
- **Services**: API client, external services

## FHIR Mapping

### Observation → LOINC Codes
- Body Weight: `29463-7`
- Body Height: `8302-2` 
- Body Temperature: `8310-5`
- Blood Pressure Systolic: `8480-6`
- Blood Pressure Diastolic: `8462-4`
- Oxygen Saturation: `2708-6`

### Condition Severity → SNOMED CT
- Mild: `255604002`
- Moderate: `6736007`
- Severe: `24484000`

## Example API Payloads

### Observation (Body Weight)
```json
{
  "resourceType": "Observation",
  "status": "final",
  "code": {
    "coding": [{
      "system": "http://loinc.org",
      "code": "29463-7",
      "display": "Body Weight"
    }]
  },
  "valueQuantity": {
    "value": 70.5,
    "unit": "kg",
    "system": "http://unitsofmeasure.org"
  }
}
```

### Condition (Symptom)
```json
{
  "resourceType": "Condition",
  "clinicalStatus": {"coding": [{"code": "active"}]},
  "severity": {
    "coding": [{
      "system": "http://snomed.info/sct",
      "code": "255604002",
      "display": "Mild"
    }]
  },
  "code": {"text": "Headache after medication"}
}
```

## Future Expansion

### HealthKit & Health Connect Integration
- iOS: HKHealthStore for automatic data collection
- Android: Health Connect for sensor aggregation
- Background sync and conflict resolution

## Technology Stack

- Flutter + Riverpod
- Dio for HTTP
- JSON serialization
- FHIR R4 compliance
