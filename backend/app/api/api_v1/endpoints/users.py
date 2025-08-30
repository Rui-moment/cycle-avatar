from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate, PasswordChange
from app.core.security import verify_password, get_password_hash
from app.api.api_v1.endpoints.auth import get_current_user

router = APIRouter()


@router.get("/me", response_model=UserResponse)
def get_current_user_profile(current_user: User = Depends(get_current_user)) -> Any:
    """Get current user profile."""
    return current_user


@router.put("/me", response_model=UserResponse)
def update_current_user_profile(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Update current user profile."""
    # Update user fields
    if user_update.display_name is not None:
        current_user.display_name = user_update.display_name
    if user_update.preferred_language is not None:
        current_user.preferred_language = user_update.preferred_language

    db.commit()
    db.refresh(current_user)

    return current_user


@router.post("/me/change-password")
def change_password(
    password_data: PasswordChange,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Change user password."""
    # Verify current password
    if not verify_password(
        password_data.current_password, current_user.hashed_password
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect current password"
        )

    # Update password
    current_user.hashed_password = get_password_hash(password_data.new_password)
    db.commit()

    return {"message": "Password successfully changed"}


@router.delete("/me")
def delete_current_user_account(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Any:
    """Delete current user account."""
    # Mark user as inactive instead of hard delete for data integrity
    current_user.is_active = False
    db.commit()

    return {"message": "Account successfully deleted"}


@router.post("/me/reactivate")
def reactivate_account(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Any:
    """Reactivate user account."""
    current_user.is_active = True
    db.commit()

    return {"message": "Account successfully reactivated"}


@router.get("/me/stats")
def get_user_statistics(current_user: User = Depends(get_current_user)) -> Any:
    """Get user account statistics."""
    from datetime import datetime

    # Calculate account age in days
    account_age_days = (
        datetime.utcnow() - current_user.created_at.replace(tzinfo=None)
    ).days

    return {
        "account_created": current_user.created_at,
        "account_age_days": account_age_days,
        "login_count": current_user.login_count,
        "last_login": current_user.last_login_at,
        "last_sync": current_user.last_sync_at,
        "preferred_language": current_user.preferred_language,
        "is_active": current_user.is_active,
    }
