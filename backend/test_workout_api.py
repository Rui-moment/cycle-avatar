#!/usr/bin/env python3
"""
Test script for workout data sync API endpoints.
This script tests the basic functionality of the workout API.
"""

import requests
import json
from datetime import datetime, timezone
from decimal import Decimal
import uuid

# Configuration
BASE_URL = "http://localhost:8000/api/v1"
TEST_EMAIL = "test@example.com"
TEST_PASSWORD = "testpassword123"

def test_workout_api():
    """Test the workout API endpoints."""
    print("🧪 Testing Workout Data Sync API")
    
    # Step 1: Register and login
    print("\n1. Registering test user...")
    register_data = {
        "email": TEST_EMAIL,
        "password": TEST_PASSWORD,
        "display_name": "Test User"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/auth/register", json=register_data)
        if response.status_code == 409:
            print("   User already exists, proceeding to login...")
        elif response.status_code == 201:
            print("   ✅ User registered successfully")
        else:
            print(f"   ❌ Registration failed: {response.status_code} - {response.text}")
            return
    except requests.exceptions.ConnectionError:
        print("   ❌ Cannot connect to server. Make sure the backend is running on localhost:8000")
        return
    
    # Login
    print("\n2. Logging in...")
    login_data = {
        "username": TEST_EMAIL,
        "password": TEST_PASSWORD
    }
    
    response = requests.post(f"{BASE_URL}/auth/login", data=login_data)
    if response.status_code != 200:
        print(f"   ❌ Login failed: {response.status_code} - {response.text}")
        return
    
    token_data = response.json()
    access_token = token_data["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}
    print("   ✅ Login successful")
    
    # Step 2: Test exercise endpoints
    print("\n3. Testing exercise endpoints...")
    response = requests.get(f"{BASE_URL}/workouts/exercises", headers=headers)
    if response.status_code == 200:
        exercises = response.json()
        print(f"   ✅ Retrieved {len(exercises)} exercises")
    else:
        print(f"   ❌ Failed to get exercises: {response.status_code}")
    
    # Step 3: Test muscle groups
    print("\n4. Testing muscle groups...")
    response = requests.get(f"{BASE_URL}/workouts/muscle-groups", headers=headers)
    if response.status_code == 200:
        muscle_groups = response.json()
        print(f"   ✅ Retrieved {len(muscle_groups)} muscle groups")
    else:
        print(f"   ❌ Failed to get muscle groups: {response.status_code}")
    
    # Step 4: Create a workout session
    print("\n5. Creating workout session...")
    
    # First, we need to create some test exercises since the database is empty
    print("   Creating test exercise...")
    
    # We'll skip creating exercises for now and just test the session creation with mock data
    session_data = {
        "start_time": datetime.now(timezone.utc).isoformat(),
        "end_time": None,
        "session_type": "strength",
        "notes": "Test workout session",
        "sets": []  # Empty sets for now since we don't have exercises
    }
    
    response = requests.post(f"{BASE_URL}/workouts/sessions", json=session_data, headers=headers)
    if response.status_code == 201:
        session = response.json()
        session_id = session["id"]
        print(f"   ✅ Created workout session: {session_id}")
    else:
        print(f"   ❌ Failed to create session: {response.status_code} - {response.text}")
        return
    
    # Step 5: Get workout sessions
    print("\n6. Retrieving workout sessions...")
    response = requests.get(f"{BASE_URL}/workouts/sessions", headers=headers)
    if response.status_code == 200:
        sessions = response.json()
        print(f"   ✅ Retrieved {len(sessions)} workout sessions")
    else:
        print(f"   ❌ Failed to get sessions: {response.status_code}")
    
    # Step 6: Update workout session
    print("\n7. Updating workout session...")
    update_data = {
        "end_time": datetime.now(timezone.utc).isoformat(),
        "notes": "Updated test workout session"
    }
    
    response = requests.put(f"{BASE_URL}/workouts/sessions/{session_id}", json=update_data, headers=headers)
    if response.status_code == 200:
        print("   ✅ Updated workout session")
    else:
        print(f"   ❌ Failed to update session: {response.status_code}")
    
    # Step 7: Test batch sync endpoint
    print("\n8. Testing batch sync...")
    sync_data = {
        "entities": [],
        "last_sync_timestamp": None,
        "client_id": "test-client"
    }
    
    response = requests.post(f"{BASE_URL}/workouts/sync", json=sync_data, headers=headers)
    if response.status_code == 200:
        sync_result = response.json()
        print(f"   ✅ Batch sync successful: {sync_result['success']}")
    else:
        print(f"   ❌ Batch sync failed: {response.status_code}")
    
    # Step 8: Test recovery states
    print("\n9. Testing recovery states...")
    response = requests.get(f"{BASE_URL}/workouts/recovery-states", headers=headers)
    if response.status_code == 200:
        recovery_states = response.json()
        print(f"   ✅ Retrieved {len(recovery_states)} recovery states")
    else:
        print(f"   ❌ Failed to get recovery states: {response.status_code}")
    
    # Step 9: Test PR records
    print("\n10. Testing PR records...")
    response = requests.get(f"{BASE_URL}/workouts/pr-records", headers=headers)
    if response.status_code == 200:
        pr_records = response.json()
        print(f"   ✅ Retrieved {len(pr_records)} PR records")
    else:
        print(f"   ❌ Failed to get PR records: {response.status_code}")
    
    # Step 10: Test templates
    print("\n11. Testing templates...")
    response = requests.get(f"{BASE_URL}/workouts/templates", headers=headers)
    if response.status_code == 200:
        templates = response.json()
        print(f"   ✅ Retrieved {len(templates)} templates")
    else:
        print(f"   ❌ Failed to get templates: {response.status_code}")
    
    # Step 11: Clean up - delete the test session
    print("\n12. Cleaning up...")
    response = requests.delete(f"{BASE_URL}/workouts/sessions/{session_id}", headers=headers)
    if response.status_code == 204:
        print("   ✅ Deleted test session")
    else:
        print(f"   ❌ Failed to delete session: {response.status_code}")
    
    print("\n🎉 Workout API test completed!")

if __name__ == "__main__":
    test_workout_api()