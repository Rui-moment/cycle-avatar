from typing import List, Optional, Dict, Any
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, Field, ConfigDict
from uuid import UUID


# Exercise schemas
class ExerciseBase(BaseModel):
    name_en: str
    name_ja: str
    category: str
    equipment: Optional[str] = None
    instructions: Optional[str] = None
    is_compound: bool = False


class ExerciseCreate(ExerciseBase):
    pass


class ExerciseUpdate(BaseModel):
    name_en: Optional[str] = None
    name_ja: Optional[str] = None
    category: Optional[str] = None
    equipment: Optional[str] = None
    instructions: Optional[str] = None
    is_compound: Optional[bool] = None


class ExerciseResponse(ExerciseBase):
    id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# MuscleGroup schemas
class MuscleGroupBase(BaseModel):
    name_en: str
    name_ja: str
    recovery_tau: Decimal = Field(..., description="Recovery time constant in hours")
    fatigue_multiplier: Decimal = Field(
        ..., description="Fatigue calculation multiplier"
    )
    body_region: str


class MuscleGroupCreate(MuscleGroupBase):
    pass


class MuscleGroupResponse(MuscleGroupBase):
    id: UUID

    model_config = ConfigDict(from_attributes=True)


# Set schemas
class SetBase(BaseModel):
    exercise_id: UUID
    weight: Decimal = Field(..., description="Weight in kg")
    reps: int = Field(..., ge=1, description="Number of repetitions")
    rpe: Optional[int] = Field(
        None, ge=1, le=10, description="Rate of Perceived Exertion"
    )
    rest_seconds: Optional[int] = Field(None, ge=0, description="Rest time in seconds")
    notes: Optional[str] = None
    set_order: int = Field(..., ge=1, description="Order of set in session")


class SetCreate(SetBase):
    pass


class SetUpdate(BaseModel):
    weight: Optional[Decimal] = None
    reps: Optional[int] = Field(None, ge=1)
    rpe: Optional[int] = Field(None, ge=1, le=10)
    rest_seconds: Optional[int] = Field(None, ge=0)
    notes: Optional[str] = None
    set_order: Optional[int] = Field(None, ge=1)


class SetResponse(SetBase):
    id: UUID
    session_id: UUID
    created_at: datetime
    updated_at: datetime
    exercise: Optional[ExerciseResponse] = None

    model_config = ConfigDict(from_attributes=True)


# WorkoutSession schemas
class WorkoutSessionBase(BaseModel):
    start_time: datetime
    end_time: Optional[datetime] = None
    session_type: Optional[str] = None
    notes: Optional[str] = None


class WorkoutSessionCreate(WorkoutSessionBase):
    sets: List[SetCreate] = []


class WorkoutSessionUpdate(BaseModel):
    end_time: Optional[datetime] = None
    session_type: Optional[str] = None
    notes: Optional[str] = None


class WorkoutSessionResponse(WorkoutSessionBase):
    id: UUID
    user_id: UUID
    is_synced: bool
    created_at: datetime
    updated_at: datetime
    sets: List[SetResponse] = []

    model_config = ConfigDict(from_attributes=True)


# Batch sync schemas
class SyncEntity(BaseModel):
    entity_type: str = Field(..., description="Type of entity (session, set, etc.)")
    entity_id: UUID
    action: str = Field(..., description="Action: create, update, delete")
    data: Optional[Dict[str, Any]] = None
    timestamp: datetime
    client_version: Optional[str] = None


class BatchSyncRequest(BaseModel):
    entities: List[SyncEntity]
    last_sync_timestamp: Optional[datetime] = None
    client_id: Optional[str] = None


class SyncConflict(BaseModel):
    entity_type: str
    entity_id: UUID
    server_data: Dict[str, Any]
    client_data: Dict[str, Any]
    conflict_fields: List[str]


class BatchSyncResponse(BaseModel):
    success: bool
    synced_entities: List[UUID] = []
    conflicts: List[SyncConflict] = []
    server_changes: List[SyncEntity] = []
    last_sync_timestamp: datetime


# Recovery and fatigue schemas
class RecoveryStateBase(BaseModel):
    muscle_group_id: UUID
    current_fatigue: Decimal = Field(..., ge=0, description="Current fatigue level")
    readiness_level: str = Field(..., description="ready, warm, or fatigued")


class RecoveryStateResponse(RecoveryStateBase):
    id: UUID
    user_id: UUID
    last_updated: datetime
    muscle_group: Optional[MuscleGroupResponse] = None

    model_config = ConfigDict(from_attributes=True)


class FatigueEventBase(BaseModel):
    muscle_group_id: UUID
    fatigue_score: Decimal = Field(..., description="Calculated fatigue score")
    timestamp: datetime
    workout_session_id: UUID


class FatigueEventCreate(FatigueEventBase):
    pass


class FatigueEventResponse(FatigueEventBase):
    id: UUID
    muscle_group: Optional[MuscleGroupResponse] = None

    model_config = ConfigDict(from_attributes=True)


# PR Record schemas
class PRRecordBase(BaseModel):
    exercise_id: UUID
    weight: Decimal
    reps: int
    estimated_max: Optional[Decimal] = None
    achieved_at: datetime


class PRRecordCreate(PRRecordBase):
    pass


class PRRecordResponse(PRRecordBase):
    id: UUID
    user_id: UUID
    exercise: Optional[ExerciseResponse] = None

    model_config = ConfigDict(from_attributes=True)


# Template schemas
class TemplateBase(BaseModel):
    name: str
    description: Optional[str] = None
    exercise_order: List[UUID] = Field(..., description="List of exercise IDs in order")
    is_public: bool = False


class TemplateCreate(TemplateBase):
    pass


class TemplateUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    exercise_order: Optional[List[UUID]] = None
    is_public: Optional[bool] = None


class TemplateResponse(TemplateBase):
    id: UUID
    user_id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
