#!/usr/bin/env python3
"""
Comprehensive test script for User Management API endpoints.
Tests user registration, login, profile management, and password operations.
"""

import requests
import json
import time
from typing import Dict, Any

BASE_URL = "http://localhost:8000/api/v1"

class UserManagementTester:
    def __init__(self):
        self.access_token = None
        self.refresh_token = None
        self.test_user_email = f"test_user_{int(time.time())}@example.com"
        self.test_user_password = "TestPassword123!"
        self.test_user_display_name = "Test User"
        
    def make_request(self, method: str, endpoint: str, data: Dict[Any, Any] = None, 
                    headers: Dict[str, str] = None, use_auth: bool = False) -> requests.Response:
        """Make HTTP request with optional authentication."""
        url = f"{BASE_URL}{endpoint}"
        request_headers = headers or {}
        
        if use_auth and self.access_token:
            request_headers["Authorization"] = f"Bearer {self.access_token}"
        
        if method.upper() == "GET":
            return requests.get(url, headers=request_headers)
        elif method.upper() == "POST":
            return requests.post(url, json=data, headers=request_headers)
        elif method.upper() == "PUT":
            return requests.put(url, json=data, headers=request_headers)
        elif method.upper() == "DELETE":
            return requests.delete(url, headers=request_headers)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
    
    def test_user_registration(self) -> bool:
        """Test user registration endpoint."""
        print("Testing user registration...")
        
        user_data = {
            "email": self.test_user_email,
            "password": self.test_user_password,
            "display_name": self.test_user_display_name,
            "preferred_language": "en"
        }
        
        response = self.make_request("POST", "/auth/register", user_data)
        
        if response.status_code == 201:
            user_info = response.json()
            print(f"✅ User registered successfully: {user_info['email']}")
            return True
        else:
            print(f"❌ Registration failed: {response.status_code} - {response.text}")
            return False
    
    def test_user_login(self) -> bool:
        """Test user login endpoint."""
        print("Testing user login...")
        
        # FastAPI OAuth2PasswordRequestForm expects form data
        login_data = {
            "username": self.test_user_email,  # OAuth2 uses 'username' field
            "password": self.test_user_password
        }
        
        # Send as form data, not JSON
        response = requests.post(
            f"{BASE_URL}/auth/login",
            data=login_data,  # Use data instead of json
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code == 200:
            token_data = response.json()
            self.access_token = token_data["access_token"]
            self.refresh_token = token_data["refresh_token"]
            print(f"✅ Login successful, token type: {token_data['token_type']}")
            return True
        else:
            print(f"❌ Login failed: {response.status_code} - {response.text}")
            return False
    
    def test_get_user_profile(self) -> bool:
        """Test getting current user profile."""
        print("Testing get user profile...")
        
        response = self.make_request("GET", "/users/me", use_auth=True)
        
        if response.status_code == 200:
            profile = response.json()
            print(f"✅ Profile retrieved: {profile['display_name']} ({profile['email']})")
            return True
        else:
            print(f"❌ Get profile failed: {response.status_code} - {response.text}")
            return False
    
    def test_update_user_profile(self) -> bool:
        """Test updating user profile."""
        print("Testing update user profile...")
        
        update_data = {
            "display_name": "Updated Test User",
            "preferred_language": "ja"
        }
        
        response = self.make_request("PUT", "/users/me", update_data, use_auth=True)
        
        if response.status_code == 200:
            updated_profile = response.json()
            print(f"✅ Profile updated: {updated_profile['display_name']}, language: {updated_profile['preferred_language']}")
            return True
        else:
            print(f"❌ Update profile failed: {response.status_code} - {response.text}")
            return False
    
    def test_change_password(self) -> bool:
        """Test changing user password."""
        print("Testing change password...")
        
        new_password = "NewTestPassword456!"
        password_data = {
            "current_password": self.test_user_password,
            "new_password": new_password
        }
        
        response = self.make_request("POST", "/users/me/change-password", password_data, use_auth=True)
        
        if response.status_code == 200:
            print("✅ Password changed successfully")
            # Update password for future tests
            self.test_user_password = new_password
            return True
        else:
            print(f"❌ Change password failed: {response.status_code} - {response.text}")
            return False
    
    def test_token_refresh(self) -> bool:
        """Test token refresh functionality."""
        print("Testing token refresh...")
        
        refresh_data = {
            "refresh_token": self.refresh_token
        }
        
        response = self.make_request("POST", "/auth/refresh", refresh_data)
        
        if response.status_code == 200:
            token_data = response.json()
            self.access_token = token_data["access_token"]
            self.refresh_token = token_data["refresh_token"]
            print("✅ Token refreshed successfully")
            return True
        else:
            print(f"❌ Token refresh failed: {response.status_code} - {response.text}")
            return False
    
    def test_user_statistics(self) -> bool:
        """Test getting user statistics."""
        print("Testing user statistics...")
        
        response = self.make_request("GET", "/users/me/stats", use_auth=True)
        
        if response.status_code == 200:
            stats = response.json()
            print(f"✅ Statistics retrieved: Login count: {stats['login_count']}, Account age: {stats['account_age_days']} days")
            return True
        else:
            print(f"❌ Get statistics failed: {response.status_code} - {response.text}")
            return False
    
    def test_password_reset_request(self) -> bool:
        """Test password reset request."""
        print("Testing password reset request...")
        
        reset_request = {
            "email": self.test_user_email
        }
        
        response = self.make_request("POST", "/auth/password-reset-request", reset_request)
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Password reset request successful")
            # In development, the token is returned in response
            if "reset_token" in result:
                return self.test_password_reset(result["reset_token"])
            return True
        else:
            print(f"❌ Password reset request failed: {response.status_code} - {response.text}")
            return False
    
    def test_password_reset(self, reset_token: str) -> bool:
        """Test password reset with token."""
        print("Testing password reset with token...")
        
        new_password = "ResetPassword789!"
        reset_data = {
            "token": reset_token,
            "new_password": new_password
        }
        
        response = self.make_request("POST", "/auth/password-reset", reset_data)
        
        if response.status_code == 200:
            print("✅ Password reset successful")
            self.test_user_password = new_password
            return True
        else:
            print(f"❌ Password reset failed: {response.status_code} - {response.text}")
            return False
    
    def test_logout(self) -> bool:
        """Test user logout."""
        print("Testing user logout...")
        
        response = self.make_request("POST", "/auth/logout", use_auth=True)
        
        if response.status_code == 200:
            print("✅ Logout successful")
            return True
        else:
            print(f"❌ Logout failed: {response.status_code} - {response.text}")
            return False
    
    def test_duplicate_registration(self) -> bool:
        """Test that duplicate email registration is prevented."""
        print("Testing duplicate registration prevention...")
        
        user_data = {
            "email": self.test_user_email,  # Same email as before
            "password": "AnotherPassword123!",
            "display_name": "Another User",
            "preferred_language": "en"
        }
        
        response = self.make_request("POST", "/auth/register", user_data)
        
        if response.status_code == 400:
            print("✅ Duplicate registration correctly prevented")
            return True
        else:
            print(f"❌ Duplicate registration not prevented: {response.status_code}")
            return False
    
    def run_all_tests(self) -> None:
        """Run all user management tests."""
        print("🚀 Starting User Management API Tests")
        print("=" * 50)
        
        tests = [
            ("User Registration", self.test_user_registration),
            ("User Login", self.test_user_login),
            ("Get User Profile", self.test_get_user_profile),
            ("Update User Profile", self.test_update_user_profile),
            ("User Statistics", self.test_user_statistics),
            ("Change Password", self.test_change_password),
            ("Token Refresh", self.test_token_refresh),
            ("Password Reset Request", self.test_password_reset_request),
            ("User Logout", self.test_logout),
            ("Duplicate Registration Prevention", self.test_duplicate_registration),
        ]
        
        passed = 0
        failed_tests = []
        
        for test_name, test_func in tests:
            print(f"\n--- {test_name} ---")
            try:
                if test_func():
                    passed += 1
                else:
                    failed_tests.append(test_name)
            except Exception as e:
                print(f"❌ {test_name} failed with exception: {e}")
                failed_tests.append(test_name)
            
            # Small delay between tests
            time.sleep(0.5)
        
        print(f"\n{'='*50}")
        print(f"Tests Results: {passed}/{len(tests)} passed")
        
        if failed_tests:
            print(f"Failed tests: {', '.join(failed_tests)}")
        
        if passed == len(tests):
            print("🎉 All User Management API tests passed!")
        else:
            print("⚠️  Some tests failed. Check the implementation.")

def main():
    """Main test runner."""
    print("User Management API Test Suite")
    print("Make sure the FastAPI server is running on localhost:8000")
    print()
    
    # Test basic connectivity first
    try:
        response = requests.get(f"{BASE_URL.replace('/api/v1', '')}/health")
        if response.status_code != 200:
            print("❌ Server health check failed. Make sure the server is running.")
            return
        print("✅ Server is running and healthy")
    except Exception as e:
        print(f"❌ Cannot connect to server: {e}")
        print("Make sure to start the server with: python backend/main.py")
        return
    
    # Run the tests
    tester = UserManagementTester()
    tester.run_all_tests()

if __name__ == "__main__":
    main()