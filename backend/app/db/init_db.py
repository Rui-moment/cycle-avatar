from sqlalchemy.orm import Session
from app.db.database import engine, Base
from app.models.user import User  # Import all models to ensure they're registered
from app.models.workout import (
    Exercise, MuscleGroup, WorkoutSession, Set, 
    FatigueEvent, RecoveryState, PRRecord, Template
)

def create_tables():
    """Create all database tables."""
    Base.metadata.create_all(bind=engine)

def init_db():
    """Initialize database with tables."""
    create_tables()
    print("Database tables created successfully!")

if __name__ == "__main__":
    init_db()