import 'questionnaire_entity.dart';

/// Clinical questionnaire definitions with FHIR coding
class QuestionnaireDefinitions {
  /// Current symptoms questionnaire - all 30 questions
  static const List<QuestionDefinition> currentSymptomsQuestions = [
    QuestionDefinition(
      id: 'q_fatigue',
      label: 'Fatigue / Weakness',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '84229001',
        display: 'Fatigue',
      ),
    ),
    QuestionDefinition(
      id: 'q_nausea',
      label: 'Nausea / Vomiting',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '249497008',
        display: 'Vomiting symptom (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_skin_changes',
      label: 'Skin Changes (e.g., rash or dry skin)',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '271807003',
        display: 'Skin lesion',
      ),
    ),
    QuestionDefinition(
      id: 'q_joint_pain',
      label: 'Joint Pain or Muscle Aches',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '68962001',
        display: 'Joint pain (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_swelling',
      label: 'Swelling of Hands, Feet, Ankles, or Legs',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '299081000',
        display: 'Edema of lower limb',
      ),
    ),
    QuestionDefinition(
      id: 'q_breathing',
      label: 'Difficulty Breathing or Shortness of Breath',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '267036007',
        display: 'Dyspnea (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_palpitations',
      label: 'Heart Palpitations or Racing Heartbeat',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '80313002',
        display: 'Palpitation',
      ),
    ),
    QuestionDefinition(
      id: 'q_mood_changes',
      label: 'Changes in Mood or Emotional State',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '46053002',
        display: 'Mood swings',
      ),
    ),
    QuestionDefinition(
      id: 'q_high_bp',
      label: 'High Blood Pressure',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '38341003',
        display: 'Hypertension (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_low_bp',
      label: 'Low Blood Pressure',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '45007003',
        display: 'Hypotension (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'q_dizziness',
      label: 'Dizziness / Lightheadedness',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'https://loinc.org/45699-6',
        code: '45699-6',
        display: 'Dizziness or vertigo',
      ),
    ),
    QuestionDefinition(
      id: 'q_headache',
      label: 'Headache',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '25064002',
        display: 'Headache (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_hair_loss',
      label: 'Hair Loss or Changes in Hair Texture',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '13938008',
        display: 'Alopecia (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'q_blurred_vision',
      label: 'Blurred Vision or Other Visual Disturbances',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '111516008',
        display: 'Blurring of visual image (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_dry_eyes',
      label: 'Dry Eyes',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '34320007',
        display: 'Xerophthalmia (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'q_tinnitus',
      label: 'Tinnitus (Ringing in the Ears)',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '60862001',
        display: 'Tinnitus (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_earache',
      label: 'Earache',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '16001004',
        display: 'Ear pain (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_hearing_loss',
      label: 'Hearing Loss',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '343087000',
        display: 'Acquired hearing loss (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_runny_nose',
      label: 'Runny Nose',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '26284000',
        display: 'Rhinorrhea (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_stuffy_nose',
      label: 'Stuffy Nose',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '68235000',
        display: 'Nasal congestion (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_mouth_sores',
      label: 'Mouth Sores',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '26284000',
        display: 'Ulcer of mouth (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'q_dry_mouth',
      label: 'Dry Mouth',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '16045098',
        display: 'Xerostomia (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'q_chest_tightness',
      label: 'Chest Tightness',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'https://loinc.org/58259-3',
        code: '58259-3',
        display: 'Chest pain',
      ),
    ),
    QuestionDefinition(
      id: 'q_palpitations_standalone',
      label: 'Palpitations',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '80313002',
        display: 'Palpitation',
      ),
    ),
    QuestionDefinition(
      id: 'q_constipation',
      label: 'Constipation or Difficulty Digesting Foods',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '14760008',
        display: 'Constipation (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_abdominal_pain',
      label: 'Abdominal Pain or Cramping',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '21522001',
        display: 'Abdominal pain (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'q_urinary_frequency',
      label: 'Urinary Frequency or Urgency',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://terminology.hl7.org/CodeSystem/mdr',
        code: '10046539',
        display: 'Urinary frequency',
      ),
    ),
    QuestionDefinition(
      id: 'q_sexual_dysfunction',
      label: 'Sexual Dysfunction',
      category: 'current_symptom',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '44820008',
        display: 'Sexual dysfunction (finding)',
      ),
    ),
  ];

  /// Side effects questionnaire - 13 questions
  static const List<QuestionDefinition> sideEffectsQuestions = [
    QuestionDefinition(
      id: 'se_proteinuria',
      label: 'Proteinuria (Protein in Urine)',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '29738008',
        display: 'Proteinuria (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'se_hand_foot',
      label: 'Hand-Foot Syndrome',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '28538005',
        display: 'Hand foot syndrome',
      ),
    ),
    QuestionDefinition(
      id: 'se_liver',
      label: 'Liver Problems (Elevated Liver Enzymes)',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '707724006',
        display: 'Liver enzymes level above reference range (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'se_kidney',
      label: 'Kidney Problems',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '90708001',
        display: 'Kidney disease',
      ),
    ),
    QuestionDefinition(
      id: 'se_heart',
      label: 'Heart Problems',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '84114007',
        display: 'Heart failure',
      ),
    ),
    QuestionDefinition(
      id: 'se_infusion_reaction',
      label: 'Infusion Reactions',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '61783001',
        display: 'Infusion reaction',
      ),
    ),
    QuestionDefinition(
      id: 'se_injection_site',
      label: 'Pain at Injection Site',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '95376002',
        display: 'Injection site disorder (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'se_infection_risk',
      label: 'Increased Risk of Infections',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '102466009',
        display: 'Increased susceptibility to infections (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'se_bleeding',
      label: 'Bleeding (Including GI Bleeding)',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '74474003',
        display: 'Gastrointestinal hemorrhage (disorder)',
      ),
    ),
    QuestionDefinition(
      id: 'se_nail_changes',
      label: 'Nail Changes',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '416596008',
        display: 'Nail Changes',
      ),
    ),
    QuestionDefinition(
      id: 'se_fever',
      label: 'Fever and Chills',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '386661006',
        display: 'Fever (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'se_dyspnea',
      label: 'Shortness of Breath or Coughing',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '267036007',
        display: 'Dyspnea (finding)',
      ),
    ),
    QuestionDefinition(
      id: 'se_paresthesia',
      label: 'Fingertip Tingling or Numbness',
      category: 'side_effect',
      coding: FhirCoding(
        system: 'http://snomed.info/sct',
        code: '91019004',
        display: 'Paresthesia (finding)',
      ),
    ),
  ];

  static List<QuestionDefinition> getQuestionsByCategory(String category) {
    if (category == 'current_symptom') {
      return currentSymptomsQuestions;
    } else if (category == 'side_effect') {
      return sideEffectsQuestions;
    }
    return [];
  }

  static QuestionDefinition? getQuestionById(String id) {
    for (final q in currentSymptomsQuestions) {
      if (q.id == id) return q;
    }
    for (final q in sideEffectsQuestions) {
      if (q.id == id) return q;
    }
    return null;
  }
}
