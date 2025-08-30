from sqlalchemy import (
    Column,
    String,
    DateTime,
    Boolean,
    Text,
    Integer,
    Numeric,
    ForeignKey,
    JSON,
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import uuid
from app.db.database import Base


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    name_en = Column(String, nullable=False)
    name_ja = Column(String, nullable=False)
    category = Column(String, nullable=False)
    equipment = Column(String, nullable=True)
    instructions = Column(Text, nullable=True)
    is_compound = Column(Boolean, default=False, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    sets = relationship("Set", back_populates="exercise")
    pr_records = relationship("PRRecord", back_populates="exercise")

    def __repr__(self):
        return f"<Exercise(id={self.id}, name_en={self.name_en})>"


class MuscleGroup(Base):
    __tablename__ = "muscle_groups"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    name_en = Column(String, nullable=False)
    name_ja = Column(String, nullable=False)
    recovery_tau = Column(
        Numeric(5, 2), nullable=False
    )  # Recovery time constant in hours
    fatigue_multiplier = Column(Numeric(3, 2), nullable=False)
    body_region = Column(String, nullable=False)

    # Relationships
    fatigue_events = relationship("FatigueEvent", back_populates="muscle_group")
    recovery_states = relationship("RecoveryState", back_populates="muscle_group")

    def __repr__(self):
        return f"<MuscleGroup(id={self.id}, name_en={self.name_en})>"


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    session_type = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    is_synced = Column(Boolean, default=False, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    user = relationship("User", back_populates="workout_sessions")
    sets = relationship("Set", back_populates="session", cascade="all, delete-orphan")
    fatigue_events = relationship("FatigueEvent", back_populates="workout_session")

    def __repr__(self):
        return f"<WorkoutSession(id={self.id}, user_id={self.user_id}, start_time={self.start_time})>"


class Set(Base):
    __tablename__ = "sets"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    session_id = Column(
        String(36), ForeignKey("workout_sessions.id"), nullable=False, index=True
    )
    exercise_id = Column(
        String(36), ForeignKey("exercises.id"), nullable=False, index=True
    )
    weight = Column(Numeric(6, 2), nullable=False)  # Weight in kg
    reps = Column(Integer, nullable=False)
    rpe = Column(Integer, nullable=True)  # Rate of Perceived Exertion (1-10)
    rest_seconds = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    set_order = Column(Integer, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    session = relationship("WorkoutSession", back_populates="sets")
    exercise = relationship("Exercise", back_populates="sets")

    def __repr__(self):
        return f"<Set(id={self.id}, exercise_id={self.exercise_id}, weight={self.weight}, reps={self.reps})>"


class FatigueEvent(Base):
    __tablename__ = "fatigue_events"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    muscle_group_id = Column(
        String(36), ForeignKey("muscle_groups.id"), nullable=False, index=True
    )
    fatigue_score = Column(Numeric(8, 2), nullable=False)
    timestamp = Column(DateTime(timezone=True), nullable=False)
    workout_session_id = Column(
        String(36), ForeignKey("workout_sessions.id"), nullable=False, index=True
    )

    # Relationships
    muscle_group = relationship("MuscleGroup", back_populates="fatigue_events")
    workout_session = relationship("WorkoutSession", back_populates="fatigue_events")

    def __repr__(self):
        return f"<FatigueEvent(id={self.id}, muscle_group_id={self.muscle_group_id}, fatigue_score={self.fatigue_score})>"


class RecoveryState(Base):
    __tablename__ = "recovery_states"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    muscle_group_id = Column(
        String(36), ForeignKey("muscle_groups.id"), nullable=False, index=True
    )
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    current_fatigue = Column(Numeric(8, 2), nullable=False, default=0)
    last_updated = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    readiness_level = Column(
        String, nullable=False, default="ready"
    )  # ready, warm, fatigued

    # Relationships
    muscle_group = relationship("MuscleGroup", back_populates="recovery_states")
    user = relationship("User", back_populates="recovery_states")

    def __repr__(self):
        return f"<RecoveryState(id={self.id}, muscle_group_id={self.muscle_group_id}, readiness_level={self.readiness_level})>"


class PRRecord(Base):
    __tablename__ = "pr_records"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    exercise_id = Column(
        String(36), ForeignKey("exercises.id"), nullable=False, index=True
    )
    weight = Column(Numeric(6, 2), nullable=False)
    reps = Column(Integer, nullable=False)
    estimated_max = Column(Numeric(6, 2), nullable=True)
    achieved_at = Column(DateTime(timezone=True), nullable=False)

    # Relationships
    user = relationship("User", back_populates="pr_records")
    exercise = relationship("Exercise", back_populates="pr_records")

    def __repr__(self):
        return f"<PRRecord(id={self.id}, user_id={self.user_id}, weight={self.weight}, reps={self.reps})>"


class Template(Base):
    __tablename__ = "templates"

    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    exercise_order = Column(JSON, nullable=False)  # List of exercise IDs in order
    is_public = Column(Boolean, default=False, nullable=False)
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    user = relationship("User", back_populates="templates")

    def __repr__(self):
        return f"<Template(id={self.id}, name={self.name}, user_id={self.user_id})>"
