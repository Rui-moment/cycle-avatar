from app.db.database import engine, Base


def create_tables():
    """Create all database tables."""
    Base.metadata.create_all(bind=engine)


def init_db():
    """Initialize database with tables."""
    create_tables()
    print("Database tables created successfully!")


if __name__ == "__main__":
    init_db()
