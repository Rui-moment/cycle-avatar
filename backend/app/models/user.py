from sqlalchemy import Column, String, DateTime, Boolean, Integer
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import uuid
from app.db.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    display_name = Column(String, nullable=False)
    preferred_language = Column(String, default="en", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_sync_at = Column(DateTime(timezone=True), nullable=True)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    login_count = Column(Integer, default=0, nullable=False)

    # Relationships
    workout_sessions = relationship("WorkoutSession", back_populates="user")
    recovery_states = relationship("RecoveryState", back_populates="user")
    pr_records = relationship("PRRecord", back_populates="user")
    templates = relationship("Template", back_populates="user")

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email})>"
