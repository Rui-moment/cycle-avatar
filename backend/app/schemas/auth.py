from pydantic import BaseModel


class Token(BaseModel):
    """Token response model."""

    access_token: str
    refresh_token: str
    token_type: str


class TokenRefresh(BaseModel):
    """Token refresh request model."""

    refresh_token: str


class PasswordResetRequest(BaseModel):
    """Password reset request model."""

    email: str


class PasswordReset(BaseModel):
    """Password reset model."""

    token: str
    new_password: str
