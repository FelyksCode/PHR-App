# PHR App Authentication System

## 🔐 Authentication Features

This Personal Health Record (PHR) app now includes a complete authentication system with:

- **Secure JWT Authentication**: Token-based authentication with FastAPI backend
- **Secure Storage**: JWT tokens stored securely using `flutter_secure_storage`
- **Form Validation**: Email and password validation with real-time feedback
- **Auto Login**: Automatic login on app restart if valid token exists
- **Clean Architecture**: Separation of concerns with repositories, services, and providers
- **State Management**: Riverpod for reactive state management
- **Error Handling**: Comprehensive error handling with user-friendly messages

## 🚀 Setup Instructions

### 1. Install Python Dependencies (for Mock Backend)
```bash
pip install fastapi uvicorn pydantic python-jose PyJWT python-multipart
# or
pip install -r requirements.txt
```

### 2. Start Mock Backend
```bash
python mock_backend.py
```
The backend will run at `http://localhost:8000`

### 3. Run Flutter App
```bash
flutter pub get
flutter run -d web-server --web-port 3000
# or for mobile
flutter run
```

## 🧪 Demo Credentials

Use these credentials to test the authentication:
- **Email**: `demo@example.com`
- **Password**: `demo123`

## 📱 App Flow

1. **App Start**: Shows login screen if not authenticated
2. **Login**: Enter credentials and authenticate with backend
3. **Dashboard**: Access full PHR functionality after authentication
4. **Auto-Login**: Automatically login on app restart
5. **Logout**: Secure logout with confirmation dialog

## 🏗️ Architecture

### Authentication Components

```
lib/
├── core/
│   ├── network/api_client.dart          # HTTP client configuration
│   ├── secure_storage/                  # Secure token storage
│   └── validators/validators.dart        # Form validation
├── data/
│   ├── models/auth_models.dart          # Auth data models
│   ├── services/auth_service.dart       # API communication
│   └── repositories/auth_repository.dart # Business logic
├── presentation/
│   └── screens/auth/login_screen.dart   # Login UI
├── providers/
│   └── auth_provider.dart               # State management
└── main.dart                            # App initialization
```

### Key Features

#### Secure Storage
- JWT tokens stored in device keychain/keystore
- Automatic encryption on Android and iOS
- Secure deletion on logout

#### Error Handling
- Network timeouts and connection errors
- Invalid credentials handling
- Token expiration management
- User-friendly error messages

#### Form Validation
- Real-time email format validation
- Password length requirements
- Loading states during authentication

#### State Management
- Reactive UI updates with Riverpod
- Global auth state management
- Auto-login functionality

## 🔧 Backend API Endpoints

### POST /auth/login
Login with email and password
```json
{
  "email": "demo@example.com",
  "password": "demo123"
}
```

Response:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "name": "Demo User",
    "email": "demo@example.com",
    "fhir_patient_id": "patient-demo-001"
  }
}
```

### GET /auth/me
Get current user info (requires Bearer token)

## 🛡️ Security Features

- **JWT Tokens**: Stateless authentication with expiration
- **Secure Storage**: Platform-specific secure storage
- **HTTPS Ready**: Configured for production HTTPS
- **CORS Protection**: Proper CORS configuration
- **Token Validation**: Server-side token verification

## 📋 Next Steps for Production

1. **Environment Configuration**: Use environment variables for API URLs
2. **HTTPS**: Deploy backend with SSL certificate
3. **Password Hashing**: Implement bcrypt for password hashing
4. **Refresh Tokens**: Add refresh token functionality
5. **User Registration**: Add user registration flow
6. **Password Reset**: Implement forgot password feature
7. **Multi-Factor Authentication**: Add 2FA support

## 🐛 Troubleshooting

### Common Issues

1. **Connection Refused**: Make sure mock backend is running on port 8000
2. **CORS Errors**: Backend includes CORS middleware for development
3. **Token Expired**: App automatically handles token expiration and logout
4. **Network Errors**: Check internet connection and backend availability

### Debug Mode
The API client includes logging for development. Check console for HTTP requests and responses.

## 📚 Dependencies

### Flutter Packages
- `flutter_secure_storage`: Secure token storage
- `go_router`: Navigation (future routing enhancement)
- `dio`: HTTP client
- `flutter_riverpod`: State management
- `json_annotation`: JSON serialization

### Backend Packages
- `fastapi`: Modern Python web framework
- `uvicorn`: ASGI server
- `pydantic`: Data validation
- `python-jose`: JWT handling
- `PyJWT`: JWT token library