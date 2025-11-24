class ValidationUtils {
  static String? validateWeight(String? value) {
    if (value == null || value.isEmpty) return 'Weight is required';
    final weight = double.tryParse(value);
    if (weight == null || weight <= 0) return 'Enter valid weight';
    if (weight > 500) return 'Weight seems too high';
    return null;
  }

  static String? validateHeight(String? value) {
    if (value == null || value.isEmpty) return 'Height is required';
    final height = double.tryParse(value);
    if (height == null || height <= 0) return 'Enter valid height';
    if (height > 300) return 'Height seems too high';
    return null;
  }

  static String? validateTemperature(String? value) {
    if (value == null || value.isEmpty) return 'Temperature is required';
    final temp = double.tryParse(value);
    if (temp == null || temp <= 0) return 'Enter valid temperature';
    if (temp < 25 || temp > 50) return 'Temperature out of normal range';
    return null;
  }

  static String? validateBloodPressure(String? value, {required bool isSystolic}) {
    if (value == null || value.isEmpty) return 'Blood pressure is required';
    final bp = int.tryParse(value);
    if (bp == null || bp <= 0) return 'Enter valid blood pressure';
    
    if (isSystolic) {
      if (bp < 60 || bp > 250) return 'Systolic BP out of range (60-250)';
    } else {
      if (bp < 40 || bp > 150) return 'Diastolic BP out of range (40-150)';
    }
    return null;
  }

  static String? validateOxygenSaturation(String? value) {
    if (value == null || value.isEmpty) return 'Oxygen saturation is required';
    final spo2 = double.tryParse(value);
    if (spo2 == null || spo2 <= 0) return 'Enter valid SpO₂';
    if (spo2 < 70 || spo2 > 100) return 'SpO₂ out of range (70-100%)';
    return null;
  }

  static String? validateConditionDescription(String? value) {
    if (value == null || value.trim().isEmpty) return 'Description is required';
    if (value.trim().length < 5) return 'Please provide more details (at least 5 characters)';
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}