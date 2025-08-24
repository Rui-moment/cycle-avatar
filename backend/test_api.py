#!/usr/bin/env python3
"""
Simple test script to verify the FastAPI server is working.
Run this after starting the server with: python main.py
"""

import requests
import json

BASE_URL = "http://localhost:8000"

def test_health_check():
    """Test health check endpoint."""
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"Health check: {response.status_code} - {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return False

def test_root_endpoint():
    """Test root endpoint."""
    try:
        response = requests.get(f"{BASE_URL}/")
        print(f"Root endpoint: {response.status_code} - {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Root endpoint failed: {e}")
        return False

def test_openapi_docs():
    """Test OpenAPI documentation endpoint."""
    try:
        response = requests.get(f"{BASE_URL}/api/v1/openapi.json")
        print(f"OpenAPI docs: {response.status_code}")
        return response.status_code == 200
    except Exception as e:
        print(f"OpenAPI docs failed: {e}")
        return False

if __name__ == "__main__":
    print("Testing CycleAvatar API...")
    print("=" * 40)
    
    tests = [
        ("Health Check", test_health_check),
        ("Root Endpoint", test_root_endpoint),
        ("OpenAPI Docs", test_openapi_docs),
    ]
    
    passed = 0
    for test_name, test_func in tests:
        print(f"\nTesting {test_name}...")
        if test_func():
            print(f"✅ {test_name} passed")
            passed += 1
        else:
            print(f"❌ {test_name} failed")
    
    print(f"\n{'='*40}")
    print(f"Tests passed: {passed}/{len(tests)}")
    
    if passed == len(tests):
        print("🎉 All basic tests passed! FastAPI server is working correctly.")
    else:
        print("⚠️  Some tests failed. Check the server configuration.")