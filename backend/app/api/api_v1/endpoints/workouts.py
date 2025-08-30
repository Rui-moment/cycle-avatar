from typing import Any, List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import desc, and_

from app.db.database import get_db
from app.models.user import User
from app.models.workout import (
    WorkoutSession,
    Set,
    Exercise,
    MuscleGroup,
    RecoveryState,
    PRRecord,
    Template,
)
from app.api.api_v1.endpoints.auth import get_current_user
from app.schemas.workout import (
    WorkoutSessionCreate,
    WorkoutSessionUpdate,
    WorkoutSessionResponse,
    SetCreate,
    SetUpdate,
    SetResponse,
    ExerciseResponse,
    MuscleGroupResponse,
    BatchSyncRequest,
    BatchSyncResponse,
    SyncEntity,
    SyncConflict,
    RecoveryStateResponse,
    PRRecordCreate,
    PRRecordResponse,
    TemplateCreate,
    TemplateUpdate,
    TemplateResponse,
)

router = APIRouter()


# Workout Session endpoints
@router.get("/sessions", response_model=List[WorkoutSessionResponse])
def get_workout_sessions(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Get user's workout sessions with optional date filtering."""
    query = db.query(WorkoutSession).filter(WorkoutSession.user_id == current_user.id)

    if start_date:
        query = query.filter(WorkoutSession.start_time >= start_date)
    if end_date:
        query = query.filter(WorkoutSession.start_time <= end_date)

    sessions = (
        query.options(joinedload(WorkoutSession.sets).joinedload(Set.exercise))
        .order_by(desc(WorkoutSession.start_time))
        .offset(skip)
        .limit(limit)
        .all()
    )

    return sessions


@router.post(
    "/sessions",
    response_model=WorkoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_workout_session(
    session_data: WorkoutSessionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Create a new workout session with sets."""
    # Create workout session
    db_session = WorkoutSession(
        user_id=current_user.id,
        start_time=session_data.start_time,
        end_time=session_data.end_time,
        session_type=session_data.session_type,
        notes=session_data.notes,
    )
    db.add(db_session)
    db.flush()  # Get the session ID

    # Create sets
    for set_data in session_data.sets:
        # Verify exercise exists
        exercise = (
            db.query(Exercise).filter(Exercise.id == set_data.exercise_id).first()
        )
        if not exercise:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Exercise with id {set_data.exercise_id} not found",
            )

        db_set = Set(
            session_id=db_session.id,
            exercise_id=set_data.exercise_id,
            weight=set_data.weight,
            reps=set_data.reps,
            rpe=set_data.rpe,
            rest_seconds=set_data.rest_seconds,
            notes=set_data.notes,
            set_order=set_data.set_order,
        )
        db.add(db_set)

    db.commit()
    db.refresh(db_session)

    # Load with relationships
    session_with_sets = (
        db.query(WorkoutSession)
        .options(joinedload(WorkoutSession.sets).joinedload(Set.exercise))
        .filter(WorkoutSession.id == db_session.id)
        .first()
    )

    return session_with_sets


@router.get("/sessions/{session_id}", response_model=WorkoutSessionResponse)
def get_workout_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Get a specific workout session."""
    session = (
        db.query(WorkoutSession)
        .options(joinedload(WorkoutSession.sets).joinedload(Set.exercise))
        .filter(
            and_(
                WorkoutSession.id == session_id,
                WorkoutSession.user_id == current_user.id,
            )
        )
        .first()
    )

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Workout session not found"
        )

    return session


@router.put("/sessions/{session_id}", response_model=WorkoutSessionResponse)
def update_workout_session(
    session_id: str,
    session_update: WorkoutSessionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Update a workout session."""
    session = (
        db.query(WorkoutSession)
        .filter(
            and_(
                WorkoutSession.id == session_id,
                WorkoutSession.user_id == current_user.id,
            )
        )
        .first()
    )

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Workout session not found"
        )

    # Update fields
    update_data = session_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(session, field, value)

    session.is_synced = False  # Mark as needing sync
    db.commit()
    db.refresh(session)

    return session


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_workout_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Delete a workout session and all its sets."""
    session = (
        db.query(WorkoutSession)
        .filter(
            and_(
                WorkoutSession.id == session_id,
                WorkoutSession.user_id == current_user.id,
            )
        )
        .first()
    )

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Workout session not found"
        )

    db.delete(session)
    db.commit()


# Set endpoints
@router.post(
    "/sessions/{session_id}/sets",
    response_model=SetResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_set_to_session(
    session_id: str,
    set_data: SetCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Add a set to an existing workout session."""
    # Verify session belongs to user
    session = (
        db.query(WorkoutSession)
        .filter(
            and_(
                WorkoutSession.id == session_id,
                WorkoutSession.user_id == current_user.id,
            )
        )
        .first()
    )

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Workout session not found"
        )

    # Verify exercise exists
    exercise = db.query(Exercise).filter(Exercise.id == set_data.exercise_id).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Exercise with id {set_data.exercise_id} not found",
        )

    db_set = Set(
        session_id=session_id,
        exercise_id=set_data.exercise_id,
        weight=set_data.weight,
        reps=set_data.reps,
        rpe=set_data.rpe,
        rest_seconds=set_data.rest_seconds,
        notes=set_data.notes,
        set_order=set_data.set_order,
    )

    db.add(db_set)
    session.is_synced = False  # Mark session as needing sync
    db.commit()
    db.refresh(db_set)

    # Load with exercise relationship
    set_with_exercise = (
        db.query(Set)
        .options(joinedload(Set.exercise))
        .filter(Set.id == db_set.id)
        .first()
    )

    return set_with_exercise


@router.put("/sets/{set_id}", response_model=SetResponse)
def update_set(
    set_id: str,
    set_update: SetUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Update a set."""
    # Get set and verify ownership through session
    db_set = (
        db.query(Set)
        .join(WorkoutSession)
        .filter(and_(Set.id == set_id, WorkoutSession.user_id == current_user.id))
        .first()
    )

    if not db_set:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Set not found"
        )

    # Update fields
    update_data = set_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_set, field, value)

    # Mark session as needing sync
    db_set.session.is_synced = False
    db.commit()
    db.refresh(db_set)

    return db_set


@router.delete("/sets/{set_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_set(
    set_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Delete a set."""
    # Get set and verify ownership through session
    db_set = (
        db.query(Set)
        .join(WorkoutSession)
        .filter(and_(Set.id == set_id, WorkoutSession.user_id == current_user.id))
        .first()
    )

    if not db_set:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Set not found"
        )

    # Mark session as needing sync
    db_set.session.is_synced = False
    db.delete(db_set)
    db.commit()


# Exercise endpoints
@router.get("/exercises", response_model=List[ExerciseResponse])
def get_exercises(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    category: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
) -> Any:
    """Get exercises with optional filtering."""
    query = db.query(Exercise)

    if category:
        query = query.filter(Exercise.category == category)

    if search:
        query = query.filter(
            (Exercise.name_en.ilike(f"%{search}%"))
            | (Exercise.name_ja.ilike(f"%{search}%"))
        )

    exercises = query.offset(skip).limit(limit).all()
    return exercises


# Muscle Group endpoints
@router.get("/muscle-groups", response_model=List[MuscleGroupResponse])
def get_muscle_groups(db: Session = Depends(get_db)) -> Any:
    """Get all muscle groups."""
    muscle_groups = db.query(MuscleGroup).all()
    return muscle_groups


# Recovery State endpoints
@router.get("/recovery-states", response_model=List[RecoveryStateResponse])
def get_recovery_states(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Any:
    """Get user's current recovery states for all muscle groups."""
    recovery_states = (
        db.query(RecoveryState)
        .options(joinedload(RecoveryState.muscle_group))
        .filter(RecoveryState.user_id == current_user.id)
        .all()
    )

    return recovery_states


# Batch Sync endpoints
@router.post("/sync", response_model=BatchSyncResponse)
def batch_sync(
    sync_request: BatchSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Batch synchronization endpoint for offline-first functionality."""
    synced_entities = []
    conflicts = []
    server_changes = []

    # Process each entity in the sync request
    for entity in sync_request.entities:
        try:
            if entity.entity_type == "session":
                result = _sync_workout_session(entity, current_user.id, db)
            elif entity.entity_type == "set":
                result = _sync_set(entity, current_user.id, db)
            else:
                continue  # Skip unknown entity types

            if result["success"]:
                synced_entities.append(entity.entity_id)
            elif result["conflict"]:
                conflicts.append(result["conflict"])

        except Exception as e:
            # Log error but continue processing other entities
            print(f"Error syncing entity {entity.entity_id}: {str(e)}")
            continue

    # Get server changes since last sync
    if sync_request.last_sync_timestamp:
        server_changes = _get_server_changes_since(
            sync_request.last_sync_timestamp, current_user.id, db
        )

    # Update user's last sync timestamp
    current_user.last_sync_at = datetime.utcnow()
    db.commit()

    return BatchSyncResponse(
        success=len(conflicts) == 0,
        synced_entities=synced_entities,
        conflicts=conflicts,
        server_changes=server_changes,
        last_sync_timestamp=current_user.last_sync_at,
    )


def _sync_workout_session(entity: SyncEntity, user_id: str, db: Session) -> dict:
    """Sync a workout session entity."""
    if entity.action == "create":
        # Check if session already exists (duplicate prevention)
        existing = (
            db.query(WorkoutSession)
            .filter(WorkoutSession.id == entity.entity_id)
            .first()
        )

        if existing:
            # Check for conflicts
            if existing.updated_at > entity.timestamp:
                return {
                    "success": False,
                    "conflict": SyncConflict(
                        entity_type="session",
                        entity_id=entity.entity_id,
                        server_data=_session_to_dict(existing),
                        client_data=entity.data,
                        conflict_fields=["updated_at"],
                    ),
                }
            else:
                # Client data is newer, update existing
                _update_session_from_data(existing, entity.data)
                existing.is_synced = True
                db.commit()
                return {"success": True}
        else:
            # Create new session
            session = WorkoutSession(
                id=entity.entity_id, user_id=user_id, **entity.data
            )
            session.is_synced = True
            db.add(session)
            db.commit()
            return {"success": True}

    elif entity.action == "update":
        session = (
            db.query(WorkoutSession)
            .filter(
                WorkoutSession.id == entity.entity_id, WorkoutSession.user_id == user_id
            )
            .first()
        )

        if not session:
            return {"success": False, "error": "Session not found"}

        # Check for conflicts (server-side changes)
        if session.updated_at > entity.timestamp:
            return {
                "success": False,
                "conflict": SyncConflict(
                    entity_type="session",
                    entity_id=entity.entity_id,
                    server_data=_session_to_dict(session),
                    client_data=entity.data,
                    conflict_fields=["updated_at"],
                ),
            }

        # Apply client priority conflict resolution
        _update_session_from_data(session, entity.data)
        session.is_synced = True
        db.commit()
        return {"success": True}

    elif entity.action == "delete":
        session = (
            db.query(WorkoutSession)
            .filter(
                WorkoutSession.id == entity.entity_id, WorkoutSession.user_id == user_id
            )
            .first()
        )

        if session:
            db.delete(session)
            db.commit()

        return {"success": True}

    return {"success": False, "error": "Unknown action"}


def _sync_set(entity: SyncEntity, user_id: str, db: Session) -> dict:
    """Sync a set entity."""
    if entity.action == "create":
        # Verify session ownership
        session = (
            db.query(WorkoutSession)
            .filter(
                WorkoutSession.id == entity.data.get("session_id"),
                WorkoutSession.user_id == user_id,
            )
            .first()
        )

        if not session:
            return {"success": False, "error": "Session not found or not owned by user"}

        # Check if set already exists
        existing = db.query(Set).filter(Set.id == entity.entity_id).first()

        if existing:
            # Check for conflicts
            if existing.updated_at > entity.timestamp:
                return {
                    "success": False,
                    "conflict": SyncConflict(
                        entity_type="set",
                        entity_id=entity.entity_id,
                        server_data=_set_to_dict(existing),
                        client_data=entity.data,
                        conflict_fields=["updated_at"],
                    ),
                }
            else:
                # Update existing
                _update_set_from_data(existing, entity.data)
                db.commit()
                return {"success": True}
        else:
            # Create new set
            db_set = Set(id=entity.entity_id, **entity.data)
            db.add(db_set)
            session.is_synced = False  # Mark session as modified
            db.commit()
            return {"success": True}

    elif entity.action == "update":
        # Get set and verify ownership through session
        db_set = (
            db.query(Set)
            .join(WorkoutSession)
            .filter(Set.id == entity.entity_id, WorkoutSession.user_id == user_id)
            .first()
        )

        if not db_set:
            return {"success": False, "error": "Set not found"}

        # Check for conflicts
        if db_set.updated_at > entity.timestamp:
            return {
                "success": False,
                "conflict": SyncConflict(
                    entity_type="set",
                    entity_id=entity.entity_id,
                    server_data=_set_to_dict(db_set),
                    client_data=entity.data,
                    conflict_fields=["updated_at"],
                ),
            }

        # Apply client priority
        _update_set_from_data(db_set, entity.data)
        db_set.session.is_synced = False
        db.commit()
        return {"success": True}

    elif entity.action == "delete":
        db_set = (
            db.query(Set)
            .join(WorkoutSession)
            .filter(Set.id == entity.entity_id, WorkoutSession.user_id == user_id)
            .first()
        )

        if db_set:
            db_set.session.is_synced = False
            db.delete(db_set)
            db.commit()

        return {"success": True}

    return {"success": False, "error": "Unknown action"}


def _get_server_changes_since(
    last_sync: datetime, user_id: str, db: Session
) -> List[SyncEntity]:
    """Get server-side changes since last sync timestamp."""
    changes = []

    # Get updated sessions
    updated_sessions = (
        db.query(WorkoutSession)
        .filter(
            WorkoutSession.user_id == user_id, WorkoutSession.updated_at > last_sync
        )
        .all()
    )

    for session in updated_sessions:
        changes.append(
            SyncEntity(
                entity_type="session",
                entity_id=session.id,
                action="update",
                data=_session_to_dict(session),
                timestamp=session.updated_at,
            )
        )

    # Get updated sets
    updated_sets = (
        db.query(Set)
        .join(WorkoutSession)
        .filter(WorkoutSession.user_id == user_id, Set.updated_at > last_sync)
        .all()
    )

    for db_set in updated_sets:
        changes.append(
            SyncEntity(
                entity_type="set",
                entity_id=db_set.id,
                action="update",
                data=_set_to_dict(db_set),
                timestamp=db_set.updated_at,
            )
        )

    return changes


def _session_to_dict(session: WorkoutSession) -> dict:
    """Convert WorkoutSession to dictionary."""
    return {
        "start_time": session.start_time.isoformat(),
        "end_time": session.end_time.isoformat() if session.end_time else None,
        "session_type": session.session_type,
        "notes": session.notes,
        "updated_at": session.updated_at.isoformat(),
    }


def _set_to_dict(db_set: Set) -> dict:
    """Convert Set to dictionary."""
    return {
        "session_id": str(db_set.session_id),
        "exercise_id": str(db_set.exercise_id),
        "weight": float(db_set.weight),
        "reps": db_set.reps,
        "rpe": db_set.rpe,
        "rest_seconds": db_set.rest_seconds,
        "notes": db_set.notes,
        "set_order": db_set.set_order,
        "updated_at": db_set.updated_at.isoformat(),
    }


def _update_session_from_data(session: WorkoutSession, data: dict) -> None:
    """Update session from dictionary data."""
    if "start_time" in data:
        session.start_time = datetime.fromisoformat(data["start_time"])
    if "end_time" in data and data["end_time"]:
        session.end_time = datetime.fromisoformat(data["end_time"])
    if "session_type" in data:
        session.session_type = data["session_type"]
    if "notes" in data:
        session.notes = data["notes"]


def _update_set_from_data(db_set: Set, data: dict) -> None:
    """Update set from dictionary data."""
    if "weight" in data:
        db_set.weight = data["weight"]
    if "reps" in data:
        db_set.reps = data["reps"]
    if "rpe" in data:
        db_set.rpe = data["rpe"]
    if "rest_seconds" in data:
        db_set.rest_seconds = data["rest_seconds"]
    if "notes" in data:
        db_set.notes = data["notes"]
    if "set_order" in data:
        db_set.set_order = data["set_order"]


# Conflict Resolution endpoint
@router.post("/resolve-conflicts")
def resolve_conflicts(
    conflicts: List[SyncConflict],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Resolve sync conflicts using client priority strategy."""
    resolved = []

    for conflict in conflicts:
        try:
            if conflict.entity_type == "session":
                session = (
                    db.query(WorkoutSession)
                    .filter(
                        WorkoutSession.id == conflict.entity_id,
                        WorkoutSession.user_id == current_user.id,
                    )
                    .first()
                )

                if session:
                    _update_session_from_data(session, conflict.client_data)
                    session.is_synced = True
                    resolved.append(conflict.entity_id)

            elif conflict.entity_type == "set":
                db_set = (
                    db.query(Set)
                    .join(WorkoutSession)
                    .filter(
                        Set.id == conflict.entity_id,
                        WorkoutSession.user_id == current_user.id,
                    )
                    .first()
                )

                if db_set:
                    _update_set_from_data(db_set, conflict.client_data)
                    db_set.session.is_synced = False
                    resolved.append(conflict.entity_id)

        except Exception as e:
            print(f"Error resolving conflict for {conflict.entity_id}: {str(e)}")
            continue

    db.commit()

    return {
        "success": True,
        "resolved_conflicts": resolved,
        "message": f"Resolved {len(resolved)} conflicts using client priority",
    }


# PR Records endpoints
@router.get("/pr-records", response_model=List[PRRecordResponse])
def get_pr_records(
    exercise_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Get user's PR records."""
    query = (
        db.query(PRRecord)
        .options(joinedload(PRRecord.exercise))
        .filter(PRRecord.user_id == current_user.id)
    )

    if exercise_id:
        query = query.filter(PRRecord.exercise_id == exercise_id)

    pr_records = query.order_by(desc(PRRecord.achieved_at)).all()
    return pr_records


@router.post(
    "/pr-records", response_model=PRRecordResponse, status_code=status.HTTP_201_CREATED
)
def create_pr_record(
    pr_data: PRRecordCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Create a new PR record."""
    # Verify exercise exists
    exercise = db.query(Exercise).filter(Exercise.id == pr_data.exercise_id).first()
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Exercise not found"
        )

    pr_record = PRRecord(
        user_id=current_user.id,
        exercise_id=pr_data.exercise_id,
        weight=pr_data.weight,
        reps=pr_data.reps,
        estimated_max=pr_data.estimated_max,
        achieved_at=pr_data.achieved_at,
    )

    db.add(pr_record)
    db.commit()
    db.refresh(pr_record)

    # Load with exercise relationship
    pr_with_exercise = (
        db.query(PRRecord)
        .options(joinedload(PRRecord.exercise))
        .filter(PRRecord.id == pr_record.id)
        .first()
    )

    return pr_with_exercise


# Template endpoints
@router.get("/templates", response_model=List[TemplateResponse])
def get_templates(
    include_public: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Get user's workout templates."""
    query = db.query(Template)

    if include_public:
        query = query.filter(
            (Template.user_id == current_user.id) | (Template.is_public.is_(True))
        )
    else:
        query = query.filter(Template.user_id == current_user.id)

    templates = query.order_by(desc(Template.created_at)).all()
    return templates


@router.post(
    "/templates", response_model=TemplateResponse, status_code=status.HTTP_201_CREATED
)
def create_template(
    template_data: TemplateCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Create a new workout template."""
    # Verify all exercises exist
    for exercise_id in template_data.exercise_order:
        exercise = db.query(Exercise).filter(Exercise.id == exercise_id).first()
        if not exercise:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Exercise with id {exercise_id} not found",
            )

    template = Template(
        user_id=current_user.id,
        name=template_data.name,
        description=template_data.description,
        exercise_order=template_data.exercise_order,
        is_public=template_data.is_public,
    )

    db.add(template)
    db.commit()
    db.refresh(template)

    return template


@router.put("/templates/{template_id}", response_model=TemplateResponse)
def update_template(
    template_id: str,
    template_update: TemplateUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Any:
    """Update a workout template."""
    template = (
        db.query(Template)
        .filter(Template.id == template_id, Template.user_id == current_user.id)
        .first()
    )

    if not template:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )

    # Verify exercises if exercise_order is being updated
    if template_update.exercise_order:
        for exercise_id in template_update.exercise_order:
            exercise = db.query(Exercise).filter(Exercise.id == exercise_id).first()
            if not exercise:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Exercise with id {exercise_id} not found",
                )

    # Update fields
    update_data = template_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(template, field, value)

    db.commit()
    db.refresh(template)

    return template


@router.delete("/templates/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_template(
    template_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Delete a workout template."""
    template = (
        db.query(Template)
        .filter(Template.id == template_id, Template.user_id == current_user.id)
        .first()
    )

    if not template:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Template not found"
        )

    db.delete(template)
    db.commit()
