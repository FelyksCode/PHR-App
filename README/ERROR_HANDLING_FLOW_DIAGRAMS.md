# Error Handling Flow Diagrams

## 1. Error Flow: From Exception to UI

```
┌─────────────────────────────────────────────────────────────┐
│                    Low-Level Exception                       │
│  DioException, SocketException, TimeoutException, etc.       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼ (Caught in Service/API layer)
┌─────────────────────────────────────────────────────────────┐
│                    ApiErrorMapper                            │
│                                                               │
│  fromException(error) {                                      │
│    if (error is DioException)                                │
│      return _handleDioException(error)                       │
│    if (error is SocketException)                             │
│      return NetworkError(...)                                │
│    if (error is TimeoutException)                            │
│      return TimeoutError(...)                                │
│    return UnknownError(...)                                  │
│  }                                                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼ Domain-Level Error
┌─────────────────────────────────────────────────────────────┐
│                    AppError (Sealed)                         │
│                                                               │
│  ├─ NetworkError                                             │
│  ├─ UnauthorizedError                                        │
│  ├─ ForbiddenError                                           │
│  ├─ NotFoundError                                            │
│  ├─ ValidationError                                          │
│  ├─ ServerError                                              │
│  ├─ TimeoutError                                             │
│  └─ UnknownError                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
           ┌─────────────┼─────────────┐
           │             │             │
           ▼             ▼             ▼
    Logged to        Propagated    Used in
    Backend          to UI Layer    State
   (Firebase,                       (Error field)
   Sentry, etc.)                    
                         │
                         ▼ (Caught in UI layer)
┌─────────────────────────────────────────────────────────────┐
│              ErrorMessageResolver                            │
│                                                               │
│  resolve(error, context) {                                   │
│    return switch(error) {                                    │
│      NetworkError => 'Check your connection...',             │
│      UnauthorizedError => 'Please login again...',           │
│      ValidationError => 'Please fix the errors...',          │
│      ...                                                      │
│    };                                                         │
│  }                                                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼ User-Friendly Message
┌─────────────────────────────────────────────────────────────┐
│         Show to User (Snackbar, Dialog, Inline)              │
│                                                               │
│  "No internet connection. Please check your network."        │
│  (Non-technical, localized, no stack trace)                  │
└─────────────────────────────────────────────────────────────┘
```

## 2. HTTP Status Code Mapping

```
┌─────────────────────────────┐
│   HTTP Response Received    │
└──────────────┬──────────────┘
               │
         ┌─────┴──────────────────────────────────┐
         │                                         │
         ▼                                         ▼
    ┌────────┐                            ┌──────────────┐
    │ Success│                            │ Error Status │
    │2xx/3xx │                            │ Code         │
    └────────┘                            └──────┬───────┘
         │                                       │
         │                                  ┌────┴─────────────────┬──────────┬──────────┬─────────┐
         │                                  │                      │          │          │         │
         ▼                                  ▼                      ▼          ▼          ▼         ▼
    Parse Data              ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌─────┐ ┌──────┐ ┌──┐ ┌──────┐
                            │ 400     │ │401-403   │ │404      │ │408  │ │5xx   │ │N/A Or│
                            │Bad Req. │ │Auth      │ │Not Found│ │Timeout Server│ Conn.│
                            └────┬────┘ └────┬─────┘ └────┬────┘ └──┬──┘ └──┬───┘ └──┬─┘
                                 │           │            │         │      │       │
                                 ▼           ▼            ▼         ▼      ▼       ▼
                        ┌──────────────┐ ┌─────────────┐ ┌────┐ ┌─────┐ ┌──────┐ ┌─────────┐
                        │Validation    │ │Unauthorized │ │Not │ │Time │ │Server│ │Network  │
                        │Error         │ │Error        │ │Fou-│ │out  │ │Error │ │Error    │
                        │{fieldErrors} │ │{shouldLogout│ │nd  │ │     │ │      │ │         │
                        └──────────────┘ └─────────────┘ │Err.│ └─────┘ └──────┘ └─────────┘
                                                          └────┘
```

## 3. Repository Error Handling Pattern

```
┌────────────────────────────────────┐
│   Repository Method Called         │
│   Example: login(email, password)  │
└────────────────┬───────────────────┘
                 │
         ┌───────▼────────┐
         │ Validate Input │ (LocalValidationError)
         └───────┬────────┘
                 │
         ┌───────▼────────────┐
         │ Make API Request   │ (DioException possible)
         └───────┬────────────┘
                 │
         ┌───────▼──────────────────────┐
         │ Try-Catch Block              │
         │                              │
         │ 1. Catch LocalValidationError│
         │    └─ Re-throw (UI shows fields)
         │                              │
         │ 2. Catch DioException        │
         │    ├─ Call ApiErrorMapper    │
         │    ├─ Call AppErrorLogger    │
         │    └─ Throw AppError         │
         │                              │
         │ 3. Catch Any Other Exception │
         │    ├─ Wrap in UnknownError   │
         │    ├─ Call AppErrorLogger    │
         │    └─ Throw AppError         │
         └───────┬──────────────────────┘
                 │
         ┌───────▼────────────┐
         │ Only AppError or   │
         │ LocalValidationErr │
         │ escapes Repository │
         └───────┬────────────┘
                 │
         ┌───────▼──────────────┐
         │ Caught by State      │
         │ Management Layer     │
         └───────┬──────────────┘
                 │
         ┌───────▼────────────┐
         │ Stored in State    │
         │ error: AppError?   │
         └───────┬────────────┘
                 │
         ┌───────▼────────────────────┐
         │ UI Reads state.error       │
         │ and Shows to User          │
         └────────────────────────────┘
```

## 4. Error Type Decision Tree

```
                        Exception Occurs
                              │
                    ┌─────────┴──────────┐
                    │                    │
              Has Response?          No Response?
                    │                    │
         ┌──────────┴─────────┐         │
         │                    │         │
      Status Code         (DioException │
         │                 properties)  │
         │                    │         │
    ┌────┴───────────────┬────┴─┐      │
    │                    │      │      │
  4xx                  5xx   Other   Network
    │                    │      │      │
  ┌─┼─────────────┐      │      │      │
  │ │             │      │      │      │
400 401-403 404  408  Server Timeout  Socket
 │   │      │    │      │      │      │
 ▼   ▼      ▼    ▼      ▼      ▼      ▼
Val Unauth Not Timeout Server Unknown Network
 │    │     │   Error   Error  Error  Error
 │    │     │
 │    │     └─ NotFoundError
 │    │
 │    └─ UnauthorizedError
 │
 └─ ValidationError
```

## 5. UI Error Handling Decision Tree

```
              Caught AppError
                    │
     ┌──────────────┼──────────────┬──────────┐
     │              │              │          │
LocalValidation Unauthorized   Network   ServerError
Error            Error          Error        │
 │               │              │           │
 │               │              │      ┌────┴────┐
 │               │              │      │          │
 │               │              │      Is        Not
 │               │              │   Retryable  Retryable
 │               │              │      │          │
 ▼               ▼              ▼      ▼          ▼
Show         Force         Show     Show     Show
Field        Logout        Snackbar Snackbar Dialog
Errors                     with     (try     (try
                           Retry    again)   again)
                           Button            later)
                                  
Special: UnauthorizedError.shouldLogout = true
└─ Always triggers logout, clear tokens, redirect to login
```

## 6. Retry Logic Flow

```
┌─────────────────────────┐
│  Attempt Operation      │
└────────────┬────────────┘
             │
        ┌────▼─────────────┐
        │ Success?         │
        └────┬────────┬────┘
             │        │
            YES       NO
             │        │
             ▼        ▼
        Return    Caught Exception
        Result        │
                      ▼
              Is it AppError?
                  │        │
                 YES       NO
                  │        │
                  ▼        ▼
             Check Type  Wrap in
             (switch)    UnknownError
                │
      ┌─────────┼──────────┐
      │         │          │
   Network   Timeout   Other
   Error     Error     Error
      │         │          │
      ▼         ▼          ▼
   Check    Check      Don't
   isRetry- isRetry-   Retry
   able     able       (throw)
      │         │
   ┌──┴──┐   ┌──┴──┐
   │     │   │     │
  YES   NO  YES   NO
   │     │   │     │
   ▼     ▼   ▼     ▼
 Retry Throw Retry Throw
  (with    (with
 backoff)  backoff)
   │        │
   └────┬───┘
        │
    Increment
    Attempt
        │
        ▼
   ┌─────────────┐
   │Attempt < Max│
   └─┬───────┬───┘
     │       │
    YES     NO
     │       │
     ▼       ▼
  Sleep   Throw
   &     Error
 Retry
```

## 7. Logging Severity Decision

```
         Error Type
              │
    ┌─────────┼──────────────┬─────────────┐
    │         │              │             │
 Network   Validation    Unauthorized   Server
 Error     Error         Error          Error
    │         │              │             │
    ▼         ▼              ▼             ▼
 MEDIUM      LOW          HIGH         (varies)
              │              │             │
        (User mistake)  (Session        ┌──┴──┐
                        expired)        │     │
                                       5xx  4xx
                                       │     │
                                    CRITICAL HIGH
```

## 8. Complete Request-Response Cycle

```
LAYER          REQUEST                    RESPONSE
─────          ───────                    ────────

┌──────────────────────────────────────────────────────┐
│ UI Layer      └─── Login Button Pressed ─────┘       │
│               Calls: ref.read(authProvider)          │
└──────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────┐
│ State Mgmt.   AuthNotifier.login(email, pass)        │
│               Calls repository.login()               │
└──────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────┐
│ Repository    AuthRepository.login()                 │
│               ├─ Validates locally                   │
│               ├─ Calls _dio.post('/auth/login')      │
│               └─ Converts exception → AppError       │
└──────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────┐
│ API Layer     Dio.post() sends HTTP request          │
│               ├─ Network established                 │
│               ├─ Request sent                        │
│               └─ Response received (or times out)    │
└──────────────────────────────────────────────────────┘
                        │
           ┌────────────┴────────────┐
           │                         │
           ▼ Success (200)           ▼ Error (4xx/5xx or exception)
    ┌────────────────┐         ┌──────────────────┐
    │Parse JSON      │         │Catch Exception   │
    │Return User     │         │Map to AppError   │
    └────┬───────────┘         │Log Error         │
         │                     │Throw AppError    │
         ▼                     └────┬─────────────┘
    ┌────────────────────────────┐  │
    │AuthRepository returns       │  │
    │User (success)              │  ▼
    └────┬───────────────────────┘  ┌──────────────────┐
         │                          │AuthRepository    │
         ▼                          │throws AppError   │
    ┌──────────────────────────┐    └────┬─────────────┘
    │AuthNotifier._login()     │         │
    │Updates state             │         ▼
    │isAuthenticated: true     │    ┌──────────────────┐
    │user: User                │    │AuthNotifier      │
    └────┬─────────────────────┘    │catches AppError  │
         │                          │Updates state     │
         ▼                          │error: AppError   │
    ┌──────────────────────────┐    └────┬─────────────┘
    │UI reads state            │         │
    │Sees isAuthenticated=true │         ▼
    │Navigates to Dashboard    │    ┌──────────────────┐
    │SUCCESS!                  │    │UI reads state    │
    └──────────────────────────┘    │Sees error field  │
                                    │Calls            │
                                    │ErrorMessageR...  │
                                    │get user message  │
                                    │Shows Snackbar    │
                                    │ERROR DISPLAYED!  │
                                    └──────────────────┘
```

This visual representation helps understand the complete flow from API call to UI error display.
