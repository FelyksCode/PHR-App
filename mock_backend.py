"""
Mock FastAPI backend for PHR app authentication testing.
Run with: python mock_backend.py
"""
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional
import uvicorn
import jwt
from datetime import datetime, timedelta

app = FastAPI(title="PHR Mock Backend", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# JWT settings
SECRET_KEY = "your-secret-key-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Mock user database
MOCK_USERS = {
    "demo@example.com": {
        "id": 1,
        "name": "Demo User",
        "email": "demo@example.com",
        "fhir_patient_id": "patient-demo-001",
        "is_admin": False,
        "is_active": True,
        "created_at": "2024-01-01T10:00:00Z",
        "password": "demo123"  # In production, this should be hashed
    },
    "john@example.com": {
        "id": 2,
        "name": "John Doe",
        "email": "john@example.com",
        "fhir_patient_id": "12345",
        "is_admin": False,
        "is_active": True,
        "created_at": "2024-01-01T10:00:00Z",
        "password": "securepassword123"  # In production, this should be hashed
    }
}

# Pydantic models
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class User(BaseModel):
    id: int
    name: str
    email: str
    fhir_patient_id: str
    is_admin: bool
    is_active: bool
    created_at: str

class LoginResponse(BaseModel):
    access_token: str
    token_type: str

# Security
security = HTTPBearer()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return email
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

@app.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    user_data = MOCK_USERS.get(request.email)
    
    if not user_data or user_data["password"] != request.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": request.email}, expires_delta=access_token_expires
    )
    
    return LoginResponse(
        access_token=access_token,
        token_type="bearer"
    )

@app.get("/auth/me", response_model=User)
async def get_current_user(email: str = Depends(verify_token)):
    user_data = MOCK_USERS.get(email)
    
    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return User(
        id=user_data["id"],
        name=user_data["name"],
        email=user_data["email"],
        fhir_patient_id=user_data["fhir_patient_id"],
        is_admin=user_data["is_admin"],
        is_active=user_data["is_active"],
        created_at=user_data["created_at"]
    )

@app.get("/")
async def root():
    return {"message": "PHR Mock Backend is running!", "version": "1.0.0"}

if __name__ == "__main__":
    print("🚀 Starting PHR Mock Backend...")
    print("📧 Demo credentials:")
    print("   Email: demo@example.com")
    print("   Password: demo123")
    print("📧 John credentials:")
    print("   Email: john@example.com")
    print("   Password: securepassword123")
    print("🔗 API will be available at: http://localhost:8000")
    print("📖 API docs: http://localhost:8000/docs")
    
    uvicorn.run(app, host="0.0.0.0", port=8000)