from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr
from uuid import UUID

class UserBase(BaseModel):
    """Base user model."""
    email: EmailStr
    display_name: str
    preferred_language: Optional[str] = "en"

class UserCreate(UserBase):
    """User creation model."""
    password: str

class UserUpdate(BaseModel):
    """User update model."""
    display_name: Optional[str] = None
    preferred_language: Optional[str] = None

class PasswordChange(BaseModel):
    """Password change model."""
    current_password: str
    new_password: str

class UserResponse(UserBase):
    """User response model."""
    id: UUID
    is_active: bool
    created_at: datetime
    last_sync_at: Optional[datetime] = None
    last_login_at: Optional[datetime] = None
    login_count: int
    
    class Config:
        from_attributes = True