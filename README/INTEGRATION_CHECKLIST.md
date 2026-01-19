# Questionnaire System Integration Checklist

## Pre-Integration Requirements

- [ ] Flutter 3.0+ installed
- [ ] Riverpod dependency in pubspec.yaml
- [ ] API service configured
- [ ] Authentication provider setup
- [ ] Offline queue service available (optional)

## Core System Implementation

### ✅ Domain Layer (COMPLETED)
- [x] `questionnaire_entity.dart` - Core models
- [x] `questionnaire_definitions.dart` - 43 questions with FHIR codes
- [x] `fhir_condition_mapper.dart` - FHIR mapping logic
- [x] `questionnaire_usecases.dart` - Use cases
- [x] Updated `condition_entity.dart` - Severity enums

### ✅ Data Layer (COMPLETED)
- [x] Updated `health_data_repository.dart` - Added submitFhirBundle
- [x] Updated `health_data_repository_impl.dart` - Implemented submitFhirBundle
- [x] Updated `api_service.dart` - Added submitFhirBundle method

### ✅ Presentation Layer (COMPLETED)
- [x] `questionnaire_provider.dart` - Riverpod state management
- [x] `questionnaire_condition_screen.dart` - Main UI screen
- [x] `questionnaire_item_widget.dart` - Question item widget
- [x] `condition_severity_extensions.dart` - UI extensions

## Integration Steps

### Step 1: Navigation Integration
**File**: `lib/presentation/screens/main_shell.dart` or your routing file

```dart
// OLD
case 'conditions':
  return ConditionScreen();

// NEW
case 'conditions':
  return QuestionnaireConditionScreen();
```

### Step 2: Menu/Navigation Button
Update any navigation buttons or menu items that point to the condition screen to ensure they work with the new screen.

### Step 3: Verify API Service Methods
Confirm these methods exist in your `ApiService`:
- [ ] `getFhirPatientId()` - Returns patient ID from auth
- [ ] `isOnline()` - Checks connectivity
- [ ] `submitFhirBundle(Map<String, dynamic> bundle)` - NEW METHOD (added automatically)

### Step 4: Verify Repository Methods
Confirm these methods exist in your `HealthDataRepository`:
- [ ] `submitFhirBundle(Map<String, dynamic> bundle)` - NEW METHOD (added automatically)

### Step 5: Test Offline Support (Optional)
If using offline queue:

```dart
final queueService = ref.read(offlineQueueServiceProvider);
final hasQueuedConditions = await queueService.getQueuedItemsCount()['conditions'] ?? 0;
```

### Step 6: Update Patient ID Retrieval
In `questionnaire_condition_screen.dart`, the system automatically:
```dart
final patientId = await apiService.getFhirPatientId();
```

If your app uses a different auth structure, update `_submitQuestionnaire()` method.

## Testing Checklist

### Unit Tests
- [ ] Test `QuestionnaireResponseNotifier` state updates
- [ ] Test `FhirConditionMapper` output format
- [ ] Test FHIR bundle generation
- [ ] Test severity mapping

### Widget Tests
- [ ] Test `QuestionnaireItemWidget` renders correctly
- [ ] Test severity selection interaction
- [ ] Test form submission validation

### Integration Tests
- [ ] Test full questionnaire submission flow
- [ ] Test offline submission queueing
- [ ] Test API integration
- [ ] Test FHIR bundle endpoint

### Manual Testing
- [ ] Open questionnaire screen
- [ ] Select a few symptoms with different severities
- [ ] Add optional notes
- [ ] Submit while online
- [ ] Verify FHIR output in network inspector
- [ ] Test offline submission (disable network)

## FHIR Validation

### Using HAPI FHIR Online
1. Go to http://hapi.fhir.org/
2. Submit your generated FHIR bundle
3. Validate against FHIR R4 specification
4. Check for any validation errors

### Backend Validation
Your backend should validate:
```json
POST /fhir
{
  "resourceType": "Bundle",
  "type": "transaction",
  "entry": [
    {
      "resource": {
        "resourceType": "Condition",
        "code": { "coding": [...] },
        "severity": { "coding": [...] },
        "subject": { "reference": "Patient/..." },
        ...
      },
      "request": {
        "method": "POST",
        "url": "Condition"
      }
    }
  ]
}
```

## Debugging

### Enable Logging
The system prints to console:
```dart
print('Submitting FHIR Bundle:');
print('Bundle type: ${bundle['type']}');
print('Entry count: ${(bundle['entry'] as List?)?.length ?? 0}');
```

Monitor in development:
```bash
flutter run -v | grep -i "FHIR\|questionnaire"
```

### Check State
In hot reload console:
```dart
final response = ref.read(questionnaireResponseProvider);
print(response.answeredQuestions);
```

### Network Inspection
Use your browser's network tab or Dio Interceptor to inspect:
- Request payload: `/fhir`
- Response status: 200/201
- Response body: Bundle response

## Rollback Plan

If issues arise:

1. **Revert questionnaire_condition_screen.dart**: Use old condition_screen.dart
2. **Keep new entities/models**: They're backward compatible
3. **Keep API methods**: No breaking changes to existing APIs
4. **Keep repository changes**: Only additions, no removals

All changes are additive and safe to keep even if rolling back UI.

## Post-Integration

### Monitoring
- [ ] Monitor submission success rate
- [ ] Track error logs for FHIR validation issues
- [ ] Monitor offline queue size
- [ ] Track user completion rates

### Documentation
- [ ] Update API documentation with /fhir endpoint
- [ ] Document expected FHIR output
- [ ] Create backend integration guide
- [ ] Update mobile app release notes

### Training
- [ ] Train clinicians on questionnaire UI
- [ ] Educate on clinical data expectations
- [ ] Provide FHIR specification overview
- [ ] Share troubleshooting guide

## Support Files Created

- `QUESTIONNAIRE_SYSTEM.md` - Complete system documentation
- `FHIR_CONDITION_MAPPING_REFERENCE.md` - Code mapping reference
- `QUESTIONNAIRE_INTEGRATION_EXAMPLES.dart` - Usage examples

## Performance Considerations

- **Memory**: 43 questions × responses = ~2KB state
- **Network**: Bundle with ~20 conditions ≈ 15KB payload
- **UI**: ListView with 43 items uses efficient itemBuilder
- **Offline**: Uses existing offline_queue_provider

## Security Notes

✓ Patient ID from authenticated session  
✓ Bearer token in all requests  
✓ HTTPS required for production  
✓ Validate token before submission  
✓ No sensitive data in logs  

## Known Issues & Workarounds

None currently. Report issues with:
- Flutter/Dart version
- Device/emulator details
- Exact error message
- Steps to reproduce

## Success Criteria

✅ Questionnaire screen loads without errors  
✅ Can select severity for questions  
✅ Can submit with 1+ symptom  
✅ FHIR bundle generated correctly  
✅ Backend receives and processes bundle  
✅ Offline queue works (if enabled)  
✅ Patient data properly referenced  

## Contact & Support

For questions about:
- **FHIR Mapping**: See FHIR_CONDITION_MAPPING_REFERENCE.md
- **Architecture**: See QUESTIONNAIRE_SYSTEM.md
- **Integration**: See QUESTIONNAIRE_INTEGRATION_EXAMPLES.dart
- **Implementation**: Review inline comments in source files

---

**Integration Date**: [Your Date]  
**Integrated By**: [Your Name]  
**Status**: ☐ In Progress ☐ Completed ☐ Validated
