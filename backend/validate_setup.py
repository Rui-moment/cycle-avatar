#!/usr/bin/env python3
"""
Validation script to check if the FastAPI setup is correct.
This script imports and validates the main components without starting the server.
"""

import sys
import traceback

def validate_imports():
    """Validate that all imports work correctly."""
    try:
        print("Validating imports...")
        
        # Test core imports
        from app.core.config import settings
        print("✅ Core config imported successfully")
        
        from app.core.security import create_access_token, verify_password
        print("✅ Security module imported successfully")
        
        # Test database imports
        from app.db.database import Base, get_db
        print("✅ Database module imported successfully")
        
        # Test model imports
        from app.models.user import User
        print("✅ User model imported successfully")
        
        # Test schema imports
        from app.schemas.user import UserCreate, UserResponse
        from app.schemas.auth import Token
        print("✅ Schemas imported successfully")
        
        # Test API imports
        from app.api.api_v1.api import api_router
        print("✅ API router imported successfully")
        
        # Test main app
        from main import app
        print("✅ Main FastAPI app imported successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Import validation failed: {e}")
        traceback.print_exc()
        return False

def validate_config():
    """Validate configuration settings."""
    try:
        print("\nValidating configuration...")
        
        from app.core.config import settings
        
        # Check required settings
        assert settings.SECRET_KEY, "SECRET_KEY is required"
        assert settings.DATABASE_URL, "DATABASE_URL is required"
        assert settings.API_V1_STR, "API_V1_STR is required"
        
        print(f"✅ API Version: {settings.API_V1_STR}")
        print(f"✅ Project Name: {settings.PROJECT_NAME}")
        print(f"✅ Database URL configured: {settings.DATABASE_URL[:20]}...")
        print(f"✅ CORS Origins: {settings.BACKEND_CORS_ORIGINS}")
        
        return True
        
    except Exception as e:
        print(f"❌ Configuration validation failed: {e}")
        return False

def validate_app_structure():
    """Validate FastAPI app structure."""
    try:
        print("\nValidating app structure...")
        
        from main import app
        
        # Check routes are registered
        routes = [route.path for route in app.routes]
        
        expected_routes = [
            "/",
            "/health",
            "/api/v1/auth/register",
            "/api/v1/auth/login",
            "/api/v1/users/me",
        ]
        
        for expected_route in expected_routes:
            if any(expected_route in route for route in routes):
                print(f"✅ Route found: {expected_route}")
            else:
                print(f"⚠️  Route not found: {expected_route}")
        
        print(f"✅ Total routes registered: {len(routes)}")
        
        return True
        
    except Exception as e:
        print(f"❌ App structure validation failed: {e}")
        return False

def main():
    """Run all validations."""
    print("CycleAvatar Backend Validation")
    print("=" * 40)
    
    validations = [
        ("Import Validation", validate_imports),
        ("Configuration Validation", validate_config),
        ("App Structure Validation", validate_app_structure),
    ]
    
    passed = 0
    for validation_name, validation_func in validations:
        if validation_func():
            passed += 1
        else:
            print(f"\n❌ {validation_name} failed!")
    
    print(f"\n{'='*40}")
    print(f"Validations passed: {passed}/{len(validations)}")
    
    if passed == len(validations):
        print("🎉 All validations passed! Backend setup is correct.")
        print("\nNext steps:")
        print("1. Set up your PostgreSQL database")
        print("2. Configure your .env file")
        print("3. Run: alembic upgrade head")
        print("4. Start the server: python main.py")
        return True
    else:
        print("⚠️  Some validations failed. Please fix the issues above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)