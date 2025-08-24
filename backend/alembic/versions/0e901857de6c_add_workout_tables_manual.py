"""add_workout_tables_manual

Revision ID: 0e901857de6c
Revises: 0e53cb98f524
Create Date: 2025-08-23 13:34:33.924183

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy import String


# revision identifiers, used by Alembic.
revision = '0e901857de6c'
down_revision = '0e53cb98f524'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create exercises table
    op.create_table('exercises',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('name_en', sa.String(), nullable=False),
        sa.Column('name_ja', sa.String(), nullable=False),
        sa.Column('category', sa.String(), nullable=False),
        sa.Column('equipment', sa.String(), nullable=True),
        sa.Column('instructions', sa.Text(), nullable=True),
        sa.Column('is_compound', sa.Boolean(), nullable=False, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_exercises_id'), 'exercises', ['id'], unique=False)
    
    # Create muscle_groups table
    op.create_table('muscle_groups',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('name_en', sa.String(), nullable=False),
        sa.Column('name_ja', sa.String(), nullable=False),
        sa.Column('recovery_tau', sa.Numeric(5, 2), nullable=False),
        sa.Column('fatigue_multiplier', sa.Numeric(3, 2), nullable=False),
        sa.Column('body_region', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_muscle_groups_id'), 'muscle_groups', ['id'], unique=False)
    
    # Create workout_sessions table
    op.create_table('workout_sessions',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('start_time', sa.DateTime(timezone=True), nullable=False),
        sa.Column('end_time', sa.DateTime(timezone=True), nullable=True),
        sa.Column('session_type', sa.String(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('is_synced', sa.Boolean(), nullable=False, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_workout_sessions_id'), 'workout_sessions', ['id'], unique=False)
    op.create_index(op.f('ix_workout_sessions_user_id'), 'workout_sessions', ['user_id'], unique=False)
    
    # Create sets table
    op.create_table('sets',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('session_id', sa.String(36), sa.ForeignKey('workout_sessions.id'), nullable=False),
        sa.Column('exercise_id', sa.String(36), sa.ForeignKey('exercises.id'), nullable=False),
        sa.Column('weight', sa.Numeric(6, 2), nullable=False),
        sa.Column('reps', sa.Integer(), nullable=False),
        sa.Column('rpe', sa.Integer(), nullable=True),
        sa.Column('rest_seconds', sa.Integer(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('set_order', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_sets_id'), 'sets', ['id'], unique=False)
    op.create_index(op.f('ix_sets_session_id'), 'sets', ['session_id'], unique=False)
    op.create_index(op.f('ix_sets_exercise_id'), 'sets', ['exercise_id'], unique=False)
    
    # Create fatigue_events table
    op.create_table('fatigue_events',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('muscle_group_id', sa.String(36), sa.ForeignKey('muscle_groups.id'), nullable=False),
        sa.Column('fatigue_score', sa.Numeric(8, 2), nullable=False),
        sa.Column('timestamp', sa.DateTime(timezone=True), nullable=False),
        sa.Column('workout_session_id', sa.String(36), sa.ForeignKey('workout_sessions.id'), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_fatigue_events_id'), 'fatigue_events', ['id'], unique=False)
    op.create_index(op.f('ix_fatigue_events_muscle_group_id'), 'fatigue_events', ['muscle_group_id'], unique=False)
    op.create_index(op.f('ix_fatigue_events_workout_session_id'), 'fatigue_events', ['workout_session_id'], unique=False)
    
    # Create recovery_states table
    op.create_table('recovery_states',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('muscle_group_id', sa.String(36), sa.ForeignKey('muscle_groups.id'), nullable=False),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('current_fatigue', sa.Numeric(8, 2), nullable=False, default=0),
        sa.Column('last_updated', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('readiness_level', sa.String(), nullable=False, default='ready'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_recovery_states_id'), 'recovery_states', ['id'], unique=False)
    op.create_index(op.f('ix_recovery_states_muscle_group_id'), 'recovery_states', ['muscle_group_id'], unique=False)
    op.create_index(op.f('ix_recovery_states_user_id'), 'recovery_states', ['user_id'], unique=False)
    
    # Create pr_records table
    op.create_table('pr_records',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('exercise_id', sa.String(36), sa.ForeignKey('exercises.id'), nullable=False),
        sa.Column('weight', sa.Numeric(6, 2), nullable=False),
        sa.Column('reps', sa.Integer(), nullable=False),
        sa.Column('estimated_max', sa.Numeric(6, 2), nullable=True),
        sa.Column('achieved_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_pr_records_id'), 'pr_records', ['id'], unique=False)
    op.create_index(op.f('ix_pr_records_user_id'), 'pr_records', ['user_id'], unique=False)
    op.create_index(op.f('ix_pr_records_exercise_id'), 'pr_records', ['exercise_id'], unique=False)
    
    # Create templates table
    op.create_table('templates',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('exercise_order', JSON(), nullable=False),
        sa.Column('is_public', sa.Boolean(), nullable=False, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_templates_id'), 'templates', ['id'], unique=False)
    op.create_index(op.f('ix_templates_user_id'), 'templates', ['user_id'], unique=False)


def downgrade() -> None:
    # Drop tables in reverse order
    op.drop_table('templates')
    op.drop_table('pr_records')
    op.drop_table('recovery_states')
    op.drop_table('fatigue_events')
    op.drop_table('sets')
    op.drop_table('workout_sessions')
    op.drop_table('muscle_groups')
    op.drop_table('exercises')