from sqlalchemy import Column, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base
import uuid
import os

Base = declarative_base()


# Use String for SQLite, UUID for PostgreSQL
def get_uuid_column():
    """Get appropriate UUID column type based on database."""
    database_url = os.getenv("DATABASE_URL", "sqlite:///./cycleavatar.db")
    if database_url.startswith("sqlite"):
        return Column(
            String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
        )
    else:
        return Column(
            UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True
        )


def get_uuid_foreign_key(table_name: str, column_name: str = "id"):
    """Get appropriate UUID foreign key column type based on database."""
    database_url = os.getenv("DATABASE_URL", "sqlite:///./cycleavatar.db")
    if database_url.startswith("sqlite"):
        return Column(String(36), nullable=False, index=True)
    else:
        return Column(UUID(as_uuid=True), nullable=False, index=True)
