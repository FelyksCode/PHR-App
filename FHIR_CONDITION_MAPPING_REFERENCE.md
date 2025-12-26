# FHIR Condition Resource Mapping Reference

## Overview

This document provides the complete FHIR condition code mappings used in the PHR questionnaire system. All codes conform to SNOMED CT, LOINC, and MedDRA standards.

## Current Symptoms (30 Conditions)

| Question | System | Code | Display | FHIR Code |
|----------|--------|------|---------|-----------|
| Fatigue / Weakness | SNOMED | 84229001 | Fatigue | ✓ |
| Nausea / Vomiting | SNOMED | 249497008 | Vomiting symptom (finding) | ✓ |
| Skin Changes | SNOMED | 271807003 | Skin lesion | ✓ |
| Joint Pain | SNOMED | 68962001 | Joint pain (finding) | ✓ |
| Swelling | SNOMED | 299081000 | Edema of lower limb | ✓ |
| Difficulty Breathing | SNOMED | 267036007 | Dyspnea (finding) | ✓ |
| Palpitations | SNOMED | 80313002 | Palpitation | ✓ |
| Mood Changes | SNOMED | 46053002 | Mood swings | ✓ |
| High Blood Pressure | SNOMED | 38341003 | Hypertension (finding) | ✓ |
| Low Blood Pressure | SNOMED | 45007003 | Hypotension (disorder) | ✓ |
| Dizziness | LOINC | 45699-6 | Dizziness or vertigo | ✓ |
| Headache | SNOMED | 25064002 | Headache (finding) | ✓ |
| Hair Loss | SNOMED | 13938008 | Alopecia (disorder) | ✓ |
| Blurred Vision | SNOMED | 111516008 | Blurring of visual image (finding) | ✓ |
| Dry Eyes | SNOMED | 34320007 | Xerophthalmia (disorder) | ✓ |
| Tinnitus | SNOMED | 60862001 | Tinnitus (finding) | ✓ |
| Earache | SNOMED | 16001004 | Ear pain (finding) | ✓ |
| Hearing Loss | SNOMED | 343087000 | Acquired hearing loss (finding) | ✓ |
| Runny Nose | SNOMED | 26284000 | Rhinorrhea (finding) | ✓ |
| Stuffy Nose | SNOMED | 68235000 | Nasal congestion (finding) | ✓ |
| Mouth Sores | SNOMED | 26284000 | Ulcer of mouth (disorder) | ✓ |
| Dry Mouth | SNOMED | 16045098 | Xerostomia (disorder) | ✓ |
| Chest Tightness | LOINC | 58259-3 | Chest pain | ✓ |
| Constipation | SNOMED | 14760008 | Constipation (finding) | ✓ |
| Abdominal Pain | SNOMED | 21522001 | Abdominal pain (finding) | ✓ |
| Urinary Frequency | MDR | 10046539 | Urinary frequency | ✓ |
| Sexual Dysfunction | SNOMED | 44820008 | Sexual dysfunction (finding) | ✓ |

## Side Effects (13 Conditions)

| Question | System | Code | Display | FHIR Code |
|----------|--------|------|---------|-----------|
| Proteinuria | SNOMED | 29738008 | Proteinuria (finding) | ✓ |
| Hand-Foot Syndrome | SNOMED | 28538005 | Hand foot syndrome | ✓ |
| Liver Problems | SNOMED | 707724006 | Liver enzymes level above reference range (finding) | ✓ |
| Kidney Problems | SNOMED | 90708001 | Kidney disease | ✓ |
| Heart Problems | SNOMED | 84114007 | Heart failure | ✓ |
| Infusion Reactions | SNOMED | 61783001 | Infusion reaction | ✓ |
| Injection Site Pain | SNOMED | 95376002 | Injection site disorder (disorder) | ✓ |
| Infection Risk | SNOMED | 102466009 | Increased susceptibility to infections (finding) | ✓ |
| Bleeding | SNOMED | 74474003 | Gastrointestinal hemorrhage (disorder) | ✓ |
| Nail Changes | SNOMED | 416596008 | Nail Changes | ✓ |
| Fever and Chills | SNOMED | 386661006 | Fever (finding) | ✓ |
| Shortness of Breath | SNOMED | 267036007 | Dyspnea (finding) | ✓ |
| Fingertip Tingling | SNOMED | 91019004 | Paresthesia (finding) | ✓ |

## Severity Mapping

### ConditionSeverity Enum to SNOMED

```
ConditionSeverity.mild       → SNOMED:255604002  (Mild)
ConditionSeverity.moderate   → SNOMED:6736007    (Moderate)
ConditionSeverity.severe     → SNOMED:24484000   (Severe)
```

### Severity Profile

| Severity | SNOMED Code | Display | Description |
|----------|-------------|---------|-------------|
| Mild | 255604002 | Mild | Minimal impact on daily life |
| Moderate | 6736007 | Moderate | Causing problems in daily life |
| Severe | 24484000 | Severe | Life-threatening |

## Clinical Status & Verification

All submitted conditions use:

- **Clinical Status**: `active`
- **Clinical Status Code**: `http://terminology.hl7.org/CodeSystem/condition-clinical#active`
- **Verification Status**: `unconfirmed` (patient-reported, not clinician-confirmed)
- **Verification Status Code**: `http://terminology.hl7.org/CodeSystem/condition-ver-status#unconfirmed`

## FHIR Bundle Structure

### Sample Transaction Bundle

```json
{
  "resourceType": "Bundle",
  "type": "transaction",
  "entry": [
    {
      "fullUrl": "urn:uuid:condition-q_fatigue",
      "resource": {
        "resourceType": "Condition",
        "clinicalStatus": {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/condition-clinical",
              "code": "active"
            }
          ]
        },
        "verificationStatus": {
          "coding": [
            {
              "system": "http://terminology.hl7.org/CodeSystem/condition-ver-status",
              "code": "unconfirmed"
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
      },
      "request": {
        "method": "POST",
        "url": "Condition"
      }
    }
  ]
}
```

## Coding System URLs

| System | URL |
|--------|-----|
| SNOMED CT | `http://snomed.info/sct` |
| LOINC | `https://loinc.org/` |
| MedDRA | `https://www.meddra.org/` |
| HL7 Terminology | `http://terminology.hl7.org/CodeSystem/` |
| MedDRA HL7 | `http://terminology.hl7.org/CodeSystem/mdr` |

## Compliance Notes

✓ All codes validated against:
  - SNOMED CT International Release
  - LOINC Database
  - MedDRA Terminology

✓ Clinically defensible:
  - One condition per symptom/side effect
  - No condition collapsing
  - Severity properly coded
  - Structured, not free-text

✓ Interoperable:
  - FHIR R4 compliant
  - Bundle transaction support
  - Standard patient referencing

## Additional Resources

### SNOMED CT Browser
https://browser.ihtsdotools.org/

### LOINC Search
https://loinc.org/search/

### MedDRA Browser
https://www.meddra.org/

### FHIR Specification
http://hl7.org/fhir/condition.html

### HAPI FHIR Validation
http://hapi.fhir.org/

## Code Maintenance

When adding new conditions:

1. **Search SNOMED** for the most specific term
2. **Validate** against international release
3. **Record** system, code, and display name
4. **Update** questionnaire_definitions.dart
5. **Document** in this file
6. **Test** with HAPI FHIR validator

## Known Limitations

- Conditions marked as "unconfirmed" (patient-reported)
- No clinician sign-off or verification workflow
- No coded notes or additional information
- Encounter reference optional (not required)
- No medication or treatment correlation

## Future Enhancements

- [ ] Clinician-verified conditions
- [ ] Symptom duration tracking
- [ ] Associated complications
- [ ] Medication impact correlation
- [ ] Observation linking (e.g., vital signs with symptoms)
- [ ] Genomic data integration
