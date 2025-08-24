#!/usr/bin/env python3
"""
Comprehensive test script for User Management API endpoints.
Tests user registration, login, profile management, and password reset functionality.
"""

import requests
import json
import time
from typing import Dict, Any

BASE_URL = "http://localhost:8000/api/v1"

class UserManagementAPITester:
    def __init__(self):
        self.base_url = BASE_URL
        self.test_user_data = {
            "email": "test@cycleavatar.com",
            "password": "TestPassword123!",
            "display_name": "Test User",
            "preferred_language": "en"
        }
        self.access_token = None
        self.refresh_token = None
        self.user_id = None
        
    def test_user_registration(self) -> bool:
        """Test user registration endpoint."""
        print("Testing user registration...")
        
        try:
            response = requests.post(
                f"{self.base_url}/auth/register",
                json=self.test_user_data
            )
            
            if response.status_code == 201:
                user_data = response.json()
                self.user_id = user_data.get("id")
                print(f"✅ User registration successful: {user_data['email']}")
                print(f"   User ID: {self.user_id}")
                print(f"   Display Name: {user_data['display_name']}")
                return True
            elif response.status_code == 400 and "already registered" in response.json().get("detail", ""):
                print("⚠️  User already exists, continuing with login test...")
                return True
            else:
                print(f"❌ Registration failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Registration error: {e}")
            return False
    
    def test_user_login(self) -> bool:
        """Test user login endpoint."""
        print("Testing user login...")
        
        try:
            # FastAPI OAuth2PasswordRequestForm expects form data
            login_data = {
                "username": self.test_user_data["email"],  # OAuth2 uses 'username' field
                "password": self.test_user_data["password"]
            }
            
            response = requests.post(
                f"{self.base_url}/auth/login",
                data=login_data  # Use data for form submission
            )
            
            if response.status_code == 200:
                token_data = response.json()
                self.access_token = token_data["access_token"]
                self.refresh_token = token_data["refresh_token"]
                print(f"✅ Login successful")
                print(f"   Token type: {token_data['token_type']}")
                print(f"   Access token: {self.access_token[:20]}...")
                return True
            else:
                print(f"❌ Login failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Login error: {e}")
            return False
    
    def test_get_user_profile(self) -> bool:
        """Test get current user profile endpoint."""
        print("Testing get user profile...")
        
        if not self.access_token:
            print("❌ No access token available")
            return False
        
        try:
            headers = {"Authorization": f"Bearer {self.access_token}"}
            response = requests.get(f"{self.base_url}/users/me", headers=headers)
            
            if response.status_code == 200:
                profile_data = response.json()
                print(f"✅ Profile retrieved successfully")
                print(f"   Email: {profile_data['email']}")
                print(f"   Display Name: {profile_data['display_name']}")
                print(f"   Language: {profile_data['preferred_language']}")
                print(f"   Active: {profile_data['is_active']}")
                return True
            else:
                print(f"❌ Profile retrieval failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Profile retrieval error: {e}")
            return False
    
    def test_update_user_profile(self) -> bool:
        """Test update user profile endpoint."""
        print("Testing update user profile...")
        
        if not self.access_token:
            print("❌ No access token available")
            return False
        
        try:
            headers = {"Authorization": f"Bearer {self.access_token}"}
            update_data = {
                "display_name": "Updated Test User",
                "preferred_language": "ja"
            }
            
            response = requests.put(
                f"{self.base_url}/users/me",
                json=update_data,
                headers=headers
            )
            
            if response.status_code == 200:
                updated_profile = response.json()
                print(f"✅ Profile updated successfully")
                print(f"   New Display Name: {updated_profile['display_name']}")
                print(f"   New Language: {updated_profile['preferred_language']}")
                return True
            else:
                print(f"❌ Profile update failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Profile update error: {e}")
            return False
    
    def test_change_password(self) -> bool:
        """Test change password endpoint."""
        print("Testing change password...")
        
        if not self.access_token:
            print("❌ No access token available")
            return False
        
        try:
            headers = {"Authorization": f"Bearer {self.access_token}"}
            password_data = {
                "current_password": self.test_user_data["password"],
                "new_password": "NewTestPassword123!"
            }
            
            response = requests.post(
                f"{self.base_url}/users/me/change-password",
                json=password_data,
                headers=headers
            )
            
            if response.status_code == 200:
                print(f"✅ Password changed successfully")
                # Update our test data for future tests
                self.test_user_data["password"] = password_data["new_password"]
                return True
            else:
                print(f"❌ Password change failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Password change error: {e}")
            return False
    
    def test_token_refresh(self) -> bool:
        """Test token refresh endpoint."""
        print("Testing token refresh...")
        
        if not self.refresh_token:
            print("❌ No refresh token available")
            return False
        
        try:
            refresh_data = {"refresh_token": self.refresh_token}
            response = requests.post(
                f"{self.base_url}/auth/refresh",
                json=refresh_data
            )
            
            if response.status_code == 200:
                token_data = response.json()
                old_access_token = self.access_token[:20] if self.access_token else "None"
                self.access_token = token_data["access_token"]
                self.refresh_token = token_data["refresh_token"]
                new_access_token = self.access_token[:20]
                
                print(f"✅ Token refresh successful")
                print(f"   Old token: {old_access_token}...")
                print(f"   New token: {new_access_token}...")
                return True
            else:
                print(f"❌ Token refresh failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Token refresh error: {e}")
            return False
    
    def test_password_reset_request(self) -> bool:
        """Test password reset request endpoint."""
        print("Testing password reset request...")
        
        try:
            reset_request = {"email": self.test_user_data["email"]}
            response = requests.post(
                f"{self.base_url}/auth/password-reset-request",
                json=reset_request
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Password reset request successful")
                print(f"   Message: {result['message']}")
                
                # In development, the token is returned in response
                if "reset_token" in result:
                    print(f"   Reset token: {result['reset_token'][:20]}...")
                    return result["reset_token"]
                return True
            else:
                print(f"❌ Password reset request failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Password reset request error: {e}")
            return False
    
    def test_password_reset(self, reset_token: str) -> bool:
        """Test password reset endpoint."""
        print("Testing password reset...")
        
        try:
            reset_data = {
                "token": reset_token,
                "new_password": "ResetPassword123!"
            }
            
            response = requests.post(
                f"{self.base_url}/auth/password-reset",
                json=reset_data
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Password reset successful")
                print(f"   Message: {result['message']}")
                # Update our test data
                self.test_user_data["password"] = reset_data["new_password"]
                return True
            else:
                print(f"❌ Password reset failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Password reset error: {e}")
            return False
    
    def test_user_statistics(self) -> bool:
        """Test get user statistics endpoint."""
        print("Testing user statistics...")
        
        if not self.access_token:
            print("❌ No access token available")
            return False
        
        try:
            headers = {"Authorization": f"Bearer {self.access_token}"}
            response = requests.get(f"{self.base_url}/users/me/stats", headers=headers)
            
            if response.status_code == 200:
                stats = response.json()
                print(f"✅ User statistics retrieved successfully")
                print(f"   Account created: {stats['account_created']}")
                print(f"   Account age (days): {stats['account_age_days']}")
                print(f"   Login count: {stats['login_count']}")
                print(f"   Last login: {stats['last_login']}")
                return True
            else:
                print(f"❌ User statistics failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ User statistics error: {e}")
            return False
    
    def test_logout(self) -> bool:
        """Test logout endpoint."""
        print("Testing logout...")
        
        if not self.access_token:
            print("❌ No access token available")
            return False
        
        try:
            headers = {"Authorization": f"Bearer {self.access_token}"}
            response = requests.post(f"{self.base_url}/auth/logout", headers=headers)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Logout successful")
                print(f"   Message: {result['message']}")
                return True
            else:
                print(f"❌ Logout failed: {response.status_code} - {response.json()}")
                return False
                
        except Exception as e:
            print(f"❌ Logout error: {e}")
            return False
    
    def run_all_tests(self):
        """Run all user management API tests."""
        print("🚀 Starting User Management API Tests")
        print("=" * 50)
        
        tests = [
            ("User Registration", self.test_user_registration),
            ("User Login", self.test_user_login),
            ("Get User Profile", self.test_get_user_profile),
            ("Update User Profile", self.test_update_user_profile),
            ("User Statistics", self.test_user_statistics),
            ("Token Refresh", self.test_token_refresh),
            ("Change Password", self.test_change_password),
        ]
        
        passed = 0
        failed_tests = []
        
        for test_name, test_func in tests:
            print(f"\n{'='*20} {test_name} {'='*20}")
            try:
                if test_func():
                    passed += 1
                else:
                    failed_tests.append(test_name)
            except Exception as e:
                print(f"❌ {test_name} crashed: {e}")
                failed_tests.append(test_name)
            
            # Small delay between tests
            time.sleep(0.5)
        
        # Test password reset flow
        print(f"\n{'='*20} Password Reset Flow {'='*20}")
        try:
            reset_token = self.test_password_reset_request()
            if reset_token and isinstance(reset_token, str):
                if self.test_password_reset(reset_token):
                    passed += 1
                else:
                    failed_tests.append("Password Reset")
            else:
                failed_tests.append("Password Reset Flow")
        except Exception as e:
            print(f"❌ Password Reset Flow crashed: {e}")
            failed_tests.append("Password Reset Flow")
        
        # Test logout
        print(f"\n{'='*20} Logout {'='*20}")
        try:
            if self.test_logout():
                passed += 1
            else:
                failed_tests.append("Logout")
        except Exception as e:
            print(f"❌ Logout crashed: {e}")
            failed_tests.append("Logout")
        
        # Summary
        total_tests = len(tests) + 2  # +2 for password reset flow and logout
        print(f"\n{'='*50}")
        print(f"📊 Test Results Summary")
        print(f"{'='*50}")
        print(f"Total tests: {total_tests}")
        print(f"Passed: {passed}")
        print(f"Failed: {total_tests - passed}")
        
        if failed_tests:
            print(f"\n❌ Failed tests:")
            for test in failed_tests:
                print(f"   - {test}")
        
        if passed == total_tests:
            print(f"\n🎉 All User Management API tests passed!")
            print(f"✅ User registration, login, profile management, and password reset are working correctly.")
        else:
            print(f"\n⚠️  Some tests failed. Check the server logs and configuration.")
        
        return passed == total_tests

def main():
    """Main function to run the tests."""
    print("CycleAvatar User Management API Test Suite")
    print("Make sure the FastAPI server is running on http://localhost:8000")
    print()
    
    # Check if server is running
    try:
        response = requests.get("http://localhost:8000/health")
        if response.status_code != 200:
            print("❌ Server health check failed. Make sure the server is running.")
            return
    except Exception as e:
        print(f"❌ Cannot connect to server: {e}")
        print("Please start the server with: python backend/main.py")
        return
    
    # Run tests
    tester = UserManagementAPITester()
    tester.run_all_tests()

if __name__ == "__main__":
    main()