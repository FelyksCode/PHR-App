# FHIR Questionnaire System Implementation Guide

## Overview

This is a clinical-grade structured questionnaire system for capturing cancer outpatient symptoms and side effects, with complete FHIR Condition resource mapping.

## Architecture

### Domain Layer

#### Entities

- **`questionnaire_entity.dart`**: Core data models
  - `QuestionDefinition`: Individual question with FHIR coding
  - `FhirCoding`: SNOMED/LOINC/MedDRA coding system
  - `QuestionResponse`: User response to a single question
  - `QuestionnaireResponse`: Container for all responses

- **`questionnaire_definitions.dart`**: Pre-defined questionnaires
  - 30 Current Symptoms questions
  - 13 Side Effects questions
  - All with SNOMED/LOINC/MedDRA codes

- **`condition_entity.dart`**: Existing severity enums (reused)
  - `ConditionSeverity`: Mild | Moderate | Severe

#### Mappers

- **`fhir_condition_mapper.dart`**: Convert responses → FHIR Conditions
  - Maps questionnaire responses to individual FHIR Condition resources
  - Creates transaction Bundle for batch submission
  - Severity mapping: Mild/Moderate/Severe → SNOMED codes

#### Use Cases

- **`questionnaire_usecases.dart`**:
  - `SubmitQuestionnaireUseCase`: Submit responses to FHIR endpoint
  - `GetQuestionnaireDefinitionsUseCase`: Retrieve question definitions

### Presentation Layer

#### Providers

- **`questionnaire_provider.dart`**: State management
  - `questionnaireResponseProvider`: Main questionnaire state
  - `answeredCountCurrentProvider`: Answered current symptoms count
  - `answeredCountSideEffectsProvider`: Answered side effects count
  - `totalAnsweredProvider`: Total answered questions
  - `hasAnswersProvider`: Validation check

#### Screens

- **`questionnaire_condition_screen.dart`**: Main UI
  - Tabbed interface (Current Symptoms | Side Effects)
  - Dynamic question list with severity selectors
  - Optional notes field
  - Submission with validation

#### Widgets

- **`questionnaire_item_widget.dart`**: Individual question UI
  - Severity selector (Mild/Moderate/Severe)
  - Visual feedback with colors and icons
  - Clear button for unanswered questions

- **`condition_severity_extensions.dart`**: UI utilities
  - Color mappings for severity levels
  - Icons for severity levels

## Data Flow

```
User Input
    ↓
QuestionnaireItemWidget (UI)
    ↓
questionnaireResponseProvider (Riverpod)
    ↓
QuestionnaireResponse (State)
    ↓
SubmitQuestionnaire → FhirConditionMapper
    ↓
FHIR Bundle (Transaction)
    ↓
API Service → Backend
```

## FHIR Mapping

### Current Symptoms (30 questions)

Each symptom maps to a SNOMED code or LOINC code:

```dart
// Example: Fatigue
QuestionDefinition(
  id: 'q_fatigue',
  label: 'Fatigue / Weakness',
  category: 'current_symptom',
  coding: FhirCoding(
    system: 'http://snomed.info/sct',
    code: '84229001',
    display: 'Fatigue',
  ),
)
```

### Side Effects (13 questions)

```dart
// Example: Proteinuria
QuestionDefinition(
  id: 'se_proteinuria',
  label: 'Proteinuria (Protein in Urine)',
  category: 'side_effect',
  coding: FhirCoding(
    system: 'http://snomed.info/sct',
    code: '29738008',
    display: 'Proteinuria (finding)',
  ),
)
```

### Severity Mapping

- **Mild** → SNOMED code: `255604002`
- **Moderate** → SNOMED code: `6736007`
- **Severe** → SNOMED code: `24484000`

### FHIR Condition Resource Example

```json
{
  "resourceType": "Condition",
  "clinicalStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/condition-clinical",
        "code": "active",
        "display": "Active"
      }
    ]
  },
  "verificationStatus": {
    "coding": [
      {
        "system": "http://terminology.hl7.org/CodeSystem/condition-ver-status",
        "code": "unconfirmed",
        "display": "Unconfirmed"
      }
    ]
  },
  "code": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "84229001",
        "display": "Fatigue"
      }
    ]
  },
  "subject": {
    "reference": "Patient/patient-123"
  },
  "recordedDate": "2025-12-23T10:30:00.000Z",
  "severity": {
    "coding": [
      {
        "system": "http://snomed.info/sct",
        "code": "255604002",
        "display": "Mild"
      }
    ]
  }
}
```

### Batch Submission Bundle

Multiple conditions are submitted as a FHIR transaction Bundle:

```json
{
  "resourceType": "Bundle",
  "type": "transaction",
  "entry": [
    {
      "fullUrl": "urn:uuid:condition-q_fatigue",
      "resource": { /* Condition resource */ },
      "request": {
        "method": "POST",
        "url": "Condition"
      }
    },
    {
      "fullUrl": "urn:uuid:condition-q_nausea",
      "resource": { /* Another Condition resource */ },
      "request": {
        "method": "POST",
        "url": "Condition"
      }
    }
  ]
}
```

## Usage Example

### Basic Integration

```dart
// In your routing file, replace old condition screen with:
const QuestionnaireConditionScreen()

// Or update navigation references:
// OLD: navigator.push(ConditionScreen)
// NEW: navigator.push(QuestionnaireConditionScreen)
```

### Accessing State

```dart
final response = ref.watch(questionnaireResponseProvider);
final answered = response.answeredQuestions;
final count = ref.watch(totalAnsweredProvider);
```

### Manual Submission

```dart
final response = ref.read(questionnaireResponseProvider);
final bundle = FhirConditionMapper.questionnaireResponseToFhirBundle(
  response,
  patientId: 'patient-123',
);
```

## Validation Rules

1. **No empty submissions**: At least one symptom/side effect must be selected
2. **Severity required**: Each answered question must have severity selected
3. **Notes optional**: Additional notes are optional
4. **Patient ID required**: Must provide patient ID for FHIR reference
5. **Timestamp**: Automatically set to current time

## Clinical Compliance

✓ All questions use standardized SNOMED/LOINC codes  
✓ No free-text diagnosis (structured only)  
✓ Severity mapped to established coding systems  
✓ Supports batch submission for efficiency  
✓ Offline queue support (if integrated with offline_queue_provider)  
✓ Encounter tracking (optional)  
✓ No Observation/Condition mixing  
✓ One Condition per symptom/side effect  

## Integration Checklist

- [ ] Add imports in routing/navigation file
- [ ] Replace condition screen references with `QuestionnaireConditionScreen`
- [ ] Update API service to support `submitFhirBundle()` method
- [ ] Add `submitFhirBundle()` method to `HealthDataRepository`
- [ ] Test offline queue integration (if needed)
- [ ] Configure patient ID retrieval from auth provider
- [ ] Update backend to accept FHIR Bundle transactions
- [ ] Test FHIR validation against HAPI FHIR or similar validator

## Backend Requirements

The backend must:

1. Accept FHIR Bundle (type: transaction)
2. Process multiple Condition resources
3. Map severity codes correctly
4. Validate SNOMED/LOINC codes
5. Link conditions to patient by ID
6. Store recordedDate for audit trail
7. Support encounter reference (optional)

## Files Modified/Created

- ✅ `lib/domain/entities/questionnaire_entity.dart` (NEW)
- ✅ `lib/domain/entities/questionnaire_definitions.dart` (NEW)
- ✅ `lib/domain/mappers/fhir_condition_mapper.dart` (NEW)
- ✅ `lib/domain/usecases/questionnaire_usecases.dart` (NEW)
- ✅ `lib/presentation/providers/questionnaire_provider.dart` (NEW)
- ✅ `lib/presentation/screens/questionnaire_condition_screen.dart` (NEW)
- ✅ `lib/presentation/widgets/questionnaire_item_widget.dart` (NEW)
- ✅ `lib/presentation/widgets/condition_severity_extensions.dart` (NEW)
- ⚠️ `lib/presentation/screens/condition_screen.dart` (KEEP or REPLACE)

## Next Steps

1. **Integration**: Update navigation to use `QuestionnaireConditionScreen`
2. **Backend**: Implement FHIR Bundle endpoint
3. **Testing**: Unit test questionnaire state management
4. **Validation**: Validate FHIR output against HAPI validator
5. **Documentation**: Update API documentation
6. **Monitoring**: Add logging for FHIR submissions

## Testing Recommendations

```dart
// Example test
testWidgets('Questionnaire UI test', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  // Select severity for first question
  await tester.tap(find.byIcon(Icons.sentiment_satisfied));
  await tester.pumpAndSettle();
  
  // Verify state updated
  expect(find.text('1 symptom reported'), findsWidgets);
  
  // Submit
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
});
```

## Maintenance Notes

- All question codes are immutable (const)
- Adding new questions: Update `questionnaire_definitions.dart`
- Changing severity scale: Update `condition_entity.dart` and `fhir_condition_mapper.dart`
- Custom codes: Ensure SNOMED/LOINC compliance before adding
