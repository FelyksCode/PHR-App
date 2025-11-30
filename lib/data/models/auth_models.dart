class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String fhirPatientId;
  final bool? isAdmin;
  final bool? isActive;
  final String? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.fhirPatientId,
    this.isAdmin,
    this.isActive,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      fhirPatientId: json['fhir_patient_id'] as String,
      isAdmin: json['is_admin'] as bool?,
      isActive: json['is_active'] as bool?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'fhir_patient_id': fhirPatientId,
      'is_admin': isAdmin,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}

class LoginResponse {
  final String accessToken;
  final String tokenType;

  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
    };
  }
}

class AuthState {
  final User? user;
  final String? accessToken;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.accessToken,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  factory AuthState.fromJson(Map<String, dynamic> json) {
    return AuthState(
      user: json['user'] != null ? User.fromJson(json['user'] as Map<String, dynamic>) : null,
      accessToken: json['access_token'] as String?,
      isAuthenticated: json['is_authenticated'] as bool? ?? false,
      isLoading: json['is_loading'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user?.toJson(),
      'access_token': accessToken,
      'is_authenticated': isAuthenticated,
      'is_loading': isLoading,
      'error': error,
    };
  }

  AuthState copyWith({
    User? user,
    String? accessToken,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  AuthState clearError() {
    return copyWith(error: null);
  }

  static const AuthState initial = AuthState();
}

