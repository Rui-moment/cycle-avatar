from fastapi import APIRouter
from app.api.api_v1.endpoints import auth, users, workouts

api_router = APIRouter()

# Include endpoint routers
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(workouts.router, prefix="/workouts", tags=["workouts"])